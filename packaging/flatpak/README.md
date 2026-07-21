# Vibemis Flatpak packaging (`io.github.navyas321.Vibemis`)

This directory builds Vibemis as a Flatpak — the supported way to run it on
**SteamOS / Steam Deck / Linux handhelds in Game Mode**: the read-only root
filesystem rules out native packages, and binaries built on a rolling distro
won't match SteamOS's glibc across OS updates. The Flatpak is ADDITIVE next to
the AppImage (GitHub Releases), not a replacement.

Approach ported from Nonary's moonlight-qt SteamOS packaging (commit
`b6c398ff`), itself derived from the official Flathub packaging
(`flathub/com.moonlight_stream.Moonlight`), with these Vibemis specifics:

- **App-id / branding stay Vibemis** (`io.github.navyas321.Vibemis`, command
  `vibemis`) — this is not a Moonlight rebuild.
- **`--env=PREFER_VULKAN=1`**: the VRR cadence pacing being ported on the
  BL-2212 line lives in the Vulkan (libplacebo) renderer, so the Flatpak
  selects it by default. Launch with `PREFER_VULKAN=0` for the stock renderer
  order.
- **libdrm enabled** (upstream Flathub's `CONFIG+=disable-libdrm` removed):
  HAVE_DRM lets the client read the true display refresh rate from DRM scanout
  state (gamescope's XWayland advertises a fake 60 Hz mode).
- **`app/version.txt` is stamped** with the precise release identity at build
  time.
- **REAL SDL2, never SDL3/sdl2-compat** — see below. This is the one deliberate
  divergence from both Nonary's and upstream Flathub's manifests.

The gamescope WSI Vulkan layer json is kept (semantics identical to Nonary /
Flathub): in Game Mode it lets Vulkan present directly to gamescope instead of
through XWayland. The layer name `VK_LAYER_FROG_gamescope_wsi_x86_64` must
match the host's layer library, so it is not rebranded.

## AUDIO INVARIANT — real SDL2 only (BL-2213)

Vibemis is the Moonlight fork WITHOUT audio crackling on PipeWire handhelds
(vibemis issue #239) precisely because it ships **classic SDL2**, whose audio
backend priority puts **PulseAudio first** (served by `pipewire-pulse` with
deep buffering). Upstream and Nonary builds ship **SDL3 + sdl2-compat**, which
prefer SDL3's native PipeWire backend — documented to crackle under
Moonlight's 5 ms `SDL_QueueAudio` submission pattern (SDL#6121, sdl2-compat#539,
moonlight-qt#1943). Full RCA: `docs/engineering/BL-2213-audio-no-crackle-rca.md`
in the vibemis-agent-meta repo.

Therefore the manifest builds `SDL2` from the real SDL2 maintenance line
(`release-2.32.10`) into `/app/lib`. **Never "re-sync" that module to
SDL3 + sdl2-compat** on a Flathub/upstream rebase — the KDE runtime's own
libSDL2 may itself be sdl2-compat, which is why we build our own.

To verify on-device: the stream log prints `SDL audio driver: pulseaudio` at
stream start. (`SDL_AUDIODRIVER=pipewire` remains available for the BL-2213
A/B experiment.)

## Files

| File | Purpose |
|------|---------|
| `io.github.navyas321.Vibemis.yml` | The Flatpak manifest (module chain + sandbox `finish-args`). |
| `io.github.navyas321.Vibemis.metainfo.xml` | AppStream metainfo with the Flathub app-id. |
| `io.github.navyas321.Vibemis.desktop` | Desktop entry with the Flathub app-id. |
| `flathub.json` | `{"only-arches": ["x86_64"]}` — we ship x86_64 only. |
| `VkLayer_FROG_gamescope_wsi.x86_64.json` | gamescope WSI Vulkan layer (SteamOS Game Mode). |

## Build

On any Linux box (or the Deck itself in Desktop Mode):

```sh
flatpak install flathub org.flatpak.Builder org.kde.Sdk//6.10 org.kde.Platform//6.10
flatpak run org.flatpak.Builder --user --force-clean --sandbox \
    --install-deps-from=flathub --ccache \
    --repo=repo builddir packaging/flatpak/io.github.navyas321.Vibemis.yml
flatpak build-bundle repo Vibemis.flatpak io.github.navyas321.Vibemis master
```

(CI: `.github/workflows/flatpak.yml` validates the manifest on every packaging
change and builds the bundle on manual dispatch.)

## Install (Steam Deck / SteamOS handheld)

```sh
flatpak install --user ./Vibemis.flatpak
```

or open the file in Discover. It installs as `io.github.navyas321.Vibemis`
(branch `master`). Add it to Steam with `steamos-add-to-steam` or via Discover
to use it in Game Mode.

## Quick local checks

```bash
# Validate the metainfo (appstreamcli, part of AppStream):
appstreamcli validate io.github.navyas321.Vibemis.metainfo.xml

# Validate the desktop entry:
desktop-file-validate io.github.navyas321.Vibemis.desktop

# Lint the manifest (Flathub's linter):
flatpak install flathub org.flatpak.Builder
flatpak run --command=flatpak-builder-lint org.flatpak.Builder \
  manifest io.github.navyas321.Vibemis.yml
```

## Flathub

**Do not submit to Flathub yet**: submission is maintainer-gated and blocked on
the public repo split + a security audit. Full context, the pre-submission
checklist (incl. re-pinning the `vibemis` module from the current beta tag to a
bare stable tag), and the submission steps live in
[`docs/FLATHUB.md`](../../docs/FLATHUB.md).
