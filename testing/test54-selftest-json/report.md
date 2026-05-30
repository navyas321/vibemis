# Test54 Report — `selftest --json` + settings round-trip checks

**Artifact tested:** `Vibemis-0.6.7-alpha.test54-selftest-json.20260529.2108+15732f9-x86_64.AppImage`
**md5:** `3715d5747fd32ea233545f11f5c5d8df`
**Branch:** `test54-selftest-json` (commit `15732f9`, stacks on test52)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5 (BUILD_ID 20260520.100), Mesa 25.3.0
**Test date:** 2026-05-29
**Prior report:** `testing/test52-selftest-cli/report.md` (PASS)

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — line output + 2 new checks | PASS ✅ | 7/7 PASS incl. `settings-writable` + `settings-roundtrip`, exit=0 |
| B — `--json` valid & parseable | PASS ✅ | Valid JSON, `result=PASS`, `failures=0`, all 7 checks as booleans, deterministic |
| C — non-destructive | PASS ✅ | Real settings file untouched (mtime unchanged), no probe group leaked |

**Minor finding:** with `2>&1`, the `--json` output is preceded by 2 noise lines (AppRun hook + Qt platform warning), so `json.load(whole_file)` fails — you must extract the `{…}` line first. See Other Findings.

---

## 2. Tier 1 — line output still works (+ new checks)

```
$ "$APP" selftest > /tmp/st.log 2>&1; echo "exit=$?"   # exit=0
SELFTEST prefs-load: PASS
SELFTEST default-bitrate: PASS
SELFTEST display-mode: PASS
SELFTEST bitrate-positive: PASS
SELFTEST audio-config-range: PASS
SELFTEST settings-writable: PASS        # NEW
SELFTEST settings-roundtrip: PASS       # NEW
SELFTEST RESULT: PASS (0 failure(s))
```

Both new checks present and PASS; original 5 unchanged; `RESULT: PASS`, exit=0. **PASS.**

---

## 3. Tier 2 — JSON output valid & parseable

```
$ "$APP" selftest --json   # (JSON line, exit=0)
{"checks":{"audio-config-range":true,"bitrate-positive":true,"default-bitrate":true,
"display-mode":true,"prefs-load":true,"settings-roundtrip":true,"settings-writable":true},
"failures":0,"result":"PASS"}

$ ... | grep '^{' | python3 -c "import json,sys;d=json.load(sys.stdin);print(d['result'],d['failures'])"
PASS 0
```

Single valid JSON object, `result=PASS`, `failures=0`, `checks` has all 7 names as booleans, exit=0. Re-ran — JSON line byte-identical (deterministic). **PASS.**

---

## 4. Tier 3 — non-destructive

```
$ ls -la ~/.config/"Vibemis Project"/Vibemis/vibemis-settings.ini
-rw-r--r-- 1 deck deck 462 May 29 00:27 vibemis-settings.ini   # mtime predates today's runs
$ grep -i selftest ~/.config/"Vibemis Project"/Vibemis/vibemis-settings.ini
(none) → no probe group leaked into real settings
$ grep uniqueid ~/.config/"Vibemis Project"/Vibemis.conf
uniqueid=3ca53e803678f6a4   # unchanged from test19/20 pairing
```

After multiple `selftest` / `selftest --json` runs, the real settings file's mtime is still `00:27` (untouched), no `vibemis-selftest` group leaked, and the persisted uniqueid + paired host are intact. The isolated probe group is cleaned up as designed. **PASS.**

---

## 5. Other findings

- **`--json` not a clean single line under `2>&1`.** The AppRun wrapper prints `[vibemis-apprun] FORCE_VAAPI=1 …` and Qt prints `Could not find the Qt platform plugin "wayland"` before the JSON. For true machine-parseability, consider emitting the JSON to **stdout only** and routing the AppRun hook + Qt warnings to **stderr** (then `selftest --json 2>/dev/null` is pure JSON). Consumers today must `grep '^{'`. Same benign Qt warning as test52.

---

## 6. Recommendation

**MERGE.** `--json` is valid/deterministic and the two new non-destructive checks work. Pairs well with the test52 enabler for scripted Tier-1 automation. Optional polish: separate JSON (stdout) from diagnostic noise (stderr) so `--json` is parseable without a grep.
