#!/bin/bash
# gamescope-lease.sh — cooperative mutex for nested-gamescope emulation across PARALLEL test agents.
#
# Problem: nested gamescope emulation uses GLOBAL, single-instance resources — the nested XWayland
# display (:1), the `gamescope-0` wayland socket, /tmp/.X<n>-lock, and a systemwide /dev/uinput mouse.
# When two+ test agents run emulation at once they collide: `XIO: fatal IO error 17 (File exists) on
# :1`, gamescopectl grabbing the wrong compositor, black/duplicate captures, and cursor cross-talk.
# gamescope offers no clean per-instance socket isolation, so the robust fix is to SERIALIZE: only one
# agent drives the emulator at a time; the rest queue on an flock. A crashed holder is auto-recovered
# (kernel releases the flock on death; we clean its leftovers on the next acquire).
#
# Usage:
#   scripts/gamescope-lease.sh [-w WAIT_SECS] -- <command to run while holding the emulator>
#   e.g.  scripts/gamescope-lease.sh -- scripts/gamescope-emulate.sh -t 12
#   e.g.  GAMESCOPE_AGENT_ID=clienttest scripts/gamescope-lease.sh -w 600 -- ./my-cycle-driver.sh
# Exit: the wrapped command's exit code, or 75 (EX_TEMPFAIL) if the lease couldn't be acquired in time.
#
# Env: GAMESCOPE_LEASE (lock path, default /tmp/vibemis-gamescope.lease),
#      GAMESCOPE_LEASE_WAIT (default 300s), GAMESCOPE_AGENT_ID (holder label; default user-PID),
#      GAMESCOPE_BUS (hub coordination URL; if set, announces acquire/release for visibility).
set -uo pipefail

LEASE="${GAMESCOPE_LEASE:-/tmp/vibemis-gamescope.lease}"
WAIT="${GAMESCOPE_LEASE_WAIT:-300}"
HOLDER="${GAMESCOPE_AGENT_ID:-$(id -un)-$$}"
XRUN="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

usage(){ sed -n '2,20p' "$0"; exit 2; }
while getopts "w:" o; do case "$o" in w) WAIT="$OPTARG";; *) usage;; esac; done
shift $((OPTIND-1)); [ "$#" -gt 0 ] || usage

# Hardened cleanup — recovers a crashed prior holder. NESTED displays :1-:3 ONLY, never :0 (real desktop).
gs_clean(){
    pkill -9 -x mangoapp >/dev/null 2>&1
    for _ in $(seq 1 15); do
        [ "$(pgrep -fc 'gamescope --backend headless' 2>/dev/null || echo 0)" = "0" ] && break
        for p in $(pgrep -f 'gamescope --backend headless' 2>/dev/null) \
                 $(pgrep -f 'Xwayland.*:[123]\b' 2>/dev/null); do kill -9 "$p" 2>/dev/null; done
        sleep 1
    done
    sleep 1
    for n in 1 2 3; do rm -f "/tmp/.X${n}-lock" "/tmp/.X11-unix/X${n}" 2>/dev/null; done
    rm -f "$XRUN"/gamescope-0 "$XRUN"/gamescope-0.lock 2>/dev/null
}
bus(){ [ -n "${GAMESCOPE_BUS:-}" ] && curl -s -m 5 -X POST "$GAMESCOPE_BUS/api/coordination/announce" \
        -H "Content-Type: application/json" -H "X-Ask-Claude: 1" \
        -d "{\"text\":\"[gamescope-lease] $HOLDER $1\",\"kind\":\"info\"}" >/dev/null 2>&1 || true; }

# Acquire the exclusive lease (fd 9). flock auto-releases if we die → no stale lease from a crash.
exec 9>"$LEASE"
if ! flock -w "$WAIT" 9; then
    echo "gamescope-lease: BUSY — holder=$(cat "$LEASE.holder" 2>/dev/null || echo '?'); waited ${WAIT}s" >&2
    exit 75
fi
echo "$HOLDER @ $(date -u +%FT%TZ)" > "$LEASE.holder" 2>/dev/null || true
trap 'gs_clean; rm -f "$LEASE.holder" 2>/dev/null; bus release' EXIT
bus "acquired (${WAIT}s max wait)"
gs_clean            # start from a clean slate (also recovers any crashed prior holder's leftovers)

"$@"; rc=$?
exit "$rc"
