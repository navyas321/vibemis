# BL-1560 Report — Vulkan decode + HDR pipeline validation (alpha.008)

**Artifact:** `Vibemis-0.2.0-alpha.008-x86_64.AppImage` (md5 `87aacf52ceb28354624fea25ae270ef0` ✓ — same build as test116, separate report per the build agent's 15:02 tasking)
**Device:** Legion Go S Z2 (AMD Z2 Go / RADV REMBRANDT), SteamOS 3.8.5, Desktop Mode — **panel has no HDR**, so this validates the client pipeline (tone-map path), not HDR display output.
**Host:** Navid-PC, Vibepollo/Apollo 7.1.431, RTX 5070.
**Test date:** 2026-07-16 — client setup `rendererbackend=1` (RB_VULKAN), `hdr=true` (config-level; see §4)

---

## 1. TL;DR — all four criteria PASS

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | PlVkRenderer chosen, no EGL fallback | PASS | `Renderer preference: Trying Vulkan (PlVkRenderer) as frontend first` → `Vulkan rendering device chosen: AMD Ryzen Z2 Go (RADV REMBRANDT)`; zero EGLRenderer lines all session |
| 2 | Host negotiates HEVC Main10 | PASS | Client decode picked `p010le` for `yuv420p10le` (10-bit); host truth 16:23: `Creating encoder [hevc_nvenc], Color depth: 10-bit`, NvEnc HEVC P1 10-BIT two-pass, active session 2880×1800 @ ~121 fps, ~350 µs latency, 27 % encoder util |
| 3 | 3+ min 10-bit soak, 0 errors / WSI crash | PASS | ~8 min soak (20:18:43Z → 20:26:56Z): 0 decode errors, 0 connection terminations, no crash |
| 4 | HDR off → clean renegotiate to 8-bit | PASS | New session at 20:28:10Z with `hdr=false`: decoder picked `nv12` for `yuvj420p` (8-bit), 0 errors. *Interpretation:* flip done **between sessions** — the client has no live mid-stream HDR toggle; renegotiation is per-connection. |

Expected-and-harmless: `Vulkan device … does not support HDR10 (ST.2084 PQ)` warnings on this
panel — libplacebo then runs the tone-map path, exactly the scenario this check targets.
Incidental: the session ran at 2880×1800 (the maintainer's 150 % resolution scale, left as set).

## 2. Recommendation line (for `docs/PHASE_STATUS.md` P3.6, per tasking)

> **P3.6 EGL-vs-Vulkan guidance:** On AMD handhelds (RADV), `rendererbackend=Vulkan` +
> `hdr=true` is fully functional for 10-bit HEVC Main10 streaming even on SDR panels
> (libplacebo tone-maps; ~8 min soak, 0 errors, host NvEnc 10-bit confirmed). Safe to
> recommend Vulkan as the default frontend for 10-bit content on this class of device;
> keep Auto for 8-bit/legacy. HDR flag renegotiates per-connection (no live toggle).

## 3. Client log excerpts

```
Renderer preference: Trying Vulkan (PlVkRenderer) as frontend first
Vulkan device 'AMD Ryzen Z2 Go (RADV REMBRANDT)' does not support HDR10 (ST.2084 PQ)   [expected: SDR panel]
Vulkan rendering device chosen: AMD Ryzen Z2 Go (RADV REMBRANDT)
[hevc] Picked p010le (0x30313050) as best match for yuv420p10le      ← 10-bit HDR run
[hevc] Picked nv12 (0x3231564e) as best match for yuvj420p           ← 8-bit HDR-off run
```

## 4. Method notes + new UX finding

- Settings were applied at the **config level** (`rendererbackend=1`, `hdr=true`, backup kept at
  `Vibemis.conf.bak-bl1560`) instead of UI navigation, because of a new finding:
- **UX bug (filed): d-pad focus-walk mutates ComboBoxes.** On the Advanced page, pressing d-pad
  Down while a ComboBox has focus changes its VALUE instead of moving focus — walking down the
  page flipped GUI display mode, Video decoder ("Force software decoding"!) and Video codec
  before reaching the target control. A controller user cannot pass a dropdown without editing
  it. (Recovered by killing the app pre-save; no settings were persisted.)
- Teardown: streams quit, host session ended, renderer restored to `rendererbackend=0`
  (hdr already false), app closed, rigs stopped.

## 5. Recommendation

**PASS — close BL-1560** with the P3.6 doc line above. Follow-ups: (a) the ComboBox
d-pad focus/value bug (likely same family as the slider double-step in
`sdlgamepadkeynavigation.cpp` — arrow keys land in controls' value handlers);
(b) optional AV1 10-bit variant of this check when a cycle has spare host time.
