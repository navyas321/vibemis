# Test31 Instructions — In-stream video zoom (Phase 7)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Verify the new keyboard zoom controls magnify the stream (centered), and reset works.

> **Built on test25** (video scale mode), so this build also has Fit/Fill/Stretch.
> Requires a paired host + stream. A keyboard is needed for the zoom combos.

---

## Background

New in-stream **centered zoom**, controlled by `Ctrl+Alt+Shift` +:
- **`=`** → zoom in (+0.25×, up to 4.0×)
- **`-`** → zoom out (−0.25×, down to 1.0×)
- **`0`** → reset to 1.0× (no zoom)

Zoom crops the source to a centered sub-region, so the centre of the image is magnified.
It's applied in the shared scaling path, so the mouse cursor stays aligned with the zoomed
image. Zoom is **transient** (resets to 1.0× on app restart). Pan is a planned follow-up.

---

## Artifact

**AppImage:** `testing/test31-video-zoom/Vibemis-0.6.7-vibemis-test31-video-zoom-x86_64.AppImage`
**md5:** `bd57a107ade538e5e092c4c83b3aae42`

```bash
md5sum testing/test31-video-zoom/*.AppImage
```

---

## Setup

```bash
cd ~/vibemis
git fetch origin test31-video-zoom
git checkout test31-video-zoom && git pull
chmod +x testing/test31-video-zoom/*.AppImage
./testing/test31-video-zoom/*.AppImage --appimage-extract-and-run > ~/test31.log 2>&1 &
```

---

## Tier 1 — Zoom in/out/reset

1. Start a stream to the paired host.
2. Press **Ctrl+Alt+Shift+`=`** a few times. Expected: the image **magnifies toward the
   centre** in steps; edges move off-screen (centred crop). Log shows `Video zoom set to N.NNx`.
3. Press **Ctrl+Alt+Shift+`-`** to zoom back out step by step.
4. Press **Ctrl+Alt+Shift+`0`** → image returns to **1.0× (full, no zoom)** immediately.
5. Confirm zoom stops at 1.0× (can't go below) and caps at 4.0× (can't go above).

## Tier 2 — Cursor alignment + no regression

1. At ~2× zoom, with mouse mode usable, move the cursor — it should land at roughly the
   correct on-screen position relative to the magnified image (not wildly offset).
2. Reset to 1.0× and confirm the stream looks exactly as before (no regression at default).
3. Confirm the **Video scaling** dropdown (Fit/Fill/Stretch, from test25) still works alongside zoom.

## Tier 3 — Transient

1. Zoom to ~2×, fully quit Vibemis, relaunch, stream again → starts at **1.0×** (zoom not persisted).

---

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | Ctrl+Alt+Shift+= zooms in (centred), log shows zoom factor | Yes |
| 2 | Ctrl+Alt+Shift+- zooms out | Yes |
| 3 | Ctrl+Alt+Shift+0 resets to 1.0× | Yes |
| 4 | Clamps at 1.0×–4.0× | Yes |
| 5 | Cursor roughly aligned with zoomed image | Yes |
| 6 | 1.0× unchanged vs prior builds (no regression) | Yes |
| 7 | Zoom resets on restart (transient) | Yes |

Report SteamOS + Mesa version and which renderer (`grep 'Using .* renderer' ~/test31.log`).

---

## Report format

Commit `testing/test31-video-zoom/report.md` on `diagnostic/test31-video-zoom-report`;
PR targets `test25-video-scale-mode` (its base).

---

## Safety rules (standing, streaming exception for this cycle)
- No package installs, no `sudo` outside read-only inspection; do not modify the AppImage
- Streaming authorized; pairing is not — if host isn't paired, stop and report
