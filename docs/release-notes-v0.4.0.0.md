# Vibemis 0.4.0.0 — first stable release

**Vibemis** is a gamepad-first game-streaming client for **SteamOS & Linux handhelds** — the best of
Moonlight Qt and Artemis (Apollo's extended protocol), tuned to pair with the **Vibepollo** host.
0.4.0.0 is the first production-stable release, hardware-verified on a Lenovo Legion Go S Z2.

> **Versioning note:** releases follow **[Semantic Versioning 2.0.0](https://semver.org)** — pre-releases are suffixed versions of the stable they precede (`0.1.1-beta.001` → `0.1.1`), release candidates are `-rc.NNN`, and only bare stable versions are full releases (Latest). The complete historical catalog, including the interim-scheme era it supersedes, is mapped in `docs/RELEASE_HISTORY.md`. **Bump policy (maintainer):** patch (`0.1.1`) = fixes and small additions; minor (`0.2.0`) = major feature waves.

## Highlights

### A complete gamepad-first redesign
The whole UI was redesigned from a Claude Design prototype and implemented faithfully in Qt6/QML
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
- **In-app updates with channels** — pick **Stable / Beta / Alpha** in Settings → Advanced →
  "Software updates", check for updates on demand, and update the AppImage **in place with one
  tap** (keeps a `.old` rollback next to it); builds now self-report their exact version.
- Tailscale-first **remote play** (one-command setup + in-app help).
- **SteamOS one-click integration** (guided setup, add-to-Steam helpers, self-update).
- Bounded **auto-reconnect** on stream drop, **per-game stream profiles**, **settings export/import**,
  battery-saver bitrate, a compact performance overlay, and `vibemis selftest` for CI/on-device tests.

### Polished for 0.1.0.0 (three hands-on device passes)
Every defect from the maintainer's on-device passes, fixed across three waves — including a
**Quick Menu visual redesign** onto the app's design system (line-glyph icons, token colors,
hint-bar footer — no more emoji), settings that survive a stream (a use-after-free of the shared
preferences object after disconnects was found and fixed), and touch-overlay taps that land
correctly under Gamescope scaling:
- **Settings pickers show their full text** (root-cause fix covering all 13 dropdowns) and the
  Settings page has true 2-D gamepad navigation with a single, always-visible selection ring —
  including d-pad Up at the top of a pane returning to the correct sidebar category.
- **The window actually fills the handheld screen** (1920×1200) and app-grid tiles keep their
  cover-art aspect ratio; focus halos are flush with card corners and never overlap row text.
- **Quick Menu**: d-pad auto-repeat scrolling, left-stick navigation, a roomier selector — and
  **"Quit game" now returns you to Vibemis** (game ends on the host; start another session
  without relaunching the app).
- **Back paddles work out of the box**: on paddle-equipped controllers (Legion Go, Xbox
  Elite, …) the P1 paddle opens the Quick Menu with zero setup.
- **Apollo/Vibepollo wording**: the streaming-enhancement settings now correctly say they work
  with **Vibepollo** hosts too (they always did — the labels claimed Apollo-only).
- **"Add a computer" is d-pad reachable**: Right/Down past the last host card selects it, Ⓐ
  opens the dialog (plus the Ⓨ shortcut as before) — with the freeze-proof focus model.
- **Home grid** focus hardening (no more freeze when focus enters the grid).
- **Help screen** is focusable, scrollable, and correctly scaled; Ⓑ/Back work everywhere.
- **Self-updater proven end-to-end**: a new hidden `vibemis update-selftest` command exercises
  the real check→download→swap path (used as a release gate), and the update script now finds
  your install wherever it lives instead of assuming one folder.

### Hardened (the launch-blocker wave, on-device validated)
- **Input latency fixed** — three compounding launcher stalls removed (background-poll log flood,
  a software-blur repaint on card focus, and a focus hand-off gap).
- **In-stream Quick Menu overhaul** — fills the stream window (was a tiny fixed box), no text
  cutoff, toast no longer overlaps items, and quitting from it exits cleanly (crash fixed).
- **Settings redesigned end-to-end** — all five categories on the dark design system, d-pad
  in/out of the sidebar, visible focus highlights, picker text fits.
- **Live host telemetry** — cards show a real measured "N ms" probe RTT and an offline
  "Last seen …" time.
- **Add-a-computer card** — hoverable, focusable, fully gamepad-reachable (auto-scrolls into view).
- **Opt-in on-screen touch controls** (MENU / text-send buttons composited into the stream).
- Update banner only offers stable releases; partial host rows align with the screen padding.

### Known limitations (shipped honestly)
- **HDR streaming is Experimental**: opt-in, off by default, auto-disabled on unsupported PCs.
  Code-complete but not yet validated on HDR hardware (the test device's panel is SDR);
  hardware validation planned via an external HDR display.
- **Microphone passthrough** is not possible client-side yet — needs Apollo host protocol
  support (upstream discussion #591).

## Install
Download the `.AppImage` from the release, make it executable, and double-click — or in SteamOS
Desktop Mode, right-click the AppImage → **Add to Steam**, then launch from Game Mode. Full steps in
the README.

## Notes
- Built from source under GPL-3.0; hardware-decode (VAAPI/VDPAU/NVDEC), H.264/HEVC/AV1, HDR, 7.1 audio.
- The in-stream Quick Menu opens with `Select + L1 + R1 + Y` (gamepad) or `Ctrl+Alt+Shift+\` (keyboard).

_Full commit history: the 0.6.x → 1.0.x → 0.1.0.0 development series on `vibemis-main`._
