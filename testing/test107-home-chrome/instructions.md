# test107 — Home-screen per-screen chrome (1a Computers + 1b App grid) (BL-1590)

**Branch:** `test107-home-chrome` · **Base:** `vibemis-main` · **Report:** `diagnostic/test107-home-chrome-report`
**Artifact:** CI alpha via `run-cycle.sh test107-home-chrome`. Independent (off `vibemis-main`).

## What shipped
The redesign home screens now own their **full per-screen chrome** (matching previews `1a`/`1b`)
instead of borrowing the global `ToolBar`. The global toolbar was already collapsed on Settings
(1e) + Help (1f); it now also collapses on **PcView** and **AppView**, so those screens render only
their own header + hint bar — no double header.

- `app/gui/main.qml` — extended `toolBar.redesignScreen` to also match `PcView` and `AppView`
  (`height:0`, `visible:false` on those screens). Global Esc/Back/Menu handlers live on the
  `StackView`, not the toolbar, so back/quit/`☰`-Settings navigation is unchanged.
- `app/gui/PcView.qml` (1a Computers) — fixed header: **"Computers"** title (Sora, `sizeScreenTitle`)
  + live **"N hosts · M online"** count (`textDim`); right = **Add / Help / Settings** icon buttons
  reusing the exact old-toolbar handlers (`addPcDialog.open()`, push `VbHelpView`, `navigateTo`
  Settings). Footer = `VbHintBar` `Ⓐ Connect  Ⓧ Host options  Ⓨ Add computer … ☰ Settings`.
  Online count recomputes via an `onlineRev` bump on model `dataChanged/rowsInserted/rowsRemoved/reset`.
- `app/gui/AppView.qml` (1b App grid) — fixed header: **Back `‹`** (`window.goBack()`) + host-name
  title (`objectName`) + **"K apps available"** count + **Settings** icon button. Footer = `VbHintBar`
  `Ⓐ Launch  Ⓑ Back  Ⓧ App options … ☰ Settings`. Import `QtQuick.Layouts` added.
- `app/version.txt` — `0.24.2` → `0.25.0` (MINOR: feature wave).
- `app/gui/computermodel.h` — `Q_ENUM(Roles)` (enum moved to `public`) so `ComputerModel.OnlineRole`
  resolves in QML for the live host count. Also fixes a latent bug where the `ComputerModel.NameRole`
  int-role lookups (post-pair navigation, OTP dialog title) silently fell back because the enum was
  never registered with the meta-object.

Additive only: the card delegates, `ComputerModel`/`AppModel`, all dialogs (pairing, OTP, rename,
delete, details, test-network, quit), the `1d` host-options sheet (`VbHostSheet`), and the redesign
CUES (`VbFocusRing`, `VbStatusPill`, `VbBadge`, `RESUME` badge) are untouched.

**Known scope notes (intentional):**
- No **Refresh** button: there is no safe backend refresh (`ComputerManager::startPolling()` is
  ref-counted; calling it per-click leaks a polling ref). Host/app state already refreshes via
  continuous polling. Add/Settings/Help (PcView) and Back/Settings (AppView) all have real handlers.
- No dashed **"Add a computer"** grid card: it would require touching the model. The add affordance
  is covered by the header **Add** button + the `Ⓨ Add computer` hint (per the task's fallback).
- The rarely-shown global **update-available** toolbar button no longer appears on home screens
  (same tradeoff already accepted for Settings/Help). Update still surfaces via other paths.

## Tier 1 — launcher (render, both resolutions) — PRIMARY
Run `run-cycle.sh test107-home-chrome`; `selftest` PASS; **no QML errors/warnings** in the log
(esp. no "Cannot read property", no unresolved `VbHintBar`/`ColumnLayout`, no binding-loop on
`topMargin`/`bottomMargin`). Then, in **Desktop Mode**, launch once at **1920×1200** and once at
**1280×800** (resize the window) and score:

1. **Computers (1a):** one header at top = "Computers" + "N hosts · M online" left, three icon
   buttons (Add / Help / Settings) right; NO second/global toolbar above it (no double header).
   Bottom hint bar reads `Ⓐ Connect  Ⓧ Host options  Ⓨ Add computer` … `☰ Settings`.
2. **Count is correct + live:** the "N hosts · M online" matches the actual card count and online
   pills; add/remove or wake a host → the count updates.
3. **Buttons work:** **Add** opens the Add-PC dialog (1c); **Help** pushes the Help screen (1f);
   **Settings** pushes Settings (1e). Back out of each returns to Computers.
4. **App grid (1b):** click a paired online host → header = Back `‹` + host name + "K apps available"
   left, Settings right; no double header. Hint bar reads `Ⓐ Launch  Ⓑ Back  Ⓧ App options` …
   `☰ Settings`. **Back `‹`** returns to Computers.
5. **Cards + cues intact:** host cards show the focus ring on selection, ONLINE/OFFLINE pill, and
   APOLLO/SUNSHINE badge; a running game shows the green `RESUME` badge. Cards clear the header and
   the hint bar at both resolutions (no card hidden under the header; hint bar not overlapping cards;
   no horizontal overflow). Grid scrolls **behind** the fixed header/hint bar (they stay put).
6. **No layout regression at 1280×800:** header title + count + buttons on one row (buttons not
   clipped); hint bar items fit; grid still centered.

## Tier 2 — gamepad + streaming (needs host + controller)
1. **Gamepad nav:** D-pad moves the card focus ring as before; `Ⓐ` connects/launches; `Ⓧ` opens
   host options (1d) / app options; `Ⓨ` on Computers opens Add-PC; `☰` opens Settings; `Ⓑ`/Back on
   the app grid returns to Computers; `Ⓑ`/Back on Computers prompts quit. Header buttons are
   Tab-reachable and show the accent focus ring when focused.
2. **Pairing/wake/launch** all still work end-to-end (pair an unpaired host, wake an offline
   wakeable host, launch/resume/quit a game) — chrome is additive and must not have broken them.
If no host/controller is available, mark Tier 2 **N/A** → Deferred verification ledger; pass on Tier 1.

## Report
`testing/test107-home-chrome/report.md` on `diagnostic/test107-home-chrome-report`; tick the row; bus announce.
