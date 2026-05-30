# test59 — Data-usage estimate under the bitrate slider

**Feature:** A small grey line under the Video bitrate slider showing the approximate data usage
("Uses roughly X GB/hour of data at this bitrate (video only)."), updating live as the slider moves.
Helps users on metered connections / marginal Wi-Fi. Pure QML, no new preference.
**Branch:** `test59-bitrate-data-estimate` · **Base:** `vibemis-main` · **Artifact:** 🔬 alpha
pre-release (tag contains `test59-bitrate-data-estimate`).

> Launcher-only. No host/stream.

## Setup
1. Download the alpha AppImage, `chmod +x`, record `md5sum` + SteamOS/Mesa versions.

## Tier 1 — estimate shows and updates (Desktop Mode)
1. Settings → find the **Video bitrate** slider.
2. Confirm a grey line below it reads e.g. "Uses roughly N.N GB/hour of data at this bitrate".
3. Drag the slider up and down.
   - ✅ PASS if the GB/hour figure updates live and is sane (higher bitrate → higher GB/hour).

## Tier 2 — sanity of the math
1. Set bitrate so the slider/label shows a known value (e.g. ~20 Mbps = 20000 kbps).
   - ✅ PASS if the estimate is ~9.0 GB/hour at 20 Mbps (kbps × 0.00045). A few tenths off is fine
     (rounding). It should never be negative or absurd.

## Report
Write `testing/test59-bitrate-data-estimate/report.md`, update the `test59` row in
`testing/TEST_CHECKLIST.md`, commit both on `diagnostic/test59-bitrate-data-estimate-report`,
open a PR targeting `test59-bitrate-data-estimate`.
