# Test118 Report — overlay v2: 3 icon buttons + SteamOS keyboard (BL-2002 / BL-2007)

**Artifact:** `Vibemis-0.2.0-alpha.010-x86_64.AppImage`
**md5:** `7873631741e506e146a2fde63677cf22` ✓ · **sha256:** `9fc64075…203969c` ✓ (both exact)
**Branch:** `test118-overlay-v2` — **Device:** Legion Go S Z2, SteamOS 3.8.5, **Desktop Mode**
(spec says Game Mode preferred; driven here via the synthetic uinput touch + gamepad rigs — the
actual SteamOS OSK *rising* is a Game-Mode behavior, see §3.4).
**Test date:** 2026-07-16

---

## 1. TL;DR

| Area | Status | Note |
|---|---|---|
| 3 icon-only buttons, correct positions | **PASS** | hamburger TL · touch glyph · keyboard far-TR; ~64px translucent, no labels |
| MENU opens + tap-again closes Quick Menu | **PASS** | `QuickMenu: Refreshing server commands on open`; re-tap closes |
| KBD button → SteamOS OSK request | **PARTIAL** | client toast `"Steam keyboard requested"` fires; OSK *rising* is Game-Mode |
| TOUCH toggle → toast + mode flip both ways | **PASS** | `"Touch mode: Virtual trackpad"` ↔ `"Touch mode: Direct touch"` |
| Quick Menu: new "On-screen keyboard" + old "Type text" rows | **PASS (present)** | both visible; row *activation* is gamepad-only (see §4) |
| Buttons never cause a host click | **PASS** | taps toast/act, never inject a host mouse click |

**Recommendation: MERGE the overlay v2** (all user-facing pieces present and functional), **with
two follow-ups** (§5): (a) MENU hit-target is tighter than its 64px visual; (b) Quick-Menu rows
remain gamepad-only / not touch-operable (BL-1748 persists in v2).

## 2. Tier 0

md5 + sha256 exact. `selftest --json` → `"failures":0,"result":"PASS"`, exit 0.

## 3. Tier 1 — overlay v2 visuals + actions

**3.1 Three buttons (eyeball verdict for the maintainer):** all three composite in the top strip,
icon-only, translucent ~64px: **MENU** hamburger top-left; **KBD** keyboard glyph far top-right;
**TOUCH** touch/radar glyph immediately left of KBD (~12px gap). Icons are **legible at handheld
distance** — hamburger, keyboard, and touch-radar are each unambiguous. Matches the locked spec.

**3.2 MENU open/close:** tapping the hamburger opened the Quick Menu
(`QuickMenu: Refreshing server commands on open`); a second tap closed it (menu region went blank).

**3.3 TOUCH toggle:** tapping cycled the mode with a toast each time —
`showToast("Touch mode: Virtual trackpad")` then `("Touch mode: Direct touch")` — and the persisted
`abstouchmode` flipped accordingly. Works in both directions.

**3.4 KBD button:** tap fired `QuickMenuManager: showToast("Steam keyboard requested")` — the
client-side OSK-request path works. Whether the **SteamOS on-screen keyboard actually rises + typed
chars land on the host** is a **Game-Mode** behavior (Steam's OSK is a Game-Mode/Gamescope
surface); Desktop Mode surfaces only the request + toast. Flagging the OSK-rises + typing-lands
half as a **Game-Mode re-verify** (consistent with the standing "Game Mode is the supported
workflow" rule).

**3.5 Menu rows:** the new **"On-screen keyboard"** row ("Open the SteamOS on-screen keyboard") and
the old **"Type text"** row ("Send typed text to the host") are both present, plus Paste/Upload/
Fetch clipboard, Server commands, Disconnect, Quit game. (Type-text + BL-2000 border padding were
verified end-to-end in test115; unchanged here — row present.)

## 4. Tier 2 — negatives / regressions

- **Buttons never click the host:** every button tap produced a client action/toast, never a
  host-side mouse click. (During the run I confirmed the inverse too: a stray tap *off* the buttons
  passed through to the host — the top strip between buttons still reaches the host, per spec.)
- **BL-1748 persists (touch-operability):** the overlay *buttons* (MENU/KBD/TOUCH) are touch-driven
  and work, but the **Quick Menu list rows are still gamepad/keyboard-only** — a touch tap on the
  "On-screen keyboard" row (well inside its bounds) did nothing; the row only activates via d-pad+A.
  A touch-only user can open the menu but not operate its rows.
- Overlay ON/OFF toggle, Steam-absent negative, and the mid-gesture two-finger guard (step 7) were
  **not exercised** this run — flag for the Game-Mode re-verify alongside the OSK-rises check.

## 5. Findings / follow-ups

1. **MENU hit-target tighter than the 64px visual.** A tap only ~12px off the visual center
   (client (60,60) vs. the working center ~(53,43)) **missed**; KBD/TOUCH (tapped near their
   centers) hit first try. Corroborates the maintainer's known hit-target-size row — recommend the
   touch AABB match (or slightly exceed) the 64px icon, especially for the corner-hugging MENU.
2. **Quick-Menu rows not touch-operable** (BL-1748, still open in v2) — the OSK/Type-text/etc. rows
   need a touch-activation path for a keyboard-less handheld, or the menu stays gamepad-gated.

## 6. Teardown

Stream quit, host session cancelled (`<cancel>1`), app closed, both rigs stopped. Settings restored
(abstouchmode=direct, overlay on, scaling off, scale-factor reset to 100). Nothing left on the host.

## 7. Recommendation

**MERGE overlay v2** — the three-button layout, MENU open/close, TOUCH-mode toggle, KBD OSK-request,
and the new On-screen-keyboard menu row are all present and working; icon legibility passes the
eyeball call. Ship it, and schedule a short **Game-Mode re-verify** for the two behaviors Desktop
Mode can't fully show (OSK actually rising + typing landing; mid-gesture guard) plus the two §5
follow-ups (hit-target size, menu-row touch operability).
