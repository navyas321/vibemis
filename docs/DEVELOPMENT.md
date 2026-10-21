# Vibemis: Development Notes

Where things live, and what is Vibemis-specific, for anyone changing the code. Build
setup is in [BUILD_SYSTEM.md](BUILD_SYSTEM.md); versioning and release policy are in
[RELEASING.md](RELEASING.md); upstream sync policy is in
[UPSTREAM-MERGE-STRATEGY.md](UPSTREAM-MERGE-STRATEGY.md).

## Project structure

```
vibemis/
├── app/
│   ├── backend/        # Host HTTP (nvhttp), pairing, computer/app models, updater,
│   │                   # Quick Menu, server commands, Steam shortcuts
│   ├── gui/            # QML UI (main.qml, PcView, AppView, SettingsView, QuickMenu, Vb* components)
│   ├── settings/       # StreamingPreferences (every user setting, persisted via QSettings)
│   ├── streaming/      # Session, input, audio (playback + microphone), video pipeline
│   └── deploy/linux/   # Desktop entry, AppStream metadata, AppImage patches
├── moonlight-common-c/ # Submodule: navyas321/moonlight-common-c @ vibemis-rtp-timestamp
├── qmdnsengine/        # Submodule: mDNS discovery
├── h264bitstream/      # Vendored from upstream moonlight-qt (SPS fix-ups); not a submodule
├── packaging/flatpak/  # Flatpak manifest (SteamOS sideload bundle; Flathub-ready)
├── scripts/            # Changelog generator, check-*-invariants.sh guards, install/update helpers
├── tests/              # Qt test suites (vrr, updater, bitrate, overlay, keyboard) + settings-ia audit
└── docs/
```

## Key source files

The files that carry Vibemis-specific behavior, by area. Upstream moonlight-qt files
that we have not changed are not listed.

| Area | Files | Notes |
|------|-------|-------|
| VRR pacing | `app/streaming/video/ffmpeg-renderers/pacer/` (`pacer.cpp`, `vrrpacingworker.cpp`, `vrr/vrrtimingcontroller.cpp`, `vrr/vrrtargetwaiter.cpp`) | Timing core vendored from Nonary `v6.1.0-vrr10` with local fixes; guarded by `scripts/check-vrr-invariants.sh` and `tests/vrr` |
| VRR qualification | `app/streaming/session.cpp` (decoder-time and pre-launch checks), `app/streaming/vrrratepolicy.cpp` | Decides whether a session runs VRR and whether to send `clientVrrRequested` |
| Vulkan presenter | `app/streaming/video/ffmpeg-renderers/plvk.cpp`, `vrrswapchainpolicy.h` | The active presenter on SteamOS handhelds |
| Self-updater | `app/backend/autoupdatechecker.cpp`, `appimageswap.cpp` | Channel-aware feed selection, SHA-256 check, atomic in-place AppImage swap; guarded by `scripts/check-updater-invariants.sh` |
| Bitrate rescue | `app/streaming/bitraterescuepolicy.cpp` | Detects a collapsed stream and retries at a lower bitrate |
| Microphone | `app/streaming/audio/capture/microphonecapture.cpp` | Negotiated mic stream to Vibepollo hosts |
| Keyboard | `app/streaming/input/keyboard.cpp`, `keyremotemap.h` | Local key to remote VK table, unit-tested in `tests/keyboard` |
| Quick Menu | `app/backend/quickmenumanager.cpp`, `app/gui/QuickMenu.qml` | In-stream overlay menu |
| Server commands | `app/backend/servercommandmanager.cpp`, `serverpermissions.cpp` | Apollo/Vibepollo host commands and permissions |
| Settings | `app/settings/streamingpreferences.cpp`, `app/gui/SettingsView.qml` | Settings are saved when the page closes, on channel change, and on quit |
| App identity | `app/main.cpp` | Organization "Vibemis Project", application "Vibemis"; settings live in `~/.config/Vibemis Project/Vibemis.conf` |
| Version | `app/version.txt` | The NEXT stable version; CI derives every alpha/beta/rc tag from it |

## Working with moonlight-common-c

The submodule is our fork (`navyas321/moonlight-common-c`, branch
`vibemis-rtp-timestamp`) of the ClassicOldSong/Apollo lineage, not
`moonlight-stream/moonlight-common-c`. Before using a protocol API, check that it exists in
`moonlight-common-c/moonlight-common-c/src/Limelight.h` at the pinned commit. Upstream
submodule bumps cannot be taken as-is; protocol fixes are cherry-picked onto our branch and
the submodule is re-pinned (see BUILD_SYSTEM.md).

`moonlight-common-c/moonlight-common-c.pro` builds the original `reedsolomon/rs.c` rather
than upstream's `src/rswrapper.c` / `nanors/`.

## Tests and guards

- **Invariants:** every `scripts/check-*-invariants.sh` runs in CI as one required job.
  Run them locally with `for s in scripts/check-*-invariants.sh; do bash "$s"; done`.
  Adding a guard is zero workflow change: add a new `check-<x>-invariants.sh`.
- **Qt test suites:** `tests/tests.pro` only descends into its suites when qmake gets
  `CONFIG+=tests`. CI builds each suite directly and runs `vrr`, `overlay`, `keyboard`,
  `updater` and `bitrate` in the required `Tests` job; a missing binary fails the job.
  `tests/settings-ia` holds the scripts and manifests from the one-off Settings IA audit.
- **On-device checks:** `vibemis selftest` and the log assertions in [SELFTEST.md](SELFTEST.md).
  CI green is not tested; every release candidate goes through an on-device pass.

Bugs and feature requests are tracked in [GitHub issues](https://github.com/navyas321/vibemis/issues).
