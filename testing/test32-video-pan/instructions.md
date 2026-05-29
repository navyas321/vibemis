# Test32 Instructions — In-stream video pan (Phase 7, completes pan/zoom)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Verify that while zoomed, the visible region can be panned with the keyboard, and
that pan re-centers on zoom reset.

> **Built on test31** (zoom), which is on test25 (scale) — so this build has scale + zoom + pan.
> Requires a paired host + stream + a keyboard.

---

## Background

Adds **pan** to the in-stream zoom. With `Ctrl+Alt+Shift` held:
- **`=` / `-` / `0`** — zoom in / out / reset (from test31)
- **Arrow keys** — pan Left/Right/Up/Down (each press moves the view 0.2 of the way)

Pan only has a visible effect when zoomed (>1.0×); at 1.0× the whole frame already shows.
Pan re-centers automatically when zoom is reset to 1.0×. Both zoom and pan are transient
(reset on app restart) and are applied in the shared scaling path, so the mouse cursor stays
aligned with what's shown.

---

## Artifact

**AppImage:** `testing/test32-video-pan/Vibemis-0.6.7-vibemis-test32-video-pan-x86_64.AppImage`
**md5:** `dd518e6dd473ccee9d3fc58656e413f0`

```bash
md5sum testing/test32-video-pan/*.AppImage
```

---

## Setup

```bash
cd ~/vibemis
git fetch origin test32-video-pan
git checkout test32-video-pan && git pull
chmod +x testing/test32-video-pan/*.AppImage
./testing/test32-video-pan/*.AppImage --appimage-extract-and-run > ~/test32.log 2>&1 &
```

---

## Tier 1 — Pan while zoomed

1. Start a stream. Zoom in to ~2× (`Ctrl+Alt+Shift+=` a few times).
2. Hold `Ctrl+Alt+Shift` and press **Right arrow** repeatedly — the visible region should
   move toward the **right** side of the host image (you see content that was off the right edge).
   Log shows `Video pan set to (X, Y)`.
3. Pan **Left / Up / Down** similarly and confirm the view moves the expected direction.
4. Confirm panning stops at the edges (can't pan past the image; values clamp at ±1.0).

## Tier 2 — Pan only matters zoomed; reset re-centers

1. At 1.0× zoom, pan keys should have **no visible effect** (whole frame already shown).
2. Zoom to 2×, pan to a corner, then `Ctrl+Alt+Shift+0` (reset) — view returns to **full,
   centered** image, and pan is recentered (zoom in again → starts centered).

## Tier 3 — Alignment + no regression

1. While zoomed+panned, move the mouse cursor — it should land roughly where expected on the
   visible (panned) image.
2. At 1.0× / no pan, confirm the stream is unchanged vs prior builds.

---

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | Ctrl+Alt+Shift+arrows pan the zoomed view in the right direction | Yes |
| 2 | Pan clamps at image edges (±1.0) | Yes |
| 3 | Pan has no effect at 1.0× zoom | Yes |
| 4 | Zoom reset (0) re-centers + clears pan | Yes |
| 5 | Cursor roughly aligned when zoomed+panned | Yes |
| 6 | 1.0×/no-pan unchanged (no regression) | Yes |
| 7 | Zoom+pan reset on app restart (transient) | Yes |

Report SteamOS + Mesa version and active renderer.

---

## Report format

Commit `testing/test32-video-pan/report.md` on `diagnostic/test32-video-pan-report`;
PR targets `test31-video-zoom` (its base).

---

## Safety rules (standing, streaming exception for this cycle)
- No package installs, no `sudo` outside read-only inspection; do not modify the AppImage
- Streaming authorized; pairing is not — if host isn't paired, stop and report
