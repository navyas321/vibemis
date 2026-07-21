#!/usr/bin/env bash
# BL-2266 quit-loop teardown determinism harness.
#
# Launches the built vibemis binary headless (offscreen QPA), lets the QML
# engine come up, then quits it via SIGTERM (odd iterations) / SIGINT (even
# iterations) and asserts that EVERY quit:
#   - completes within the timeout (no TERM-hang: the beta.001 face),
#   - exits 0 (no SIGBUS/SEGV/abort: the beta.004 face),
#   - leaves no core file behind.
#
# Scope note: run against a bare build (qmake6 ... DEFINES+=APP_IMAGE) this
# exercises the app-side teardown path (signal thread -> quit() -> thread-pool
# drain -> deterministic _exit tail) WITHOUT a live FUSE mount. The FUSE side
# of BL-2266 needs the packaged AppImage on-device (test142 soak).
#
# Usage: scripts/quit-loop-test.sh [path-to-binary] [iterations]
set -u

BIN="${1:-app/vibemis}"
N="${2:-30}"
STARTUP_SECS="${VIBEMIS_QUITLOOP_STARTUP:-5}"
QUIT_TIMEOUT_SECS="${VIBEMIS_QUITLOOP_TIMEOUT:-20}"

if [ ! -x "$BIN" ]; then
    echo "FATAL: binary not found/executable: $BIN" >&2
    exit 2
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
ulimit -c unlimited 2>/dev/null || true

fails=0
hangs=0
for i in $(seq 1 "$N"); do
    ( cd "$WORKDIR" && exec env QT_QPA_PLATFORM=offscreen "$OLDPWD/$BIN" ) &
    pid=$!
    sleep "$STARTUP_SECS"

    if ! kill -0 "$pid" 2>/dev/null; then
        wait "$pid"; rc=$?
        echo "iter $i: FAIL — died during startup (rc=$rc)"
        fails=$((fails + 1))
        continue
    fi

    if [ $((i % 2)) -eq 1 ]; then sig=TERM; else sig=INT; fi
    kill "-$sig" "$pid"

    waited=0
    while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt $((QUIT_TIMEOUT_SECS * 10)) ]; do
        sleep 0.1
        waited=$((waited + 1))
    done

    if kill -0 "$pid" 2>/dev/null; then
        echo "iter $i: FAIL — HANG after SIG$sig (> ${QUIT_TIMEOUT_SECS}s), SIGKILLing"
        kill -9 "$pid" 2>/dev/null
        hangs=$((hangs + 1))
        fails=$((fails + 1))
        wait "$pid" 2>/dev/null
        continue
    fi

    wait "$pid"; rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "iter $i: FAIL — non-zero exit rc=$rc after SIG$sig"
        fails=$((fails + 1))
    else
        echo "iter $i: OK (SIG$sig, ${waited}00ms to exit)"
    fi
done

cores=$(find "$WORKDIR" -maxdepth 1 -name 'core*' 2>/dev/null | wc -l)
echo "----------------------------------------"
echo "quit-loop: $N iterations, $fails failures ($hangs hangs), $cores core files"
if [ "$fails" -ne 0 ] || [ "$cores" -ne 0 ]; then
    exit 1
fi
echo "quit-loop: PASS"
