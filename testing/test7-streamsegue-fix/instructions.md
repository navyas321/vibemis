# Test7 Instructions — StreamSegue stream-launch fix

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.8.5)
**Prior report:** `testing/test6-pcview-parentmenu/report.md` (PR #13 — PASS, merged)
**Goal:** Verify that clicking an app (e.g. "Desktop") actually launches the stream instead of hanging forever on "Starting Desktop..." spinner.

---

## Background

After PR #13 (PcView parentMenu fix) the Computers screen and context menu work correctly.
However, the next user action — clicking an app — revealed a second stale API call:

**`StreamSegue.qml:126`** called `SystemProperties.waitForAsyncLoad()`, but `SystemProperties`
only exposes `refreshDisplays()`, `getNativeResolution()`, `getSafeAreaResolution()`, and
`getRefreshRate()` as `Q_INVOKABLE`. `waitForAsyncLoad` does not exist.

When QML throws `TypeError: Property 'waitForAsyncLoad' of object SystemProperties is not a function`
inside `StackView.onActivated`, execution halts at line 126 **before** the lines that actually
kick off the stream:
```
spinnerTimer.start()   // never ran
streamLoader.active = true  // never ran
```
The spinner started (triggered by the QML signal fired before the slot) but the `Loader`
never activated and `Session` was never constructed. Result: the "Starting Desktop…" text
appeared and the spinner spun forever.

**Fix (PR #14):** drop the three dead lines from `StreamSegue.qml`. The `SystemProperties`
SDL probe (`querySdlVideoInfo()`) is synchronous — it runs at app startup and blocks via
`thread.wait()` before QML can navigate to `StreamSegue`. By the time a user clicks an app,
the SDL video subsystem has already been initialised, probed, and torn down.

**Also in this build (from codebase audit):** `QuickMenu.qml` used `ServerCommandManager.hasServerCommands`
(wrong object) in toast feedback messages for server_restart/shutdown/suspend. These are dead code
paths today but corrected to `quickMenuManager.hasServerCommands` for correctness.

---

## Artifact

**AppImage:** `testing/test7-streamsegue-fix/Vibemis-0.6.7-vibemis-test7-streamsegue-x86_64.AppImage`
**md5:** `fe9f1f9a86978d77f0c83e1b1211143a`

Verify before running:
```bash
md5sum testing/test7-streamsegue-fix/Vibemis-0.6.7-vibemis-test7-streamsegue-x86_64.AppImage
# must match: fe9f1f9a86978d77f0c83e1b1211143a
```

---

## Test procedure

### Setup

```bash
cd ~/vibemis
git fetch origin fix/streamsegue-waitforasyncload
git checkout fix/streamsegue-waitforasyncload
git pull
ls -lh testing/test7-streamsegue-fix/
```

Make the AppImage executable:
```bash
chmod +x testing/test7-streamsegue-fix/Vibemis-0.6.7-vibemis-test7-streamsegue-x86_64.AppImage
```

### Tier 1 — stream launch (the key regression test)

```bash
./testing/test7-streamsegue-fix/Vibemis-0.6.7-vibemis-test7-streamsegue-x86_64.AppImage \
  > /tmp/vibemis-run-test7.log 2>&1 &
APP_PID=$!
sleep 30
kill $APP_PID 2>/dev/null; wait $APP_PID 2>/dev/null
```

**During the 30-second window:**
- Wait for the Computers screen to appear (should be within 3–5s)
- Click the Desktop app (or any app) on Navid-PC
- Watch the StreamSegue screen — it should say "Connecting…" or show stream stages, not freeze forever on "Starting Desktop…"
- **Do NOT stay in the stream** — the test just needs to confirm the stream launches. As soon as the stream window appears (or you see the connection-stage progress), the fix is confirmed. Close/disconnect immediately.
- If the spinner freezes permanently at "Starting Desktop…", that is the pre-fix behavior — report it as FAIL.

### Tier 2 — waitForAsyncLoad error check

```bash
grep -i "waitForAsyncLoad\|TypeError\|is not a function" /tmp/vibemis-run-test7.log \
  || echo "(no waitForAsyncLoad TypeError — good)"
```

---

## What to check and report

**1. No waitForAsyncLoad TypeError:**
```bash
grep -i "waitForAsyncLoad\|is not a function" /tmp/vibemis-run-test7.log \
  || echo "(no TypeError — good)"
```

**2. No parentMenu regression (PR #13 still clean):**
```bash
grep -i "parentMenu\|non-existent property" /tmp/vibemis-run-test7.log \
  || echo "(no parentMenu errors — good)"
```

**3. VAAPI hook still active:**
```bash
grep "vibemis-apprun-hook" /tmp/vibemis-run-test7.log
# Expected: [vibemis-apprun-hook] preferring host libva from /usr/lib64 (via /tmp/tmp.XXXXXX)
```

**4. Stream actually launched (the main pass/fail gate):**
```bash
grep -i "Connecting\|connectionStarted\|Starting\|stageStarting\|session\|stream" /tmp/vibemis-run-test7.log | head -20
```
- **Pass:** Stream progresses through connection stages (Connecting, Starting video, etc.)
  OR the stream window appears briefly before the 30-second kill
- **Fail:** Log shows "Starting Desktop…" text but no further progress; spinner spins forever

**5. Computers screen and mDNS (regression check):**
```bash
grep -i "Discovered mDNS\|Processing new PC\|Navid-PC\|Adding computer" /tmp/vibemis-run-test7.log | head -5
```

**6. Log tail — any unexpected errors:**
```bash
tail -30 /tmp/vibemis-run-test7.log
```

**7. On-screen observation — describe what you saw:**
- Did the Computers screen load? (yes/no)
- Did you click the app? (yes/no)
- What happened after clicking: spinner hung / connection stages appeared / stream window appeared / error dialog

---

## Report format

Commit `testing/test7-streamsegue-fix/report.md` on branch `diagnostic/test7-streamsegue-report`
and open a PR against `fix/streamsegue-waitforasyncload`.

**Required sections:**
1. TL;DR table (Goal A: stream launches, Goal B: parentMenu regression-free, Goal C: VAAPI ok)
2. Tier 1 — on-screen observation (what happened after clicking the app)
3. Tier 1 — waitForAsyncLoad check result
4. Tier 1 — VAAPI hook line
5. Tier 1 — stream launch log excerpt (connection stages or "Starting…" hung)
6. Recommendation (merge PR #14 / iterate / escalate)

Keep the report under ~150 lines.

---

## Safety rules (standing)

- Do not install any packages or modify the system.
- Do not run with `sudo`.
- Do not modify the AppImage.
- You may allow the stream to reach the connection stage, but **close it immediately** once
  confirmed — do not use the stream for extended testing.
- Do NOT leave the stream running for more than a few seconds — this test only checks that
  launch works, not that streaming quality is correct.
