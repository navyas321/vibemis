# Self-test and scriptable verification surfaces

Vibemis ships a few CLI surfaces specifically so a build can be sanity-checked from a script,
with no host, stream, or GUI window required. This doc covers those surfaces; it was extracted
from the (now-private) test-agent SOP as part of the P4.0 two-repo split (BL-1565/BL-2035) since
it documents real, public product behavior. Referenced from `app/main.cpp` and
`app/cli/commandlineparser.cpp`.

## 1. Headless self-test — `vibemis selftest`

The client supports a scriptable, non-destructive smoke test that needs no host, stream, or
window and runs before GUI init:

```bash
APP=~/Downloads/Vibemis-x86_64.AppImage
"$APP" selftest > /tmp/vibemis-selftest.log 2>&1; echo "exit=$?"
grep -q "SELFTEST RESULT: PASS" /tmp/vibemis-selftest.log && echo "SMOKE OK" || echo "SMOKE FAIL"
```

- Exit code `0` = all checks PASS, `1` = a failure. Each check prints `SELFTEST <name>: PASS|FAIL`.
- **Machine-readable:** `"$APP" selftest --json 2>/dev/null` prints a single JSON object
  `{"result","failures","checks":{…}}`. Use `2>/dev/null` (the AppRun hook + Qt platform warnings
  go to **stderr**) so stdout is pure JSON for `python3 -c 'import json,sys;json.load(sys.stdin)'`.
- Use this as the first step of any verification cycle: if the build can't even initialise its
  preferences subsystem, stop before doing anything else.

## 2. Log-driven assertions (works in any mode)

Run the app for a bounded time, then grep the log for expected signals — no GUI scraping needed.

```bash
APP=~/Downloads/Vibemis-x86_64.AppImage
timeout 25s "$APP" > /tmp/vibemis-run.log 2>&1 &
PID=$!; sleep 20; kill $PID 2>/dev/null; wait $PID 2>/dev/null
grep -iE "EGLRenderer|renderer selected|overlay|error|FFmpeg" /tmp/vibemis-run.log
```

Good signals to assert on: the active renderer (expect **EGLRenderer** on AMD APUs), absence of
`SEGV`/`Critical`, decoder selection, overlay init. Quote the 2-3 lines that answer the question
rather than pasting the whole log.

## 3. Headless host/discovery checks via the CLI

The client ships these CLI verbs (no GUI required):

- `vibemis list <host>` — list a host's apps (also proves pairing/reachability). `--csv` for parsing.
- `vibemis quit <host>` — quit the running app.

These let a script assert host reachability / app presence without opening the UI. They don't
pair or start a stream on their own.

## Putting it together — a verification skeleton

```bash
#!/bin/bash
APP=~/Downloads/Vibemis-x86_64.AppImage
md5sum "$APP"
echo "== smoke =="; "$APP" selftest; echo "exit=$?"
echo "== run/log =="; timeout 25s "$APP" >/tmp/run.log 2>&1 & sleep 20; kill %1 2>/dev/null
grep -iE "EGLRenderer|error|SEGV|overlay" /tmp/run.log
```

## What this doesn't cover

Frame pacing feel, HDR color accuracy, input latency, and "does the picture look right" are
subjective and not asserted by any of the above — they need a human look at a screenshot plus
the in-app stats overlay. End-to-end streaming correctness (pairing, host handshake, live video)
also isn't covered here; it needs a real paired host and a guided test pass.
