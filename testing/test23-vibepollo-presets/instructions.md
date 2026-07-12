# Test23 Instructions — Vibepollo quality presets (P3.3)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Prior report:** test22 (Quick Menu) — independent of this cycle
**Goal:** Verify the new **Vibepollo Presets** in Settings apply the expected resolution/FPS/codec and that a stream negotiates those values.

---

## Background

Settings now has a **"Vibepollo Presets"** group at the top with four one-click profiles
tuned for the Legion Go S Z2. Each sets resolution, FPS, HEVC codec, hardware decode, frame
pacing, V-Sync, and a matching default bitrate, then saves immediately:

| Button | Resolution | FPS |
|--------|-----------|-----|
| Quality · 1200p120 | 1920×1200 | 120 |
| Balanced · 1200p90 | 1920×1200 | 90 |
| Performance · 800p120 | 1280×800 | 120 |
| Battery · 800p60 | 1280×800 | 60 |

The **bitrate slider is bound live** and should jump when a preset is applied. The resolution
and FPS combo boxes re-sync **if** the matching entry exists in their list (the native
1920×1200 / 120 Hz entries are added at runtime on this device, so they should). Regardless of
the combo display, the **stream uses the applied preference values**.

> **This test REQUIRES starting a stream** to confirm the negotiated mode. Host must already
> be paired. If not paired, report that as a blocker — do not pair.

---

## Artifact

**AppImage:** `testing/test23-vibepollo-presets/Vibemis-0.6.7-vibemis-test23-vibepollo-presets-x86_64.AppImage`
**md5:** `29bbe56b712f785b448b7f94cce0e99b`

```bash
md5sum testing/test23-vibepollo-presets/*.AppImage
```

---

## Setup

```bash
cd ~/vibemis
git fetch origin test23-vibepollo-presets
git checkout test23-vibepollo-presets && git pull
chmod +x testing/test23-vibepollo-presets/*.AppImage
./testing/test23-vibepollo-presets/*.AppImage --appimage-extract-and-run > ~/test23.log 2>&1 &
```

---

## Tier 1 — Presets exist and apply

1. Open **Settings** (gear icon). Confirm a **"Vibepollo Presets"** group appears at the top
   with four buttons.
2. Click **"Quality · 1200p120"**.
   - Does a cyan status line appear: *"Applied: Quality — takes effect on the next stream."*?
   - Does the **Video bitrate** slider value change (jump to the default for 1920×1200@120)?
   - Do the **Resolution** and **FPS** dropdowns now read **1920×1200** and **120 FPS**?
     (If they don't change but the stream in Tier 2 is correct, note it — that's the known
     combo-resync caveat, not a functional failure.)

---

## Tier 2 — Stream negotiates the preset mode

1. With **"Performance · 800p120"** applied, connect to the paired host and **start a stream**.
2. Open the performance overlay: **Ctrl+Alt+Shift+S** (or `Select+L1+R1+X` on the gamepad).
3. Read the **negotiated resolution and FPS** from the overlay.
   - Expected: **1280×800** (or the host-clamped equivalent) at **120 FPS**, HEVC.
4. End the stream. Apply **"Quality · 1200p120"**, stream again, check the overlay:
   - Expected: **1920×1200 @ 120**, HEVC.
5. Also grep the log:
   ```bash
   grep -iE 'video stream|negotiat|1920x1200|1280x800|HEVC|H.265|bitrate' ~/test23.log | head -30
   ```

---

## Tier 3 — Presets don't lock manual control

1. After applying a preset, manually change the **Resolution** dropdown to something else
   (e.g. 1080p). Confirm it changes and a subsequent stream uses the manual value.
2. Confirm nothing is greyed out or locked by the presets.

---

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | Presets group visible with 4 buttons | Yes |
| 2 | Clicking a preset shows the status line | Yes |
| 3 | Bitrate slider updates on preset apply | Yes |
| 4 | Resolution/FPS dropdowns re-sync | Yes (or note caveat) |
| 5 | Stream negotiates Performance preset (1280×800@120) | Yes |
| 6 | Stream negotiates Quality preset (1920×1200@120) | Yes |
| 7 | Manual control still works after a preset | Yes |

---

## Report format

Commit `testing/test23-vibepollo-presets/report.md` on `diagnostic/test23-vibepollo-presets-report`
and open a PR targeting `test23-vibepollo-presets`. Include the TL;DR table (checks 1–7), the
perf-overlay readings for each preset, and SteamOS + Mesa version.

---

## Safety rules (standing, with the streaming exception for this cycle)
- No package installs, no `sudo` outside read-only inspection
- Do not modify the AppImage
- Streaming **is** authorized; pairing is **not** — if the host isn't paired, stop and report
