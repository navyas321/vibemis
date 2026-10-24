# Known issues

Known issues in the current build. For what changed per release, see the latest
[Release](https://github.com/navyas321/vibemis/releases/latest) / `docs/release-notes-*.md`.

This file is hand-maintained. It is the single place for the current build's confirmed bugs
and their status — the README stays version-less and does not carry this table (see
[`docs/RELEASING.md`](RELEASING.md), "README update rule").

Last reviewed against `vibemis-main` on 2026-10-24, after the 0.6.0 on-device test cycle
(test150 to test151 on a Legion Go S against a Vibepollo host): rows were re-checked against that
evidence and the current source tree.

## Confirmed bugs

Confirmed bugs in the current build, with workarounds. (Fixes in flight are noted; rows drop
off as fixes land.)

| Issue | Workaround | Status |
|---|---|---|
| **VRR caps same-rate streams below the source rate** — with Enable VRR on and the stream rate equal to the display refresh rate, the untearing spacing floor forces a minimum gap of one display period plus a guard interval between submissions. That gap is longer than the source interval, so the pacer can never keep up and the producer permanently evicts queued frames: 120-on-120 settles at ~118.2 fps, 60-on-60 at ~59.1 fps | Stream at a rate below the display's refresh rate, or turn Enable VRR off | Confirmed (BL-2521). Measured on an instrumented harness driving the real timing controller. Not yet fixed: capping the floor at the source interval removes the untearing margin exactly when frames are densest, so it needs an on-device A/B and an explicit call on that trade-off. The figures above predate the timing-core re-vendor and want re-measuring first. |
| **VRR sessions can hit a discrete mid-session presentation collapse** — inside a 10-minute soak, one ~67.5-second window ran at ~17 fps with ~99% hitches and a 1,147-interval consecutive-repeat run, then recovered. It is one discrete stall, not gradual decay | Turn Enable VRR off for long sessions | Confirmed (BL-2545). The instrumentation needed to localise it shipped since (`VIBEMIS_PIPELINE_SAMPLER=1` prints per-second receive/decode/present counters and queue depth); Not reproduced on 2026-10-24: about two hours of instrumented 116 fps soaks on 0.6.0-beta.013 and beta.014 (VRR on and off) showed no stall of this kind. The ~10-second dips seen in those runs were Wi-Fi background scans, listed under Limitations. Kept until it is seen again or ruled out. |
| **Quick Menu is gamepad / keyboard only** — the menu is rendered from an offscreen window that is composited into the video frame, and only synthetic key events are delivered to it. Its rows therefore cannot be tapped or clicked, so a touch-only user can open the menu (MENU button) but not operate it | Navigate with D-pad + A, or arrow keys + Enter | Confirmed; touch operability planned |
| **On-screen keyboard is SteamOS-only** — the KBD overlay button raises the SteamOS keyboard via `steam://open/keyboard`. On a keyboard-less handheld that is not running Steam there is no on-screen keyboard, and the button reports "Steam not available" | Use a physical / USB keyboard, or Paste Clipboard (clipboard sync) instead | Confirmed; a built-in OSK for non-Steam devices is planned |

## Limitations

Permanent / architectural constraints (not build-specific bugs). Kept here so the README stays
version-less and free of any issues/limitations tables.

| Feature | Status |
|---|---|
| **Wi-Fi background scans cause a short dip** | Some Wi-Fi adapters scan every band every few minutes (the Legion Go S: about every 5 minutes, for about 9 seconds). While a scan runs, nothing arrives for about 150 ms at a time, so the picture briefly shows fewer new frames and catches up after each gap. Since 0.6.0 the client absorbs the resulting bursts instead of throwing frames away and asking the host for keyframes, so a scan no longer turns into a stutter of several seconds (BL-2713). The short dip itself comes from the network and cannot be removed in the client: use a wired connection (for example through a dock's Ethernet port) for the smoothest stream. |
| **Microphone passthrough** | Client capture, negotiated Opus microphone protocol support, device selection and a live input preview are implemented (BL-2629), off by default. The client degrades cleanly when a stock host does not advertise microphone support — verified on device (BL-2633). Host-side receipt is still unproven and needs a mic-enabled Apollo/Vibepollo host (BL-2634), so treat end-to-end microphone audio as unvalidated. |

## Experimental / not yet validated

Validation gaps specific to the current build — each resolves once the code path is exercised on
the hardware, or under the conditions, it was written for.

| Feature | Status |
|---|---|
| **Ghosting / lost frames with Enable VRR on** | **Believed fixed, not yet re-confirmed on device.** The cause was a VRR timing core that had been vendored verbatim from an older upstream revision and never re-synced, so it ran a stale tuning model; the core has since been re-vendored from Nonary `v6.1.0-vrr10` (July 2026) with the local fixes re-applied. Nonary has since redesigned its pacer (vrr11 through vrr18); adopting that is planned for after the 0.6.0 stable release (BL-2696), alongside a fix for frames the pacer discarded without counting them. Two earlier explanations posted here — panel overdrive, and host-side frame generation — were both measured and **withdrawn**; neither was the cause. What is still missing is the matched A/B against the reference client with host-side frame generation enabled, so parity is stated but unproven (BL-2541). If ghosting or a rendered rate below the decoded rate recurs, report it with the pacing overlay open. |
| **ABNT2 `/` `?` key (Brazilian keyboards)** | The local-key -> remote-key table is unit-tested now (`tests/keyboard`), and the extra Brazilian `/` `?` key sends `VK_ABNT_C1` un-normalised instead of collapsing onto the ISO `\` `|` key. Verified on the client: measured against real SDL 2.30 X11 events on an ABNT2 keyboard, so X11 keycodes 94 and 97 are now known to produce two different remote keys. What has NOT been run is the last hop — typing `/`, `?`, `\` and `\|` on a Windows host set to Portuguese (Brazil) ABNT2 behind Vibepollo/Apollo. If it still misbehaves, run with `VIBEMIS_DEBUG_KEYBOARD=1`: it logs the scancode and keysym SDL reported next to the VK code and normalisation flag that went out. |
| **YUV 4:4:4 hardware decode in the AppImage** | The AppImage now bundles FFmpeg 8.1 (built from the same pins as the Flatpak) instead of Ubuntu 22.04's FFmpeg 4.4, which had no VAAPI or Vulkan decoder for HEVC 4:4:4. CI confirms the new libraries are bundled with the HEVC VAAPI and Vulkan hwaccels enabled. Confirmed on AMD on 2026-10-24: a Legion Go S decoded an HEVC 4:4:4 stream in hardware through VAAPI (#319). Not yet confirmed on an Intel GPU. |
| **Host VRR capture policy (`clientVrrRequested`)** | With Enable VRR on, Vibemis now tells the host when the session qualifies for VRR, so Vibepollo/Vibeshine can switch to their low-latency VRR capture mode. Confirmed against Vibepollo 1.18.3 on 2026-10-24: its log records the low-latency VRR policy request for every VRR session (#320). Not yet tried with Vibepollo 2.0.0. |
| **Settings drag-scrolling** | The settings panel now holds a press briefly, so a vertical drag that starts on a control scrolls the panel. Fixed in code; not yet confirmed on a touchscreen. |
| **Text-send first character** | A keystroke that arrives before the compose field has focus is now handed to the field instead of being dropped. Fixed in code; not yet confirmed on device. |
