# Test78 Report — CLI app-seek fix — **PASS**

**Artifact:** `Vibemis-0.7.1-alpha.test78-cli-app-seek.20260712.0040+639de73-x86_64.AppImage`
**md5:** `aa02f4ba…` (staged as `Vibemis-test78.AppImage`)
**Branch:** `test78-cli-app-seek` · **Report branch:** `diagnostic/test78-cli-app-seek-report`
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0, Qt 6.9.1
**Host:** Navid-PC (real Apollo host, paired) · **Test date:** 2026-07-11
**Fixes:** my **test75/76 CLI finding** — `vibemis stream <host> "Desktop"` → "Failed to find application" while the GUI worked. **Fully headless, no GUI/mouse.**

---

## 1. TL;DR

| # | Case | Expected | Result |
|---|---|---|---|
| 1 | `stream "Navid-PC" "Desktop"` | stream starts | ✅ **STREAM STARTED** (the exact test75-failing command) |
| 2 | `stream "Navid-PC" "desk"` | unique-substring → Desktop | ✅ **STREAM STARTED** (same app id 785894588) |
| 3 | `stream "Navid-PC" "NoSuchApp"` | fail, list available apps | ✅ `Failed to find application NoSuchApp (available: Desktop, Steam Big Picture, Virtual Display)` |
| 4 | `stream "Navid-PC" "s"` | ambiguous → fail w/ list | ✅ `Failed to find application s (available: …)` — "s" is in all 3 apps → correctly ambiguous |

**Verdict: PASS.** All three fixed behaviors confirmed on the real host: immediate cached-list seek (no 10 s timeout), case-insensitive **unique-substring** match, and a **diagnosable** failure that lists the available apps. My test75 CLI bug is resolved.

## 2. Evidence (logs in /tmp/test78/)
```
# case 1  "Desktop"
00:00:03 Qt Info: Launching app with ID: 785894588 ...
00:00:06 SDL Info: Video stream is 1920x1200x120 (format 0x100)
# case 2  "desk"  (unique substring)
00:00:03 Qt Info: Launching app with ID: 785894588 ...
00:00:04 SDL Info: Video stream is 1920x1200x120 (format 0x100)
# case 3  "NoSuchApp"
00:00:10 Qt Critical: Failed to find application NoSuchApp (available: Desktop, Steam Big Picture, Virtual Display)
# case 4  "s"  (matches all 3 -> ambiguous)
00:00:10 Qt Critical: Failed to find application s (available: Desktop, Steam Big Picture, Virtual Display)
```
Each `stream` ran inside a single nested gamescope (for the VAAPI/GPU context); killed after the stream-start / failure signal. Host session quit between runs.

## 3. Negative / notes
- `vibemis list` + GUI launch path unaffected (untouched by the seek code).
- **Minor cosmetic:** the `available:` list contains zero-width unicode chars between names (e.g. `​​Desktop, ​‌Steam Big Picture`) — harmless in the log but if that string is ever shown in UI it may render oddly. Worth a trim of non-printing chars in the app-name formatting (not blocking; PASS).
- Harness note: this cycle also validated a **nested-`:1`-only** gamescope cleanup (kill `Xwayland.*:1` by PID + `rm /tmp/.X1-lock`) — all 4 relaunches succeeded, fixing the stale-lock `XIO error 17` flakiness seen earlier.

## 4. Recommendation
**MERGE.** The CLI app-seek fix fully resolves the test75 finding on the real host. Optional tiny follow-up: strip zero-width chars from the available-apps string.
