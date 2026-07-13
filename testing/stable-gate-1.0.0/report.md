# Stable-Gate 1.0.0 Report — headless sweep + nav-rig root cause + Vulkan stream

**Artifact tested:** `Vibemis-1.0.0-x86_64.AppImage` (release tag `1.0.0`, parked prerelease)
**md5:** `4ecd5a8fa73243938df98d55d2abe165` ✓ verified (self-reports `Vibemis 1.0.0`)
**Branch:** `vibemis-main` (commit `24c27ee`-lineage / release `1.0.0`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0, Qt 6.9.1
**Test date:** 2026-07-12
**Prior report:** bus messages 23:09–23:45Z (hearth hub) — this file is the durable copy

---

## 1. TL;DR

| Gate item | Status | Summary |
|---|---|---|
| Render gate, both viewports | **PASS** | 1a not black @1920×1200 + 1280×800, WSI surface, 0 coredumps |
| 1a / 1b / 1c / 1d / 1e exact-match | **PASS**(+2 cosmetic bugs) | see §3 |
| (2) grey CHECKING→OFFLINE pills | **PASS** | fake offline host renders grey OFFLINE pill, no teal |
| (3) update icon teal | **PASS** | header update icon teal, not red |
| (4) 1b tiles not clipped | **PASS** (headless) | full tiles + Ⓐ Launch pill visible |
| LB/RB settings category switch | **PASS** | all 5 categories, both ends, **no wrap** |
| (C) BL-1560 Vulkan | **PARTIAL-PASS** | plvk tried first + device chosen, no crash; final renderer VAAPI (fallback) |
| (9) pair/stream regression | **PASS** (headless) | real stream to Navid-PC: RTSP → 4 streams → HEVC Main10 vaapi_vld → live frames → clean quit |
| (6) "Last seen N ago" | **BLOCKED-BY-DESIGN** | never-seen fake host has no timestamp; needs once-seen offline host |
| (1)(5)(7)(8)(A)(D) + real-HW feel | **MAINTAINER** | need physical pad / touch / live Game Mode |
| (B) HDR tone-map | **IMPOSSIBLE HERE** | Legion Go S Z2 panel has no HDR |

**Verdict: NOT calling STABLE-READY yet** — two new bugs below should be judged first, and the
real-HW items remain with the maintainer.

## 2. 🚨 New bugs found on 1.0.0

1. **Stable build advertises the beta as an update.** Banner: *"Update available for Vibemis:
   Version 1.0.0-beta.20260713.0208+24c27ee"* — same commit as stable. Version comparison treats
   `1.0.0-beta.20260713 > 1.0.0` (or the feed points at prerelease-latest).
   Evidence: `item2-offline-pill-and-update-banner-bug.png`.
2. **1c Add-PC placeholder misaligned:** "192.168.1.42" renders clipped into the field's top
   border instead of centered. Evidence: `1c-addpc-placeholder-bug.png`.
3. *(minor)* Focused-tile tooltip ("Desktop"/"Steam Big Picture") can overlap the "Apps · N
   available" subtitle in 1b.

## 3. Six-screen sweep (headless gamescope, WSI/Game-Mode path)

- **1a** exact-match at both viewports (wordmark, token buttons, counts, rich cards, ghost card,
  circled hint glyphs). Env deltas only (1 real host).
- **1b** first-ever headless capture: toolbar back + host + "● Vibepollo · Tailscale", tiles
  Desktop/Steam/Virtual Desktop, focused tile + Ⓐ Launch, **not clipped**.
- **1c** modal matches (accent field, Tailscale note, Ⓑ Cancel / Ⓐ Connect pills) + bug §2.2.
- **1d** right sheet fully matches **including red Delete PC row** (offline-host variant:
  grey OFFLINE pill, "View only · LAN", Test network/Rename/Details/Delete).
- **1e** sidebar + Video panel + teal Version 1.0.0 chip; **LB/RB switch all 5 categories,
  no wrap at either end**; D-pad DOWN also walks categories; A selects.
- **1f Help** not captured headlessly (toolbar focus path); trivially reachable on real HW.

## 4. Root cause: why directional nav was "impossible" in headless for days

**The test rig, not the app or gamescope.** Repo `testing/automation/vinput.py`:
1. Gamepad dispatch implemented only `PRESS`/`HOLD` — **HAT/stick events were never emitted**.
2. `_pack_user_dev` hardcoded `absmin=0` → `ABS_HAT0X/Y` advertised as **[0,1] instead of
   [-1,1]** (sticks unsigned too) → LEFT/UP unrepresentable, SDL center/deadzone math broken.

Misdiagnosed on the bus as "gamescope keyboard-focus degradation" / "headless env limit."
**Fixed in this PR** (the previously never-pushed on-device patch): signed `absmin` support,
`DPAD <dir>` / `LS <dir>` commands, paired arrow-key fallback keyboard.
**Proof:** `1b-appgrid.png` focus moves Desktop→Steam on `DPAD RIGHT`; sidebar walks on DOWN.

## 5. (C) BL-1560 Vulkan + (9) stream regression — real stream to Navid-PC

`rendererbackend=1` (RB_VULKAN), headless gamescope, launch Desktop on Navid-PC (100.127.67.80):

```
Renderer preference: Trying Vulkan (PlVkRenderer) as frontend first
Vulkan rendering device chosen: AMD Ryzen Z2 Go (RADV REMBRANDT)
Vulkan device ... does not support HDR10 (ST.2084 PQ) / No suitable HDR-capable Vulkan devices found!
Using VAAPI accelerated renderer on x11
FFmpeg: [hevc] Main 10 profile bitstream ... Format vaapi_vld chosen by get_format()
Launch response: status_code=200 ... rtspenc://100.127.67.80:48010 ... VirtualDisplayDriverReady=true
Starting RTSP handshake / control / video / audio / input stream...
```

Pref honored, plvk inits without crash, then falls back to VAAPI in this env (no-HDR panel +
AppRun `FORCE_VAAPI=1`). Live host-desktop frames visually confirmed on 3 screenshots over 30 s
(not committed — they show the maintainer's desktop). Clean quit. **EGL-vs-Vulkan final verdict
on real Game Mode remains a maintainer check.**

## 6. Recommendation

**ITERATE**: fix §2.1 (stable-offers-beta) + §2.2 (placeholder), then flip 1.0.0 (or a 1.0.1)
to stable Latest after the maintainer's real-HW pass on items 1/5/7/8/A/B/D. Everything
automatable headlessly is green.
