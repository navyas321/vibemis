# Vibemis

**Vibemis** is a gamepad-first, actively-maintained game-streaming **client** for **SteamOS** and Linux handhelds. It takes the best of both sides of the Moonlight/Artemis world — [Moonlight Qt](https://github.com/moonlight-stream/moonlight-qt)'s solid Linux/handheld foundation and [Artemis](https://github.com/MobinYengejehi/Artemis)'s support for **Apollo**'s extended protocol — and pairs with **[Vibepollo](https://github.com/navyas321/Vibepollo)**, its host-side counterpart. Set up Vibepollo on your gaming PC, run Vibemis on your handheld, pair, and stream.

**Built for SteamOS.** The primary target is SteamOS Game Mode (Gamescope) on AMD handhelds; every release is hardware-verified on a **Lenovo Legion Go S Z2** test device before it ships. It runs on any modern Linux desktop too.

## Why Vibemis? (the best of both worlds)

Streaming clients in this world come in two flavors, and until now you couldn't get both on a Linux handheld:

- **[Moonlight Qt](https://github.com/moonlight-stream/moonlight-qt)** is the mainline open-source Qt **client** for PCs and handhelds — rock-solid and actively maintained — **but it speaks only the base GameStream/Sunshine protocol.** The extras that [Apollo](https://github.com/ClassicOldSong/Apollo) / Vibepollo hosts add (clipboard sync, server commands, OTP pairing, virtual display control, an in-stream Quick Menu, per-client permissions) simply don't work through it.
- **[Artemis](https://github.com/MobinYengejehi/Artemis)** ("Moonlight Noir") is the **client** family that *does* speak those Apollo extensions. **Artemis for Android is active**, but the **desktop/Linux** build — [wjbeckett/artemis](https://github.com/wjbeckett/artemis), which Vibemis is forked from — **went dormant (Aug 2025)** with an AppImage that no longer builds on current Mesa/glibc. That left **no maintained Linux/handheld client with the Apollo features.**

**Vibemis takes the best of both:** Moonlight Qt's current, well-supported Linux/handheld base **plus** the Apollo-protocol features from the Artemis lineage — actively maintained, fixed for current SteamOS/Mesa/AMD, gamepad-first, and tuned for the Vibepollo host.

- **The Apollo features, on a maintained Linux handheld** — clipboard sync, server commands, OTP pairing, virtual display, in-stream Quick Menu, and per-client permissions, all surfaced on-device
- **Works on current SteamOS** — VAAPI/Mesa compatibility fixes for AMD hardware; every cycle is verified on the Lenovo Legion Go S Z2 (including nested-Gamescope "Game Mode" runs)
- **Tuned for Vibepollo** — pairing flow, clipboard auth, and SSL handling built for the Vibepollo host specifically
- **Kept current** — merged with upstream moonlight-qt (May 2026), CI pipeline on every push

> **Clients vs. hosts:** Vibemis, Moonlight Qt, and Artemis are **clients** (they run on your handheld/PC). They pair with a **host** on your gaming PC: **Vibepollo** (the counterpart Vibemis is tuned for), [Apollo](https://github.com/ClassicOldSong/Apollo), or vanilla [Sunshine](https://github.com/LizardByte/Sunshine). Apollo/Vibepollo are Sunshine-lineage hosts; their extended features light up automatically when the host supports them.

---

## Installation

No building, no installer, no dependencies. Vibemis is a single self-contained file —
**download it and double-click it.**

### Easiest way (Steam Deck / SteamOS)

1. **Switch to Desktop Mode.** (Hold the **power button** → **Switch to Desktop**.)
2. Open a web browser and go to the **[Releases page](https://github.com/navyas321/vibemis/releases/latest)**.
   Download the latest **`.AppImage`** file (either a *Release* or the latest *Pre-release* —
   both work; the newest one is fine).
3. Find the downloaded file (usually in your **Downloads** folder) and **double-click it** to run.
   - If double-clicking does nothing, right-click the file → **Properties** → **Permissions**
     → tick **"Is executable"** (or *"Allow executing file as program"*), then double-click again.

That's it — Vibemis opens and you can add your host PC.

> **If it still won't open** and you see a **FUSE** error (common on SteamOS, which doesn't
> ship `libfuse2`), open a terminal in the file's folder and run it in extract mode — no
> installation needed:
> ```bash
> ./Vibemis-*.AppImage --appimage-extract-and-run
> ```

### Any other Linux

Same idea: download the latest `.AppImage` from
**[Releases](https://github.com/navyas321/vibemis/releases/latest)**, make it executable
(right-click → Properties → *"Allow executing as program"*, or `chmod +x Vibemis-*.AppImage`),
then double-click or run `./Vibemis-*.AppImage`.

### Add to Steam (SteamOS / Steam Deck)

To launch Vibemis from Game Mode:

Easiest: run `scripts/install-vibemis-desktop.sh` from a Desktop Mode terminal — it installs the
AppImage to a stable path with a clean `Vibemis` desktop entry, ready to Add to Steam. Or manually:

1. In **Desktop Mode**, right-click the AppImage and select **Add to Steam**
2. Open the shortcut's **Properties** and set the name to `Vibemis`
3. Switch to Game Mode — Vibemis appears in your library under Non-Steam Games

> The in-stream **Quick Menu works in Game Mode**: it is composited into the stream itself
> (OverlayManager surface), so it renders identically under Gamescope and on the desktop. Open it
> with `Select + L1 + R1 + Y`; close with **B**, **Back/Select**, or **Start** ("Resume Game").

---

## Features

### From Moonlight Qt

- Hardware-accelerated video decoding (VAAPI, VDPAU, NVDEC, CUDA)
- H.264, HEVC, and AV1 codec support
- YUV 4:4:4 chroma, HDR streaming, 7.1 surround sound
- 10-point multitouch, gamepad with force feedback and motion controls (up to 16 players)
- Pointer capture / direct mouse mode, system-wide keyboard shortcut passthrough

### From Artemis / Apollo (extended protocol features)

- **Clipboard Sync** — bidirectional clipboard between client and host
- **Server Commands** — trigger custom commands on the Apollo/Vibepollo host
- **OTP Pairing** — secure pairing via Vibepollo's "Pair Client" web UI
- **Quick Menu** — in-stream overlay for clipboard, commands, and stream controls
- **Fractional Refresh Rates** — client-side custom refresh (e.g. 90 Hz, 120 Hz)
- **Resolution Scaling** — client-side scale factor for performance tuning
- **Virtual Display Control** — request a virtual display on the host
- **UUID-Based App Launching** — modern app identification with legacy fallback
- **Permissions Viewer** — inspect host-side client permissions from the app

### Added by Vibemis

- **Game Mode Quick Menu** — the in-stream menu is rendered offscreen and composited into the
  video (works under Gamescope, not just the desktop), with full gamepad navigation and a
  discoverable "Resume Game" exit (B / Back / Start)
- **Tailscale-first remote play** — one-command `scripts/setup-tailscale.sh`, an in-app setup
  button, and automatic preference for tailnet addresses when reaching a host
- **SteamOS one-click integration** — `scripts/vibemis-setup.sh` guided setup (doctor → update →
  install → pair → add games to Steam), plus per-script helpers and a self-update command
- **Settings export / import** — portable `.ini` backup of the full configuration
- **Performance overlay controls** — corner anchoring, text size, optional wall clock, and a
  data-usage estimate next to the bitrate slider
- **Handheld quality-of-life** — battery-saver bitrate, controller-rumble suppression, motion
  (gyro) capability detection, host software version & per-client permission surfacing, AV1 and
  native-resolution guidance, HDR display-capability gate
- **`vibemis selftest`** — headless smoke test used by CI and the on-device test harness
- **Per-game stream profiles** — save resolution/FPS/bitrate/HDR per game from the app tile's
  context menu; the profile applies automatically at launch without touching global settings
- **Auto-reconnect** *(opt-in)* — a dropped stream retries in place (3 attempts with backoff)
  instead of dumping you back to the game grid
- **Gamepad-first redesign** *(rolling out)* — a unified dark design-token system (one
  accent/surface/type language) with controller-first layouts, live across the Computers list,
  app grid, Add-PC dialog, and in-stream Help

---

## Remote Play (over the internet)

Vibemis streams over your LAN out of the box. To stream when the client and host are on
**different networks** — without port forwarding or exposing your host to the internet — put
both devices on the same [Tailscale](https://tailscale.com) network. Tailscale is free for
personal use, end-to-end encrypted (WireGuard), and handles NAT traversal automatically.

1. **On the host** (the PC running Vibepollo/Apollo/Sunshine): install Tailscale and sign in.
2. **On the client** (Steam Deck / handheld running Vibemis): install Tailscale and sign in
   with the same account. On SteamOS, Tailscale is available as a Flatpak or via the static
   binary.
3. In Vibemis, **add the host by its Tailscale address** — either its `100.x.x.x` IP or its
   MagicDNS name (`hostname.your-tailnet.ts.net`). Pair and stream exactly as you would on
   the LAN.

> **Notes**
> - No Vibemis configuration is required beyond using the Tailscale address as the host.
> - For best latency, Tailscale will establish a direct peer-to-peer path when possible and
>   fall back to an encrypted relay (DERP) otherwise. Expect LAN-class latency on a direct
>   path; relayed paths add some overhead.
> - The host's streaming ports do **not** need to be forwarded — Tailscale carries the
>   traffic over the encrypted tunnel.

---

## Keyboard and Gamepad Shortcuts

### Quick Menu

| Input | Shortcut |
|-------|----------|
| Keyboard | `Ctrl + Alt + Shift + \` |
| Gamepad | `Select + L1 + R1 + Y` |

### Full Keyboard Reference

All shortcuts require `Ctrl + Alt + Shift`:

| Key | Action |
|-----|--------|
| `\` | Toggle Quick Menu |
| `Q` | Quit stream |
| `E` | Quit stream and exit app |
| `S` | Toggle performance stats overlay |
| `X` | Toggle fullscreen |
| `M` | Toggle mouse capture |
| `Z` | Toggle input capture |
| `C` | Toggle cursor visibility |
| `V` | Paste clipboard text |
| `L` | Toggle pointer region lock |
| `D` | Minimize window |

### Gamepad Reference

| Combo | Action |
|-------|--------|
| `Select + L1 + R1 + Y` | Toggle Quick Menu |
| D-pad / `A` (while menu open) | Navigate / activate menu item |
| `B`, `Back/Select`, or `Start` (while menu open) | Close menu / resume game |
| `Start + Select + L1 + R1` | Quit stream |
| `Select + L1 + R1 + X` | Toggle performance stats overlay |
| Long press `Start` | Toggle mouse emulation mode |

---

## Downloads

Each release ships a single **`.AppImage`** — download and double-click; nothing to extract.

| Tier | When | Use |
|---|---|---|
| 🔬 **Alpha** | Every push to a `test<N>-*` feature branch | Hardware test cycles during development |
| 🧪 **Beta** | Every PR merged into `vibemis-main` | Regular use — current recommended build |
| ✅ **Release** | Explicit milestone | Verified stable |

**[→ Download latest beta](https://github.com/navyas321/vibemis/releases/latest)**

---

## Building from Source

For development or debugging only. No need to build to use Vibemis — just download the AppImage above.

### Dependencies

**Ubuntu / Debian:**
```bash
sudo apt install \
  qt6-base-dev qt6-declarative-dev libqt6svg6-dev \
  qml6-module-qtquick-controls qml6-module-qtquick-templates \
  qml6-module-qtquick-layouts \
  libegl1-mesa-dev libgl1-mesa-dev \
  libopus-dev libsdl2-dev libsdl2-ttf-dev libssl-dev \
  libavcodec-dev libavformat-dev libswscale-dev \
  libva-dev libvdpau-dev \
  libxkbcommon-dev wayland-protocols libdrm-dev
```

**Fedora / RHEL:**
```bash
sudo dnf install \
  qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtsvg-devel \
  openssl-devel SDL2-devel SDL2_ttf-devel ffmpeg-devel \
  libva-devel libvdpau-devel opus-devel \
  pulseaudio-libs-devel alsa-lib-devel libdrm-devel
```

### Build

```bash
git clone --recurse-submodules https://github.com/navyas321/vibemis.git
cd vibemis
qmake6 vibemis.pro CONFIG+=release
make -j$(nproc)
./app/vibemis
```

### AppImage

```bash
# Requires linuxdeploy-x86_64.AppImage in PATH
bash scripts/build-appimage.sh
# Output: build/installer-release/Vibemis-<version>-x86_64.AppImage
```

---

## Attribution

- **[Artemis (desktop / "Moonlight Noir")](https://github.com/wjbeckett/artemis)** by [wjbeckett](https://github.com/wjbeckett) — the C++/QML desktop client (a Moonlight-Qt-lineage build that speaks Apollo's extensions) that Vibemis is forked from; now dormant
- **[Artemis Android](https://github.com/MobinYengejehi/Artemis)** by [MobinYengejehi](https://github.com/MobinYengejehi) — Android Apollo client whose features serve as a reference for Vibemis
- **[Moonlight Qt](https://github.com/moonlight-stream/moonlight-qt)** by the [Moonlight Team](https://github.com/moonlight-stream) — the upstream streaming client this is built on
- **[Apollo](https://github.com/ClassicOldSong/Apollo)** and **[Artemis Android](https://github.com/ClassicOldSong/moonlight-android)** by [ClassicOldSong](https://github.com/ClassicOldSong) — the Sunshine fork and Android client whose protocol extensions this client speaks
- **[Sunshine](https://github.com/LizardByte/Sunshine)** by [LizardByte](https://github.com/LizardByte) — the original open-source game streaming server
- **[moonlight-common-c](https://github.com/ClassicOldSong/moonlight-common-c)** (ClassicOldSong's Apollo-lineage fork) — the protocol/codec library submodule
- **[Vibepollo](https://github.com/navyas321/Vibepollo)** — the Apollo/Sunshine-lineage **host** Vibemis is built to pair with (the counterpart to this client)

---

## License

GPL v3 — see [LICENSE](LICENSE).
