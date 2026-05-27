# Vibemis — Development Notes

> The full workflow SOP (keyword shortcuts, test cycle process, PR format) is in [WORKFLOW.md](WORKFLOW.md).
> The project phase roadmap and user decisions are in `C:\Users\navya\.claude\plans\pure-purring-pillow.md` (build host local).

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
├── testing/                # In-repo test cycle handoff
│   └── <task>/
│       ├── instructions.md # Written by build agent, read by test agent
│       ├── report.md       # Written by test agent, read by build agent
│       └── *.AppImage      # Tracked artifact (unignored via !testing/**/*.AppImage)
├── docs/
│   ├── WORKFLOW.md         # SOP — keyword shortcuts, PR format, test cycle
│   ├── BUILD_SYSTEM.md     # Build environment, AppImage, submodule notes
│   └── DEVELOPMENT.md      # This file — project structure, key files
├── CLAUDE.md               # Session orientation for Claude agents
└── README.md               # User-facing project README
```

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
| `app/gui/SettingsView.qml` | Settings screen. Contains the `displayHdrCapability` checkbox added in Phase 2 #13. |
| `app/gui/QuickMenu.qml` | In-stream Quick Menu overlay (9 actions). |

### Build

| File | What it does |
|------|-------------|
| `artemis.pro` | Top-level qmake project file. |
| `moonlight-common-c/moonlight-common-c.pro` | Wrapper `.pro` for the submodule. Key fix: `SOURCES` uses `reedsolomon/rs.c` (not upstream's `src/rswrapper.c`); `INCLUDEPATH` uses `reedsolomon/` (not upstream's `nanors/`). |
| `scripts/build-appimage.sh` | AppImage build. Contains the apprun-hook for LIBVA_DRIVERS_PATH + surgical libva symlink. |

### App identity

| File | What it does |
|------|-------------|
| `app/main.cpp` | `setOrganizationName("Vibemis Project")`, `setApplicationName("Vibemis")`. Sets QSettings path to `~/.config/Vibemis Project/Vibemis.conf`. |
| `app/version.txt` | Current semver (`0.6.7`). |

## Phase 2 issues tracker

| # | Issue | Status | Branch / PR |
|---|-------|--------|-------------|
| #11 | VAAPI — "No functioning hardware accelerated video decoder" on SteamOS | In progress (test5 pending) | `fix/appimage-vaapi-driver-paths` (PR #4) |
| #12 | Controller input not working over stream | Pending — likely Vibepollo permissions; need user to verify in Vibepollo UI | — |
| #13 | HDR applied on SDR display | Fixed | `fix/hdr-display-capability-gate` (PR #5) |

## Vibemis vs upstream diff highlights

### vs Artemis Qt (`wjbeckett/artemis develop`)
- Upstream moonlight-qt sync (Phase 1.5 merge, May 2026)
- `displayHdrCapability` preference + `effectiveHdr` gate in session.cpp (Phase 2 #13)
- AppImage apprun-hook: LIBVA_DRIVERS_PATH + surgical libva symlink (Phase 2 #11)
- `moonlight-common-c.pro`: uses `reedsolomon/rs.c` not `src/rswrapper.c`

### vs moonlight-stream/moonlight-qt master
- Entire `app/streaming/` subtree kept on wjbeckett's API surface (session.h/cpp, all renderers). Upstream's renamed fields (`totalDecodeTimeUs`, etc.) and new APIs (`LiSendControllerTouchEvent2`, `LiGetMicroseconds`) are NOT present — don't use them in new code without first checking ClassicOldSong's submodule.
- No upstream `.github/workflows/` (removed to avoid push permission errors)
