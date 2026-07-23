# BL-2292 — vibemis VRR implementation vs Nonary v6.1.0-vrr9.1: consolidated engineering diff

**Sources (both shallow-cloned fresh for this audit, 2026-07-21):**
- vibemis: `navyas321/vibemis` branch `vibemis-main` @ `46d210ba` ("fix(BL-2266): deterministic AppImage quit", i.e. AFTER the #240 port + #242 polish + #241 tests + BL-2235 fps auto-derive + #254 Settings IA merges)
- Nonary: `Nonary/moonlight-qt` tag `v6.1.0-vrr9.1` @ `a4f2011d` ("fix(vrr): restore fullscreen toggle shortcut" — the tag HEAD *is* the fullscreen-toggle fix vibemis ported as BL-2228)

**Method:** file-by-file `diff` over the full VRR scope; for files whose totals are dominated by unrelated fork/base divergence (vibemis is a rebrand fork of an older upstream moonlight-qt base, app version 0.4.0 vs Nonary's 6.1.0), VRR-relevant hunks were isolated by hunk-filtering and by extracting and byte-comparing the individual VRR function bodies.

---

## 1. Summary table

Status legend: **identical** = byte-identical to the Nonary tag · **adapted** = ported with deliberate divergence (detailed in §2) · **vibemis-only** = no Nonary counterpart · **nonary-only** = not ported (rationale in §4).

### Core (vendored engine) — 13 of 13 files: 11 byte-identical, 2 additively extended

| File | Status | What / why |
|---|---|---|
| `pacer/pacer.h` | **identical** | VRR-as-third-pacing-mode integration; Nonary's diff applied on a byte-identical upstream base (per PR #240), so the whole file matches the tag byte-for-byte |
| `pacer/pacer.cpp` | **identical** | Same — includes `isVrrActive()`, worker startup/teardown, force-paced fixed fallback |
| `ivrrframepresenter.h` | **identical** | Renderer-facing VRR contract (prepare/presentAdaptive/cancel/suspend) |
| `pacer/pacertelemetry.h` | **identical** | Cumulative telemetry snapshot struct |
| `pacer/vrrpacingworker.h` / `.cpp` | **identical** | The pacing worker thread |
| `pacer/vrr/vrrtypes.h` | **identical** | Shared VRR types |
| `pacer/vrr/vrrtargetwaiter.h` / `.cpp` | **identical** | Target-time waiter |
| `pacer/vrr/vrrtimingcontroller.h` / `.cpp` | **identical** | Cadence learner / timing controller |
| `vrrratepolicy.h` / `.cpp` | **adapted (additive only)** | Was byte-identical at the #240 merge; BL-2235 then appended one new pure static function `sessionFpsForStart()` (+10 h / +15 cpp lines). Zero changes to any vendored line |

### Integration

| File | Status | What / why |
|---|---|---|
| `plvk.h` / `plvk.cpp` | **adapted** | All VRR presenter logic ported; function bodies byte-equal modulo base-API deltas. Deliberate WSI divergence: **no `extra_queues`** (Nonary: 1 occurrence, vibemis: 0 — the libplacebo.365 sparse-queue SIGABRT guard). Gamescope + Gamescope-WSI detection and the WSI FIFO-retains-VRR exception ported verbatim |
| `renderer.h` | **adapted** | `getVrrFramePresenter()` default-nullptr hook ported verbatim (comment stamp only); rest of the file's 170-line diff is unrelated base divergence |
| `decoder.h` | **adapted** | Full VRR telemetry field block + `enableVrr`/`vrrDisplayRefreshHz` DECODER_PARAMETERS ported; vibemis adds `LiGetMicroseconds()` extern decl (Apollo common-c compat) and a vibemis-only `isVrrActive()` decoder hook; base VIDEO_STATS stays ms/uint32 vs Nonary's µs/uint64 |
| `ffmpeg.h` / `ffmpeg.cpp` | **adapted** | `syncPacerTelemetry()` merge ported with µs→ms conversion; PacedFrame submission path ported with RTP-timestamp reconstruction (`presentationTimeMs*90`); VRR overlay-stats block ported (2 format strings shortened); **vibemis-only auto-Vulkan-when-VRR** frontend selection (2 sites); `isVrrActive()` impl |
| `session.h` / `session.cpp` | **adapted (largest deliberate restructure)** | Qualification predicate ported verbatim (strict refresh + effective-V-sync + `hasAdaptiveHeadroom`, identical log strings) but **re-derived per decoder (re)creation** instead of Nonary's once-per-session `PresentationSettings` snapshot; borderless forcing keyed off `m_Preferences->enableVrr`; vibemis-only one-time fallback notice + BL-2235 fps auto-derive apply-site |
| `streamutils.h` / `.cpp` | **adapted (trivial)** | `tryGetDisplayRefreshRate()` (strict, no 60 Hz guess) — function body byte-identical; only comment stamps differ |

### Surface

| File | Status | What / why |
|---|---|---|
| `streamingpreferences.h` / `.cpp` | **adapted** | `enablevrr` settings key, `enableVrr` Q_PROPERTY, `VrrRatePolicy::buildChoices`-driven FPS-choice list all ported near-verbatim; vibemis adds `hasExplicitFps` (BL-2235); vibemis omits Nonary's `vrrsmoothness`/`vrrscalingaggressiveness` legacy-key removal (vibemis never shipped vrr8-era keys — nothing to clean) |
| `SettingsView.qml` | **adapted (re-authored, by design)** | VRR toggle re-built in vibemis's VbTokens pill-switch design language. Post-#254 Settings IA location: sidebar category **Video (index 0)**, pacing cluster V-Sync → Frame pacing → **"Enable VRR (beta)"** (~line 1956) → low-latency preset; the VRR-aware FPS combo (~1359-1461) is in the same Video category. Nonary: single-page classic SettingsView, VRR checkbox under the V-Sync/Frame-pacing group + `vrrForced` annotations on the window-mode combo. Behavioral deltas in §2.7 |
| `commandlineparser.h` / `.cpp` | **adapted (parity)** | `--vrr` / `--no-vrr` in-memory override ported verbatim (**full parity**; only a comment stamp differs on the VRR lines). `--fps` handling adapted to set `hasExplicitFps = true` (BL-2235). Other diffs are non-VRR (selftest verbs) |
| Overlay stats path | **adapted** | Lives in `ffmpeg.cpp::stringifyVideoStats` (see above); no separate overlay file diverges for VRR |

### Tests / verification

| File | Status | What / why |
|---|---|---|
| `tests/vrr/vrrtestfakes.h` | **identical** | Vendored test fakes |
| `tests/vrr/tst_vrrpacingworker.cpp` | **identical** | Vendored QtTest suite |
| `tests/vrr/tst_vrrtimingcontroller.cpp` | **identical** | Vendored QtTest suite |
| `tests/vrr/{ratepolicy,pacingworker,timingcontroller}.pro` | **identical** (3 files) | Vendored subproject files |
| `tests/vrr/tst_vrrratepolicy.cpp` | **adapted (additive only)** | +1 test slot `sessionFpsAutoDerive` (9 QCOMPAREs for BL-2235); vendored slots untouched |
| `tests/vrr/vrr.pro` / `README.md` | **adapted (additive only)** | Registers `ratepolicy_standalone` + documents the WSL2 build recipe; vendored content untouched |
| `app/test_vrrratepolicy.cpp` | **vibemis-only** | 177-line standalone (no-Qt) VrrRatePolicy checker with its own `main()` |
| `tests/vrr/ratepolicy_standalone.pro` | **vibemis-only** | Build target for the standalone checker |
| selftest `vrr-*` checks (`app/main.cpp` ~959-982) | **vibemis-only** | 9 runtime checks shipped in the binary: `vrr-rate-120/144`, `vrr-lowlatency-120`, `vrr-headroom-116at120`, `vrr-headroom-reject-120at120`, `vrr-autofps-{derive-120,explicit-wins,off-untouched,badrefresh-keeps}`, `vrr-choices-120hz` |
| `moonlight-common-c/limelight_compat.c` | **vibemis-only** | `LiGetMicroseconds()` shim — the Apollo-lineage common-c fork doesn't export the pacing clock mainline has |
| `Audio Invariants` job in `.github/workflows/dev-build.yml` | **vibemis-only (context)** | CI guard that every VRR wave was verified against (`git diff --stat -- app/streaming/audio/` must stay empty); Nonary has no equivalent |
| d3d11va VRR presenter, vrr8-era master machinery, `latency` branch | **nonary-only** | §4 |

**File counts: 17 byte-identical · 20 adapted · 5 vibemis-only files (+2 in-file additions: selftest checks, isVrrActive hook) · 1 nonary-only unported surface (d3d11va) + off-tag machinery.**

---

## 2. Hunk summaries for adapted files

### 2.1 `vrrratepolicy.{h,cpp}` (+9/+13 changed lines, purely additive)
One new static `sessionFpsForStart(vrrEnabled, fpsExplicitlySet, configuredFps, displayRefreshHz)`: explicit choice always wins; VRR-on + no explicit fps → `vrrRateForRefresh(displayRefreshHz)`; unusable refresh (≤0 or rejected) keeps the configured fps. No vendored line modified — merges as an append.

### 2.2 `plvk.{h,cpp}` (+57/+749 total; VRR share small)
- **WSI guard (deliberate):** Nonary's `vkParams.extra_queues = VK_QUEUE_FLAG_BITS_MAX_ENUM` (their line 449) is intentionally absent (0 grep hits in vibemis) — this is the libplacebo.365/vkroots NULL-queue SIGABRT avoidance from PR #240.
- **Gamescope handling:** `isGamescopePresentation()`, `isGamescopeWsiPresentation()` (env `ENABLE_GAMESCOPE_WSI`), and the "Gamescope WSI uses FIFO application presentation; retaining adaptive VRR pacing" exception are ported byte-equal (comment rewrap only).
- **Function-body comparison** (extracted and diffed): `checkSupport`, `presentAdaptive`, `cancelFrame`, `cancelVrrFrame`, `selectLegacyPresentMode`, `getVrrFramePresenter` — **byte-identical**. `prepareFrame` / `acquireVrrSwapchainFrame` / `selectPresentationMode` differ only by: (a) dropped `m_VrrRenderTimingActive` lines, (b) `acquirePendingSwapchainFrame()` losing a message parameter, (c) two comment fixes (`presentFrame()` → `presentAdaptive()`, "Moonlight's" → "the").
- **Why (a)/(b) are correct, not gaps:** Nonary's `beginRenderTiming`/`endRenderTiming`/`finishVrrRenderTiming` machinery is entirely the upstream-6.x **Darwin** dynamic-swapchain-depth accounting (`PLVK_USE_DYNAMIC_SWAPCHAIN_DEPTH`, MoltenVK early-render-wait) that Nonary's newer base carries; vibemis's older base (constructor `PlVkRenderer(bool hwaccel, ...)` vs Nonary's `PlVkRenderer(AVHWDeviceType, ...)`) never had it, and vibemis targets Linux/SteamOS.

### 2.3 `renderer.h` / `decoder.h`
- `renderer.h`: the one VRR hunk is the `getVrrFramePresenter()` default hook, verbatim + BL stamp. Remaining ~170 changed lines are base divergence (needsTestFrame/setHdrMode-era interface vs Nonary's newer one).
- `decoder.h`: telemetry block (`vrrTelemetryActive` + 20 `vrr*` fields) verbatim; `enableVrr`/`vrrDisplayRefreshHz` params verbatim. Vibemis-only: `extern "C" uint64_t LiGetMicroseconds(void)` decl (Apollo common-c lacks it; impl in the wrapper static lib), and virtual `isVrrActive()` (default false) so Session can detect a silent downgrade. Base delta: VIDEO_STATS keeps vibemis's historical `uint32 ms` fields vs Nonary's `uint64 µs`.

### 2.4 `ffmpeg.{h,cpp}` (+22/+731 total; VRR hunks ~320 diff lines)
- `syncPacerTelemetry()` ported; **µs→ms conversion added** for `totalPacerTime`/`totalRenderTime` (explicit NB comment) because the vendored Pacer publishes µs while vibemis VIDEO_STATS is ms.
- PacedFrame submission ported; **RTP timestamp reconstructed as `presentationTimeMs * 90`** because the Apollo common-c fork doesn't expose the raw RTP timestamp on DECODE_UNIT (~0.5 ms quantization, inside the controller's filtering — documented in-code).
- **Auto-Vulkan-when-VRR (vibemis-only):** `createFrontendRenderer()` tries `PlVkRenderer` first when `params->enableVrr`, at BOTH the alternate-frontend site and the backend-can't-direct-render site; failure falls through to the ordinary chain (→ fixed pacing + notice). Nonary relies on `PREFER_VULKAN`/platform defaults instead. Also interleaved with vibemis's own `rendererBackend` (Auto/Vulkan/OpenGL) preference, which Nonary lacks.
- Overlay: VRR stats block ported; two format strings shortened (dropped the "(up to 128 retained …)" parentheticals).
- `isVrrActive()` → `m_Pacer->isVrrActive()`.

### 2.5 `session.{h,cpp}` (+94/+1261 total; the big architectural adaptation)
- **Nonary architecture:** `snapshotPresentationSettings()` fills an immutable per-session `PresentationSettings` struct at initialize (requestedVrr/effectiveVsync/enableFramePacing/enableVrr/refreshRate/windowMode); decoder resets *reuse the snapshot*; `chooseDecoder` has a `bool* effectiveVrr` out-param; a `refreshMayHaveChanged` guard (DISPLAY_CHANGED **or SIZE_CHANGED**, or SDL≥2.0.18 DISPLAY_CHANGED) *disables VRR for the rest of the session* when the display refresh changes or becomes unreadable.
- **vibemis adaptation:** no snapshot struct; the identical qualification predicate (strict `tryGetDisplayRefreshRate` — never the 60 Hz guess — effective-V-sync check, `hasAdaptiveHeadroom`, and "rejected VRR still force-paces the fixed fallback") runs **inline at the single decoder-(re)creation site** in the exec event loop (line ~2660-2724; vibemis's base creates the initial streaming decoder through the same path, so one site covers both). Cross-display moves still re-qualify via the existing forceRecreation-on-refresh-change path — arguably better than Nonary's permanent disable (re-qualifies at the new panel's rate) — **but a same-display refresh-mode switch reported only as SIZE_CHANGED is not covered** (see §5).
- **Borderless enforcement:** ported semantics (`SDL_WINDOW_FULLSCREEN_DESKTOP` forced while `enableVrr`, saved preference untouched, LXDE-Pi hack understandably un-guarded on the older base) with an explicit rationale comment.
- **Fallback notice (vibemis-only):** after decoder creation, `enableVrr && !m_VideoDecoder->isVrrActive() && !m_VrrFallbackNotified` → one-time `displayLaunchWarning(tr("VRR unavailable: falling back to fixed frame pacing"))`. Nonary vrr9.1 has **no** VRR launch warning at all (verified: no VRR string in its `emitLaunchWarning` corpus) — "never a silent downgrade" is a vibemis improvement.
- **fps auto-derive apply-site (BL-2235, vibemis-only):** in `Session::initialize()`, guarded by `enableVrr && !hasExplicitFps && !enableFractionalRefreshRate`, using the same strict refresh probe on the test window; logs "VRR: auto-selected N FPS for the M Hz display".
- **SLVideo guard** ported (non-VRR params copy + warn), minus the now-moot `effectiveVrr` write-back.

### 2.6 `streamutils.{h,cpp}` / `streamingpreferences.{h,cpp}`
- `tryGetDisplayRefreshRate()` body **byte-identical**; comments restamped.
- Prefs: `SER_ENABLEVRR "enablevrr"` (default false), `enableVrrChanged` signal, `getFpsChoices`→`buildChoices` bridge all near-verbatim. Vibemis-only: `hasExplicitFps` = `settings.contains(SER_FPS)` at load, set true on save/CLI-`--fps`. Not ported (correctly): legacy `vrrsmoothness`/`vrrscalingaggressiveness` key removal. Note Nonary tracks fps via `getFps/setFps` Q_PROPERTY accessors (their newer base); vibemis uses direct MEMBER access + the explicit flag.

### 2.7 `SettingsView.qml` (+3075 total — dominated by the #254 IA overhaul; VRR share re-authored)
- **Where VRR lives now:** sidebar IA (Video / Audio / Input & gamepad / Streaming / App & UI / Advanced). VRR toggle = category **Video**, in the pacing cluster after V-Sync and Frame pacing, before the low-latency preset and the "Decoding & HDR" section header. The FPS combo (VRR/low-latency-VRR entries, native rates hidden while VRR on — same `buildChoices` strings as Nonary) is also in Video.
- **UX deltas vs Nonary:** (1) Nonary greys the VRR checkbox out until V-Sync is on; vibemis **auto-enables V-Sync** when VRR is switched on, and the low-latency preset (which kills V-Sync) also disables VRR. (2) With VRR on and no matching saved fps, vibemis's combo **defaults to the highest VRR-kind rate** (UI twin of BL-2235); Nonary keeps the saved value semantics only. (3) **Not ported:** Nonary's `vrrForced` binding that disables the window-mode combo and explains "Borderless windowed mode is required for active VRR streaming" — vibemis still shows an enabled Display-mode combo (line ~1767) while the session silently overrides it (log-only). Cosmetic-functional gap, candidate polish item.

### 2.8 `commandlineparser.{h,cpp}`
`--vrr`/`--no-vrr` toggle-option resolution is line-for-line identical (in-memory override, never persisted); only a BL-stamp comment was added. The `--fps` hunk switches from Nonary's `setFps()` accessor to direct assignment + `hasExplicitFps = true`.

---

## 3. vibemis-only additions (no Nonary counterpart)

1. **`VrrRatePolicy::sessionFpsForStart()` fps auto-derive** (BL-2235): pure function + Session apply-site + `hasExplicitFps` plumbing (settings/CLI) + FPS-combo default. Closes the "toggle-only config streams at 60 FPS on a 120 Hz panel" hole found in device testing.
2. **Auto-Vulkan-when-VRR** renderer selection (2 sites in `createFrontendRenderer`) — the "no PREFER_VULKAN, no launch wrappers" product goal.
3. **Never-silent fallback notice**: `IVideoDecoder::isVrrActive()` → `Pacer::isVrrActive()` → one-time launch-warning toast.
4. **Verification surface**: standalone checker (`app/test_vrrratepolicy.cpp`, 55 checks) + `ratepolicy_standalone.pro` harness target + 9 in-binary selftest `vrr-*` checks + the QtTest `sessionFpsAutoDerive` slot.
5. **`LiGetMicroseconds()` compat shim** (`moonlight-common-c/limelight_compat.c`) + RTP-timestamp reconstruction — the two Apollo-lineage common-c gaps the port had to bridge.
6. **CI audio-invariants guard** (`Audio Invariants` in `.github/workflows/dev-build.yml`): every VRR wave shipped with proof `app/streaming/audio/` was untouched (BL-2213 differentiator protection).
7. **Pending, NOT on vibemis-main:** `BitrateRescuePolicy` interplay (un-merged PR #258, BL-2265) — clamps the BL-2235 auto-derived rate's default-bitrate estimate to the user's last-known bitrate (auto-derive may lower, never raise past it) plus the FEC-collapse rescue detector. Mentioned here as pending; not part of this diff's main-branch verdict.

## 4. Nonary-only, deliberately unported

Per the existing gap matrix (`docs/engineering/BL-2222-nonary-feature-gap-matrix.md`) and the PR #240 body — not re-derived here, spot-verified against the clones: the **d3d11va VRR presenter** (Nonary's `d3d11va.cpp` is 2507 lines with 191 VRR references; vibemis's is 1665 with **zero**) is a Windows-only waitable-swapchain path with no users in a Linux/SteamOS-only product, and Windows Vulkan VRR is rejected by design (`VrrFallbackReason::WindowsVulkan`) anyway. The **vrr8-era master-branch machinery** (52 commits: calibration bands, tear probes, phase snaps, hysteresis tapers, persistent calibration cache, Smoothest-VRR composition swapchain, EcoQoS) is superseded — Nonary's own vrr9 release notes call it bloat/tech debt and replaced it wholesale with the vrr9 rewrite this port vendored. The **`latency` branch** (7 commits) is unreleased and experimental — wait for Nonary to ship it. Also unported by design: `extra_queues` (the WSI-crash guard, §2.2), the `PresentationSettings` snapshot architecture (§2.5 — replaced, not omitted), and the Darwin render-timing machinery (base-inapplicable). The gap matrix's remaining delivery-surface gaps (#1 settings/CLI, #3 telemetry, tests) have since been closed by #240/#241/#242; Flatpak packaging landed separately (`.github/workflows/flatpak.yml`).

## 5. Upstream-merge cost (when Nonary ships vrr10)

**Cheap (17 files):** everything byte-identical re-merges as wholesale replacement. Take Nonary's `vrr9.1 → vrr10` diff and apply it to these files directly — never 3-way-merge vibemis against vrr10, always against the vrr9.1 base we vendored from.

**Low risk:** `vrrratepolicy.{h,cpp}` + `tst_vrrratepolicy.cpp` + `vrr.pro`/`README.md` are additive-only extensions; conflicts only if Nonary edits the exact append points or ships their own fps-derivation (then reconcile `sessionFpsForStart` semantics deliberately).

**Conflict hotspots, in cost order:**
1. **`session.cpp`** — the biggest. Vibemis restructured qualification (snapshot → inline-at-creation), so any vrr10 change to `snapshotPresentationSettings`/`PresentationSettings` has no textual anchor here; every session-side vrr10 hunk must be re-derived by hand into the event-loop block (~line 2660). Budget the majority of merge time here.
2. **`SettingsView.qml`** — treat vrr10 UI changes as a spec, never a patch; the control is fully re-authored (and #254 moved the IA again).
3. **`ffmpeg.cpp`** — the telemetry merge and auto-Vulkan blocks sit inside heavily base-diverged code; the µs→ms conversion and `presentationTimeMs*90` reconstruction must be re-asserted after any telemetry-schema change.
4. **`plvk.cpp`** — moderate: VRR function bodies are byte-equal so hunks land cleanly, but re-verify after merge that `extra_queues` is still absent (it is the crash guard) and that no new Darwin-timing coupling leaked in.

**Minimizers:** (a) keep vendored files pristine (the tests/vrr README note already mandates this); (b) maintain a VENDORED-VRR file manifest so the wholesale-replace set is mechanical; (c) re-run the standalone checker + selftest `vrr-*` + `tests/vrr` suites as the merge gate; (d) decide explicitly whether to adopt any vrr10 same-display refresh-switch handling — see the one real watch-item below.

**Watch-item (known behavioral gap):** Nonary disables VRR when a `SIZE_CHANGED`/`DISPLAY_CHANGED` event reveals a refresh change on the *same* display; vibemis only re-qualifies on cross-display moves (via decoder recreation). A same-display mode-switch mid-stream can leave the vibemis worker pacing against a stale refresh period until the next decoder recreation. Low severity on the handheld target (fixed internal panel), but it is the one place the port is *less* defensive than the source — file it if vrr10 touches this area.

## 6. Fidelity verdict

**The port is faithful where it claims to be.** Evidence:
- All 17 files claimed as vendored verbatim are **byte-identical** to tag `v6.1.0-vrr9.1` (`diff -q` clean), including the entire pacing engine and `pacer.{cpp,h}`. The 2 policy files + 3 test files that now differ do so **only by additive BL-2235/BL-2230 blocks** — no vendored line was modified.
- The adapted Vulkan presenter's nine VRR functions were extracted and byte-compared: six identical, three differing only by base-API deltas (older constructor/acquire signature, absent Darwin render-timing) and comment fixes — no logic divergence.
- The qualification predicate, borderless enforcement, strict-refresh probe, SLVideo guard, Gamescope-WSI exception, and `--vrr` CLI are semantically (mostly textually) identical; log strings match Nonary's verbatim.
- Deliberate divergences are all documented, motivated, and in vibemis's favor or neutral: no `extra_queues` (crash guard), µs→ms telemetry conversion, RTP reconstruction, auto-Vulkan selection, fallback notice, fps auto-derive, per-creation re-qualification. The two true gaps versus the source are minor: the same-display refresh-switch guard (§5 watch-item) and the missing window-mode-combo lockout in Settings (§2.7, cosmetic).

*Audit artifacts: shallow clones `vibemis@46d210ba` and `Nonary/moonlight-qt@a4f2011d` (deleted after this doc); diff commands and per-function extraction as described in Method.*
