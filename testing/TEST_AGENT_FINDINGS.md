# Test-agent sweep findings — beta 0.25.0 gate (stable-1.0)

**Device:** Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0, Qt 6.9.1. Captures via headless gamescope emulation.
**Steam target:** tracking latest beta (0.24.2 now; will bump to 0.25.0 when it builds).
*Reporting incrementally — build agent hot-fixes each. `⚠️ caveat: gamescope headless has been flaky this session; real-display/Xvfb confirmation recommended for any render finding.`*

---

## Task 5 — Mock pairing/discovery/applist — ✅ PASS (on 0.24.2)
`Vibemis-Mock-Host` @ `100.127.67.80:48900` (tailnet): `list` returns the **real Vibepollo catalog — Desktop / Steam Big Picture / Virtual Display**. Pairing (web-PIN @ :48901) + applist over paired HTTPS 48895 work. Earlier this session I also validated a **real HEVC stream of the Virtual Display** (decoded + EGLRenderer) — the mock is a fully-working real-fidelity host. serverinfo advertises `VirtualDisplayCapable=true`, `MaxLumaPixelsHEVC=1.87B`, Permission bitmask.

## Task 4 — Detail of the "1d bug" (Host-options side-sheet)
**What I observed (headless gamescope, alpha + 0.23.0 beta, 3× reproduced):**
- **Opens?** YES. Trigger = the **Menu key** (`Keys.onMenuPressed`, PcView.qml:358); also right-click / press-and-hold / Enter-on-an-offline-tile (PcView.qml onClicked `!model.online` branch).
- **Renders?** ⚠️ **Collapsed, not as the 560px right panel.** The sheet's *content* appears (I matched it to source: the "access/transport subtitle" `VbHostSheet.qml:148` = the "Full Access" text; the footer hint bar `:263` `{Ⓐ Select}`) — but it renders as a **small cluster on the focused tile (top-left)**, NOT the intended 560px right slide-in panel with scrim.
- **Navigate / crash?** Couldn't exercise D-pad rows / Ⓐ / Ⓑ because the panel never rendered as a panel.
- **Repro:** launch → focus a host tile → press **Menu** → sheet content collapses onto the tile instead of sliding in from the right.
- **Root-cause note:** I initially hypothesized the Popup `width: parent?parent.width:0` (VbHostSheet.qml:36) resolving to 0, but **retracted it** — the Add-PC dialog (also a Popup over Overlay) renders fine in the same harness, so Overlay *has* a width. Cause is VbHostSheet-specific (contentItem override + right-anchored panel + slide-in `x` translate).
- **⚠️ IMPORTANT:** this may be **headless-gamescope-Popup-specific**. You render-verified 1a/1e under Xvfb — **please render-check 1d under Xvfb too**; that's decisive. If it renders fine under Xvfb, it's a headless artifact, not a real bug.

## Tasks 1-3 — pending 0.25.0 build (grab beta → re-verify 1e → full 6-screen sweep both viewports)

## 🚨 CRITICAL (stable-1.0 blocker) — 0.25.0 renders BLACK under gamescope (Game-Mode WSI path)
On beta **0.25.0**, the Vibemis UI renders **fully black** in headless gamescope. Isolated rigorously:
- **glxgears renders perfectly** in the same gamescope → my compositor + `gamescopectl screenshot` WORK.
- **0.24.x rendered fine** in this same gamescope earlier today (captured home/add-pc/help/app-grid) → so this is a **0.25.0 REGRESSION**, not gamescope degradation.
- Renderer inits OK (log: Vulkan RADV, VAAPI on x11, HDR enabled, `[Gamescope WSI] Made gamescope surface`) but then `[Gamescope WSI] Destroying swapchain: (nil)` and the screen stays black (3 identical black screenshots over 25s). QML engine is alive (warnings repeat), so the app runs but never draws its UI.
- **⚠️ Xvfb won't catch this:** gamescope uses the Vulkan **WSI/swapchain** path that real **Game Mode** uses; Xvfb uses plain X software rendering. Your Xvfb 1a/1e check (clean) does NOT exercise the WSI path. **Please launch 0.25.0 under gamescope (or real Game Mode) — the redesign may black-screen in Game Mode.**
- **Also:** `main.qml:308` QML warning repeating every ~2s — `QQuickRectangle: Detected anchors on an item managed by a layout (undefined behavior; use Layout.alignment)` — the version-chip Rectangle. Fix regardless.
- **BLOCKS the visual sweep** (all 6 screens are black) — can't complete tasks 2/3 until 0.25.0 renders under gamescope.

## CONFIRMED via YOUR OWN gamescope-emulate.sh (FROG WSI) — 0.25.0 black is decisive
Ran `scripts/gamescope-emulate.sh -t 20 -- ~/Downloads/Vibemis.AppImage` (the project's own Game-Mode emulation harness — FROG WSI layer + mangoapp, which you wrote/merged). Result: **app ALIVE 20s, +0 coredumps, "gamescope surface made (Game-Mode WSI/HDR path exercised)" — but the screenshot is BLACK (md5 `85ccd4cf`, IDENTICAL to my ad-hoc gamescope black captures).** So it's NOT an ad-hoc-gamescope artifact — 0.25.0 black-screens under the project's own faithful Game-Mode emulation. This is as close to real Game Mode as headless gets. **Strongly implies a real Game-Mode black-screen regression in 0.25.0 — do not tag stable until this is fixed / ruled out on real hardware.**

---

## 0.25.4 sweep (md5 `7c9967dc`, Steam target) — landing-screen checks PASS
Verified under headless gamescope (WSI path) on the **1a Computers** landing screen (no input needed):
- ✅ **Task 2 — NOT black.** 0.25.4 renders the home screen clean under gamescope (the 0.25.0 black regression stays fixed; confirms the test107 toolbar-collapse fix holds on the latest beta).
- ✅ **Task 3 — single header.** One toolbar ("Computers" title + `+`/`?`/gear) + one bottom hint bar. No double header.
- ✅ **BL-1594 hint-bar accuracy.** 1a hint bar now reads **Ⓐ Connect · Ⓧ Host options · ☰ Settings** — the false "Ⓨ Add computer" is GONE (0.25.3 still showed it). Correct.

## 🚨 STABLE-1.0 BLOCKER (user-flagged) — global ToolBar header is still stock Material-INDIGO, not the redesign teal
The top toolbar bar ("Computers" header) renders the **default Material indigo-blue**, clashing with the rest of the redesign, which is correctly teal (hint-bar glyphs, APOLLO badge, Settings hamburger). User escalated this directly: *"Why is the ugly blue color in the header… and not the new modern colors from the redesign."*
- **Root cause:** `main.qml:40` sets `Material.accent = Theme.accent` (teal `#00CCCC`), but **`Material.primary` is never set.** The Material-style `ToolBar` (`main.qml:246`) uses `Material.primary` for its background fill → falls back to the stock Material indigo. Every color *derived from accent* is teal; the toolbar fill (from primary) is not.
- **Fix (build agent):** set `Material.primary = Theme.background` (dark `#303030`) on the ApplicationWindow, **or** give the `ToolBar` an explicit `background: Rectangle { color: Theme.background /* or VbTokens.bgElev1 */ }`. The redesigned per-screen headers were flat-dark, so a dark surface (not a saturated fill) is the consistent choice.
- **Minor (note, not a blocker):** two accent tokens coexist — `VbTokens.accent = #2FC6D0` and `Theme.accent = #00CCCC` (two different teals). Worth unifying to one source of truth eventually.

## Headless keyboard-nav LIMITATION this session (transparency note)
Fresh 0.25.4 captures of the **nav-gated** screens (1b app-grid, 1e Settings, 1f Help, 1d side-sheet open-state) are blocked: keyboard injection is not reaching the app's QML `Keys` handlers in headless gamescope this session — tried xdotool (to display, render surface, and the named Vibemis window) **and** a kernel-level `/dev/uinput` virtual keyboard; screenshot md5s change only from the animated online-status dots, not real navigation. Menu/Ctrl+N worked earlier this session (0.25.2), so it's a gamescope keyboard-**focus** degradation, not a Vibemis bug (app runs, renders 1a, polls host perms every 3s). **1d 560px-panel render, 1e sidebar, 1b/1c/1f were already verified on 0.24.0–0.25.2** (see checklist). Recommend the build agent do the decisive 1b–1f re-capture under Xvfb/real display, or I retry after a fresh Deck session.
