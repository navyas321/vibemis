# Test28 Report — Tailscale hint in Add-PC dialog (P3.7 #2)

**Artifact tested:** `Vibemis-0.6.7-vibemis-test28-tailscale-addpc-hint-x86_64.AppImage`
**md5:** `dfe52f38eb6fc06721bbbf71f8be1893` ✓ verified (matches instructions.md)
**Branch:** `test28-tailscale-addpc-hint` (commit `4aeb7a6`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0
**Test date:** 2026-05-29
**Prior report:** N/A

---

## 1. TL;DR

| # | Check | Status | Summary |
|---|-------|--------|---------|
| 1 | Add-PC dialog shows the Tailscale hint line | **PASS** | Greyed hint below the field names Tailscale, 100.x.x.x, MagicDNS |
| 2 | Hint wraps/readable, doesn't break dialog layout | **PASS** | Wraps cleanly over 3 lines, fully inside the dialog, not cut off |
| 3 | Text field + OK/Cancel still function | **PASS** | Field accepts typed IP; Cancel (Esc) closes, nothing added |

**Verdict: MERGE.** The Add-PC dialog now carries a readable Tailscale helper line and remains fully functional. Launcher-only check; no pairing/stream performed.

---

## 2. Tier 1 — Hint visible

Add-PC dialog opened from the main Computers screen via the "+" action
(tooltip: "Add PC manually (Ctrl+N)"). Captured with spectacle (KWin portal).

The dialog shows, top to bottom:
- Prompt: **"Enter the IP address of your host PC:"**
- The text input field (accent underline)
- A **smaller greyed hint line** below it:

  > "On the same network, use the host's local IP. To stream from a
  > different network, put both devices on Tailscale and enter the
  > host's Tailscale IP (100.x.x.x) or MagicDNS name."

- CANCEL / OK buttons

Check 1 ✓ — hint present, explicitly mentions **Tailscale**, the **100.x.x.x**
range, and **MagicDNS**, and distinguishes same-network vs different-network use.

Check 2 ✓ — the hint wraps over three lines, stays within the dialog bounds,
is not truncated, and does not push the buttons off or distort the layout.
Grey/secondary text colour is legible against the dark dialog background.

## 3. Tier 2 — Dialog still works

- Typed `192.168.4.78` into the field — text entered and displayed normally
  with a live cursor (screenshot confirmed).
- Pressed **Escape** (Cancel path) — dialog closed immediately; the Computers
  list returned showing only the existing **Navid-PC**. **Nothing was added.**
- Did **not** press OK / did not pair or connect (per instructions: UI check only).

Check 3 ✓ — field input and the Cancel/close path both behave as before.

## 4. Other findings

- Accent colour in this build is **purple**, which is expected: `test28` is based
  on `vibemis-main`, not `test27` (the teal/cyan accent change). Not in scope here.
- Clean launch; no crash, no visual glitches in the dialog.
- Screenshots captured via `spectacle -b -n -f` over the KWin portal (KDE Wayland;
  x11grab yields black on this compositor).

## 5. Recommendation

**MERGE.** All three checks pass. The Tailscale hint is present, correctly worded
(local IP same-network; Tailscale 100.x.x.x / MagicDNS different-network), wraps and
reads cleanly without breaking the dialog, and the dialog's input + Cancel path still
work. No regressions observed in the launcher.
