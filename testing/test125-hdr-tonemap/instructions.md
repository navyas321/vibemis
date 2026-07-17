# Test125 Instructions — HDR tone-map toggle (BL-1561, P3.8 parity)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** verify the new client-side **"Tone-map HDR to SDR on this device"** Settings toggle
is wired end-to-end — it appears/persists, drives the Vulkan renderer's colorspace-hint
decision (log-observable), and does not regress SDR streaming or the existing HDR path.

## Background

- **BL-1561** adds a `hdrTonemapping` preference (default **OFF = passthrough**) that complements
  the existing `displayHdrCapability` gate:
  - `displayHdrCapability` gates HDR at **codec negotiation** (whether to request 10-bit HDR at all).
  - `hdrTonemapping` gates HDR at **render/output** time: when ON, the Vulkan (libplacebo)
    renderer hints an **SDR** output colorspace regardless of the source, so `pl_render_image()`
    tone-maps HDR content down to SDR on the client instead of passing HDR through to the display.
- New control lives under Settings → **Enable HDR (Experimental)**, only visible when HDR is
  enabled, directly below **"My display supports HDR"**. Label: **"Tone-map HDR to SDR on this
  device (Experimental)"**. Default unchecked.
- **Display-panel note (important for this device):** the Legion Go S Z2 has an **SDR LCD**. On an
  SDR panel the swapchain can never enter HDR mode, so HDR content is tone-mapped *either way* —
  the toggle's **visual** effect (passthrough vs forced tone-map) is only distinguishable on an
  **HDR-capable display**. On this device, verify the toggle via the **renderer log line** (below)
  plus the no-regression checks. If you have an external HDR monitor, the optional Tier 1b covers
  the visual difference.
- Files touched: `app/settings/streamingpreferences.{h,cpp}` (pref + serialization),
  `app/gui/SettingsView.qml` (toggle), `app/streaming/video/ffmpeg-renderers/plvk.cpp`
  (colorspace-hint decision + log). No host/protocol changes.

**Alpha:** `0.2.0-alpha.NNN` — asset `Vibemis-0.2.0-alpha.NNN-x86_64.AppImage`
(exact NNN + hashes: take the newest `test125-hdr-tonemap` alpha from the GitHub Releases page /
the CI run's build summary — this file is committed before the build exists).
**md5:** `<from release page>`
**sha256:** `<from release page>`

## Test procedure

### Tier 0 — integrity + boot
1. md5/sha256 of the downloaded AppImage exactly match the dispatch values (from Releases).
2. `./Vibemis-0.2.0-alpha.NNN-x86_64.AppImage selftest --json` → PASS, exit 0.

### Tier 1 — toggle presence + persistence + render-path evidence (launcher + one stream)
1. Settings → Video: with **Enable HDR** UNchecked, the "Tone-map HDR to SDR on this device"
   row is **hidden** (mirrors "My display supports HDR").
2. Check **Enable HDR** (if supported on this PC): both "My display supports HDR" and
   "Tone-map HDR to SDR on this device" rows appear. The tone-map row is **unchecked by default**.
3. Check "Tone-map HDR to SDR on this device", fully quit the app, relaunch → the toggle is still
   **checked** (persisted to `hdrTonemapping=true` in the config).
4. **Render-path evidence (works on the SDR panel):** with Enable HDR + "My display supports HDR"
   both checked and the tone-map toggle **ON**, stream an **HDR** title (or any title with HDR
   forced on the host). In the Vibemis log, confirm the line:
   `PlVkRenderer: HDR tone-map to SDR ENABLED — hinting SDR output (source transfer=...)`.
   Toggle it **OFF**, reconnect, stream again → the log now shows
   `PlVkRenderer: HDR tone-map to SDR disabled — passthrough (source transfer=...)`.
   (Renderer must be Vulkan — the HDR-capable renderer. If Settings force a non-Vulkan renderer,
   note it; the line only emits from `PlVkRenderer`.)

### Tier 1b — OPTIONAL, external HDR display only (skip if none available)
1. Connect an HDR-capable external display; set it as the stream output.
2. Tone-map OFF → HDR content is passed through (display enters HDR; bright highlights preserved).
3. Tone-map ON → HDR content is tone-mapped to SDR (image stays in SDR range, no HDR handoff).
   Confirm the picture is clean (not clipped/washed out) in the tone-mapped case.

### Tier 2 — regression
1. **SDR streaming unaffected:** with Enable HDR OFF, stream an SDR title — picture correct,
   no new log spam, no crash. (The tone-map toggle is irrelevant here.)
2. **Default HDR path unchanged:** tone-map toggle OFF (default) + "My display supports HDR"
   checked → HDR stream renders exactly as before this build (on the SDR panel: tone-mapped by
   libplacebo automatically, as it already was). No visual regression vs the prior alpha.
3. **`displayHdrCapability` still works:** with Enable HDR ON but "My display supports HDR"
   UNchecked, the stream is 8-bit SDR (existing wash-out fix) — unchanged by this build; the
   tone-map toggle does not override that codec-level gate.
4. No crash/hang when toggling the setting between streams; reconnect is clean each time.

## What to check and report
- Tier 0 pass/fail (hashes + selftest).
- Tier 1 rows 1–4 individually (visibility gate, default-off, persistence, both log lines).
- Tier 1b only if an HDR display was available (else mark N/A — device-gated).
- Tier 2 rows 1–4 (SDR intact, default HDR unchanged, displayHdrCapability intact, no crash).
- Paste the exact `PlVkRenderer: HDR tone-map ...` log lines you observed.

## Teardown
Quit stream; set the tone-map toggle back to its default (OFF) if you changed it. Nothing host-side.

## Report
`testing/test125-hdr-tonemap/report.md` on `diagnostic/test125-hdr-tonemap-report`,
PR targets `test125-hdr-tonemap`.

## Safety rules (standing)
No sudo/installs; don't modify the AppImage; streaming required for Tier 1 row 4 and Tier 2.
