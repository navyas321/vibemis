#!/bin/bash
# vibepollo-log.sh — tail the Vibepollo host log from the WSL2 build agent (P3.5)
#
# Vibepollo runs on the Windows host; WSL2 can read its logs through /mnt/c once the
# Windows drive is mounted. This script auto-detects the newest Vibepollo log under the
# common Windows locations and tails it, so a build session can watch the server side of
# pairing / clipboard / streaming handshakes in real time.
#
# Usage:
#   ./vibepollo-log.sh            # auto-detect + tail -f the newest log
#   ./vibepollo-log.sh --list     # just list candidate log files found
#   VIBEPOLLO_LOG=/mnt/c/path/to/sunshine.log ./vibepollo-log.sh   # explicit override
#
# If auto-detection fails, set VIBEPOLLO_LOG (or edit CANDIDATES below) and re-run.

set -euo pipefail

# Explicit override wins.
if [ -n "${VIBEPOLLO_LOG:-}" ]; then
    echo "[vibepollo-log] tailing \$VIBEPOLLO_LOG: $VIBEPOLLO_LOG"
    exec tail -n 200 -f "$VIBEPOLLO_LOG"
fi

# Common Windows locations Vibepollo/Apollo/Sunshine write logs to (globbed across users).
# Sunshine-lineage servers typically log to their install/config dir as sunshine.log.
mapfile -t CANDIDATES < <(
    ls -1t \
      /mnt/c/Users/*/AppData/Roaming/Vibepollo/*.log \
      /mnt/c/Users/*/AppData/Roaming/Apollo/*.log \
      /mnt/c/Users/*/AppData/Roaming/Sunshine/*.log \
      /mnt/c/Program*Files*/Vibepollo/config/*.log \
      /mnt/c/Program*Files*/Apollo/config/*.log \
      /mnt/c/Program*Files*/Sunshine/config/*.log \
      /mnt/c/Vibepollo/*.log \
      /mnt/c/Apollo/*.log \
      2>/dev/null || true
)

if [ "${1:-}" = "--list" ]; then
    if [ "${#CANDIDATES[@]}" -eq 0 ]; then
        echo "[vibepollo-log] No candidate logs found under /mnt/c. Is the C: drive mounted in WSL?"
        echo "  Try: ls /mnt/c/Users   (if empty, run 'sudo mount -t drvfs C: /mnt/c')"
        exit 1
    fi
    printf '%s\n' "${CANDIDATES[@]}"
    exit 0
fi

if [ "${#CANDIDATES[@]}" -eq 0 ]; then
    echo "[vibepollo-log] Could not auto-detect a Vibepollo log under /mnt/c." >&2
    echo "  - Confirm the C: drive is mounted:  ls /mnt/c/Users" >&2
    echo "  - Or set the path explicitly:       VIBEPOLLO_LOG=/mnt/c/.../sunshine.log $0" >&2
    echo "  - Then add that path to CLAUDE.md (P3.5) so future sessions can tail it." >&2
    exit 1
fi

NEWEST="${CANDIDATES[0]}"
echo "[vibepollo-log] newest log: $NEWEST"
echo "[vibepollo-log] (override with VIBEPOLLO_LOG=...; --list to see all candidates)"
exec tail -n 200 -f "$NEWEST"
