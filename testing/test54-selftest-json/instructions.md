# test54 — `vibemis selftest --json` + extra checks (test-automation)

**Feature:** Extends the `selftest` smoke test (test52) with:
- a `--json` mode that prints a single compact JSON object
  `{"result":"PASS","failures":0,"checks":{…}}` for easy machine parsing;
- two new checks: a **non-destructive** QSettings round-trip (`settings-roundtrip`) and a
  writability check (`settings-writable`) — both run in an isolated `vibemis-selftest` group, so
  real preferences and paired-host data are never touched.
**Branch:** `test54-selftest-json` · **Base:** `test52-selftest-cli` (stacks on test52) ·
**Artifact:** 🔬 alpha pre-release (tag contains `test54-selftest-json`).

> Fully **headless / launcher-only**. Stacks on test52 — verify test52 first if not already done.

## Setup
1. Download the alpha AppImage, `chmod +x`, record `md5sum` + SteamOS/Mesa versions.

## Tier 1 — default (line) output still works
```bash
APP=~/Downloads/Vibemis-x86_64.AppImage
"$APP" selftest > /tmp/st.log 2>&1; echo "exit=$?"; cat /tmp/st.log
```
- ✅ PASS if it prints `SELFTEST settings-writable: PASS`, `SELFTEST settings-roundtrip: PASS`,
  the original checks, a final `SELFTEST RESULT: PASS (0 failure(s))`, and `exit=0`.

## Tier 2 — JSON output is valid and parseable
```bash
"$APP" selftest --json > /tmp/st.json 2>&1; echo "exit=$?"; cat /tmp/st.json
python3 -c "import json,sys;d=json.load(open('/tmp/st.json'));print('parsed ok, result=',d['result'],'failures=',d['failures'])"
```
- ✅ PASS if the output is a single valid JSON line, `result` is `PASS`, `failures` is `0`,
  `checks` contains all check names as booleans, and `exit=0`. (`python3` is present on SteamOS;
  if not, just eyeball that it's valid JSON.)

## Tier 3 — non-destructive (settings untouched)
1. Before running, note your current resolution/bitrate in the GUI (or skip if confident).
2. Run `selftest` and `selftest --json` a few times.
3. Open the launcher → Settings.
   - ✅ PASS if your existing settings and paired hosts are unchanged (the probe group is cleaned up).

## Report
Write `testing/test54-selftest-json/report.md` (include the JSON output), update the `test54` row
in `testing/TEST_CHECKLIST.md`, commit both on `diagnostic/test54-selftest-json-report`, open a PR
targeting `test54-selftest-json`.
