# Test33 Instructions — Quick Menu "Stream Info" (P3.4)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Verify the new **"Stream Info"** Quick Menu item shows the current resolution, FPS,
bitrate, and codec as a toast.

> **Built on test29 → test22** (Quick Menu + Paste). Requires a paired host + stream. Test in
> Desktop Mode if the Game-Mode menu render is still under verification (test22).

---

## Artifact

**AppImage:** `testing/test33-quickmenu-streaminfo/Vibemis-0.6.7-vibemis-test33-quickmenu-streaminfo-x86_64.AppImage`
**md5:** `8c4fc9aa5ba23c90d7d0de661fb60908`

```bash
md5sum testing/test33-quickmenu-streaminfo/*.AppImage
```

## Setup

```bash
cd ~/vibemis
git fetch origin test33-quickmenu-streaminfo
git checkout test33-quickmenu-streaminfo && git pull
chmod +x testing/test33-quickmenu-streaminfo/*.AppImage
./testing/test33-quickmenu-streaminfo/*.AppImage --appimage-extract-and-run > ~/test33.log 2>&1 &
```

## Tier 1 — Stream Info

1. Set a known resolution/FPS in Settings (e.g. via a Vibepollo preset — 1920x1200@120).
2. Start a stream; open the Quick Menu; select **"Stream Info"**.
3. Expected: a toast like **`1920x1200 @ 120 · 40.0 Mbps · HEVC`** (values matching your
   settings; codec = Auto/H.264/HEVC/AV1 per your codec setting). The menu then closes.

## Tier 2 — Regression

1. Confirm the other menu items still appear/work (Paste Clipboard, Toggle Performance Stats, etc.).

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | "Stream Info" item present | Yes |
| 2 | Selecting it toasts resolution/FPS/bitrate/codec matching settings | Yes |
| 3 | Other menu items unaffected | Yes |

Report SteamOS + Mesa version and the exact toast text seen.

## Report format
Commit `testing/test33-quickmenu-streaminfo/report.md` on
`diagnostic/test33-quickmenu-streaminfo-report`; PR targets the test branch.

## Safety rules (standing, streaming exception for this cycle)
- No package installs, no `sudo` outside read-only inspection; do not modify the AppImage
- Streaming authorized; pairing is not — if host isn't paired, stop and report
