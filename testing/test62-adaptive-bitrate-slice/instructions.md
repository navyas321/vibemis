# test62 — Adaptive bitrate (experimental) — first slice (P3.12)

**Feature:** New **"Adaptive bitrate (experimental)"** setting. When enabled, if the host reports a
**poor connection** during a stream, Vibemis logs a structured recommendation
(`[adaptive-bitrate] Poor connection at N kbps — recommend lowering bitrate …`). This is the
observation-only first slice; automatic runtime bitrate adjustment is pending moonlight-common-c
support (`TODO(P3.12)` in session.cpp). No behavior change when the setting is off.
**Branch:** `test62-adaptive-bitrate-slice` · **Base:** `vibemis-main` · **Artifact:** 🔬 alpha
pre-release (tag contains `test62-adaptive-bitrate-slice`).

> Tier 1 launcher-only. Tier 2 needs a stream where the connection degrades (hard to force —
> mark N/A if you can't induce a poor connection).

## Setup
1. Download the alpha AppImage, `chmod +x`, record `md5sum` + SteamOS/Mesa versions.

## Tier 1 — setting persists (launcher)
1. Settings → near the Video bitrate slider, find **"Adaptive bitrate (experimental)"** (default off).
2. Enable it, fully quit, relaunch, return to Settings.
   - ✅ PASS if still enabled.

## Tier 2 — recommendation logged on poor connection (optional, needs a degrading stream)
> Only if instructions/host owner OK a stream and you can induce a poor link (e.g. weak Wi-Fi).
1. With the setting ON, stream and capture the log:
   `Vibemis-x86_64.AppImage > /tmp/vibemis-test62.log 2>&1`
2. Degrade the connection until the on-screen "Slow connection" overlay appears, then:
   `grep "adaptive-bitrate" /tmp/vibemis-test62.log`
   - ✅ PASS if an `[adaptive-bitrate] Poor connection at … kbps` line is logged. Mark **N/A** if
     you can't induce a poor connection. Confirm with the setting OFF, no such line appears.

## Tier 3 — no regression
1. Confirm the existing "Slow connection to PC / Reduce your bitrate" overlay still behaves as before
   (it's independent of this setting).
   - ✅ PASS if connection warnings are unchanged.

## Report
Write `testing/test62-adaptive-bitrate-slice/report.md`, update the `test62` row in
`testing/TEST_CHECKLIST.md`, commit both on `diagnostic/test62-adaptive-bitrate-slice-report`,
open a PR targeting `test62-adaptive-bitrate-slice`.
