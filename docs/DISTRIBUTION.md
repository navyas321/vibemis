# Vibemis distribution / publishing plan

Decision-ready research (BL-1552). **Recommendation: publish on Flathub as a Flatpak.** Keep the
AppImage (GitHub Releases) as the beta / "any distro" fallback; keep "Add as Non-Steam Game" as the
launch mechanism. Skip the Steam store (poor fit for a free GPL streaming client; competes with
Valve's own Steam Link; no Moonlight-lineage client has ever been on the store).

## Why Flathub

- Flatpak is pre-installed on Steam Deck / SteamOS; **Discover** (Desktop Mode) is where handheld
  users are told to get Moonlight-family clients — the discovery channel.
- Flatpaks install to the home partition, so they **survive SteamOS atomic OS updates** (unlike AUR
  / pacman which touch the immutable root and get wiped).
- Works in Game Mode: upstream Moonlight's Flatpak wires `--filesystem=xdg-run/gamescope-0` and
  bundles the gamescope WSI Vulkan layer — the blessed way to do what our AppImage does ad hoc.
- Auto-updates through Discover; GPL-3.0 fully compatible (all built from source).
- **Biggest asset:** our upstream **Moonlight-Qt maintains a working Flathub manifest**
  ([flathub/com.moonlight_stream.Moonlight](https://github.com/flathub/com.moonlight_stream.Moonlight))
  we can adapt near-verbatim, and the repo already ships `app/deploy/linux/*.appdata.xml` + `*.desktop`.

## Concrete next steps (tracked as a follow-up feature)

1. **Rename the app ID** `com.vibemis.Vibemis` → **`io.github.navyas321.Vibemis`** (Flathub requires a
   namespace you control; the GitHub code-hosting namespace is allowed). Update the metainfo `<id>`/
   `<launchable>`, the `.desktop`, icon basenames, and the AppImage desktop-integration hook +
   CI references so AppImage and Flatpak agree on the ID.
2. **Fix the metainfo** (`app/deploy/linux/…appdata.xml`): real Vibemis screenshots (host in-repo),
   a current `<releases>` entry, valid `<content_rating>`, drop the placeholder contact; must pass
   `appstreamcli validate`.
3. **Author the manifest** `io.github.navyas321.Vibemis.json` — copy Moonlight's module chain
   (libplacebo, libdecor, SDL3+SDL2-compat+SDL2_ttf, dav1d, ffmpeg with vaapi/vdpau/vulkan hwaccels,
   gamescope-wsi layer) verbatim; only the final module changes to point at this repo + `vibemis.pro`
   (`buildsystem: qmake`, or `simple` with explicit `qmake6 vibemis.pro … && make && make install`);
   `disable-shallow-clone: true` so the submodules (ClassicOldSong moonlight-common-c, qmdnsengine,
   h264bitstream) resolve.
4. **Build locally** with `flatpak-builder`, then **verify on the Legion Go S in Game Mode**
   (hardware decode + gamepad + Quick Menu overlay). If the AMD/Mesa VAAPI fix is still needed, add
   `--env=FORCE_VAAPI=1` to `finish-args` and `--filesystem=host-os:ro` for host drivers.
5. **Submit:** fork `flathub/flathub`, branch off `new-pr`, add the manifest, open a PR against
   `new-pr`; iterate with reviewers (async, a few rounds). On merge you get your own
   `flathub/io.github.navyas321.Vibemis` repo to push updates to; later claim the **Verified** badge
   via GitHub ownership (no website needed).

## Secondary / optional

- **AUR** (`PKGBUILD`) — nice for Arch/Manjaro desktop; NOT the Deck path (immutable root). After Flathub.
- **Snap** — feasible (Moonlight has one) but second-class on SteamOS; low priority.
- **Steam store** — skip (eligibility shaky, $100 sunk cost, competes with Steam Link, no discovery win).

Sources: Moonlight Flathub manifest repo; Flathub submission + requirements docs; Steam Deck install
guides (XDA / Pi My Life Up); MoonDeck/Decky for Game-Mode launching.
