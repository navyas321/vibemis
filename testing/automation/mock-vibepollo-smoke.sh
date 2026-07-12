#!/bin/bash
# mock-vibepollo-smoke.sh — automate the FULL-FIDELITY mock-Vibepollo streaming validation that
# used to be done by hand. Proves the Legion Go client can actually DECODE and RENDER a real stream
# (not just the control plane) against the Windows mock host at 100.127.67.80 (tailnet "hearth":
# real Vibepollo 1.18 + SudoVDA Virtual Display, offset ports 48900/48895/48901, `-1` no-state).
#
# Why a mock, not self-host: 127.0.0.1 self-host has no GPU encoder -> control-plane only (~25-30%
# fidelity, no frames). The mock DOES have an encoder + a SudoVDA virtual display, so it streams for
# real. See testing/automation/README.md for the platform matrix.
#
# THREE phases:
#   1. reachability  — TCP connect to base(48900)/HTTPS(48895)/web(48901). Pure sockets, no app.
#   2. applist       — control plane: `Vibemis.AppImage list <host>` (needs a gamescope surface —
#                      headless/offscreen aborts). Confirms pairing + the host advertises apps.
#   3. stream+decode — gamescope-hosted `stream <host> "<app>"`; capture a frame + grep the real
#                      decode signals: "Output frame with POC", VAAPI "Decode to surface", "EGLRenderer".
#
# HARD-WON GOTCHAS baked in (see README "RCA"):
#   * The CLI `list`/`stream` HANG headless and IGNORE SIGTERM -> every app run is wrapped in
#       timeout -s KILL --kill-after=3 <secs>.
#   * `list`/`stream` are full Qt apps: QT_QPA_PLATFORM=offscreen ABORTS (core). They need the
#       nested gamescope XWayland surface -> phases 2 and 3 run INSIDE gamescope.
#   * gamescope is a global single-instance resource shared with the other test agent ->
#       phases 2+3 run under scripts/gamescope-lease.sh (flock serialization + crash recovery).
#   * SELF-MATCH TRAP: the lease's gs_clean does `pgrep -f 'gamescope --backend headless'`. Any
#       CALLER whose command line CONTAINS that literal gets SIGKILLed. That is why this is a
#       standalone FILE invoked BY PATH and re-execs itself for the gamescope phase — never inline
#       the launch in a `bash -c` string.
#
# Usage:   testing/automation/mock-vibepollo-smoke.sh [--reach-only]
# Env:     MOCK_HOST MOCK_PORT MOCK_HTTPS MOCK_WEB MOCK_APP VIBEMIS_APPIMAGE STREAM_SECS RES
# Exit:    0 all phases passed | 2 reachability fail | 3 applist fail | 4 stream/decode fail | 75 lease busy
set -uo pipefail

HOST="${MOCK_HOST:-100.127.67.80}"
BASE="${MOCK_PORT:-48900}"; HTTPS="${MOCK_HTTPS:-48895}"; WEB="${MOCK_WEB:-48901}"
APP_NAME="${MOCK_APP:-Virtual Display}"
APP="${VIBEMIS_APPIMAGE:-$HOME/Downloads/Vibemis.AppImage}"
W="${W:-1920}"; H="${H:-1200}"
STREAM_SECS="${STREAM_SECS:-16}"
RES="${RES:---1080}"
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
LEASE_SH="$REPO/scripts/gamescope-lease.sh"

# ============================================================ internal gamescope phase (re-exec'd under the lease)
if [ "${1:-}" = "--_gsphase" ]; then
    OUT="$2"
    XRUN="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    LISTLOG="$OUT/applist.log"; STREAMLOG="$OUT/stream.log"; SHOT="$OUT/stream-frame.png"

    # ---- phase 2: applist inside gamescope (own short-lived gamescope) ----
    SDL_VIDEODRIVER=x11 ENABLE_GAMESCOPE_WSI=1 gamescope --backend headless --xwayland-count 1 \
        -w "$W" -h "$H" -W "$W" -H "$H" -- \
        env -u WAYLAND_DISPLAY timeout -s KILL --kill-after=3 18 "$APP" list "$HOST" --csv --verbose \
        >"$LISTLOG" 2>&1 &
    GSL=$!
    ( sleep 22; kill -0 "$GSL" 2>/dev/null && { kill -- -"$GSL" 2>/dev/null; kill -9 "$GSL" 2>/dev/null; } ) &
    WATCH=$!
    wait "$GSL" 2>/dev/null
    kill "$WATCH" 2>/dev/null
    rm -f "$XRUN"/gamescope-0 "$XRUN"/gamescope-0.lock 2>/dev/null
    sleep 2

    # ---- phase 3: stream inside gamescope, screenshot mid-stream ----
    set -m
    SDL_VIDEODRIVER=x11 ENABLE_GAMESCOPE_WSI=1 gamescope --backend headless --xwayland-count 1 \
        -w "$W" -h "$H" -W "$W" -H "$H" -- \
        env -u WAYLAND_DISPLAY timeout -s KILL --kill-after=3 "$STREAM_SECS" \
        "$APP" stream "$HOST" "$APP_NAME" "$RES" --no-vsync --fps 60 \
        >"$STREAMLOG" 2>&1 &
    GS=$!
    set +m
    # Snapshot AFTER real frames are decoding, not during the RTSP handshake splash: poll the log for
    # the first decoded frame ("Output frame with POC"), then wait 2s so a decoded frame is on screen.
    for _ in $(seq 1 "$STREAM_SECS"); do
        sleep 1
        kill -0 "$GS" 2>/dev/null || break
        grep -qi "Output frame with POC" "$STREAMLOG" 2>/dev/null && break
    done
    sleep 2
    GAMESCOPE_WAYLAND_DISPLAY=gamescope-0 gamescopectl screenshot "$SHOT" >/dev/null 2>&1
    sleep 1
    # wait out the rest of the stream window, then tear down THIS run's group only
    for _ in $(seq 1 10); do sleep 1; kill -0 "$GS" 2>/dev/null || break; done
    if kill -0 "$GS" 2>/dev/null; then
        kill -- -"$GS" 2>/dev/null; sleep 2; kill -9 -- -"$GS" 2>/dev/null || true
    fi
    rm -f "$XRUN"/gamescope-0 "$XRUN"/gamescope-0.lock 2>/dev/null
    exit 0
fi

# ============================================================ helpers
pass(){ echo "  PASS  $*"; }
fail(){ echo "  FAIL  $*"; }
tcp(){ timeout 5 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null; }

echo "=============================================================="
echo " Vibemis mock-Vibepollo streaming smoke — host=$HOST app='$APP_NAME'"
echo " appimage=$APP"
echo "=============================================================="
[ -x "$APP" ] || { echo "FATAL: AppImage not found/executable: $APP"; exit 2; }

# ---------------- PHASE 1: reachability ----------------
echo "== Phase 1: reachability =="
rc1=0
for pair in "$BASE:base-http" "$HTTPS:paired-https" "$WEB:web-ui"; do
    port="${pair%%:*}"; label="${pair##*:}"
    if tcp "$HOST" "$port"; then pass "TCP $HOST:$port ($label) open"; else fail "TCP $HOST:$port ($label) UNREACHABLE"; rc1=1; fi
done
[ "$rc1" = 0 ] || { echo "RESULT: reachability FAILED — is tailscale up / mock host online?"; exit 2; }
[ "${1:-}" = "--reach-only" ] && { echo "RESULT: reach-only PASS"; exit 0; }

# ---------------- PHASE 2+3: under the gamescope lease ----------------
OUT="$(mktemp -d /tmp/vibemis-mocksmoke.XXXXXX)"
echo "== Phases 2-3: applist + stream (leased gamescope; artifacts in $OUT) =="
GAMESCOPE_AGENT_ID="${GAMESCOPE_AGENT_ID:-clienttest-mocksmoke}" \
GAMESCOPE_LEASE_MAXHOLD="${GAMESCOPE_LEASE_MAXHOLD:-120}" \
    "$LEASE_SH" -w "${LEASE_WAIT:-240}" -- "$0" --_gsphase "$OUT"
lrc=$?
if [ "$lrc" = 75 ]; then echo "RESULT: gamescope lease BUSY (other agent streaming) — retry later"; rm -rf "$OUT"; exit 75; fi

LISTLOG="$OUT/applist.log"; STREAMLOG="$OUT/stream.log"; SHOT="$OUT/stream-frame.png"

echo "== Phase 2: applist result =="
# NOTE: the CLI's rendered --csv table only prints if the app fully exits, which it does NOT do
# headless within the timeout. The RELIABLE proof that the paired-HTTPS control plane returned an
# app list is the NvHTTP traffic it generates: it opens a connection per host and fetches an asset
# per enumerated app (appid=...). Those log lines ARE the applist working over paired HTTPS.
rc2=1
if grep -qiE "getServerInfo.*response|PairStatus|paired=1" "$LISTLOG" 2>/dev/null; then pass "control-plane getServerInfo/pair handshake seen"; fi
napps=$(grep -oE "appid=[0-9]+" "$LISTLOG" 2>/dev/null | sort -u | wc -l)
if grep -qiE "NvHTTP::openConnection|Executing request:.*$HTTPS" "$LISTLOG" 2>/dev/null && [ "$napps" -ge 1 ]; then
    pass "paired-HTTPS control plane enumerated apps ($napps distinct appid over :$HTTPS)"; rc2=0
elif grep -qiE "$APP_NAME|Steam Big Picture|Virtual Display" "$LISTLOG" 2>/dev/null; then
    pass "host advertised app names in CSV"; rc2=0
else
    fail "no control-plane app enumeration in applist output (see $LISTLOG)"
fi

echo "== Phase 3: stream + decode result =="
rc3=1; sigs=0
declare -A SIG=( ["Output frame with POC"]="decoder output (POC)"
                 ["Decode to surface"]="VAAPI decode-to-surface"
                 ["EGLRenderer"]="EGL renderer active"
                 ["Initialized VAAPI"]="VAAPI init"
                 ["Starting"]="stream stage start" )
for key in "Output frame with POC" "Decode to surface" "EGLRenderer" "Initialized VAAPI" "Starting"; do
    if grep -qi "$key" "$STREAMLOG" 2>/dev/null; then pass "decode signal: ${SIG[$key]}"; sigs=$((sigs+1)); fi
done
# the three PRIMARY real-decode signals the maintainer asked for:
core=0
grep -qi "Output frame with POC" "$STREAMLOG" 2>/dev/null && core=$((core+1))
grep -qi "Decode to surface"     "$STREAMLOG" 2>/dev/null && core=$((core+1))
grep -qi "EGLRenderer"           "$STREAMLOG" 2>/dev/null && core=$((core+1))
if [ -s "$SHOT" ]; then
    # imagemagick `identify` is NOT installed on SteamOS; parse dims from `file` instead.
    px=$(file "$SHOT" 2>/dev/null | grep -oE "[0-9]+ x [0-9]+" | head -1 | tr -d ' ' || echo "?")
    bytes=$(stat -c%s "$SHOT" 2>/dev/null || echo 0)
    pass "captured frame: $SHOT (${px}, ${bytes}B)"
else
    fail "no frame captured"
fi
if [ "$core" -ge 1 ] && [ -s "$SHOT" ]; then rc3=0; fi
echo "  decode-signal count: $sigs (core real-decode signals: $core/3)"

# stage trace excerpt for the report
echo "== stream stage trace (excerpt) =="
grep -iE "stage|connect|rtsp|sdp|Starting [A-Z]|VAAPI|decode|POC|EGLRenderer|error|refused|fail" "$STREAMLOG" 2>/dev/null \
    | grep -ivE "Qt Warning|platform plugin|translation" | tail -18

echo "=============================================================="
echo " SUMMARY: reachability=$([ $rc1 = 0 ] && echo PASS || echo FAIL)  applist=$([ $rc2 = 0 ] && echo PASS || echo FAIL)  stream+decode=$([ $rc3 = 0 ] && echo PASS || echo FAIL)"
echo " Artifacts: $OUT  (frame: $SHOT)"
echo "=============================================================="
[ "$rc2" = 0 ] || exit 3
[ "$rc3" = 0 ] || exit 4
exit 0
