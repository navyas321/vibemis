#!/usr/bin/env bash
# BL-2301 CLI help/error prompt-exit regression harness.
#
# `vibemis stream --help` printed its full usage text and then hung forever
# (main thread in futex wait; SIGKILL orphaned the FUSE mount) because the
# subcommand parsers used to run AFTER the QQmlApplicationEngine and the rest
# of the heavyweight init, so their exit() walked a doomed atexit()/static-
# destructor teardown (the BL-2266 race face). Bare `--help` — which exits
# before that init — was always clean. The fix moves all subcommand parsing
# to that same early point; this harness pins the behavior for every CLI
# help/version/argument-error exit path:
#   - each invocation completes within the timeout (no hang: exit 124),
#   - help/version exit 0, argument errors exit 1 (no SIGSEGV 139 / SIGBUS),
#   - help output actually contains the usage text,
#   - no core file is left behind.
#
# Works against a bare build or a packaged AppImage (pass its path).
#
# Usage: scripts/cli-help-exit-test.sh [path-to-binary] [timeout-secs]
set -u

BIN="${1:-app/vibemis}"
T="${2:-10}"

if [ ! -x "$BIN" ]; then
    echo "FATAL: binary not found/executable: $BIN" >&2
    exit 2
fi

# Resolve to an absolute path so we can run from a scratch cwd
case "$BIN" in
    /*) : ;;
    *) BIN="$PWD/$BIN" ;;
esac

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
ulimit -c unlimited 2>/dev/null || true

fails=0

# check <expected-exit> <must-contain|-> <arg...>
check() {
    expected="$1"; needle="$2"; shift 2
    out="$WORKDIR/out.txt"
    ( cd "$WORKDIR" && timeout "$T" "$BIN" "$@" >"$out" 2>&1 )
    rc=$?
    label="vibemis $*"
    if [ "$rc" -eq 124 ]; then
        echo "FAIL: $label — HUNG (timeout ${T}s)"
        fails=$((fails + 1))
    elif [ "$rc" -ne "$expected" ]; then
        echo "FAIL: $label — exit $rc (expected $expected)"
        fails=$((fails + 1))
    elif [ "$needle" != "-" ] && ! grep -q "$needle" "$out"; then
        echo "FAIL: $label — exit $rc but output lacks '$needle'"
        fails=$((fails + 1))
    else
        echo "PASS: $label — exit $rc"
    fi
    if ls "$WORKDIR"/core* >/dev/null 2>&1; then
        echo "FAIL: $label — core file left behind"
        rm -f "$WORKDIR"/core*
        fails=$((fails + 1))
    fi
}

# Help / version paths must print and exit 0 promptly
check 0 "Usage:" --help
check 0 - --version
check 0 "Usage:" stream --help
check 0 "Usage:" quit --help
check 0 "Usage:" pair --help
check 0 "Usage:" list --help

# Argument-error paths must print the error + usage and exit 1 promptly
check 1 "Host not provided" stream
check 1 "Unknown option" stream --bogus-option
check 1 "Host not provided" quit
check 1 "Host not provided" list

if [ "$fails" -eq 0 ]; then
    echo "CLI-HELP-EXIT RESULT: PASS"
    exit 0
else
    echo "CLI-HELP-EXIT RESULT: FAIL ($fails failure(s))"
    exit 1
fi
