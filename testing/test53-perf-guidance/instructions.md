# test53 — Settings performance-guidance advisories

**Feature:** Two contextual ⚠ advisories in Settings that appear only when relevant:
1. **Software decoding** is forced → warns it adds latency (~8 ms vs ~2 ms hardware) + CPU/battery.
2. **Bitrate** is set above **2×** the recommended default for the resolution → warns it commonly
   causes stutter/dropped frames over Wi-Fi.
**Branch:** `test53-perf-guidance` · **Base:** `vibemis-main` · **Artifact:** 🔬 alpha pre-release
(tag contains `test53-perf-guidance`).

> Fully **launcher-only** — no host, pairing, or stream needed.

## Setup
1. Download the alpha AppImage, `chmod +x`, record `md5sum` + SteamOS/Mesa versions.
2. (Optional automation) `Vibemis-x86_64.AppImage selftest` should still print `SELFTEST RESULT: PASS`.

## Tier 1 — software-decode advisory (Desktop Mode launcher)
1. Settings → Video decoder dropdown → select **"Force software decoding"**.
   - ✅ A yellow ⚠ line appears directly under the dropdown about added latency.
2. Switch back to **"Automatic"**.
   - ✅ The warning disappears.

## Tier 2 — high-bitrate advisory
1. Note the **"Use Default (… Mbps)"** button text — that's the recommended bitrate.
2. Drag the **Video bitrate** slider to **more than double** that recommended value.
   - ✅ A yellow ⚠ line appears under the slider about stutter on Wi-Fi.
3. Click **Use Default** (or lower the slider back under 2×).
   - ✅ The warning disappears.

## Tier 3 — no false positives
1. With **Automatic** decoder and a **default** bitrate, confirm **neither** warning is shown.
   - ✅ PASS if both advisories are hidden in the normal/default configuration.

## What to capture / report
- md5 + environment. A screenshot of each advisory (Desktop Mode: `spectacle -b -n -a -o <file>`).
- Confirm the warnings are advisory only (they don't block changing the setting).

## Report
Write `testing/test53-perf-guidance/report.md`, update the `test53` row in
`testing/TEST_CHECKLIST.md` (☐→☑/✗), commit both on `diagnostic/test53-perf-guidance-report`,
open a PR targeting `test53-perf-guidance`.
