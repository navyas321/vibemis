# test51 — Prefer Tailscale addresses for remote play (P3.7)

**Feature:** New Settings toggle **"Prefer Tailscale addresses for remote play"**. When ON, the
client reorders a host's connection candidates so a Tailscale address (CGNAT `100.64.0.0/10`, or a
`*.ts.net` MagicDNS name) is tried **first**. When OFF (default), behavior is unchanged
(LAN/local first).
**Branch:** `test51-prefer-tailscale` · **Base:** `vibemis-main`
**Artifact:** 🔬 alpha pre-release for this branch (tag contains `test51-prefer-tailscale`),
asset `Vibemis-x86_64.AppImage`.

> Tier 1 + Tier 2 are launcher-only (no streaming required). Tier 3 needs a tailnet and is
> **optional** — mark N/A if no Tailscale host is available.

## Setup
1. Download the alpha AppImage, `chmod +x`, record `md5sum`. Record SteamOS + Mesa versions.

## Tier 1 — setting persists (launcher)
1. Launch in Desktop Mode → Settings → **Vibemis Features** group.
2. Confirm a **"Prefer Tailscale addresses for remote play"** checkbox exists, **unchecked** by default.
3. Check it, fully quit, relaunch, return to Settings.
   - ✅ PASS if it's still checked (persisted).

## Tier 2 — no regression with toggle OFF (launcher, existing host on LAN)
1. With the toggle **OFF**, confirm your normally-paired LAN host still appears in the Computers
   list and shows **Online** (do **not** start a stream unless told to).
   - ✅ PASS if host discovery/online status is unchanged from the stock build.

## Tier 3 — OPTIONAL, needs a Tailscale host
> Only if a host reachable via Tailscale (100.64.x or *.ts.net) is configured.
1. With the toggle **ON**, confirm the host still reaches **Online** and (if instructed) connects.
   Capture the log and `grep -i "address\|100\.\|ts.net" /tmp/vibemis-test51.log`.
   - ✅ PASS if the tailnet address is used and the host connects. Otherwise mark **N/A**.

## What to capture / report
- md5 + environment. For Tier 3, the address actually used (from the log).
- Run with logging: `~/Downloads/Vibemis-x86_64.AppImage > /tmp/vibemis-test51.log 2>&1`

## Report
Write `testing/test51-prefer-tailscale/report.md`, update the `test51` row in
`testing/TEST_CHECKLIST.md` (☐→☑/✗, mark Tier 3 N/A if applicable), commit both on
`diagnostic/test51-prefer-tailscale-report`, open a PR targeting `test51-prefer-tailscale`.
