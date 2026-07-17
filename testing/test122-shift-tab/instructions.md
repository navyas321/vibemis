# Test122 Instructions — Quick Menu "Send Shift+Tab" special key (BL-1788)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** the new Quick Menu row "Send Shift+Tab" reverse-tabs focus **on the host** — the
missing counterpart to the existing special keys.

> **RE-TEST (alpha.016).** The first rev (alpha.014) FAILED host-side: the client fired
> `key_shift_tab` cleanly but host focus never moved — not even forward. Root cause: the
> handler passed `MODIFIER_SHIFT` only as a per-event **bitfield** and never pressed a real
> Shift key; Sunshine-lineage hosts (Vibepollo/Apollo) derive held-modifier state from real
> `VK_LSHIFT` key events, not the bitfield. **Fix (this rev):** `key_shift_tab` now wraps
> `VK_TAB` in a real `VK_LSHIFT` DOWN/UP pair, mirroring the physical-keyboard path. This
> re-test must prove the host focus ring actually walks BACKWARD.

## Background

`sendSpecialKey()` now emits, for `key_shift_tab`: VK_LSHIFT down → VK_TAB down → VK_TAB up
→ VK_LSHIFT up. The other chords (Ctrl+Alt+Del/Alt+F4/Win/Esc) are unchanged.

**Alpha:** `0.2.0-alpha.016` — asset `Vibemis-0.2.0-alpha.016-x86_64.AppImage`
**md5:** `6453bbed0ed32bf47c2c722a4a1df35c`
**sha256:** `64ea08b6f08bf3d39a590abc0df94a8f5ea648f2a7c75118d4df391ecdcec5e7`

## Test procedure

### Tier 0 — integrity + boot
md5/sha256 exact vs dispatch; `selftest --json` PASS exit 0.

### Tier 1 — host-visual reverse-tab (stream required; THE verdict)
This tier is the whole point. Prove Shift+Tab moves host focus BACKWARD, with a control that
distinguishes "worked" from "delivery broken" and from "moved forward instead".

1. **Host prep (self-serve via stream, or ask @host):** open a multi-control dialog on the
   host with a legible focus ring. **Notepad Save-As** is ideal (File name edit → Save-as-type
   combo → toolbar/items view — many controls, hard to escape). Avoid dialogs with only 1–2
   controls (Shift+Tab can wrap past the first control and dismiss them).
2. **Foreground hygiene (learned the hard way):** make sure NO host game / fullscreen app is
   holding foreground — it eats injected keys. Confirm the dialog is truly foreground: send a
   plain **stream Tab** first and watch the focus ring move one control FORWARD. If it does,
   the keyboard channel reaches the dialog and you have a clean baseline. (This forward-Tab
   baseline is what made the alpha.014 FAIL unambiguous.)
3. Note the control the ring is on. Open Quick Menu → **Send Shift+Tab** (icon: key, below
   Send Esc). Screenshot-verify the QM row is highlighted before firing.
4. **Fire once.** Verify the host focus ring moves BACKWARD exactly one control. Screenshot
   the ring before and after. Report which control it left and which it landed on.
5. **Fire again.** Ring moves backward one more control. Screenshot.
6. **Discriminating control (do this to lock the verdict):** from the SAME Quick Menu, fire
   **Send Esc** — it should close the dialog. Esc closing proves the delivery path works, so
   if Shift+Tab ALSO moved the ring, the feature is genuinely fixed (not a delivery fluke).
7. Toast "Sent key to host" appears on each fire.

**PASS = the focus ring visibly walks BACKWARD one control per Send Shift+Tab fire** (with the
forward-Tab baseline confirming the channel and Esc confirming delivery). Focus not moving, or
moving forward, is a FAIL — report exactly what you observed with screenshots + fire timestamps.

### Tier 2 — regressions
1. The other special keys still fire (Esc closes/reacts; Alt+F4, Win, Ctrl+Alt+Del as before).
2. Quick Menu list scrolls cleanly with the extra row (no footer clipping — BL-1688 must hold).
3. Row count/order sane in Desktop and (if convenient) Game Mode.

## What to check and report
Per-fire host focus-ring behavior (which control → which control), the forward-Tab baseline
result, the Esc discriminating result, toast per fire, list rendering with the extra row.
Include screenshots + fire timestamps so the host UIA focus log can corroborate.

## Teardown
Quit the stream; nothing launched host-side (close any dialog you opened).

## Report
`testing/test122-shift-tab/report.md` on `diagnostic/test122-shift-tab-report`,
PR targets `test122-shift-tab`.

## Safety rules (standing)
No sudo/installs; don't modify the AppImage; streaming required for Tier 1.
