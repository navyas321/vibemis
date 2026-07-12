# test108 — Settings LB/RB shoulder-button category switching (redesign 1e)

Wires the **shoulder buttons** so they actually switch the Settings category, matching the
`VbHintBar` hint **"LB · RB  Switch category"** on screen 1e. Until now this hint was
**visual only** — `test101` shipped the sidebar redesign with an explicit note that "LB/RB
shoulder-button category switching is **not** wired." **This cycle closes that gap.**

**Mapping under test:**
- **LB** (left bumper) → **previous** category (moves the selection *left*, toward **Video**)
- **RB** (right bumper) → **next** category (moves the selection *right*, toward **Advanced**)
- 5 categories in order: **Video (0) · Audio (1) · Input & gamepad (2) · Streaming (Apollo) (3) · Advanced (4)**
- **Clamped 0..4 with NO wrap** — LB at Video stays on Video; RB at Advanced stays on Advanced.

## What changed (2 code files + version)
- `app/gui/sdlgamepadkeynavigation.cpp` — added `SDL_CONTROLLER_BUTTON_LEFTSHOULDER` /
  `RIGHTSHOULDER` cases to the menu-nav button switch. They forward synthetic keycodes
  `Qt::Key_MediaPrevious` (LB) / `Qt::Key_MediaNext` (RB) — the same "repurposed keycode" trick
  already used for Ⓨ (`Key_Yellow`) and Start (`Key_Hangup`).
- `app/gui/SettingsView.qml` — a `Keys.onPressed` handler on the **page root** consumes those
  keycodes and decrements/increments `settingsPage.category` (clamped, no wrap). It lives on the
  root so a shoulder press bubbles up from **whatever control has focus** inside Settings.
- `app/version.txt` → **0.26.3**.

**Nothing else changed** — no panel content, no bindings, no other screen. The existing sidebar
rows are still D-pad/Tab focusable and Ⓐ-selectable (the pre-existing fallback still works).

Build host self-verified: `sdlgamepadkeynavigation.cpp` compiles clean (`qmake6`/`g++ -Wall
-Wextra`, 0 warnings); `SettingsView.qml` passes `qmllint` parse (0 syntax errors). **Runtime
behavior with a real controller is exactly what this cycle must confirm.**

Test on the Legion Go S Z2 with its **built-in controller**. **Game Mode (Gamescope) is the
priority target** — see the Game Mode section. Use `scripts/gamescope-emulate.sh` for Game-Mode
validation. Where a step says "watch stderr", run the AppImage from a terminal.

---

## Tier 1 — Build / launch (must pass)

| # | Step | Expected |
|---|------|----------|
| 1 | Launch the test AppImage | App starts, reaches the Computers screen, no crash |
| 2 | Open **Settings** (`☰` / Start) | Redesigned Settings opens: header + left sidebar (5 rows) + right panel + bottom hint bar |
| 3 | Confirm the version chip | Reads **`Version 0.26.3`** (confirms you're on the test108 build, not an older one) |
| 4 | Look at the hint bar | Shows **`LB` `RB` Switch category** on the left, then `Ⓐ Toggle / adjust`, and `Ⓑ Back` on the right |
| 5 | Run from a terminal, open Settings, press LB & RB a few times, watch stderr | No `qrc:/gui/SettingsView.qml:… ReferenceError/TypeError/Cannot assign` and no crash |

## Tier 2 — Core feature: LB/RB switch category (the main event)

Controller connected, in Settings, **Video** selected on entry.

| # | Step | Expected |
|---|------|----------|
| 6 | Press **RB** once | Selection advances **Video → Audio**: the **Audio** sidebar row gets the accent border/fill, the category **title** changes to "Audio", and the panel shows **only** Audio Settings |
| 7 | Press **RB** again | **Audio → Input & gamepad** (panel shows Input + Gamepad Settings only) |
| 8 | Press **RB** again | **Input & gamepad → Streaming (Apollo)** |
| 9 | Press **RB** again | **Streaming (Apollo) → Advanced** (panel shows UI + Advanced + System Info + About + Help) |
| 10 | Press **RB** a 5th time (already at Advanced) | **Stays on Advanced** — no wrap to Video, no crash, no flicker |
| 11 | Press **LB** once | **Advanced → Streaming (Apollo)** (moves back one) |
| 12 | Hold-tap **LB** three more times | Streaming → Input & gamepad → Audio → **Video** |
| 13 | Press **LB** again (already at Video) | **Stays on Video** — no wrap to Advanced |
| 14 | Each switch above | Sidebar highlight, category title, **and** right-panel content all update **together** and match the selected category |

## Tier 3 — Focus independence + hint-bar accuracy

| # | Step | Expected |
|---|------|----------|
| 15 | Select **Video**, then D-pad **into the panel** and put focus on a control deep in the list (e.g. the bitrate slider or a checkbox) | Control shows its focus ring |
| 16 | With that panel control focused, press **RB** | Category **still advances** (Video → Audio) — proving the shoulder handler works regardless of which control holds focus, not just when a sidebar row is focused |
| 17 | Press **LB** with a panel control focused | Category goes back one, same as above |
| 18 | Compare behavior to the hint bar keycaps | Real behavior matches the advertised **`LB`/`RB` Switch category** (LB = left/previous, RB = right/next) — the hint is now truthful |
| 19 | The pre-existing path still works: focus a sidebar row via D-pad, press **Ⓐ** | That category is selected (sidebar-row selection unaffected by this change) |

## Tier 4 — Regression (no hijack elsewhere; existing input intact)

| # | Step | Expected |
|---|------|----------|
| 20 | On the **Computers** screen, press **LB** and **RB** | Nothing happens — no crash, no navigation, no visual change (these screens don't bind the keys) |
| 21 | On Computers, confirm **Ⓨ** still opens **Add computer** and **Start/`☰`** still opens Settings | Unchanged |
| 22 | Open a **host options / AppView** screen, press LB/RB | No-op, no crash |
| 23 | In Settings, verify all existing gamepad nav still works: D-pad/left-stick navigate, **Ⓐ** toggles/adjusts, **Ⓑ**/Esc backs out, **Start** re-opens | All unchanged |
| 24 | **In-stream passthrough (critical):** start a stream to a host, then in a game that uses the bumpers (or a controller-test) press **LB/RB** | Shoulder buttons reach the **game** normally and do **NOT** switch any settings category (menu-nav is disabled during streaming; only in-stream `gamepad.cpp` is active). Confirm no Settings UI appears mid-stream. |
| 25 | Change a setting in a couple of categories (reached via LB/RB), close Settings, reopen, then fully quit & relaunch | Changes persist (the `StreamingPreferences.save()` on deactivate/destruction still fires) |

## Tier 5 — Negative / stress

| # | Step | Expected |
|---|------|----------|
| 26 | **Mash** RB rapidly ~15×, then LB rapidly ~15× | Selection saturates at Advanced then walks back to Video; never goes out of range, never crashes, panel never blank |
| 27 | **Hold** LB (and separately RB) down for ~2 s | Advances **once per physical press** (SDL button-down is discrete — a held bumper should **not** auto-cycle categories). Note actual behavior if it does repeat. |
| 28 | Press **LB + RB together** | No crash; ends on a single valid category |
| 29 | Switch to Advanced with RB, press **Ⓑ** to leave Settings, re-enter Settings | Re-enters cleanly (note whether it reopens on Video or remembers Advanced — either is acceptable; just report which) |

## Game Mode (Gamescope) — PRIORITY

Repeat the **core** checks under Game Mode, since Game Mode (Gamescope) is the primary target
and input routing differs from Desktop Mode.

| # | Step | Expected |
|---|------|----------|
| 30 | Launch under `scripts/gamescope-emulate.sh` (or add to Steam and launch in Game Mode) | App runs; Settings opens |
| 31 | Repeat steps **6–14** (RB walks Video→Advanced and stops; LB walks back and stops) | Identical behavior to Desktop Mode — LB/RB switch category with no wrap |
| 32 | Repeat step **16** (RB switches category while a panel control is focused) | Works in Game Mode too |
| 33 | Repeat step **24** (in-stream passthrough) in Game Mode | LB/RB reach the game, do not open/switch Settings |

## Layout sanity (light — behavior cycle, not a restyle)

| # | Step | Expected |
|---|------|----------|
| 34 | At **1920×1200** and **1280×800**, switch through all 5 categories with RB/LB | No text clipping, no overlap, hint bar not overlapped, panel scrolls where needed at either resolution |

---

### Report back
Fill each row **PASS/FAIL** with a one-line note. Attach a short **screen recording / GIF** of
RB walking Video→Advanced and LB walking back (Tier 2) — that's the clearest proof. Explicitly
call out: (a) whether **no-wrap** clamping holds at both ends (steps 10 & 13), (b) whether
**focus-independent** switching works (step 16), (c) the **held-bumper** behavior (step 27), and
(d) the **in-stream passthrough** result (step 24) — that one is the most important regression.
Flag any QML console error or crash. Commit the report to
`testing/test108-settings-shoulder-nav/report.md` on a `diagnostic/test108-report` branch and
open a PR.
