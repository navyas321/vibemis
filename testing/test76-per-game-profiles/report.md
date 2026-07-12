# Test76 Report — Per-game stream profiles (P3.8) — **PARTIAL**

**Artifact:** `Vibemis-0.6.7-alpha.test76-per-game-profiles.20260711.2348+010b36c-x86_64.AppImage`
**md5:** `6f2ee714cb3a2e8c568adea0e4fe8292` ✓
**Branch:** `test76-per-game-profiles` (@ `010b36c`) · **Report branch:** `diagnostic/test76-per-game-profiles-report`
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0, Qt 6.9.1
**Test date:** 2026-07-11 · **Method:** `scripts/gamescope-emulate.sh` (nested headless)

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| Build health | **PASS** | `selftest`: prefs-load / default-bitrate / display-mode all **PASS**; launches, Navid-PC grid renders. |
| Feature wiring | **PASS (source)** | AppProfileManager + Save/Update/Clear menu items + conf key format all present & correctly wired. |
| Tier 1 UI CRUD (runtime) | **BLOCKED** | The app-grid **context menu could not be opened headlessly** — synthetic right-click / long-press does not trigger the NavigableMenu popup in nested gamescope/XWayland. No `appprofiles` written. |
| Tier 2 (stream applies profile) | **NOT RUN** | Depends on a Tier-1 save. |

**Not a feature defect — a harness/input limitation.** Needs a physical **right-click / long-press / controller Menu button** on-device (Game Mode), or the build agent's self-run.

## 2. What passed
- `selftest` (in gamescope): `SELFTEST prefs-load: PASS`, `default-bitrate: PASS`, `display-mode: PASS`.
- App launches under gamescope emulation; Navid-PC app grid renders (Desktop / Steam / Virtual Desktop). Screenshots `shots/00-grid.png`.

## 3. Feature source-confirmed (branch @ 010b36c)
- `app/gui/AppView.qml`
  - `:241 onPressAndHold` + `:254 acceptedButtons: Qt.RightButton` → opens `NavigableMenu` (`:296`).
  - `:332-333` item text toggles **"Update Game Profile from Current Settings"** (hasProfile) / **"Save Current Settings as Game Profile"** → `:335 AppProfileManager.saveCurrentAsProfile(uuid, appid)`.
  - `:347 "Clear Game Profile (%1)"` (profileSummary) → `:351 AppProfileManager.clearProfile(...)`.
- `app/backend/appprofilemanager.cpp` — `SER_APPPROFILES "appprofiles"`, `profileGroup = appprofiles/<uuid>/<appId>`, `saveCurrentAsProfile` logs `AppProfileManager: saved profile for app %d on %s: %dx%d@%d %d kbps HDR=%d`.
- Matches the instructions' described behavior (conf group + apply-on-launch log line).

## 4. Blocker detail
- Right-click (`xdotool click 3`) on the Desktop tile registered as a **tile hover** (play/stop overlay), not a context menu (`shots/01-ctxmenu-before.png`). A keyboard-nav retry after right-click showed **no popup** (R1-ctx ≡ R2-navdown byte-identical), and `grep appprofiles ~/.config/Vibemis\ Project/Vibemis.conf` stayed empty.
- Synthetic pointer button-3 / press-and-hold is not delivered to the QML `MouseArea` as a context-menu gesture through nested gamescope + XWayland. (Same class of input-delivery gap noted for the Quick Menu in test75, but here it blocks the *only* entry point to the feature.)

## 5. Recommendation
**ITERATE on verification, not code** — the feature is correctly built and wired. Options to close Tier 1/2:
1. Build agent **self-run** the CRUD + `grep appprofiles` (you self-verified other cycles this way), or
2. An **on-device Game-Mode pass** with the controller **Menu button** (physical) to open the tile context menu, save/clear, and confirm the `AppProfileManager: applying...` log at launch for the 720p60 profile.
No code change indicated from what was testable. Marking the checklist row **⚠ PARTIAL (build+source PASS; UI CRUD needs physical menu-button / self-run)**.
