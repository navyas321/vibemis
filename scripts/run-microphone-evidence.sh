#!/usr/bin/env bash
# BL-2633/BL-2634: collect one reproducible client-side microphone evidence run.
# The operator sets the microphone toggle in Settings before invoking this script.
set -u

fail=0
err() { echo "MIC-EVIDENCE FAIL: $1" >&2; fail=1; }

: "${APP:?Set APP to the Vibemis AppImage path}"
: "${HOST:?Set HOST to the paired host name or address}"
: "${APPNAME:?Set APPNAME to the host application name}"
: "${MODE:?Set MODE to off or on}"

case "$MODE" in
  off|on) ;;
  *) err "MODE must be off or on"; exit 2 ;;
esac

RUN=${RUN:-"$PWD/mic-evidence-${MODE}-$(date -u +%Y%m%dT%H%M%SZ)"}
DURATION=${DURATION:-90}
EXPECT_MIC=${EXPECT_MIC:-0}
mkdir -p "$RUN"

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi
}

git rev-parse HEAD >"$RUN/client-parent-sha.txt" || err "not a git checkout"
git -C moonlight-common-c/moonlight-common-c rev-parse HEAD >"$RUN/client-common-c-sha.txt" \
  || err "common-c submodule SHA unavailable"
sha256 "$APP" >"$RUN/app-sha256.txt" || err "could not hash APP"
"$APP" selftest --json >"$RUN/selftest.json" 2>"$RUN/selftest.stderr" || err "selftest failed"
"$APP" list "$HOST" --csv >"$RUN/host-apps.csv" 2>"$RUN/host-apps.stderr" || err "host app listing failed"

set +e
timeout --signal=INT "${DURATION}s" "$APP" stream "$HOST" "$APPNAME" >"$RUN/client.log" 2>&1
stream_status=$?
set -e
printf '%s\n' "$stream_status" >"$RUN/stream-exit-status.txt"

if [ "$stream_status" -ne 0 ] && [ "$stream_status" -ne 124 ]; then
  err "stream exited with status $stream_status"
fi

if [ "$MODE" = on ] && [ "$EXPECT_MIC" -eq 0 ]; then
  grep -qF 'Host does not advertise negotiated microphone support; continuing without microphone passthrough' \
    "$RUN/client.log" || err "stock-host graceful-degradation line missing"
  grep -qF 'streamid=mic' "$RUN/client.log" && err "stock-host run attempted microphone RTSP setup"
fi

if [ "$EXPECT_MIC" -eq 1 ]; then
  grep -qF 'Microphone capture device:' "$RUN/client.log" || err "capture device line missing"
  grep -qF 'negotiated mic stream is active' "$RUN/client.log" || err "mic-active line missing"
  grep -qF 'Microphone stream encryption: enabled' "$RUN/client.log" || err "encrypted mic state missing"
  grep -qF 'Sent first client microphone packet' "$RUN/client.log" || err "first packet line missing"
  grep -qF 'streamid=mic' "$RUN/client.log" || err "positive mic RTSP setup evidence missing"
fi

if [ "$fail" -ne 0 ]; then
  echo "Evidence directory retained at $RUN" >&2
  exit 1
fi
echo "Microphone evidence run collected: $RUN"
echo "Host-side receipt proof is still required for BL-2634."
