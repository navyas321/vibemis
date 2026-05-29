# Vibemis

**Vibemis** is the only actively maintained Linux client for the [Apollo](https://github.com/ClassicOldSong/Apollo) / [Vibepollo](https://github.com/navyas321/Vibepollo) game streaming ecosystem. There is no official Artemis client for Linux — [wjbeckett's Artemis Qt](https://github.com/wjbeckett/artemis) has been dormant since August 2025 with a broken AppImage build on current Mesa/glibc, and a native Apollo Linux client ([Apollo issue #937](https://github.com/ClassicOldSong/Apollo/issues/937)) remains in development and unreleased. Vibemis fills that gap — forked from Artemis Qt, running on current SteamOS/Mesa/AMD hardware today.

## Why Vibemis?

Standard Moonlight doesn't support Apollo's extended protocol features. Apollo and Vibepollo add clipboard sync, server command execution, OTP pairing, virtual display control, an in-stream Quick Menu, and per-client permission management — but without a working Linux client, those features were inaccessible on SteamOS and Linux handhelds.

- **The only working Linux client for Apollo** — fills the gap left by dormant Artemis Qt
- **Works on current SteamOS** — VAAPI/Mesa compatibility fixes for AMD hardware (tested on the Lenovo Legion Go S Z2)
- **Tuned for Vibepollo** — pairing flow, clipboard auth, and SSL handling built for Vibepollo specifically
- **Kept current** — merged with upstream moonlight-qt (May 2026), CI pipeline on every push

> **Compatibility:** Vibemis works with Vibepollo, Apollo, and vanilla Sunshine hosts. Apollo-only features light up automatically when connected to a compatible host.

---

## Installation

### Quick start (recommended)

1. Download the latest AppImage from **[GitHub Releases](https://github.com/navyas321/vibemis/releases/latest)**
2. Make it executable and run:
   ```bash
   chmod +x Vibemis-*.AppImage
   ./Vibemis-*.AppImage
   ```
   That's it — no installation required, no dependencies to install.

### Add to Steam (SteamOS / Steam Deck)

To launch Vibemis from Game Mode:

1. In **Desktop Mode**, right-click the AppImage and select **Add to Steam**
2. Open the shortcut's **Properties** and set the name to `Vibemis`
3. Switch to Game Mode — Vibemis will appear in your library under Non-Steam Games

> **Note:** Quick Menu is currently only functional in Desktop Mode. Game Mode (Gamescope) support is in active development (P3.1).

---

## Features

### From Moonlight Qt

- Hardware-accelerated video decoding (VAAPI, VDPAU, NVDEC, CUDA)
- H.264, HEVC, and AV1 codec support
- YUV 4:4:4 chroma, HDR streaming, 7.1 surround sound
- 10-point multitouch, gamepad with force feedback and motion controls (up to 16 players)
- Pointer capture / direct mouse mode, system-wide keyboard shortcut passthrough

### From Artemis Qt (Apollo protocol features)

- **Clipboard Sync** — bidirectional clipboard between client and host
- **Server Commands** — trigger custom commands on the Apollo/Vibepollo host
- **OTP Pairing** — secure pairing via Vibepollo's "Pair Client" web UI
- **Quick Menu** — in-stream overlay for clipboard, commands, and stream controls
- **Fractional Refresh Rates** — client-side custom refresh (e.g. 90 Hz, 120 Hz)
- **Resolution Scaling** — client-side scale factor for performance tuning
- **Virtual Display Control** — request a virtual display on the host
- **UUID-Based App Launching** — modern app identification with legacy fallback
- **Permissions Viewer** — inspect host-side client permissions from the app

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
| `Start + Select + L1 + R1` | Quit stream |
| `Select + L1 + R1 + X` | Toggle performance stats overlay |
| Long press `Start` | Toggle mouse emulation mode |

---

## Known Issues

| Issue | Workaround | Planned fix |
|---|---|---|
| **Quick Menu not visible in Game Mode (Gamescope)** | Use keyboard shortcuts directly; or Desktop Mode | P3.1 — SDL overlay rearchitecture |
| **Server Commands only reachable via Quick Menu** | — | Unblocked by P3.1 |
| **Steam library shows app name with "AppImage"** | Rename shortcut in Steam → Properties | P3.2 |

---

## Downloads

| Tier | When | Use |
|---|---|---|
| 🔬 **Alpha** | Every push to a `fix/**` or `feat/**` branch | Test cycles during development |
| 🧪 **Beta** | Every merge to `vibemis-main` | Regular use — current recommended build |
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

- **[Artemis Qt](https://github.com/wjbeckett/artemis)** by [wjbeckett](https://github.com/wjbeckett) — the C++/QML desktop port of the Apollo extensions that Vibemis is forked from
- **[Artemis Android](https://github.com/MobinYengejehi/Artemis)** by [MobinYengejehi](https://github.com/MobinYengejehi) — Android Apollo client whose features serve as a reference for Vibemis
- **[Moonlight Qt](https://github.com/moonlight-stream/moonlight-qt)** by the [Moonlight Team](https://github.com/moonlight-stream) — the upstream streaming client this is built on
- **[Apollo](https://github.com/ClassicOldSong/Apollo)** and **[Artemis Android](https://github.com/ClassicOldSong/moonlight-android)** by [ClassicOldSong](https://github.com/ClassicOldSong) — the Sunshine fork and Android client whose protocol extensions this client speaks
- **[Sunshine](https://github.com/LizardByte/Sunshine)** by [LizardByte](https://github.com/LizardByte) — the original open-source game streaming server
- **[moonlight-common-c](https://github.com/ClassicOldSong/moonlight-common-c)** (ClassicOldSong's Apollo-lineage fork) — the protocol/codec library submodule
- **[Vibepollo](https://github.com/navyas321/Vibepollo)** by [Nonary](https://github.com/Nonary) — the Apollo fork this client is tuned to pair with

---

## License

GPL v3 — see [LICENSE](LICENSE).
