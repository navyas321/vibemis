# Test117 Report — AppView re-entry resumes the running session (BL-1756)

**Artifact:** `Vibemis-0.2.0-alpha.009-x86_64.AppImage`
**md5:** `4abec8dc6b0db7ab86f08b5177d8aeb6` ✓ · **sha256:** `914333a0…43dbea04` ✓ (both exact vs dispatch)
**Branch:** `test117-resume-reentry` (commit `0587759`) — **Device:** Legion Go S Z2, SteamOS 3.8.5
**Test date:** 2026-07-16 — self-serve Tier 1 (no host operator). Gamepad nav via the uinput rig.

---

## 1. TL;DR

| Goal | Status | Evidence |
|---|---|---|
| A — end-without-quit stamps the app; re-entry RESUMES not relaunches | **PASS** | stamp line fired; AppView showed RESUME badge; A sent `/resume` not `/launch` |
| B — negative: activating a DIFFERENT app keeps the quit-prompt flow | **PASS** | "Are you sure you want to quit Desktop?" dialog appeared |
| C — regression: proper quit → no phantom RESUME after next poll | **PASS** | after host quit + refresh, badge gone, tile back to plain Launch |

**Recommendation: MERGE — close BL-1756.**

## 2. Tier 0 — integrity + boot

md5 + sha256 both exact. `selftest --json` → `"failures":0,"result":"PASS"`, exit 0.

## 3. Tier 1 — resume on re-entry (the fix)

Streamed Desktop from Navid-PC (stream up 16:37:13). Ended the stream **without quitting**
(`Ctrl+Alt+Shift+Q` disconnect, not "Quit app"). The new stamp fired immediately:

```
00:01:18 - Qt Info: Session ended without quit; app 785894588 stays current for AppView resume
```

Back in AppView the Desktop tile showed the green **RESUME** badge + play glyph (screenshot).
Pressing **A** on it issued RESUME, not LAUNCH — the exact bug from the test110 finding:

```
00:01:55 - Qt Debug: NvHTTP …Command: "resume" Arguments: "appid=785894588&mode=2880x1800…"
00:01:55 - Qt Info:  Executing request: "https://192.168.4.96:47984/resume?…appid=785894588…"
```

(Contrast: the very first cold launch this session used `/launch?…` — so the client correctly
picks `/resume` only when a session is stamped-live.)

## 4. Negative + regression

- **Negative (different app):** disconnected without quit (RESUME badge live on Desktop), then
  activated **Steam**. The **"Are you sure you want to quit Desktop? Any unsaved progress will be
  lost."** confirm dialog appeared — the existing quit-prompt flow is preserved for a different
  app; the resume path did not hijack it.
- **Regression (proper quit self-heals):** performed a proper host-side quit
  (`Vibemis … quit "Navid-PC"` → `<cancel>1`), refreshed AppView. The **RESUME badge cleared**,
  the Desktop tile reverted to the plain monitor icon + "Launch", and the bottom bar dropped
  "Quit session". The stale currentGameId self-heals via the serverinfo poll as designed — no
  phantom RESUME.

## 5. AppView/badge oddities

None. Badge, play glyph, and the "Quit session" hint appeared/cleared consistently with session
state. (Note: in Desktop Mode the RESUME/quit context menu is gamepad/keyboard-only, consistent
with the standing Quick-Menu touch-operability gap — not a test117 regression.)

## 6. Teardown

Stream disconnected, host session quit (`<cancel>1`, confirmed by the badge clearing — a busy
host would keep it), app closed, gamepad rig stopped, `/tmp/test117-*.log` removed after excerpts.

## 7. Recommendation

**MERGE — close BL-1756.** All three tiers pass: resume-on-re-entry works end-to-end, the
different-app quit-prompt is intact, and a proper quit self-heals the badge via the poll.
