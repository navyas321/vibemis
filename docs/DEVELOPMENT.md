# Vibemis — Development Notes

> Contributing conventions (commit format, PR test scorecard) are in [CONTRIBUTING.md](../CONTRIBUTING.md).

## Project structure

```
vibemis/
├── app/                    # Main application (C++/QML)
│   ├── backend/            # NvHTTP, streaming manager, clipboard, OTP, etc.
│   ├── gui/                # QML UI files (SettingsView.qml, QuickMenu.qml, etc.)
│   ├── settings/           # StreamingPreferences (streamingpreferences.h/.cpp)
│   ├── streaming/          # Session, video pipeline, renderers (session.cpp, etc.)
│   └── deploy/linux/       # .desktop file, .appdata.xml
├── moonlight-common-c/     # Submodule — ClassicOldSong Apollo-lineage fork
├── qmdnsengine/            # Submodule — mDNS discovery
├── scripts/
│   └── build-appimage.sh   # AppImage bundler (linuxdeploy-based)
├── docs/
│   ├── BUILD_SYSTEM.md     # Build environment, AppImage, submodule notes
│   ├── RELEASING.md        # Versioning, CI release tiers, AppImage pipeline
│   ├── SELFTEST.md         # Scriptable self-test / verification surfaces
│   └── DEVELOPMENT.md      # This file — project structure, key files
├── CONTRIBUTING.md         # Commit format, PR test scorecard
└── README.md               # User-facing project README
```

> Versioning and release policy are documented in [RELEASING.md](RELEASING.md); contribution
> conventions (commit format, PR test scorecard) are in [CONTRIBUTING.md](../CONTRIBUTING.md).

## Key source files

### Settings

| File | What it does |
|------|-------------|
| `app/settings/streamingpreferences.h` | All user preferences as Q_PROPERTYs. `enableHdr`, `displayHdrCapability` (Vibemis addition). |
| `app/settings/streamingpreferences.cpp` | `reload()` / `save()` with `QSettings`. Key: `SER_DISPLAY_HDR_CAPABILITY`. |

### Streaming session

| File | What it does |
|------|-------------|
| `app/streaming/session.cpp` | Session setup, codec negotiation. `effectiveHdr = enableHdr && displayHdrCapability` (Vibemis addition). |
| `app/streaming/session.h` | Session class declaration. |

### UI

| File | What it does |
|------|-------------|
| `app/gui/SettingsView.qml` | Settings screen. Contains the `displayHdrCapability` checkbox added in the HDR display-capability gate (PR #5). |
| `app/gui/QuickMenu.qml` | In-stream Quick Menu overlay (9 actions). |

### Build

| File | What it does |
|------|-------------|
| `vibemis.pro` | Top-level qmake project file. |
| `moonlight-common-c/moonlight-common-c.pro` | Wrapper `.pro` for the submodule. Key fix: `SOURCES` uses `reedsolomon/rs.c` (not upstream's `src/rswrapper.c`); `INCLUDEPATH` uses `reedsolomon/` (not upstream's `nanors/`). |
| `scripts/build-appimage.sh` | AppImage build. Contains the apprun-hook for LIBVA_DRIVERS_PATH + surgical libva symlink. |

### App identity

| File | What it does |
|------|-------------|
| `app/main.cpp` | `setOrganizationName("Vibemis Project")`, `setApplicationName("Vibemis")`. Sets QSettings path to `~/.config/Vibemis Project/Vibemis.conf`. |
| `app/version.txt` | Current semver (`0.6.7`). |

## Issues tracker

| # | Issue | Status | Branch / PR |
|---|-------|--------|-------------|
| #11 | VAAPI — "No functioning hardware accelerated video decoder" on SteamOS | Open | `fix/appimage-vaapi-driver-paths` (PR #4) |
| #12 | Controller input not working over stream | Open — likely a Vibepollo host permissions setting | — |
| #13 | HDR applied on SDR display | Fixed | `fix/hdr-display-capability-gate` (PR #5) |

## Vibemis vs upstream diff highlights

### vs Vibemis Qt (`wjbeckett/vibemis develop`)
- Upstream moonlight-qt sync (May 2026)
- `displayHdrCapability` preference + `effectiveHdr` gate in session.cpp (PR #5)
- AppImage apprun-hook: LIBVA_DRIVERS_PATH + surgical libva symlink (PR #4)
- `moonlight-common-c.pro`: uses `reedsolomon/rs.c` not `src/rswrapper.c`

### vs moonlight-stream/moonlight-qt master
- Entire `app/streaming/` subtree kept on wjbeckett's API surface (session.h/cpp, all renderers). Upstream's renamed fields (`totalDecodeTimeUs`, etc.) and new APIs (`LiSendControllerTouchEvent2`, `LiGetMicroseconds`) are NOT present — don't use them in new code without first checking ClassicOldSong's submodule.
- No upstream `.github/workflows/` (removed to avoid push permission errors)
