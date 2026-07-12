# Test40 Instructions — Battery-saver bitrate (P3.10)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Verify the new **"Reduce bitrate when on battery"** setting lowers the stream bitrate
to 60% when the device is unplugged, and leaves it unchanged when plugged in.

> Requires a paired host + stream. The Legion Go S has a battery, so SDL should report
> on-battery vs charging. The perf overlay / log shows the negotiated bitrate.

---

## Artifact

**AppImage:** `testing/test40-battery-saver/Vibemis-0.6.7-vibemis-test40-battery-saver-x86_64.AppImage`
**md5:** `a3b5146fafbf80871486ff6e367ec14c`

```bash
md5sum testing/test40-battery-saver/*.AppImage
```

## Setup

```bash
cd ~/vibemis
git fetch origin test40-battery-saver
git checkout test40-battery-saver && git pull
chmod +x testing/test40-battery-saver/*.AppImage
./testing/test40-battery-saver/*.AppImage --appimage-extract-and-run > ~/test40.log 2>&1 &
```

Note your configured bitrate (Settings → Video bitrate), e.g. 40 Mbps.

## Tier 1 — On battery, reduced

1. **Unplug** the Legion Go (running on battery).
2. Settings → enable **"Reduce bitrate when on battery"** (in the same group as "Keep display awake").
3. Start a stream. Check the log:
   ```bash
   grep -i 'battery saver' ~/test40.log
   ```
   Expected: `Vibemis battery saver: on battery, reducing bitrate 40000 -> 24000 kbps` (≈60%).
4. Confirm via the perf overlay (Ctrl+Alt+Shift+S) that the streamed bitrate is the reduced value.

## Tier 2 — Plugged in, unchanged

1. End stream. **Plug in** the charger.
2. Start a stream again. Log should show **no** "battery saver" reduction line; bitrate = configured value.

## Tier 3 — Toggle off

1. Unplug again, but **disable** the setting. Stream → bitrate stays at the configured value (no reduction).

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | Setting present ("Reduce bitrate when on battery") | Yes |
| 2 | On battery + enabled → bitrate reduced to ~60% (log + overlay) | Yes |
| 3 | Plugged in → no reduction | Yes |
| 4 | Setting off → no reduction even on battery | Yes |
| 5 | Setting persists across restart | Yes |

Report the exact log line and the overlay bitrate values, plus SteamOS + Mesa version.

## Report format
Commit `testing/test40-battery-saver/report.md` on `diagnostic/test40-battery-saver-report`;
PR targets the test branch.

## Safety rules (standing, streaming exception for this cycle)
- No package installs, no `sudo` outside read-only inspection; do not modify the AppImage
- Streaming authorized; pairing is not — if host isn't paired, stop and report
