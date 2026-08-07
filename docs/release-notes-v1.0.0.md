# Vibemis v1.0.0 — first stable release

**Vibemis** is a gamepad-first game-streaming client for **SteamOS & Linux handhelds** — the best of
Moonlight Qt and Artemis (Apollo's extended protocol), tuned to pair with the **Vibepollo** host.
1.0.0 is the first production-stable release, hardware-verified on a Lenovo Legion Go S Z2.

## Highlights

### A complete gamepad-first redesign
The whole UI was redesigned from a design prototype and implemented faithfully in Qt6/QML
(dark theme, 1920×1200 canvas that scales cleanly to 1280×800), on a single design-token system, with
a persistent **VIBEMIS** wordmark header and a controller hint bar on every screen:
- **Computers** — rich host cards: online/offline pulse pill, host name, access line, a
  **Vibepollo / Apollo / Sunshine** host-type badge, and transport (LAN / Tailscale); offline hosts
  show a "Last seen …" time, and the focused card lifts with an accent glow + drop shadow; plus a
  live `N hosts · M online` count.
- **App grid** — larger tiles with a green RESUME badge and a "launch" hint on the running app.
- **Add-PC dialog**, **Host-options side-sheet** (replaces the old right-click menu), **Settings**
  (a gamepad-navigable category sidebar), and **Help** — all with the accent focus-ring recipe and
  circled controller-glyph hints.

### Apollo / Vibepollo protocol features on a maintained Linux handheld
Clipboard sync, server commands, OTP pairing, virtual display control, an in-stream **Quick Menu**
(composited into the video so it works in Game Mode / Gamescope), and a per-client permissions viewer
— all surfaced on-device, lighting up automatically on capable hosts.

### Added by Vibemis
- Tailscale-first **remote play** (one-command setup + in-app help).
- **SteamOS one-click integration** (guided setup, add-to-Steam helpers, self-update).
- Bounded **auto-reconnect** on stream drop, **per-game stream profiles**, **settings export/import**,
  battery-saver bitrate, a compact performance overlay, and `vibemis selftest` for CI/on-device tests.
- **Optional microphone passthrough** (off by default) with device selection, a live input preview,
  negotiated Opus capture, and a clean fallback when the host does not support microphone streaming.
  End-to-end host receipt is still unproven — see `docs/KNOWN_ISSUES.md`.

## Install
Download the `.AppImage` from the release, make it executable, and double-click — or in SteamOS
Desktop Mode, right-click the AppImage → **Add to Steam**, then launch from Game Mode. Full steps in
the README.

## Notes
- Built from source under GPL-3.0; hardware-decode (VAAPI/VDPAU/NVDEC), H.264/HEVC/AV1, HDR, 7.1 audio.
- The in-stream Quick Menu opens with `Select + L1 + R1 + Y` (gamepad) or `Ctrl+Alt+Shift+\` (keyboard).

_Full commit history: the 0.6.x → 1.0.0 development series on `vibemis-main`._
