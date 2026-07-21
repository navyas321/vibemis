# BL-2263 — Settings information-architecture overhaul

Every user-visible settings control was inventoried (`extract_manifest.py` →
`manifest-before.json`: **84 controls, 13 cards, 5 categories**), reviewed,
and either moved or explicitly kept with a recorded verdict. Settings KEYS and
persistence are untouched — this is a pure UI relocation (no renamed keys, no
data migration). Zero-drop is machine-enforced by `check_no_drop.py`.

## Category model

| # | Before (5) | After (6) | Owns |
|---|------------|-----------|------|
| 0 | Video | Video | display, resolution/FPS, bitrate quality cluster, decoding, codec, HDR, VRR |
| 1 | Audio | Audio | audio |
| 2 | Input & gamepad | Input & gamepad | mouse/keyboard/touch, gamepad |
| 3 | Streaming | Streaming | connection, host-session behavior, Apollo enhancements, Tailscale |
| 4 | Advanced | **App & UI (new)** | app appearance/behavior, warnings, overlay, backup |
| 5 | — | Advanced | genuinely-expert knobs + updates/system info/about/help |

The new **App & UI** category (icon kind `apps`, existing VbSheetIcon glyph)
takes index 4; Advanced shifts to 5. No category index is persisted anywhere
(`property int category: 0`, session-local; verified no external deep-links).

## Moves made (14 controls + 1 whole card = 22 controls relocated)

| Control (id) | Current | Proposed | Why |
|---|---|---|---|
| `decoderComboBox` (Video decoder) | Advanced | Video · Decoding & HDR | Video decoding is a Video concern; user looks in Video when the picture breaks |
| `codecComboBox` (Video codec) | Advanced | Video · Decoding & HDR | Codec pairs with HDR (HDR needs HEVC/AV1) and shows in the Video summary line |
| `rendererBackendComboBox` (Preferred renderer) | Advanced | Video · Decoding & HDR (last) | Video pipeline knob; orphaned in Advanced once decoder/codec leave |
| `enableHdr` | Advanced | Video · Decoding & HDR | THE reported misplacement — HDR is a Video item |
| `displayHdrCapability` | Advanced | Video · Decoding & HDR | Child of Enable HDR; moves with its visible/enabled chain |
| `hdrTonemapping` | Advanced | Video · Decoding & HDR | Child of Enable HDR; moves with its chain |
| `enableYUV444` | Advanced | Video · Decoding & HDR | Chroma-quality knob; recomputes the default bitrate owned by the Video card |
| `enableMdns` (find PCs) | Advanced | Streaming · Connection (new card) | Host discovery = connection behavior |
| `detectNetworkBlocking` | Advanced | Streaming · Connection | Connection diagnostics |
| `showPerformanceOverlay` (+4 below) | Advanced | App & UI · Performance overlay (new card) | Client overlay appearance/behavior; a 5-control cluster is not a "rare knob" |
| `compactPerformanceOverlay`, `perfOverlayShowClock`, `perfOverlayTextSizeComboBox`, `perfOverlayPositionComboBox` | Advanced | App & UI · Performance overlay | Pure appearance sub-knobs; enable/visible chains to `showPerformanceOverlay` move intact |
| `accentComboBox` (Accent color) | Input & gamepad (Gamepad card) | App & UI · UI Settings | App-wide appearance; nothing gamepad about it |
| `touchOverlayCheck` (on-screen touch controls) | Streaming (Vibemis Features) | Input & gamepad · Input Settings | Touch input, client-side, no Apollo dependency (unlike its old card siblings) |
| `reduceBitrateOnBatteryCheck` | Advanced (UI Settings card) | Video · Stream settings, after Adaptive bitrate | Bitrate behavior modifier — "60% of the configured value" = the slider two rows above |
| whole `uiSettingsGroupBox` card (language, GUI display mode, connection warnings, configuration warnings, nav sounds, Discord presence, keep awake, Export/Import settings) | Advanced | **App & UI** (new category) | None of these are expert; Language buried in Advanced was the largest misplacement by count |

## Adversarial self-review — kills & amendments (proposal attacked before implementing)

| # | Attacked move | Verdict |
|---|---|---|
| K1 | Bitrate slider/reset/adaptive → Streaming ("Streaming owns bitrate") | **KILLED.** res/fps→bitrate auto-adjust coupling, preset buttons write all three, the Video summary line shows all three. Splitting the strongest muscle-memory cluster costs more than principle purity. Bitrate stays in Video. |
| K2 | `unlockBitrate` → Video (next to slider) | **KILLED.** Genuinely-expert footgun (500 Mbps, Ethernet-LAN-only per its own tooltip). Advanced exists precisely for this. Stays Advanced. |
| K3 | `virtualDisplayCheck`/`resolutionScalingCheck` → Video (they set resolution!) | **KILLED.** Apollo-host-session features living under the card whose intro text explains the Apollo requirement; splitting orphans the explanation. Host-session behavior stays Streaming. |
| K4 | Software updates cluster → App & UI | **KILLED.** README (×3) and release notes document "Settings → Advanced → Software updates"; docs + muscle-memory cost outweighs purity. Stays Advanced — all doc references remain valid. |
| K5 | `showHintsCheck` (hint bar) → App & UI | **KILLED.** Gamepad-specific UI (glyph hint bar); adjacency to gamepad config wins. |
| K6 | `quickMenuComboBox` → App & UI | **KILLED.** It selects a gamepad button combo. Stays Gamepad. |
| K7 | Settings backup → Advanced | **KILLED.** App-level management fits App & UI; zero extra churn. |
| K8 | `muteOnFocusLossCheck` → App & UI (window-focus behavior) | **KILLED.** It mutes audio; Audio owns audio. |
| K9 | Clipboard sync cluster → Input | **KILLED.** Apollo session data feature, stays Streaming (Vibemis Features). |
| K10 | `keepAwakeCheck` → Video (display!) | **KILLED.** OS power management by the app, not stream image. Stays with App & UI. |
| K11 | Split basicSettingsGroupBox into "Stream quality" + "Display" cards | **DEFERRED.** Pure churn; fixes no misplacement; within-card order already sensible. |
| K12 | Renderer backend kept in Advanced as driver-bug escape hatch | **AMENDED → moved.** Placed LAST in the Decoding & HDR card (rarest first-class video knob) instead of staying Advanced, so the decode/render pipeline lives in one place. |

Doc-reference sweep: "Settings → Advanced → Software updates" (README ×3,
release notes) — preserved by K4. "Settings → Input" (README gamepad combo +
virtual trackpad) — unchanged. "Settings → Prefer Tailscale"
(REMOTE_PLAY_TAILSCALE.md, no category named) — unchanged.
QML dependency sweep: every moved control's `enabled`/`visible`/JS references
(`slider`, `showPerformanceOverlay`, `enableHdr`, `codecListModel`) are QML
ids, which are file-scoped — cross-card references keep resolving after
relocation. The `ClipboardSettings` component and its card were not split.

## Reorders (within categories)

- **Streaming** card order: Host Settings → Connection (new) → Vibemis
  Streaming Enhancements → Vibemis Features (general-first; Apollo-specific
  after).
- **Video**: summary → Presets → Stream settings (res/fps/bitrate cluster +
  display-mode/scaling/V-Sync/pacing/VRR) → Decoding & HDR (decoder, codec,
  HDR ×3, YUV 4:4:4, renderer).
- **App & UI**: UI Settings (Language, GUI display mode, Accent color,
  warnings ×2, nav sounds, Discord, keep awake, Settings backup) →
  Performance overlay card.
- **Gamepad** card: order preserved minus Accent color (muscle memory).

## Zero-drop gate

`extract_manifest.py` (deterministic text parse) runs before and after;
`check_no_drop.py` asserts every control in `manifest-before.json` exists in
`manifest-after.json` exactly once (identity = id + label + backing pref
keys), that ONLY category/card/position changed, and that no orphan controls
appeared. Run:

    python3 tests/settings-ia/extract_manifest.py --out tests/settings-ia/manifest-after.json
    python3 tests/settings-ia/check_no_drop.py
