# Redesign correction punch-list — STABLE-1.0 GATE (maintainer escalation 2026-07-12)

**Maintainer verdict:** *"CRITICAL: completely wrong UI was in redesign."* Stable 1.0 is **HELD** until the
shipped build faithfully matches the repo design spec (`docs/design/redesign/previews/1a–1f` + `HANDOFF.md`
+ `tokens/`). Test agent diagnosis + build agent's punch-list below.

**Maintainer decisions (2026-07-12):**
1. **Match the repo spec faithfully** — the previews ARE the intended look; the build drifted. Make the build
   match the spec on every screen, including re-doing the Computers home screen. Test agent validates each
   screen against its preview.
2. **App tiles (1b) — enhance beyond current spec:** use **real per-app box-art/icons** (from the host app
   list) AND a layout that **fills the screen** (more columns / larger grid / centered) — not 3 placeholder
   tiles clustered in the top-left third of a 1920×1200 canvas.

---

## Root cause (single, structural)

**`PcView.qml` (1a Computers — the FIRST screen the user sees) was never converted to the redesign.** It is
still the old Moonlight UI, while `AppView`(1b)/`SettingsView`(1e)/etc. were converted. Evidence:

| Symptom (shipped 0.25.4) | Spec (`previews/1a-computers.png`) | Source |
|---|---|---|
| Royal-blue Material toolbar "Computers" | ◆ VIBEMIS wordmark on dark, no toolbar | `main.qml:257-260` — `redesignScreen` **excludes PcView**, so the global blue ToolBar stays |
| Grey `#303030` background | near-black `#0E1013` | PcView doesn't paint `VbTokens.bgWindow` (AppView does, `AppView.qml:45`) |
| Tall vertical cards (icon-on-top, name below) | wide **horizontal** `VbHostCard` | `PcView.qml:289` old `NavigableItemDelegate` 300×320, 200px icon |
| `APOLLO` badge, no subtitle, no latency | `VIBEPOLLO` badge + "Paired · Full access" + "4 ms · LAN" | old delegate lacks the rich-status row |

This one gap explains BOTH the "blue header" and the "wrong UI" the maintainer flagged — they're the same screen.

## Token-system split (fix as part of this)

Two token singletons coexist and disagree with the spec:
- ✅ `VbTokens.qml` — **spec-correct**: `bgWindow #0E1013`, `bgElev #15181D`, `accent #2FC6D0`, `accentOptions[0]=#2FC6D0`.
- ❌ `Theme.qml` — **wrong**: `accent #00CCCC`, `background #303030`, `surface #2D2D2D`. Old screens (`import Theme 1.0`) render off-spec.

**Action:** migrate any remaining `Theme.*` colour usage on redesigned screens to `VbTokens` (spec), or make
`Theme.qml` alias the `VbTokens`/`tokens.json` values so there is ONE source of truth. Per HANDOFF: accent
`#2FC6D0`, bg-window `#0E1013`, elev `#15181D`, text `#ECEEF1`, dim `#98A1AB`, online `#3ED598`, danger `#F26D6D`.

## The constraint that caused this (must be solved, not worked around)

PcView wasn't converted because the redesigned per-screen header **resized the window during gamescope
swapchain creation → black screen** (`Destroying swapchain: (nil)`). Test agent confirmed that black
regression on 0.25.0 under the project's own `gamescope-emulate.sh` (FROG WSI). So: apply the 1a redesign in a
way that does **not** resize the top-level window after the swapchain exists (e.g. keep a stable window size /
build the wordmark header inside the existing surface / avoid toggling `ToolBar` height on the startup screen).
Verify under gamescope (WSI path), not just Xvfb — Xvfb won't catch the black.

---

## Per-screen validation checklist (build must match each preview)

- [ ] **1a Computers** — wordmark header (no blue toolbar), `#0E1013` bg, horizontal `VbHostCard` with ONLINE/OFFLINE pill + name (Sora) + "Paired · Full access" + VIBEPOLLO/SUNSHINE badge + "4 ms · LAN" / "Last seen…", dashed Add card, hint bar. **NOT black under gamescope.**  ← primary fix
- [ ] **1b App grid** — matches `previews/1b-app-grid.png` for structure; **PLUS enhancement:** real app art/icons + fill-the-screen layout (per maintainer decision #2).
- [ ] **1c Add-PC dialog** — 720px centered modal over scrim, 72px field, Tailscale note, Cancel/Connect. (verify vs preview)
- [ ] **1d Host options** — 560px right side-sheet, full height, action rows, Delete in red. (render-verified 560px on 0.25.2; reconfirm on the correction build)
- [ ] **1e Settings** — 340px sidebar categories + panel; already on `VbTokens`. (verify vs preview)
- [ ] **1f Help** — two columns, Quick Menu hero card, gamepad/keyboard shortcut lists. (verify vs preview)
- [ ] **Both viewports** — 1920×1200 AND 1280×800, no cutoff/overlap.
- [ ] **Fonts** — Sora (titles/wordmark/labels) + Manrope (body) per HANDOFF, if bundled.

## Test-agent validation plan
I compare each shipped screen against its `previews/*.png` and report per-screen PASS/deltas on the bus +
`TEST_AGENT_FINDINGS.md`. **Caveat:** headless-gamescope keyboard nav is unreliable this session (can capture
the 1a landing screen without input; nav-gated screens need input) — so please **self-verify 1c–1f under Xvfb/
real display** as you go; I'll confirm what I can capture and do the decisive 1a check under gamescope.
