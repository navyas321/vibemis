# Vibemis distribution / publishing plan

Decision-ready research. **Recommendation: publish on Flathub as a Flatpak.** Keep the
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

## 2026-07-13 research refresh (confirms the plan, adds specifics)

Ranked by real one-click-ness for a Game-Mode user vs maintainer effort:

| Rank | Path | User steps that remain | Effort |
|---|---|---|---|
| **1** | **Flathub via Discover** | Desktop Mode once → Discover → Install → right-click "Add to Steam" | ~1-2 days |
| 2 | Steam store (Steam Direct) | none — fully in Game Mode, auto-updates | $100 deposit (recoup only after $1k revenue), paperwork, ~30-day wait, SteamPipe, GPL-fork rights review. OBS/Blender precedent exists — a *revisit-later*, not a hard skip |
| 3 | AppImage + Gear Lever | strictly more steps than Flathub | ~0 (keep for power users; add zsync) |
| 4 | Decky Loader | not a distribution channel — "VibeDeck" companion-plugin idea only (MoonDeck precedent) | n/a |

Confirmed specifics to fold into the manifest work:
- Moonlight's manifest currently pins `org.kde.Platform` **6.10**; module chain unchanged
  (libplacebo, libdecor, SDL3, SDL2-compat, SDL2_ttf, dav1d, cgutman ffmpeg, gamescope-wsi
  VkLayer json). Drop its three Qt-6.9 patches if already merged in our tree.
- Add `flathub.json` with `{"only-arches": ["x86_64"]}` (we ship x86_64 only).
- Wire `x-checker-data` (git tag-pattern) on the app source so stable-tag bumps arrive as
  **automated update PRs** in the flathub repo; merging publishes.
- Verification = GitHub login in the Flathub Developer Portal (io.github.* IDs).
- **Phase E UX polish:** an in-app "Add me to Steam" button (Heroic precedent — shortcuts.vdf
  write, or `steamos-add-to-steam` via `flatpak-spawn --host`; expect reviewers to question the
  permission) + a first-run SteamOS hint. README install section then reads:
  "Discover → Vibemis → Install → right-click → Add to Steam."
- Game-Mode reality: **nothing except the real Steam store removes the one Desktop-Mode visit
  and the one Add-to-Steam right-click.**
