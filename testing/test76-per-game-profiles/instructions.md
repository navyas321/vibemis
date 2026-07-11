# test76 — Per-game stream profiles (P3.8 headline parity feature)

**Branch:** `test76-per-game-profiles` · **Base:** `vibemis-main` · **Report:** `diagnostic/test76-per-game-profiles-report`
**Artifact:** CI 🔬 alpha for this branch — `./testing/run-cycle.sh test76-per-game-profiles` fetches and md5-verifies it.
**Host needed:** paired only (Tier 1 needs the app grid, no stream). Tier 2 streams briefly — Navid-PC is authorized.

## What shipped

Per host+app **stream profiles**: right-click (or controller Menu button) on a game tile →
**"Save Current Settings as Game Profile"** snapshots the current global resolution/FPS/bitrate/HDR
into QSettings (`appprofiles/<hostUuid>/<appId>/...` in `~/.config/Vibemis Project/Vibemis.conf`).
When a profiled game is launched, the session runs on a **private preferences copy** with the profile
applied — the global settings object is untouched (Settings UI keeps showing global values). A second
menu item **"Clear Game Profile (summary)"** removes it. Log line at launch:
`AppProfileManager: applying per-app profile for app <id> on <uuid>: WxH@FPS <kbps> kbps HDR=<0|1>`

## Tier 1 — launcher-only (profile CRUD + persistence)

1. `./testing/run-cycle.sh test76-per-game-profiles` (fetch + md5 + selftest: expect `SELFTEST RESULT: PASS`).
2. Launch the app (Desktop Mode, `QT_QPA_PLATFORM=xcb` as usual), open **Navid-PC**'s app grid.
3. On any non-running app tile open the context menu (right-click / Menu button):
   - EXPECT a new item **"Save Current Settings as Game Profile"** (below Direct Launch/above Hide Game order may vary).
   - Trigger it. Re-open the menu: EXPECT it now reads **"Update Game Profile from Current Settings"**
     and a second item **"Clear Game Profile (WxH @ FPS, N Mbps…)"** matching your current Basic Settings.
4. `grep -A5 appprofiles ~/.config/Vibemis\ Project/Vibemis.conf` — EXPECT width/height/fps/bitrate/hdr keys under the host uuid + app id.
5. Quit, relaunch, re-open the menu: EXPECT "Update…" + "Clear…" still shown (persistence).
6. Trigger **Clear Game Profile**, re-open menu: EXPECT back to "Save Current Settings…", and the
   `appprofiles` group gone from the conf (re-run the grep).

## Tier 2 — stream applies the profile (short stream, authorized)

1. In Settings, note current resolution/FPS (call it GLOBAL). Change to a DIFFERENT distinctive shape
   (e.g. 1280x720 @ 60, 5 Mbps), go to the grid, **save profile** for the **Desktop** app, then set
   Settings BACK to GLOBAL (e.g. 1920x1200 @ 120).
2. Launch **Desktop** with logging. EXPECT in the log:
   `AppProfileManager: applying per-app profile for app <id> ...: 1280x720@60 5000 kbps` and the
   stream negotiating **720p60** (stats overlay / stream info), while Settings still shows GLOBAL.
3. Quit the stream. Clear the profile from the tile menu. Launch Desktop again: EXPECT **no**
   "applying per-app profile" line and the stream at GLOBAL shape.

## Negative checks

- An app with no profile must show only "Save Current Settings…" (no Clear item) and log no
  `AppProfileManager: applying` line at launch.
- Settings → the global values must never change as a side-effect of save/apply/clear.

## Report

`testing/test76-per-game-profiles/report.md` on `diagnostic/test76-per-game-profiles-report`,
PR against `test76-per-game-profiles`. Tick the checklist row (☑/✗) in the same commit.
Announce START/DONE on the bus: `https://hearth.tail71d120.ts.net/api/coordination/announce` (ASCII payload).
