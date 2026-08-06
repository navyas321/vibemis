# Known issues

Known issues in the current build. For what changed per release, see the latest
[Release](https://github.com/navyas321/vibemis/releases/latest) / `docs/release-notes-*.md`.

This file is hand-maintained. It is the single place for the current build's confirmed bugs
and their status — the README stays version-less and does not carry this table (see
[`docs/RELEASING.md`](RELEASING.md), "README update rule").

Last reviewed against `vibemis-main` on 2026-08-06: every row below was re-checked against the
current source tree and the fix that closed it; rows that no longer reproduce were removed.

## Confirmed bugs

Confirmed bugs in the current build, with workarounds. (Fixes in flight are noted; rows drop
off as fixes land.)

| Issue | Workaround | Status |
|---|---|---|
| **VRR caps same-rate streams below the source rate** — with Enable VRR on and the stream rate equal to the display refresh rate, the untearing spacing floor forces a minimum gap of one display period plus a guard interval between submissions. That gap is longer than the source interval, so the pacer can never keep up and the producer permanently evicts queued frames: 120-on-120 settles at ~118.2 fps, 60-on-60 at ~59.1 fps | Stream at a rate below the display's refresh rate, or turn Enable VRR off | Confirmed (BL-2521). Measured on an instrumented harness driving the real timing controller. Not yet fixed: capping the floor at the source interval removes the untearing margin exactly when frames are densest, so it needs an on-device A/B and an explicit call on that trade-off. The figures above predate the timing-core re-vendor and want re-measuring first. |
| **VRR sessions can hit a discrete mid-session presentation collapse** — inside a 10-minute soak, one ~67.5-second window ran at ~17 fps with ~99% hitches and a 1,147-interval consecutive-repeat run, then recovered. It is one discrete stall, not gradual decay | Turn Enable VRR off for long sessions | Confirmed (BL-2545). The instrumentation needed to localise it shipped since (`VIBEMIS_PIPELINE_SAMPLER=1` prints per-second receive/decode/present counters and queue depth); the soak has not yet been re-run with it on a build that includes the re-vendored timing core. |
| **Quick Menu is gamepad / keyboard only** — the menu is rendered from an offscreen window that is composited into the video frame, and only synthetic key events are delivered to it. Its rows therefore cannot be tapped or clicked, so a touch-only user can open the menu (MENU button) but not operate it | Navigate with D-pad + A, or arrow keys + Enter | Confirmed; touch operability planned |
| **Settings only drag-scrolls from empty space** — the settings panel is flickable, but it has no press delay, so a drag that starts on a control (slider, combo box, checkbox) is consumed by that control instead of scrolling the panel | Drag from a blank part of the panel, or use the scroll wheel, the scroll bar, or D-pad / stick navigation | Confirmed |
| **Text-send can drop the first character** — the compose field takes focus on a 50 ms timer after the view opens, so a keystroke that lands inside that window is lost | Pause briefly before typing, or retype the first character | Confirmed |
| **On-screen keyboard is SteamOS-only** — the KBD overlay button raises the SteamOS keyboard via `steam://open/keyboard`. On a keyboard-less handheld that is not running Steam there is no on-screen keyboard, and the button reports "Steam not available" | Use a physical / USB keyboard, or Paste Clipboard (clipboard sync) instead | Confirmed; a built-in OSK for non-Steam devices is planned |

## Limitations

Permanent / architectural constraints (not build-specific bugs). Kept here so the README stays
version-less and free of any issues/limitations tables.

| Feature | Status |
|---|---|
| **Microphone passthrough** | Not possible yet in any Moonlight-family client: it requires host-side protocol support that Apollo/Vibepollo does not ship (tracked upstream — Apollo discussion #591). |

## Experimental / not yet validated

Validation gaps specific to the current build — each resolves once the code path is exercised on
the hardware, or under the conditions, it was written for.

HDR streaming used to sit here. It was validated on HDR hardware on 2026-08-06 and is no longer
experimental: the row is gone and the Settings toggle now reads simply "Enable HDR". The separate
HDR-to-SDR tone-map option keeps its Experimental label — tone-mapping down to an SDR panel is a
different code path and has not been validated on its own.

| Feature | Status |
|---|---|
| **Ghosting / lost frames with Enable VRR on** | **Believed fixed, not yet re-confirmed on device.** The cause was a VRR timing core that had been vendored verbatim from an older upstream revision and never re-synced, so it ran a stale tuning model; the core has since been re-vendored from current upstream with the local fixes re-applied, alongside a fix for frames the pacer discarded without counting them. Two earlier explanations posted here — panel overdrive, and host-side frame generation — were both measured and **withdrawn**; neither was the cause. What is still missing is the matched A/B against the reference client with host-side frame generation enabled, so parity is stated but unproven (BL-2541). If ghosting or a rendered rate below the decoded rate recurs, report it with the pacing overlay open. |
