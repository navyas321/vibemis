# Test119 Instructions — touch passthrough finally CLICKS: dense pointer-id slots (BL-2015)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** the 0.2.0 STABLE BLOCKER: with finger ids mapped to dense slots (0–9), a
direct-touch tap must CLICK (ink a dot) and a swipe must DRAW a continuous stroke in
Paint on the host — the first fully-inking touch run.

## Background

Evidence chain (BL-2015): test116 proved the client sends correct events (pressure 1,
err 0) yet nothing inked; native InjectTouchInput on the host DID ink with dense ids and
fails with ERROR_INVALID_PARAMETER when pointerId >= the initialized max; Apollo-lineage
hosts forward the client's id verbatim, and Vibemis sent raw/CRC'd SDL finger ids (huge).
Android clients send 0–9 — which is why they work. Fix: lowest-free-slot mapping per
finger lifetime (abstouch.cpp + input.h).

**Build tier: ALPHA (BL-2016). Hashes stamped at dispatch.**

## Test procedure

### Tier 0 — integrity + boot
md5/sha256 exact vs dispatch; `selftest --json` PASS exit 0.

### Tier 1 — THE INK TEST (host operator on the bus, BL-1528 flow)
1. Post `@host test119 Tier1 GO` — build agent opens fresh Paint maximized + confirms.
2. Stream Navid-PC Desktop in **direct-touch mode**; capture client log.
3. ONE tap center-ish; post timestamp. 4. Slow diagonal swipe (>=2s, >=20 points); post
   timestamp. 5. Quit cleanly.
- Client greps: `Touch DOWN` x2 with `err 0`; swipe UP `after N moves` N>=15.
- Host truth (build agent): **ink DOT at the tap point + CONTINUOUS stroke** — screenshot.
- PASS = both ink. This closes BL-2015 + the BL-1528/P3.23 checklist row for real.

### Tier 2 — test118 Game-Mode deferrals (fold-in, Game Mode)
1. KBD button → SteamOS OSK **visually rises**; typed characters **land in the host app**.
2. Mid-gesture guard: finger held + TOUCH tap with second finger = consumed, no mode flip;
   solo tap flips.
3. Overlay toggle OFF from Quick Menu → all 3 buttons vanish, corner taps pass through;
   ON → returns.
4. (If feasible) Steam-absent negative: KBD tap toasts "Steam not available", no crash.

### Tier 3 — regressions
Touchpad-emu mode: relative cursor only, no absolute taps (host confirms no touch-device
line for that session). Multi-finger sanity: two-finger tap/pinch doesn't crash or leak a
stuck pointer (host cursor sane after).

## What to check and report
Per-tier verdicts with the exact greps; quote the build agent's ink screenshot post;
any stuck-pointer/ghost-touch anomaly.

## Teardown
Quit streams; nothing launched host-side (Paint is the build agent's). Restore prefs.

## Report
`testing/test119-pointer-slots/report.md` on `diagnostic/test119-pointer-slots-report`,
tick the BL-1528/P3.23 row on PASS, PR targets `test119-pointer-slots`.

## Safety rules (standing)
No sudo/installs; don't modify the AppImage; streaming IS required.
