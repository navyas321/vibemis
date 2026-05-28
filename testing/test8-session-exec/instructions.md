# Test8 Instructions — StreamSegue stale API complete fix

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Prior report:** `testing/test7-streamsegue-fix/report.md` (test7 FAIL — stream still did not launch)
**Goal:** Confirm that a stream now launches all the way to video with the complete stale-API fix applied.

---

## Background

Test7 FAIL report showed that removing `SystemProperties.waitForAsyncLoad()` alone was not enough — the stream still hung without launching. The build agent identified three more stale QML→C++ calls that each halted the launch chain before the next one was reached:

1. `session.initialize(window)` — private non-Q_INVOKABLE; called in `streamLoader.onLoaded`. TypeError halts before `startSessionTimer.start()`.
2. `session.launchWarnings.length` — not a Q_PROPERTY; `undefined.length` TypeError also in `streamLoader.onLoaded`.
3. `session.start()` — method does not exist in Session API; TypeError in `startSessionTimer.onTriggered`.

This build collapses the over-engineered chain into a single `session.exec(window)` call (the only Q_INVOKABLE), which already calls `initialize()` internally. A `displayLaunchWarning` signal handler using a ToolTip toast replaces the stale pre-collection loop.

Also fixed: three dead-code cases in `QuickMenu.showActionFeedback()` that referenced `ServerCommandManager.hasServerCommands` (does not exist) instead of `quickMenuManager.hasServerCommands`.

---

## Artifact

**AppImage:** `testing/test8-session-exec/Vibemis-0.6.7-vibemis-test8-session-exec-x86_64.AppImage`
**md5:** `88388d7086d77fe0383b36c34da59b6b`

Verify before running:
```bash
md5sum testing/test8-session-exec/*.AppImage
```

---

## Test procedure

### Setup
```bash
cd ~/vibemis
git fetch origin test8-session-exec
git checkout test8-session-exec && git pull
chmod +x testing/test8-session-exec/*.AppImage
```

### Tier 1 — Stream launch test (main goal)

Launch the AppImage and attempt to start a stream against Navid-PC (Vibepollo). Capture logs for 90 seconds, then kill.

```bash
APPIMAGE=testing/test8-session-exec/Vibemis-0.6.7-vibemis-test8-session-exec-x86_64.AppImage
./testing/test8-session-exec/Vibemis-0.6.7-vibemis-test8-session-exec-x86_64.AppImage \
  > /tmp/vibemis-test8-tier1.log 2>&1 &
VPID=$!
sleep 90
kill $VPID 2>/dev/null
echo "Tier 1 done. PID was $VPID"
```

Then check the log for the critical stream launch signals.

### Tier 2 — Control run / baseline UI check

Verify the app opens, shows the PC list, and Navid-PC is visible — without attempting to connect.

```bash
./testing/test8-session-exec/Vibemis-0.6.7-vibemis-test8-session-exec-x86_64.AppImage \
  > /tmp/vibemis-test8-tier2.log 2>&1 &
VPID=$!
sleep 30
kill $VPID 2>/dev/null
echo "Tier 2 done."
```

---

## What to check and report

### 1. StreamSegue — no TypeError on launch attempt (critical)

```bash
grep -i "typeerror\|waitforasyncload\|session\.start\|session\.initialize\|launchwarnings" \
  /tmp/vibemis-test8-tier1.log
```
**Expected:** No output (zero matches). Any TypeError here means the fix is incomplete.

### 2. Session exec — called and progresses past initialization

```bash
grep -i "stage\|connect\|rtsp\|sdp\|starting\|stream\|exec" \
  /tmp/vibemis-test8-tier1.log | head -30
```
**Expected:** Lines showing stages progressing (e.g. `Starting RTSP...`, `Starting Control...`, `Starting Video...`). These would not appear in test7 because `streamLoader.active` was never set to `true`.

### 3. Video render or stream active

```bash
grep -i "video\|render\|frame\|decode\|sdl\|launched\|session" \
  /tmp/vibemis-test8-tier1.log | head -30
```
**Expected:** Some indication the video pipeline started (even if the stream later disconnects cleanly).

### 4. No regression — PC list loads in Tier 2

```bash
grep -i "computer\|pc\|navid\|host\|mdns\|discover" \
  /tmp/vibemis-test8-tier2.log | head -20
```
**Expected:** Navid-PC appears as it did in test6 (which passed Tier 2).

### 5. QuickMenu smoke — open the menu during stream (if stream launches)

If the stream does launch in Tier 1, press Ctrl+Alt+Shift+Q to open the Quick Menu. Report whether it opens without errors in the log.

```bash
grep -i "quickmenu\|quick menu\|menu\|hasservercommands" \
  /tmp/vibemis-test8-tier1.log | head -20
```
**Expected:** No `hasServerCommands` TypeError or similar.

---

## Report format

Commit `testing/test8-session-exec/report.md` on branch `diagnostic/test8-session-exec-report` and open a PR targeting `test8-session-exec`.

Required sections in the report: TL;DR table, Tier 1 results (with relevant log excerpts), Tier 2 results, recommendation (MERGE / ITERATE / ESCALATE).

---

## Safety rules (standing)
- No package installs, no sudo outside read-only inspection
- Do not modify the AppImage
- Do not attempt to pair or stream unless the instructions explicitly ask for it (Tier 1 does ask)
- If a step needs a permission or capability outside these rules, stop and ask
