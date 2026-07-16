# Test118 Instructions — overlay v2: 3 icon buttons + SteamOS keyboard (BL-2002 / BL-2007)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** the in-stream touch overlay per the maintainer-locked spec: three icon-only
always-visible buttons — MENU (hamburger, top-left), KBD (keyboard glyph, far top-right),
TOUCH-MODE toggle (touch glyph, left of KBD) — and KBD summons the **SteamOS on-screen
keyboard** instead of the text-send view.

**Build tier: ALPHA (BL-2016). Hashes stamped at dispatch (instructions/inbox/bus).**

## Test procedure

### Tier 0 — integrity + boot
md5/sha256 exact vs dispatch; `selftest --json` PASS exit 0.

### Tier 1 — overlay v2 visuals + actions (Game Mode preferred)
1. Settings → enable "On-screen touch controls while streaming"; stream Navid-PC Desktop.
2. THREE translucent 64px icon buttons visible: hamburger top-left; keyboard far top-right;
   touch glyph immediately left of it (12px gap). NO text labels anywhere.
3. Tap MENU → Quick Menu opens; tap again → closes. (Repeat later in the other touch mode.)
4. Tap KBD (Steam running) → **SteamOS OSK rises**; type → characters land in the host app;
   a toast "Steam keyboard requested" composites into the stream. Dismiss OSK.
5. Quick Menu → new "On-screen keyboard" row → same OSK; **"Type text" row still opens the
   old text-send view and Send works** (regression: BL-2000 padding intact).
6. Tap TOUCH toggle → toast names the new mode; behavior flips immediately (trackpad =
   relative cursor drag; direct = absolute tap). Toggle back. After stream exit, Settings'
   "virtual trackpad" checkbox reflects the final state; mode persists into the next stream.
7. Mid-gesture guard: hold one finger center-screen, tap TOUCH with a second → consumed,
   mode does NOT change; release all, tap TOUCH alone → mode changes.

### Tier 2 — negatives + regressions
1. Taps in the top strip between/outside buttons still reach the host (both modes).
2. MENU/KBD/TOUCH taps never produce a host-side click (watch host cursor).
3. Quick Menu row: toggle "Touch overlay" OFF → all three buttons vanish; corner taps pass
   through; ON → they return.
4. Steam-absent negative (if feasible: quit Steam in Desktop Mode): KBD tap toasts
   "Steam not available", no crash.

## What to check and report
Per-step results; icon legibility verdict at handheld distance (maintainer wants an eyeball
call); any hit-target size complaint (known-issue row exists); log excerpts for the OSK
launch and mode flips.

## Teardown
Quit the stream; nothing launched host-side. Restore your preferred touch mode + overlay pref.

## Report
`testing/test118-overlay-v2/report.md` on `diagnostic/test118-overlay-v2-report`, tick the
checklist, PR targets `test118-overlay-v2`.

## Safety rules (standing)
No sudo/installs; don't modify the AppImage; streaming IS required for Tiers 1–2.
