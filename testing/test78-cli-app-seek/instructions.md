# test78 — CLI app seek: use the cached app list + robust name matching (fixes your test75/76 finding)

**Branch:** `test78-cli-app-seek` · **Base:** `vibemis-main` · **Report:** `diagnostic/test78-cli-app-seek-report`
**Artifact:** CI 🔬 alpha — `./testing/run-cycle.sh test78-cli-app-seek`.
**Host:** the paired host PC (up). This is YOUR bug (`vibemis stream <host> "Desktop"` → "Failed to find application" while the GUI works) — fully headless-verifiable, no GUI interaction needed.

## What changed

1. **Root cause:** on `ComputerFound` the CLI entered app-seek but only evaluated the app list on a
   *subsequent* `computerStateChanged` event; with a cached, unchanged host nothing arrives within
   the 10 s window → timeout despite the app being in the cached list. The seek now runs
   **immediately against the cached list** on entering app-seek (and still on every update).
2. **Matching:** exact match is now trimmed + case-insensitive; if no exact match, a **unique**
   case-insensitive substring match is accepted (`desk` → `Desktop`); ambiguous substrings fail.
3. **Diagnosable failure:** the timeout message now lists the available app names
   (`Failed to find application X (available: Desktop, Steam, …)`).

## Tier 1 — headless CLI (the fix target)

1. `run-cycle.sh test78-cli-app-seek` (md5 + `selftest` PASS).
2. `timeout 60 ./Vibemis*.AppImage stream "<host>" "Desktop"` → EXPECT the stream to START
   (kill after ~10 s of video; capture the log — no "Failed to find application"). This exact
   command failed on the beta during test75.
3. `timeout 30 ./Vibemis*.AppImage stream "<host>" "desk"` → EXPECT unique-substring match starts
   the Desktop stream the same way.
4. `timeout 30 ./Vibemis*.AppImage stream "<host>" "NoSuchApp"` → EXPECT failure message listing
   the available apps.
5. `timeout 30 ./Vibemis*.AppImage stream "<host>" "s"` (ambiguous: Steam + others?) → EXPECT
   ambiguity to FAIL with the available-apps list (only if ≥2 apps contain "s"; note actual list).
6. `vibemis quit <host>` between runs as needed.

## Negative checks
- `vibemis list <host>` unchanged.
- GUI launch path unaffected (it doesn't use this seek code).

## Report
`testing/test78-cli-app-seek/report.md` on `diagnostic/test78-cli-app-seek-report`; tick the
checklist row in the same commit; announce on the hub bus as usual.
