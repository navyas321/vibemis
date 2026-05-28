# Test7 Report — StreamSegue stream-launch fix

**Artifact tested:** `Vibemis-0.6.7-vibemis-test7-streamsegue-x86_64.AppImage`
**md5:** `fe9f1f9a86978d77f0c83e1b1211143a` ✓ verified
**Branch:** `fix/streamsegue-waitforasyncload` (commit 9d767f80)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0
**Test date:** 2026-05-27
**Prior report:** test6 (PR #13 — merged)

---

## 1. TL;DR

| Goal | Status | Evidence |
|---|---|---|
| **Goal A — Stream actually launches** | **FAIL** | New `TypeError` at `StreamSegue.qml:171` — `session.initialize` is not a function. Spinner reaches "Starting Desktop…" and halts. |
| **Goal B — `waitForAsyncLoad` removed** | **PASS** | No `waitForAsyncLoad` TypeError in the log; the PR #14 fix landed cleanly. |
| **Goal C — VAAPI / parentMenu regression-free** | **PASS** | VAAPI hook fires, no `parentMenu` errors, pairing succeeds (`PairStatus=1`). |

**Recommendation: iterate.** PR #14 fixed the first blocker; the second was hidden behind it. Fix proposed on `fix/session-exec-stale-api` (PR #15).

---

## 2. On-screen observation

- Computers screen loaded normally; Navid-PC visible and online.
- Pairing already completed in a prior session — host shows as paired.
- Clicked the Desktop app.
- StreamSegue screen appeared with "Starting Desktop…" text and a spinner.
- Spinner spun for the remainder of the 30 s window. No connection stages displayed, no stream window appeared, no error dialog.
- Same hang as before PR #14, just one line deeper into the QML.

---

## 3. Tier 1 — waitForAsyncLoad check

```
grep -i "waitForAsyncLoad\|is not a function" /tmp/vibemis-run-test7.log
→ 00:00:25 - Qt Warning: qrc:/gui/StreamSegue.qml:171: TypeError:
    Property 'initialize' of object Session(0x55686827d0c0) is not a function
```

`waitForAsyncLoad` itself is gone — that's the PR #14 fix verified. The remaining "is not a function" hit is a **new** TypeError on the next line that runs after PR #14's cleanup: `session.initialize(window)`.

---

## 4. Tier 1 — VAAPI hook

```
[vibemis-apprun-hook] preferring host libva from /usr/lib64 (via /tmp/tmp.vNvF0TFftW)
```

Surgical libva hook still active. No `parentMenu`, no `mismatching Qt`, no Qt fatal.

---

## 5. Tier 1 — stream launch log excerpt

```
00:00:02 - Qt Info: "Navid-PC" is now online at "192.168.4.78:47989"
00:00:05 - Qt Info: getServerInfo HTTPS response: ...PairStatus>1<...
00:00:25 - Qt Warning: qrc:/gui/StreamSegue.qml:171:
    TypeError: Property 'initialize' of object Session(0x55686827d0c0) is not a function
(no Connecting / stageStarting / connectionStarted lines after this)
```

`StreamSegue` loaded, `streamLoader.onLoaded` fired, the QML throws at `session.initialize(window)`, and `startSessionTimer.start()` is never reached. The spinner was already running (started by the parent `StackView.onActivated`), so the screen looks alive but the Loader/Session pipeline never starts. Same outcome as the pre-PR #14 hang.

---

## 6. Root cause — second stale QML→C++ call

`Session.h` exposes exactly one `Q_INVOKABLE`:
```cpp
Q_INVOKABLE void exec(QWindow* qtWindow);
```

`bool initialize()` exists but is **not** `Q_INVOKABLE` and **takes no arguments**. `session.start()` (called by `startSessionTimer.onTriggered`) doesn't exist at all. Both QML call sites are stale.

`Session::exec` already does what `StreamSegue` was trying to do explicitly:
```cpp
// session.cpp:1934
if (!initialize()) {
    emit sessionFinished(0);
    emit readyForDeletion();
    return;
}
```

Same emit-and-bail behaviour the QML guard reimplemented incorrectly.

---

## 7. Proposed fix (PR #15 — `fix/session-exec-stale-api`)

- Remove the redundant `session.initialize(window)` block (`StreamSegue.qml` lines 170-175).
- Change `session.start()` to `session.exec(window)` at line 150.

After this change the launch flow is: `streamLoader.onLoaded` → toasts → `startSessionTimer.onTriggered` → `session.exec(window)`. `exec()` handles initialize-failure internally with the same signals the QML already listens for (`sessionFinished`, `readyForDeletion`).

---

## 8. Recommendation

**Merge PR #14 (this build's base) AND PR #15 (the follow-up).** PR #14 alone is necessary but not sufficient — it removed one stale call and exposed the next two. PR #15 closes the loop and should make the Desktop stream actually launch.

Next test cycle: build test8 from `fix/session-exec-stale-api` and re-run the same procedure.

---

## Artifacts

| File | Lines | Notes |
|---|---|---|
| `/tmp/vibemis-run-test7.log` | 578 | Tier 1 — full run; pairing works, stream halts at `StreamSegue.qml:171` |
