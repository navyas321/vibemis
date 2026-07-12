# Test25 Instructions — Video scale mode (Fit / Fill / Stretch)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Verify the new **Video scaling** setting (Fit / Fill / Stretch) changes how the stream
fills the screen, and that the default (Fit) is unchanged.

---

## Background

A new **"Video scaling"** dropdown in Settings (in the display/Basic Settings group, near
Resolution/FPS) controls how the video frame is fit to the window:

- **Fit** (default) — preserve aspect ratio, black bars if needed (the original behaviour)
- **Fill** — preserve aspect ratio but scale up to fill the screen, cropping the overflow
- **Stretch** — fill the screen exactly, ignoring aspect ratio (may look distorted)

Implemented in the shared scaling helper so it applies consistently to both the video and
absolute mouse/touch coordinate mapping. **Independent of the Quick Menu** — no menu needed to test.

This matters most when the stream's aspect ratio doesn't match the 1920×1200 (16:10) screen
(e.g. a 16:9 host desktop leaves bars in Fit; Fill removes them by cropping).

> **Requires a stream.** Host must already be paired (do not pair if not).

---

## Artifact

**AppImage:** `testing/test25-video-scale-mode/Vibemis-0.6.7-vibemis-test25-video-scale-mode-x86_64.AppImage`
**md5:** `0e14a97333aa1124c1ea68b9a66a1720`

```bash
md5sum testing/test25-video-scale-mode/*.AppImage
```

---

## Setup

```bash
cd ~/vibemis
git fetch origin test25-video-scale-mode
git checkout test25-video-scale-mode && git pull
chmod +x testing/test25-video-scale-mode/*.AppImage
./testing/test25-video-scale-mode/*.AppImage --appimage-extract-and-run > ~/test25.log 2>&1 &
```

To make the effect obvious, set the host/stream resolution to a **16:9** ratio (e.g. 1920×1080)
so there are visible letterbox bars on the 16:10 screen in Fit mode.

---

## Tier 1 — The three modes

1. In **Settings → Basic Settings**, find the **"Video scaling"** dropdown. Confirm it lists
   **Fit / Fill / Stretch** and defaults to **Fit**.
2. Leave it on **Fit**, start a stream (16:9 content if possible). Observe: image preserves
   aspect ratio, **black bars** top/bottom (or sides) if the ratio differs from the screen.
3. End stream. Set scaling to **Fill**, stream again. Observe: **no black bars** — the image
   is scaled up to fill the screen and the overflow is **cropped** (edges cut off), aspect
   ratio still correct (no distortion).
4. End stream. Set scaling to **Stretch**, stream again. Observe: image **fills the whole
   screen** and looks **stretched/distorted** if the aspect ratios differ.

---

## Tier 2 — Default unchanged (regression)

1. With scaling on **Fit** and a stream whose aspect ratio **matches** the screen (1920×1200),
   confirm the image fills the screen normally with no regression vs prior builds.

---

## Tier 3 — Persistence + input alignment

1. Set **Fill**, fully quit Vibemis, relaunch — confirm the dropdown still shows **Fill**.
2. (If you use absolute mouse / touch:) in **Fill** mode, confirm the cursor still lands at
   roughly the right place on the host (input mapping should track the displayed image).
   Gamepad-only use is unaffected.

---

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | "Video scaling" dropdown present, defaults to Fit | Yes |
| 2 | Fit: aspect preserved, bars when ratios differ | Yes |
| 3 | Fill: no bars, image cropped to fill, no distortion | Yes |
| 4 | Stretch: fills screen, distorted when ratios differ | Yes |
| 5 | Fit on matching-ratio content unchanged (no regression) | Yes |
| 6 | Setting persists across restart | Yes |

Note the test resolutions used and SteamOS + Mesa version. Photos of each mode are ideal.

---

## Report format

Commit `testing/test25-video-scale-mode/report.md` on `diagnostic/test25-video-scale-mode-report`;
open a PR targeting `test25-video-scale-mode`.

---

## Safety rules (standing, with streaming exception for this cycle)
- No package installs, no `sudo` outside read-only inspection; do not modify the AppImage
- Streaming authorized; pairing is not — if host isn't paired, stop and report
