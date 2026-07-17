# Test125 Report — HDR tone-map toggle (BL-1561) — PARTIAL (Tier 1 wiring PASS; render-log + regressions streaming-gated)

**Artifact tested:** `Vibemis-0.2.0-alpha.018-x86_64.AppImage`
**md5:** `51f24d5ad60811d99d92de157fc05192` ✓ · **sha256:** `e623017655c952e8…78099b35` ✓ · selftest PASS.
**Branch:** `test125-hdr-tonemap` · **Device:** Lenovo Legion Go S Z2 (SDR LCD), SteamOS 3.8.5
**Test date:** 2026-07-16

---

## 1. TL;DR

| Row | Status | Summary |
|---|---|---|
| Tier 0 — integrity + boot | **PASS** | md5 + sha256 exact, selftest `{"failures":0,"result":"PASS"}` exit 0 |
| Tier 1.1 — visibility gate | **PASS** | HDR OFF → tone-map row hidden |
| Tier 1.2 — default-off | **PASS** | HDR ON → both HDR sub-rows appear; tone-map **unchecked by default** |
| Tier 1.3 — persistence | **PASS** | check tone-map → quit → relaunch → still checked (`hdrTonemapping=true`) |
| Tier 1.4 — render-path log | **PENDING** | needs an HDR-negotiated stream (see §4); PlVkRenderer confirmed available |
| Tier 1b — HDR visual | **N/A** | device-gated (no HDR display; Legion Go S Z2 has an SDR LCD) |
| Tier 2 — regressions | **PENDING** | needs streams (SDR + HDR); see §4 |

---

## 2. Tier 0

md5 `51f24d5a…` and sha256 `e623017655c952e8…` match the dispatch exactly. `selftest --json` →
`{"failures":0,"result":"PASS"}`, exit 0.

## 3. Tier 1 — toggle presence + persistence (launcher, verified)

The HDR controls live under **Settings → Advanced → Advanced Settings**, below **Preferred
renderer** (which reads **"Auto (Vulkan, fallback to OpenGL)"**).

1. **Visibility gate — PASS.** With **Enable HDR (Experimental)** OFF (baseline `hdr=false`), the
   Advanced list goes Enable HDR → **Enable YUV 4:4:4** directly — **no "My display supports HDR"
   and no "Tone-map HDR to SDR" rows** are shown. The HDR sub-rows are correctly hidden.
2. **Default-off — PASS.** Toggling **Enable HDR ON** reveals **"My display supports HDR"** (ON —
   `displayHdrCapability=true`) and, directly below it, **"Tone-map HDR to SDR on this device
   (Experimental)"** which is **unchecked by default**. Label matches the spec exactly. (The
   display-HDR tooltip explicitly names the Legion Go S Z2 SDR-panel case.)
3. **Persistence — PASS.** Checked the tone-map toggle → config wrote **`hdrTonemapping=true`**
   (alongside `hdr=true`). Fully quit the app and relaunched → Advanced still shows **Tone-map HDR
   to SDR ON**. The pref round-trips through serialization.

Config restored to baseline after the test: `hdr=false`, `hdrTonemapping=false`,
`displayHdrCapability=true` (unchanged).

## 4. What's left — Tier 1.4 (render log) + Tier 2 (regressions): streaming-gated

These require live streams and were **not** run this cycle because completing them needs the
maintainer to enable HDR on the host (Windows HDR on the desktop, or an HDR title) — disruptive to
the host desktop they were actively working on. **De-risking note:** the plvk path is available on
this device — startup log shows `HDR Debug: Trying PlVkRenderer for 10-bit content` →
`PlVkRenderer success - HDR support enabled`, so the `PlVkRenderer:` colorspace-hint line **can**
emit here (FORCE_VAAPI in the AppRun is decoder-only and does not disable the Vulkan renderer).

Exact remaining procedure (≈1 short session, needs an HDR source + host coordination):
- **1.4a** — HDR + display-HDR + tone-map **ON**, stream an HDR title (or HDR-enabled desktop) →
  expect `PlVkRenderer: HDR tone-map to SDR ENABLED — hinting SDR output (source transfer=…)`.
- **1.4b** — tone-map **OFF**, reconnect → expect
  `PlVkRenderer: HDR tone-map to SDR disabled — passthrough (source transfer=…)`.
- **Tier 2.1** — Enable HDR OFF, stream an SDR title → picture correct, no new log spam, no crash.
- **Tier 2.2** — tone-map OFF (default) + display-HDR ON → HDR stream unchanged vs prior alpha.
- **Tier 2.3** — Enable HDR ON + display-HDR OFF → 8-bit SDR (codec-gate unchanged; tone-map
  toggle must not override it).
- **Tier 2.4** — toggle the setting between streams → no crash/hang, clean reconnect each time.

## 5. Recommendation

**HOLD (do not merge yet).** The pref is proven wired end-to-end at the UI + config level (Tier 1
rows 1–3 PASS) and the Vulkan HDR path is present, so the design is sound. But the **render-path
log evidence (Tier 1.4) — the load-bearing proof that the toggle actually drives the colorspace
hint — is not yet captured**, nor are the Tier 2 regressions. Recommend a short follow-up on an
HDR-enabled host source (Desktop tile with Windows HDR on, or any HDR title) to capture both log
lines and the four regression rows, then flip to PASS.
