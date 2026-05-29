# Vibemis

**Vibemis** is a Linux-first game streaming client built on top of [Artemis Qt](https://github.com/wjbeckett/artemis) by [wjbeckett](https://github.com/wjbeckett), tuned to pair with [Vibepollo](https://github.com/navyas321/Vibepollo) as its host. It targets desktop Linux, Steam Deck, and Linux handhelds (tested on the Lenovo Legion Go S Z2 under SteamOS), and ships as an AppImage.

Vibemis inherits all of Artemis Qt's Apollo-protocol client features — clipboard sync, server commands, OTP pairing, virtual display toggle, Quick Menu, fractional refresh rates, resolution scaling, UUID-based app launching, and a permissions viewer — then adds Linux-specific polish and Vibepollo-aware fixes on top.

> **Compatibility:** Vibemis works with Vibepollo, Apollo, and vanilla Sunshine hosts. Apollo-only features (clipboard sync, server commands, virtual display, OTP) light up automatically when connected to a compatible host and are hidden when not applicable.

---

## Features

### Inherited from Moonlight Qt

- Hardware-accelerated video decoding (VAAPI, VDPAU, NVDEC, CUDA)
- H.264, HEVC, and AV1 codec support (AV1 requires Sunshine/Apollo host + supported GPU)
- YUV 4:4:4 chroma support (Sunshine/Apollo only)
- HDR streaming support
- 7.1 surround sound audio
- 10-point multitouch (Sunshine/Apollo only)
- Gamepad support with force feedback and motion controls, up to 16 players
- Pointer capture mode (games) and direct mouse mode (remote desktop)
- System-wide keyboard shortcut passthrough (Alt+Tab, etc.)

### Inherited from Artemis Qt

- **Clipboard Sync** — bidirectional clipboard between client and host
- **Server Commands** — trigger custom commands on the Apollo/Vibepollo host
- **OTP Pairing** — one-time-password pairing for enhanced security
- **Quick Menu** — in-stream overlay for controls without leaving your game
- **Fractional Refresh Rates** — client-side custom refresh (e.g. 90 Hz, 120 Hz)
- **Resolution Scaling** — client-side scale factor for performance tuning
- **Virtual Display Control** — choose whether to request a virtual display on the host
- **UUID-Based App Launching** — modern app identification with automatic fallback to legacy IDs
- **Permissions Viewer** — inspect host-side client permissions from within the app

### Added by Vibemis

- **HDR display capability gate** — "My display supports HDR" toggle prevents the app from requesting HDR from the host when your client display is SDR, eliminating the washed-out/dim picture that occurs when host HDR is applied but the client has no HDR-capable output
- **VAAPI driver path fix** — AppImage apprun-hook that sets `LIBVA_DRIVERS_PATH` to the host's DRI directory and surgically loads the host's `libva.so.2` (via a temp-dir symlink), bridging the ABI gap between the bundled libva 1.20 and modern Mesa drivers that only export `__vaDriverInit_1_22`
- **FORCE_VAAPI apprun hook** — prevents the upstream Gallium VAAPI deprioritisation that would otherwise fall through to `hevc_cuvid` and crash on non-NVIDIA hardware
- **EGL shader fix** — corrects a missing vertex shader reference that caused a black screen on AMD/Mesa hardware after the VAAPI fix exposed the EGLRenderer path
- **Vibepollo-aware OTP pairing** — standard Moonlight pairing flow with a 120-second timeout; the dialog generates a PIN, shows it prominently, and waits for the user to submit it in Vibepollo's "Pair Client" web form. No web UI credentials required.
- **Persistent client identity** — `uniqueid` generated once and stored in settings, so the paired client certificate remains valid across app restarts (no 403 after relaunch)
- **Clipboard SSL fix** — VerifyNone for clipboard HTTPS endpoints (Vibepollo cert is issued to hostname, not IP; peer already trusted via pairing cert)
- **Clipboard auth params** — `uniqueid` and `uuid` included in clipboard requests so Vibepollo accepts them
- **Upstream moonlight-qt sync** — merged with `moonlight-stream/moonlight-qt:master` (May 2026), bringing in nine months of upstream fixes while preserving all Apollo extensions

---

## Keyboard and Gamepad Shortcuts

### Quick Menu

| Input | Shortcut |
|-------|----------|
| Keyboard | `Ctrl + Alt + Shift + \` |
| Gamepad | `Select + L1 + R1 + Y` |

### Full Keyboard Reference

All shortcuts require the `Ctrl + Alt + Shift` prefix:

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

| Issue | Workaround | Status |
|---|---|---|
| **Quick Menu not visible in Game Mode (Gamescope)** | Use Desktop Mode, or use keyboard shortcuts directly | In progress — P3.1 SDL overlay rearchitecture |
| **Quick Menu buttons not interactable with gamepad in Game Mode** | Use keyboard shortcuts | Same as above |
| **Server Commands accessible only via Quick Menu** | Once Quick Menu works in Game Mode, Bubbles and other commands will be available | Blocked on P3.1 |
| **Steam library shows "Vibemis App Image" instead of "Vibemis"** | Rename the shortcut manually in Steam → Properties | P3.2 investigation |
| **ENet drops in Desktop Mode** | Environmental — occurs with weak LAN signal in Desktop Mode; Game Mode typically more stable | Network quality issue, not app bug |

---

## Downloads

Vibemis ships as a prebuilt AppImage. Three release tiers:

| Tier | Source | Prerelease | Use for |
|---|---|---|---|
| 🔬 **Alpha** | `fix/**` branches | Yes | Targeted test cycles before merging |
| 🧪 **Beta** | `vibemis-main` | No — shown as **latest** | Regular use; current recommended build |
| ✅ **Release** | `release/**` or manual trigger | No | Explicitly verified milestones |

**Download the latest beta:** [GitHub Releases](https://github.com/navyas321/vibemis/releases/latest)

The AppImage runs on any x86-64 Linux with glibc 2.17+ — no installation required. On SteamOS / Steam Deck, run from Desktop Mode or add as a non-Steam game.

---

## Building from Source

Vibemis builds on Linux (Ubuntu 22.04+, Fedora 38+, SteamOS Desktop Mode, or WSL2).

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

The AppImage build uses [linuxdeploy](https://github.com/linuxdeploy/linuxdeploy) (not linuxdeployqt — incompatible with glibc ≥ 2.36):

```bash
# Ensure linuxdeploy-x86_64.AppImage is in your PATH, then:
bash scripts/build-appimage.sh
# Output: build/installer-release/Vibemis-<version>-x86_64.AppImage
```

---

## Attribution

Vibemis is built on the shoulders of several excellent projects:

- **[Artemis Qt](https://github.com/wjbeckett/artemis)** by [wjbeckett](https://github.com/wjbeckett) — the C++/QML desktop port of the Artemis-Android Apollo extensions that forms the direct base of Vibemis.
- **[Moonlight Qt](https://github.com/moonlight-stream/moonlight-qt)** by the [Moonlight Team](https://github.com/moonlight-stream) — the upstream streaming client whose core decode/network/input pipeline everything builds on.
- **[Apollo](https://github.com/ClassicOldSong/Apollo)** and **[Vibemis Android](https://github.com/ClassicOldSong/moonlight-android)** by [ClassicOldSong](https://github.com/ClassicOldSong) — the Sunshine fork and Android client whose protocol extensions Vibemis speaks.
- **[Sunshine](https://github.com/LizardByte/Sunshine)** by [LizardByte](https://github.com/LizardByte) — the original open-source game streaming server.
- **[moonlight-common-c](https://github.com/ClassicOldSong/moonlight-common-c)** (ClassicOldSong's Apollo-lineage fork) — the protocol/codec library submodule.
- **[Vibepollo](https://github.com/navyas321/Vibepollo)** by [Nonary](https://github.com/Nonary) — the Apollo fork this client is tuned to pair with.

---

## License

GPL v3 — see [LICENSE](LICENSE).
