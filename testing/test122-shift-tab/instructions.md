# Test122 Instructions — Quick Menu "Send Shift+Tab" special key (BL-1788)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** the new Quick Menu row "Send Shift+Tab" reverse-tabs focus on the host — the
missing counterpart to the existing special keys.

## Background

Same LiSendKeyboardEvent DOWN/UP pattern as Ctrl+Alt+Del/Alt+F4/Win/Esc (VK_TAB +
MODIFIER_SHIFT); one new row in the special-keys section of the Quick Menu list.

**Build tier: ALPHA (BL-2016). Hashes stamped at dispatch.**

## Test procedure

### Tier 0 — integrity + boot
md5/sha256 exact vs dispatch; `selftest --json` PASS exit 0.

### Tier 1 — the key (stream required, self-serve)
1. Stream Navid-PC Desktop. On the host a multi-field dialog helps (the build agent can
   open one on request — Paint's File>Properties or any form; or use the taskbar).
2. Open Quick Menu → find "Send Shift+Tab" (icon: key) below "Send Esc".
3. Give a host window with tabbable fields focus; press Tab twice via "Send Esc"-style…
   (correction: use a physical keyboard Tab if attached, or the text-send box to type)
   — simplest check: activate "Send Shift+Tab" and verify the host's focus moves
   BACKWARD one control (visible focus ring reverses). Repeat x2.
4. Toast "Sent key to host" appears each activation.

### Tier 2 — regressions
1. The other special keys still fire (Esc toast + host reaction).
2. Quick Menu list scrolls cleanly with the extra row (no clipping at the footer —
   the BL-1688 clip fix must hold).
3. Row count/order sane in both Desktop and (if convenient) Game Mode.

## What to check and report
Focus-reversal observed (describe the host control focus behavior); toast per fire;
list rendering with the extra row.

## Teardown
Quit the stream; nothing launched host-side.

## Report
`testing/test122-shift-tab/report.md` on `diagnostic/test122-shift-tab-report`,
PR targets `test122-shift-tab`.

## Safety rules (standing)
No sudo/installs; don't modify the AppImage; streaming required for Tier 1.
