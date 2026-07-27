# Vibemis — Build System

> This file covers the Vibemis build environment.

## Build host

WSL2 Ubuntu 24.04 on Windows. Build tools:

| Tool | Version | Location |
|------|---------|----------|
| qmake6 | Qt 6.4.2 | `/usr/bin/qmake6` |
| make | system | `/usr/bin/make` |
| linuxdeploy | latest | `/usr/local/bin/linuxdeploy.AppImage` |
| linuxdeploy Qt plugin | latest | `/usr/local/bin/linuxdeploy-plugin-qt.AppImage` |
| gh (GitHub CLI) | system | `/usr/bin/gh` |

## Build commands

### Native binary (development / smoke test)

```bash
qmake6 vibemis.pro CONFIG+=release
make -j$(nproc) release
./app/vibemis   # smoke test
```

### AppImage (test / release)

```bash
bash scripts/build-appimage.sh
# Output: build/installer-release/Vibemis-<version>-x86_64.AppImage
```

The script:
1. Runs `qmake6 + make install` into a staging dir
2. Writes `apprun-hooks/01-libva-driver-paths.sh` (LIBVA_DRIVERS_PATH + surgical libva symlink fix)
3. Runs `linuxdeploy --plugin qt --output appimage`

### Disabled build options for AppImage

| Option | Why disabled |
|--------|-------------|
| `CONFIG+=disable-wayland` | linuxdeploy bundles libwayland-client; mixing with host libwayland-egl breaks EGL on X11 |
| `CONFIG+=disable-libdrm` | linuxdeploy doesn't bundle Qt EGLFS dependencies |
| `CONFIG+=disable-cuda` | AppImage targets portable install; VAAPI/VDPAU are the runtime decode path |

## Submodule notes

`moonlight-common-c/moonlight-common-c` points at **our own fork**,
[navyas321/moonlight-common-c](https://github.com/navyas321/moonlight-common-c) — which is itself
based on [ClassicOldSong's Apollo-lineage fork](https://github.com/ClassicOldSong/moonlight-common-c),
**not** `moonlight-stream/moonlight-common-c`. BL-2336 re-pointed `.gitmodules` from ClassicOldSong to
our fork so vibemis can carry fork-local commits (currently the raw 90 kHz RTP timestamp thread-through
for VRR pacing).

### Remote layout

`.gitmodules` is **canonical**. The checked-out submodule's remotes follow it:

| Remote | URL | Use |
| --- | --- | --- |
| `origin` | `navyas321/moonlight-common-c` | **The push target.** Matches `.gitmodules`, so it is what CI clones. |
| `upstream` | `ClassicOldSong/moonlight-common-c` | Fetch/merge only — the lineage the fork is based on. Never a push target. |

`.gitmodules` also records `branch = vibemis-rtp-timestamp`, so `git submodule update --remote`
resolves to the fork branch the parent pointer tracks instead of guessing a remote HEAD.

A fresh `git submodule update --init --recursive` gives you a correct `origin` automatically; add the
lineage yourself when you need to merge upstream work:

```sh
git -C moonlight-common-c/moonlight-common-c remote add upstream \
    https://github.com/ClassicOldSong/moonlight-common-c.git
```

### Landing a fork-local common-c change

CI clones the submodule from the `.gitmodules` URL, so **a commit that exists only in some other repo
makes the build fail on a submodule that resolves nowhere.** Order matters:

1. Commit inside the submodule on the `vibemis-rtp-timestamp` branch.
2. `git -C moonlight-common-c/moonlight-common-c push origin vibemis-rtp-timestamp` — push **first**.
3. Only then bump the parent pointer (`git add moonlight-common-c/moonlight-common-c`) and commit it
   in vibemis.

Bumping the pointer to an unpushed SHA produces a green local build and a red CI. This bit BL-2415,
where the submodule's `origin` still aimed at ClassicOldSong (a repo we cannot push to) while
`.gitmodules` already aimed at our fork; the mismatch had to be spotted and patched by hand.
`scripts/check-submodule-invariants.sh` (BL-2526) now fails the build if `.gitmodules` and the
submodule's configured `origin` ever disagree again. An intentional pin bump must also update the
hash in `scripts/check-audio-invariants.sh` guard #6.

### Symbol differences when syncing upstream

When syncing with upstream `moonlight-qt`, check `moonlight-common-c/moonlight-common-c.pro` for symbols that mainline uses but ClassicOldSong's fork doesn't expose:

- `src/rswrapper.c` → use `reedsolomon/rs.c` instead
- `nanors/` includes → use `reedsolomon/` instead
- `LiSendControllerTouchEvent2`, `LI_CCAP_DUAL_TOUCHPAD`, `LiGetMicroseconds` → guard with `#ifdef` or revert if absent

## AppImage apprun-hook: libva fix

The hook at `apprun-hooks/01-libva-driver-paths.sh` does two things:

1. Sets `LIBVA_DRIVERS_PATH` to the host's DRI directory (finds `/usr/lib64/dri`, `/usr/lib/x86_64-linux-gnu/dri`, or `/usr/lib/dri`).
2. Creates a `mktemp -d` temp directory with **only** symlinks to `libva.so.2`, `libva-drm.so.2`, `libva-x11.so.2` from the system, then prepends that dir to `LD_LIBRARY_PATH`. This overrides the bundled libva 1.20 with the system libva (1.22+ on SteamOS/Mesa 25.3) without surfacing other system libs (specifically system Qt) that would break platform plugin loading.

Escape hatch: `VIBEMIS_SKIP_HOST_LIBVA=1` disables step 2.

## Supported targets

Vibemis is Linux-first. The AppImage targets x86-64 Linux with glibc 2.17+.

| Target | Build | Tested on |
|--------|-------|----------|
| Linux x86-64 (generic) | AppImage | WSL2 (smoke), Legion Go S Z2 (real hardware) |
| Steam Deck / SteamOS | AppImage | Lenovo Legion Go S Z2 (Z2 Go APU / AMD Phoenix) |

Windows and macOS are **not** targets for Vibemis. See upstream [Moonlight Qt](https://github.com/moonlight-stream/moonlight-qt) or [Vibemis Qt](https://github.com/navyas321/vibemis) for those platforms.
