# test56 — Help & Links section in Settings

**Feature:** A new **"Help & Links"** group at the bottom of Settings with buttons that open (in the
default browser) the Vibemis GitHub repo, the install guide (README), and the Tailscale remote-play
setup page. Shown only when a browser is available (`SystemProperties.hasBrowser`). Pure QML.
**Branch:** `test56-help-links` · **Base:** `vibemis-main` · **Artifact:** 🔬 alpha pre-release
(tag contains `test56-help-links`).

> Launcher-only. Opening a link requires a browser (Desktop Mode). No host/stream.

## Setup
1. Download the alpha AppImage, `chmod +x`, record `md5sum` + SteamOS/Mesa versions.

## Tier 1 — section renders (Desktop Mode)
1. Launch, open **Settings**, scroll to the bottom.
2. Confirm a **"Help & Links"** group with three buttons: "Vibemis on GitHub",
   "Install guide (README)", "Remote play over Tailscale — setup".
   - ✅ PASS if the group and all three buttons render.

## Tier 2 — links open
1. Click **Vibemis on GitHub**.
   - ✅ PASS if the default browser opens to `https://github.com/navyas321/vibemis`.
2. Click the other two; confirm they open the README anchor and the Tailscale install page.
   - ✅ PASS if each opens the expected URL. (If clicking does nothing, note whether a default
     browser is configured — the feature uses the system handler.)

## Tier 3 — Game Mode (optional)
1. In Game Mode, confirm the section either renders (and is harmless if no browser) or is hidden.
   Mark N/A if not convenient. Screenshot with Super+S if testing.

## Report
Write `testing/test56-help-links/report.md`, update the `test56` row in
`testing/TEST_CHECKLIST.md`, commit both on `diagnostic/test56-help-links-report`,
open a PR targeting `test56-help-links`.
