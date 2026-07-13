# Session handoff — manual-testing cascade + beta ship (2026-07-13)

Pick-up doc for continuing in a fresh session. Covers what shipped, what's verified, and what's
left. Companion docs: **`docs/UI_DEFECT_CHECKLIST.md`** (every defect + status) and the memory note
`vibemis-render-test-text-clip-gap.md` (why automated testing missed the cutoffs).

---

## 1. What SHIPPED (this session)

**Commit `b6198e4f`** on `vibemis-main` (fast-forward from `test109-gamescope-scaling`) — a single
beta with the whole manual-testing cascade of fixes. Build: `make release` clean (exit 0, 43 MB
binary); all 8 edited QML files pass `qmllint` (no parse errors, only expected import warnings).

- **Beta build**: `gh workflow run dev-build.yml --ref vibemis-main` → run **29226398013**
  (workflow_dispatch, was still building the AppImage at handoff). **VERIFY IT PUBLISHED**:
  `gh run list --workflow=dev-build.yml` and check GitHub Releases for a fresh `1.0.1-beta.<ts>`.
  If the dispatch didn't publish, re-run it (direct pushes to vibemis-main don't auto-release; only
  workflow_dispatch or a PR merge does).

### Fixes in `b6198e4f` (all code-written + compiles; **need on-device verification by maintainer**)
| Area | Fix | Files | ID |
|---|---|---|---|
| Settings combos clip text | recalc width at init (`onCountChanged/Completed: Qt.callLater`) — RCA-confirmed fixes ALL 13 combos, not just the 3 seen | `AutoResizingComboBox.qml` | BL-1664 |
| Settings 1-D nav + double selector | lock selection↔focus (`focusCategoryRow`/`onActiveFocusChanged`/up-down) → true 2-D, one ring | `SettingsView.qml` | BL-1667 |
| Window never fills 1920×1200 / apps squished | init `isSteamDeck` (was uninitialized) via new `isSteamDeckOrGamescope()`; maximize default windowed on handhelds; min height 600→720 | `main.qml`, `systemproperties.cpp` | BL-1668 |
| Quick Menu no d-pad auto-scroll | nav auto-repeat timer (380→90ms) | `quickmenumanager.*`, `gamepad.cpp` | BL-1665 |
| Quick Menu left stick dead | translate left stick → nav (edge-detected) | `gamepad.cpp`, `input.h` | BL-1665 |
| Quick Menu selector too tight | row 60→70px | `QuickMenu.qml` | BL-1666 |
| Help screen unusable/cutoff/not navigable | grab focus (Ⓑ/Back work), Flickable scroll, real column widths | `VbHelpView.qml` | BL-1669 |
| Home-grid freeze (repro hardening) | land on a real card when focus enters the grid | `PcView.qml` | BL-1662 |
| (already uncommitted before) freeze / card cutoff / tile squish | ghost non-focusable / anchored badge row / aspect-preserving width | `PcView.qml`, `VbHostCard.qml`, `AppView.qml` | BL-1662/1661/1663 |

---

## 2. Answered questions (no code needed)

- **"Quit session quits the whole app — crash or by design?"** → **BY DESIGN, not a crash.**
  `QuickMenuManager::quit()` intentionally calls `setShouldExitAfterQuit()` + `http.quitApp()`:
  **Quit** = terminate the game on the host AND exit Vibemis (back to Steam/Game Mode). **Disconnect**
  = end the stream, stay in Vibemis at the grid (game keeps running on host). BL-1630 already hardened
  this path against the old quit-crash. *Optional polish (not done, ask first): relabel "Quit" →
  "Quit game & exit Vibemis" in `QuickMenu.qml` for clarity.*

- **"Is there a way to update without GitHub / from Game Mode?"** →
  - The in-app toolbar "update" button is **notify-and-link** (opens the Releases page), not an
    installer.
  - **Fixed `scripts/vibemis-update.sh`** this session: it used `/releases/latest` which GitHub
    returns **only for non-prereleases**, so it could never fetch a beta. Now defaults to the newest
    release **including betas** (`/releases`), with `--stable`, `--check`, `--launch` flags.
  - **Easiest Game-Mode path today**: add `vibemis-update.sh --launch` as a non-Steam shortcut
    ("Update Vibemis") → one tap downloads the newest beta to `~/Applications/Vibemis.AppImage` and
    launches it. (Or run `bash scripts/vibemis-update.sh` from Konsole in Desktop Mode.)

---

## 3. NEXT / IN PROGRESS — in-app update channel selector (user's latest request)

**Requested but NOT started in code.** User wants to select **Stable / Beta / Alpha** inside the app
and update easily (ideally one-tap from Game Mode). Design scoped this session:

1. **Pref** — add `enum UpdateChannel { UC_STABLE, UC_BETA, UC_ALPHA }` + `updateChannel` member,
   Q_PROPERTY, and save/load in `app/settings/streamingpreferences.{h,cpp}` (mirror the
   `UIDisplayMode` pattern at streamingpreferences.h:75-81, :238, :318). Default `UC_STABLE`.
2. **Checker** — `app/backend/autoupdatechecker.cpp` already queries `/releases` (all). Currently it
   hard-filters to stable only (BL-1646, lines ~153-164). Change to filter **by channel**: Stable =
   `!prerelease && !draft`; Beta = tag contains `-beta`; Alpha = tag contains `-alpha`. Also extract
   the `.AppImage` **asset** `browser_download_url` (not just `html_url`) and add
   `Q_INVOKABLE void checkNow()`.
3. **In-app install (the friction-killer, AppImage only)** — add
   `Q_INVOKABLE void installUpdate(QString assetUrl)`: download to `$APPIMAGE` path + `.new`,
   `chmod +x`, atomic rename, `QProcess::startDetached($APPIMAGE)` + quit. Emit progress signals.
   **Defensive**: temp file + fallback to opening the release page on any failure. ⚠️ Can't be
   validated on the build host (host = BUILD ONLY) — needs on-device test.
4. **Settings UI** — new "Software updates" block in the **Advanced** category of `SettingsView.qml`:
   an `AutoResizingComboBox` for channel (Stable/Beta/Alpha) + a "Check for updates" button +
   status text + an "Update now" button when available. (Combos now size correctly thanks to BL-1664.)
5. **main.qml** — the existing `onUpdateAvailable` banner should offer Install (AppImage) or Open page.

Recommendation: ship the low-risk parts (pref + combo + channel-aware checker + manual check) first;
gate the in-place binary swap behind on-device validation since the build host can't run it.

---

## 4. Backlog / follow-ups (not blocking)

- **Latent MED clip risks** (from the RCA audit, `UI_DEFECT_CHECKLIST.md`) — clip only with longer
  translations/values today: resolution/fps display Text, VbHostSheet action-row labels, VbHintBar
  labels, NavigableMessageDialog 400px height cap, ServerCommands buttons, ClipboardSettings
  checkboxes, QuickMenu row descriptions.
- **Durable test-harness prevention** (from RCA): install **Sora + Manrope** fonts in CI; add
  per-control `contentWidth ≤ width` (not-truncated) assertions on the static page; render at
  1280×800 + pseudo-localization; add "read every control's COMPLETE text" to the test-agent scorecard.
- **Stable 1.0.1** — once the maintainer's manual pass on this beta is green, cut a fresh STABLE
  1.0.1 (contains all blocker + cascade fixes); do NOT un-park the old 1.0.0 (lacks them). See
  memory `stable-release-procedure`.
- **BL-1614** (focus drop-shadow + offline "Last seen") — still pending on-device validation.

---

## 5. Key state / gotchas for the next session

- **Repo**: `C:\Users\navya\Downloads\workspace\vibemis` = source of truth. WSL build clone =
  `/root/vibemis` (Ubuntu-24.04). `version.txt` = `1.0.1` (leave until stable is cut).
- **Build recipe**: `rsync -a --exclude=release/ /mnt/c/…/vibemis/app/ /root/vibemis/app/` (inline
  literal `/mnt/c` paths — `VAR=/mnt/c/…` gets eaten through the GitBash→WSL bridge), then in
  `/root/vibemis`: `touch app/qml.qrc; rm -f app/release/qrc_qml.* app/vibemis`; `qmake6 && make -j4
  release`. QML errors are NOT caught by make — validate with `/usr/lib/qt6/bin/qmllint -I
  app/gui app/gui/<file>.qml` (only import warnings = clean; look for "Error:").
- **Test agent**: maintainer **killed it** and is doing manual testing — do NOT use the coordination
  bus unless they say otherwise.
- **CI**: direct pushes to vibemis-main don't publish a beta; use `gh workflow run dev-build.yml
  --ref vibemis-main`. HEAD commit must touch code (`.cpp/.h/.qml`) or the build is skipped.
- Uncommitted-but-harmless working-tree noise: dirty submodules (`h264bitstream`,
  `moonlight-common-c`) and build artifacts (`config.tests/EGL/EGL`) — do NOT commit these.
