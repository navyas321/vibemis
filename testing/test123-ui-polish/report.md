# Test123 Report — UI polish pair: combo arrow guard (BL-2021) + overlay hit-slop (BL-2032)

**Artifact tested:** `Vibemis-0.2.0-alpha.015-x86_64.AppImage`
**md5:** `d2e1b5d13abf9b3f48393da4dedc3fdf` ✓ verified
**sha256:** `4bf28f4f7af8f7f5cec3a9e2e01e1f555b4ec3f5d68c7e8f3e242cd739aaa5b3` ✓ verified
**Branch:** `test123-ui-polish` (report off `c99e39c0`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0
**Test date:** 2026-07-16
**Prior report:** N/A (first cycle for this branch)

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — BL-2021 combo arrow guard | **PASS** | Closed combo arrows navigate (no value edit); open popup + commit is the only edit path; Esc = no commit; gamepad d-pad unaffected |
| B — BL-2032 overlay hit-slop | **PASS** | All three buttons accept taps ~10px beyond their 64px visuals on every open edge; KBD/TOUCH gap split at midpoint fires exactly one; 30px-away passes through to host |

Tier 0: md5 ✓, sha256 ✓, `selftest --json` = `{"failures":0,"result":"PASS"}` exit 0.

---

## 2. Tier 1 — BL-2021 combo guard (launcher, synthetic keyboard via xdotool)

Tested on the Video settings ComboBoxes (Resolution, Frame rate). All four rows PASS.

1. **Closed combo + arrow = navigate, value unchanged.** Resolution focused-and-closed (opened
   then Esc, teal focus ring, value "Native (1920x1200)"). Pressed **Down** → focus moved to the
   Frame rate combo (ring jumped), **Resolution value stayed "Native (1920x1200)"**. This is the
   fix: closed combos no longer edit their value on focus-walk arrows.
2. **Open popup + arrow-nav + commit = the only edit path.** **Space** opened the Frame rate popup
   (30/60/120/Custom); **Up** highlighted 60 FPS; **Enter** committed → Frame rate changed to
   **60 FPS**. Value changes only here.
3. **Esc from open popup = no commit.** Opened Resolution (hovered 1080p) → **Esc** → value stayed
   **Native (1920x1200)**, the hovered option was not committed (default QQC2 behavior intact).
4. **Gamepad d-pad regression clean.** With the Steam Virtual Gamepad connected, d-pad Tab-navigated
   through the Video controls (landed on the Video scaling combo) **without mutating any ComboBox
   value** (Resolution/Frame rate/Video scaling all unchanged). **LB/RB flipped categories**
   bidirectionally (Video ⇄ Audio). UiNavMode = Tab confirmed unaffected.

**Nuance worth noting (not a regression):** a *closed* combo does **not** open on plain **Enter/Return**
— it opens on **Space** (or Alt+Down/F4), which is standard Qt Quick Controls 2 behavior. Enter
*does* commit the highlighted item once the popup is open. The instruction's "A/Enter opens" holds
for the gamepad A button (maps to activate/Space); a bare keyboard Enter on a closed combo is a
no-op by QQC2 design. Flagging only so the keybinding expectation is documented.

Frame rate was restored to 120 FPS after the test (prefs left at baseline).

## 3. Tier 2 — BL-2032 hit-slop (live Desktop stream, synthetic direct-touch rig)

Method: a recreated uinput touchscreen rig (`INPUT_PROP_DIRECT` + ABS_MT, 1920×1200, real
`SDL_FINGERDOWN` — synthetic mouse cannot reach these paths). Direct-touch mode, native-res
fullscreen stream (no letterboxing, scale = 1). Button geometry from alpha.015 source:
`TouchButtonSize=64, Inset=24, Spacing=12, slop=12`. MENU top-left (visual [24–88]²), TOUCH-MODE
and KBD top-right 12px apart. Every claim verified by an observable side effect (Quick Menu opens /
"Steam keyboard requested" / "Touch mode:" toggle toast), reset between taps with gamepad B.

1. **MENU, ~10px outside each edge — all four HIT.** Taps at (14,56) left, (98,56) right, (56,14)
   top, (56,98) bottom each **opened the Quick Menu**. Center control (56,56) hit as expected.
2. **KBD, outer edge + above + below — all HIT.** (1906,56), (1864,14), (1864,98) each fired
   **"Steam keyboard requested"**, with **no** touch-mode toggle.
   **TOUCH-MODE, outer edge + above + below — all HIT.** (1746,56), (1788,14), (1788,98) each
   **toggled touch mode**, with **no** KBD fire.
3. **Gap midpoint fires exactly one.** The 12px gap between TOUCH-MODE (visual right 1820) and KBD
   (visual left 1832) splits at **x=1826**. A tap there fired **TOUCH-MODE only** (KBD count
   unchanged) — the shared boundary pixel resolves to touch-mode per the hit-test order. **Never
   both, never a host pass-through.**
4. **Slop is bounded.** Taps ~30px past the slop region — (56,130) and (56,200) — did **not** hit
   any button; they **passed through to the host** (the host desktop UI responded, Quick Menu did
   not open). Confirms the enlarged hit target doesn't swallow nearby host taps.

Touch mode left at **Direct touch** (baseline); `abstouchmode=true`, `touchoverlay=true` verified
in config after teardown.

## 4. Other findings

- Rig note: the recreated `vtouch.py` needed the 64-bit `input_event` struct (`@llHHi`, 24-byte)
  — a 16-byte pack throws `EINVAL` on write. Functionally validated (a tap switched Settings
  categories) before the stream, per rig discipline.
- The "Refreshing server commands on open" log line does **not** fire on every Quick Menu open
  (server-command cache), so it is unreliable as a per-open counter — screenshot/toggle-state and
  the toast logs are the trustworthy signals.

## 5. Teardown

Stream **Disconnected** (Desktop stream — the maintainer was actively working on that desktop, so
Disconnect was chosen over Quit-game to leave their session running). App closed, input rigs
stopped. Prefs at baseline (Frame rate 120, Direct touch, overlay on). Nothing left host-side.

## 6. Recommendation

**MERGE.** Both fixes verified independently and completely — BL-2021 all 4 rows, BL-2032 all 4
rows including the gap-midpoint disambiguation and the bounded-slop pass-through. No regressions.
One documentation nuance (Enter vs Space to open a closed combo) noted in §2; not blocking.
