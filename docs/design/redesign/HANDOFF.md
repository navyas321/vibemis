# Vibemis — build handoff

This folder is a finished **design prototype** for a full redesign of **Vibemis** — a gamepad-first
Linux/SteamOS game-streaming client (a Moonlight / Artemis Qt6+QML fork) that pairs with **Apollo /
Vibepollo** hosts and runs on handhelds (Lenovo Legion Go S, Steam Deck) from Steam Game Mode. It is
the source of truth for the visual system. Use it to build the real app in Qt6/QML — **do not
redesign, implement it faithfully.**

## What's here
| File / folder | What it is |
|---|---|
| `Vibemis Redesign.dc.html` | **Entry point** — open in a browser to see the whole canvas (pan/zoom, focus any screen). All six screens live here, ids `1a`–`1f`, each an `[data-screen-label]` block. |
| `tokens/vibemis-tokens.json` | **Canonical** design tokens (hex, type, spacing, radius, focus-ring recipe, gauge/motion). Map 1:1 into QML. |
| `tokens/vibemis-tokens.css` | CSS mirror of the same tokens (variables + focus-ring/motion helpers). |
| `logo/app/` | App-icon tiles 16–512 + transparent marks (diamond-cradling-play). See `logo/README.md`. |
| `logo/README.md` | How to use / regenerate the logo; Linux hicolor + Steam grid + Windows `.ico` packing. |
| `previews/` | **Static render** of each redesigned screen (1a–1f), 1920×1200 — quick visual reference. |
| `original-ui/` | Screenshots of the **current** app (before state) for before/after reference. |

## Locked decisions
- **Six screens:** `1a` Computers · `1b` App grid · `1c` Add-PC dialog · `1d` Host options **(a right
  side-sheet that replaces the old right-click context menu)** · `1e` Settings **(sidebar categories,
  one section at a time; LB/RB switches)** · `1f` Help.
- **Gamepad-first, always.** One focused element per screen; focus = 2 px accent border + 5 px
  accent@22 % glow + elevation; hit targets ≥ 56 px; a persistent **button-hint bar** (`Ⓐ/Ⓑ/Ⓧ/Ⓨ`,
  `LB/RB`, `☰`) at the bottom of every screen (toggleable).
- **Dark theme only.** accent `#2FC6D0` (3 alt accents offered), bg-window `#0E1013`, elev `#15181D`,
  text `#ECEEF1`, dim `#98A1AB`, online `#3ED598`, danger `#F26D6D`. Full set in `tokens/`.
- **Type:** Sora (700/800) for titles/wordmark/labels; Manrope (400–800) for body/UI.
- **Canvas 1920×1200 (Legion Go S)**; must scale cleanly to 1280×800 (Steam Deck) and other sizes —
  use anchors/Layouts + relative units, never hard-coded coordinates.
- **Rich host status:** online dot (pulse) + host-type badge (Vibepollo / Apollo / Sunshine) + latency
  + transport (LAN / Tailscale); offline → greyed card + "Last seen …".

## Screens (detail)

### `1a` Computers — host list
Header (wordmark left; 52×52 icon buttons right: Add `+`, Refresh, Help `?`, Settings `⚙`) → title
"Computers" + "2 hosts · 1 online" → row of **430 px** host cards (gap 32) → hint bar.
- **Online card (focused):** monitor icon; `● ONLINE` pill (dot pulses); name (Sora 27); "Paired ·
  Full access"; `VIBEPOLLO` badge (accent outline) + "4 ms · LAN". Focus = accent ring + elev-2 fill.
- **Offline card:** whole card `opacity .75`; grey monitor + `● OFFLINE`; `SUNSHINE` badge (neutral);
  "Last seen 2 h ago".
- **Add card:** dashed border, `+` circle + "Add a computer".
- Hint bar: `Ⓐ Connect  Ⓧ Host options  Ⓨ Add computer` … `☰ Settings`.

### `1b` App grid — launch on selected host
Header: Back `‹` + host name w/ green dot + "Vibepollo · 4 ms"; right Refresh, Settings. Body: "Apps" +
"3 available" → **320×430** tiles (gap 36): Desktop, Steam **(focused — accent ring, green `RESUME`
badge, `Ⓐ Launch` under it)**, Virtual Desktop (dashed + `+`). Hint bar: `Ⓐ Launch  Ⓑ Back  Ⓧ App
options` … `☰ Settings`.

### `1c` Add-PC dialog
Scrim `rgba(4,5,7,.72)` over Computers; centered **720 px** modal (radius 24, pad 48). Title "Add a
computer" + helper; a **72 px** text field (focused ring, sample `192.168.1.42` + blinking caret);
Tailscale note (Tailscale in accent, `100.x.x.x` in text-mute). Buttons right: **Cancel** (`Ⓑ`, neutral)
+ **Connect** (`Ⓐ`, accent fill, text `#08090B`).

### `1d` Host options — action sheet (replaces the context menu)
560 px right side-sheet, full height, slides in over a 60 % scrim. Header: monitor + ONLINE pill; name
(Sora 28); `VIBEPOLLO` badge + "Full access · 4 ms · LAN". **66 px action rows** (icon + label): *View
all apps* (focused), *Test network*, *Rename*, *View details & permissions*; divider; *Delete PC* in
red. Footer: `Ⓐ Select  Ⓑ Close`. (Maps to the old menu: View All Apps / Test Network / Rename / View
Details / Delete — plus the Apollo permissions viewer.)

### `1e` Settings — sidebar categories
Header: Back `‹`, "Settings", right `Version 0.6.7` chip. Body = **340 px sidebar** (Video [selected],
Audio, Input & gamepad, Streaming (Apollo), Advanced — 58 px rows) + panel. **Video panel:** live
summary line (`1920×1200 · 120 fps · 64 Mbps …`, stats in accent); two dropdown cards (Resolution,
Frame rate); a **bitrate card** (label + "64 Mbps", accent slider, "≈ 28.8 GB/hour"); three **toggle
rows** (label + sublabel + switch): *Use virtual display* (ON), *HDR streaming* (off), *V-Sync* (off).
Migrate **every** setting from the current app (`original-ui/6-settings-view.jpg`) into these 5
categories. Hint bar: `LB RB Switch category   Ⓐ Toggle / adjust` … `Ⓑ Back` (LB/RB are rounded key
caps, not circles).

### `1f` Help
Header: Back `‹`, "Help". Two columns. **Left:** a hero **Quick Menu** card (subtle accent gradient,
accent border) — "Open the in-stream overlay" + chord `Select + L1 + R1 + Ⓨ` as key caps; below,
**Gamepad shortcuts** (Quit stream, Performance stats, Mouse emulation). **Right:** **Keyboard
shortcuts** ("All require Ctrl + Alt + Shift"; `\ Q X V`) + **Remote play** (Tailscale for
cross-network).

## Interactions
D-pad/stick moves focus; `Ⓐ` confirm/launch/connect, `Ⓑ` back/cancel/close, `Ⓧ` options (opens `1d` on
Computers), `Ⓨ` add computer, `☰` Settings, `LB/RB` switch Settings category. Online dot pulses;
Add-PC caret blinks; sheet & dialog dismiss on `Ⓑ`; Delete PC confirms first; the Settings summary line
is live; Apollo-only features (virtual display, permissions, Quick Menu, server commands) light up only
on capable hosts.

## State model
- `hosts[]`: `{ name, online, paired, access, hostType (vibepollo|apollo|sunshine), latencyMs,
  transport (lan|tailscale), lastSeen }`
- `selectedHostId`, per-view `focusedIndex`, `activeView`, `actionSheetOpen`, `addDialogOpen`,
  `addDialogInput`
- Settings: `resolution`, `fps`, `bitrateMbps`, `useVirtualDisplay`, `hdr`, `vsync` + the full current
  set, grouped under the 5 categories
- Theme: `accent` (one of the 4 token values), `showHints` (bool)

## Assets
- **Fonts:** Sora (700/800) + Manrope (400–800), Google Fonts — bundle in the Qt build.
- **Icons:** the prototype draws icons with CSS borders as **placeholders** (monitor, refresh, gear,
  help, plus, back, info, trash, checkbox) — swap in the app's real icon set / SVGs.
- **Logo:** `logo/app/` (generated). No other raster art is required.

## How the prototype is wired (if you edit it)
A single self-contained Design Component (`Vibemis Redesign.dc.html`). All six screens are inline-styled
`<section>`/`<div>` blocks on one canvas. Two live tweaks are exposed as props: **accent** (4 curated
colors) and **showHints** (hint-bar visibility). Tokens flow from `tokens/` — treat those values as
exact when porting to QML.
