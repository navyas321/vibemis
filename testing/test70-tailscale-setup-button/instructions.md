# test70 — In-app "Set up Tailscale" entry point (P3.7)

**Feature:** In **Settings → Vibemis Features**, a short remote-play line plus two buttons —
**"Set up Tailscale"** (opens the Tailscale install guide) and **"One-command setup (guide)"**
(opens `scripts/setup-tailscale.sh` on GitHub) — and a tip to run the one-command script on SteamOS.
Buttons shown only when a browser is available. Pure QML, no new preference. The in-app companion to
test69's setup script + test51's "Prefer Tailscale addresses".
**Branch:** `test70-tailscale-setup-button` · **Base:** `vibemis-main` · **Artifact:** 🔬 alpha
pre-release (tag contains `test70-tailscale-setup-button`). **Launcher-only / batchable.**

## Setup
1. Download the alpha AppImage, `chmod +x`, record `md5sum` + SteamOS/Mesa versions.

## Tier 1 — entry point renders (Desktop Mode)
1. Settings → **Vibemis Features** group. Confirm the remote-play line + the two buttons
   ("Set up Tailscale", "One-command setup (guide)") + the SteamOS tip are present.
   - ✅ PASS if they render (buttons visible when a browser is available).

## Tier 2 — buttons open the right pages
1. Click **Set up Tailscale** → ✅ browser opens `https://tailscale.com/kb/installation`.
2. Click **One-command setup (guide)** → ✅ browser opens the `setup-tailscale.sh` page on GitHub.
   - (If clicking does nothing, note whether a default browser is configured.)

## Report
Write `testing/test70-tailscale-setup-button/report.md`, update the `test70` row in
`testing/TEST_CHECKLIST.md`, commit both on `diagnostic/test70-tailscale-setup-button-report`,
open a PR targeting `test70-tailscale-setup-button`.
