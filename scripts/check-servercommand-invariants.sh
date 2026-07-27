#!/usr/bin/env bash
# BL-2539: the custom server-command path must stay REAL.
#
# executeCustomCommand() shipped for months as a stub: a 1.5 s QTimer that
# emitted commandExecuted(..., true, ...) without sending anything to the
# host, so every custom command showed a success toast over a silent no-op.
# Found on-device (test agent, 2026-07-27) when triggering the host's
# "Bubbles" command did nothing. These guards fail the build if the fake
# reappears or the real send path is removed.
set -u

fail=0
err() { echo "SERVERCOMMAND-INVARIANT FAIL: $1" >&2; fail=1; }

src="app/backend/servercommandmanager.cpp"
[ -f "$src" ] || { err "missing $src"; echo "One or more servercommand invariants failed." >&2; exit 1; }

# The stub's signature move: a fake-success TODO. Must never come back.
if grep -qF 'TODO: Implement actual custom command execution' "$src"; then
  err "executeCustomCommand is a fake-success stub again"
fi

# The custom path must reach a real transport: the Apollo HTTP endpoint...
grep -qF 'sendHttpCustomCommand' "$src" ||
  err "the custom-command HTTP send path is gone"
sed -n '/void ServerCommandManager::sendHttpCustomCommand/,/^}/p' "$src" |
  grep -qF 'openConnectionToString' ||
  err "sendHttpCustomCommand no longer performs a real HTTP request"

# ...and a timer-based success emit inside executeCustomCommand is exactly
# the stub shape, whatever it claims to be.
if sed -n '/void ServerCommandManager::executeCustomCommand/,/^}/p' "$src" |
     grep -qE 'QTimer::singleShot.*commandExecuted'; then
  err "executeCustomCommand emits success from a timer (stub shape)"
fi
if sed -n '/void ServerCommandManager::executeCustomCommand/,/^}/p' "$src" |
     grep -v '^[[:space:]]*//' | grep -qE 'commandExecuted\(.*true'; then
  err "executeCustomCommand emits unconditional success directly"
fi

if [ "$fail" -ne 0 ]; then
  echo "One or more servercommand invariants failed." >&2
  exit 1
fi

echo "All servercommand invariants hold."
