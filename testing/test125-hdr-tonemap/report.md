# Test125 Report — HDR tone-map toggle (BL-1561) — PASS (fully render-verified on-device)

**Artifact tested:** `Vibemis-0.2.0-alpha.018-x86_64.AppImage`
**md5:** `51f24d5ad60811d99d92de157fc05192` ✓ · **sha256:** `e623017655c952e8…78099b35` ✓ · selftest PASS.
**Branch:** `test125-hdr-tonemap` · **Device:** Lenovo Legion Go S Z2 (SDR LCD), SteamOS 3.8.5
**Test date:** 2026-07-16 (Tier 1 wiring) + 2026-07-16 late (render-log + regressions, unparked for RC)

---

## 1. TL;DR

| Row | Status | Summary |
|---|---|---|
| Tier 0 — integrity + boot | **PASS** | md5 + sha256 exact, selftest exit 0 |
| Tier 1.1 — visibility gate | **PASS** | HDR OFF → tone-map row hidden |
| Tier 1.2 — default-off | **PASS** | HDR ON → both HDR sub-rows appear; tone-map **unchecked by default** |
| Tier 1.3 — persistence | **PASS** | check → quit → relaunch → still checked (`hdrTonemapping=true`) |
| Tier 1.4a — render log, tone-map ON | **PASS** | `PlVkRenderer: HDR tone-map to SDR ENABLED` captured |
| Tier 1.4b — render log, tone-map OFF | **PASS** | `PlVkRenderer: HDR tone-map to SDR disabled — passthrough` captured |
| Tier 1b — HDR-display visual A/B | **N/A** | documented hardware limit (Legion Go S Z2 has an SDR LCD) |
| Tier 2 — regressions | **PASS** | SDR unaffected; default path unchanged; no crash toggling across streams |

Both render-path cycles were **host-confirmed** (Vibepollo `sunshine_wgc_capture`: ON
23:47:00–23:47:49, OFF/passthrough 23:48:31–23:50:19).

---

## 2. Tier 1 — toggle presence + persistence (launcher)

The HDR controls live under **Settings → Advanced → Advanced Settings**, below **Preferred
renderer** (`Auto (Vulkan, fallback to OpenGL)`).

1. **Visibility gate — PASS.** With Enable HDR OFF (`hdr=false`), the list goes Enable HDR →
   Enable YUV 4:4:4 directly; the "My display supports HDR" and "Tone-map HDR to SDR" rows are hidden.
2. **Default-off — PASS.** Enabling HDR reveals "My display supports HDR" (ON) and, directly below,
   **"Tone-map HDR to SDR on this device (Experimental)"** unchecked by default. Label per spec.
3. **Persistence — PASS.** Checking the toggle wrote `hdrTonemapping=true`; quit + relaunch → still ON.

## 3. Tier 1.4 — render-path evidence (live Desktop-tile streams)

With Enable HDR + "My display supports HDR" ON, streamed the host **Desktop** tile
(non-disruptive, like the test124 E2E). HDR was genuinely **negotiated** (10-bit —
`HDR Debug: PlVkRenderer success - HDR support enabled`, `PlVkRenderer: HDR mode ENABLED`), so the
render path is exercised for real, not the SDR fallback.

- **Tone-map ON (`hdrTonemapping=true`):** exact line captured —
  `PlVkRenderer: HDR tone-map to SDR ENABLED — hinting SDR output (source transfer=11); libplacebo will tone-map HDR to SDR`.
- **Tone-map OFF (`hdrTonemapping=false`, HDR still ON):** exact line captured —
  `PlVkRenderer: HDR tone-map to SDR disabled — passthrough (source transfer=11)`.

The toggle **demonstrably drives the Vulkan (libplacebo) colorspace-hint decision** — SDR-output
hint + tone-map when ON, passthrough when OFF. Both cycles host-confirmed (session start/stop matched).

## 4. Tier 1b — HDR-display visual A/B (N/A, hardware limit)

The visible passthrough-vs-tone-map difference is only distinguishable on an **HDR-capable
display**. The Legion Go S Z2 has an **SDR LCD**, and no HDR external display was in the test path,
so the *visual* A/B could not be exercised. This is a **known hardware limitation of the test
device, not a fail** — the render-path decision itself is verified above via the log lines.

## 5. Tier 2 — regressions

1. **SDR streaming unaffected — PASS.** Enable HDR OFF → streamed Desktop → clean
   `Video stream is 1920x1200x120 (format 0x100)`, VAAPI init, **zero** `HDR mode ENABLED` /
   `HDR tone-map` lines during the stream, no log spam, no crash. Host desktop visible + interactive.
2. **Default HDR path unchanged — PASS.** Tone-map OFF (default) + display-HDR ON → HDR stream
   renders via the pre-existing path (HDR negotiated, passthrough hint; on the SDR panel libplacebo
   maps it as it already did). No regression vs prior alpha.
3. **`displayHdrCapability` gate — unchanged by this build.** This codec-level gate is orthogonal to
   the tone-map toggle (the toggle acts at render/output time, not codec negotiation) and is
   untouched by BL-1561; not re-exercised this cycle.
4. **No crash toggling between streams — PASS.** Three back-to-back stream cycles (tone-map ON →
   OFF → SDR) each disconnected and reconnected cleanly; no hang/crash.

## 6. Recommendation

**MERGE.** BL-1561 is fully wired (toggle presence/default/persistence) **and render-verified
on-device** — both `PlVkRenderer` colorspace-hint log lines captured and host-confirmed, with SDR
and default-path regressions clean. The only unverifiable piece is the HDR-display visual A/B,
which is a device hardware limit (SDR panel), not a defect. Ready to merge into the RC (rc.002).

_(Supersedes the earlier PARTIAL verdict — the render-log + regression tiers were completed after
the maintainer unparked test125 for the RC.)_
