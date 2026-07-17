# Flathub submission — Vibemis (`io.github.navyas321.Vibemis`)

Status: **packaging authored, submission intentionally deferred.** (BL-1556)

The Flatpak packaging lives in [`packaging/flatpak/`](../packaging/flatpak/):

| File | Purpose |
|------|---------|
| `io.github.navyas321.Vibemis.yml` | The Flatpak manifest (module chain + sandbox `finish-args`). |
| `io.github.navyas321.Vibemis.metainfo.xml` | AppStream metainfo with the Flathub app-id. |
| `io.github.navyas321.Vibemis.desktop` | Desktop entry with the Flathub app-id. |
| `flathub.json` | `{"only-arches": ["x86_64"]}` — we ship x86_64 only. |
| `VkLayer_FROG_gamescope_wsi.x86_64.json` | gamescope WSI Vulkan layer (SteamOS Game Mode). |

These are the exact files the flathub repo will carry. Authoring them here (rather
than only in a flathub fork) keeps the manifest under version control with the app
and makes the eventual submission a copy-and-open-PR step.

## Why deferred (do not submit yet)

Flathub submission is a **maintainer + external** action and is **gated** on two things
that must land first:

1. **Public repo split** — Flathub builds from a public git URL. The manifest is pinned
   to `https://github.com/navyas321/vibemis.git` @ tag `0.1.0`; if the repo is split into
   a dedicated public repo (see `docs/REPO_SPLIT_PLAN.md`), re-pin the `url` + `tag` +
   `commit` in the manifest's final `vibemis` module before submitting.
2. **Security audit** — a Flathub PR is public and permanent; the `--device=all` and
   `--filesystem=host-os:ro` permissions get reviewer scrutiny. Complete the audit and be
   ready to justify each `finish-args` entry.

Submitting also requires a maintainer decision (it publishes under a namespace the
maintainer owns and creates a long-lived support obligation). **An agent must not open the
Flathub PR.** This is flagged `needsUserDecision`.

## Pre-submission checklist (do these first)

- [ ] **Real screenshots.** The metainfo `<screenshot>` URLs are placeholders. Commit real
      Vibemis screenshots to the repo and point the `<image>` URLs at reachable https paths
      (Flathub requires them to resolve). Suggested location:
      `docs/design/screenshots/{pcview,settings,quickmenu}.png`.
- [ ] **Re-pin the app source** in the manifest to the public repo + the stable tag you are
      shipping (currently `0.1.0` / `60736b0`), including the exact `commit`.
- [ ] **Confirm the latest `<release>`** in the metainfo matches the tag the manifest builds.
- [ ] **Local build + smoke test** (needs a Linux box with `flatpak` + `flatpak-builder`;
      not available in the current WSL toolchain):
      ```bash
      flatpak install flathub org.kde.Platform//6.10 org.kde.Sdk//6.10
      flatpak-builder --force-clean --install --user build-dir \
        packaging/flatpak/io.github.navyas321.Vibemis.yml
      flatpak run io.github.navyas321.Vibemis
      ```
- [ ] **Lint** (Flathub gate):
      ```bash
      flatpak install flathub org.flatpak.Builder
      flatpak run --command=flatpak-builder-lint org.flatpak.Builder \
        manifest packaging/flatpak/io.github.navyas321.Vibemis.yml
      flatpak run --command=flatpak-builder-lint org.flatpak.Builder \
        builddir build-dir
      ```
- [ ] **Verify on the Legion Go S in Game Mode** (hardware decode + gamepad + Quick Menu
      overlay), per `docs/DISTRIBUTION.md`. If the AMD/Mesa VAAPI fix is still needed, the
      manifest already ships `--filesystem=host-os:ro`; add an `--env=` override if required.

## Submission steps (deferred — maintainer performs)

1. Fork `flathub/flathub` on GitHub (keep all branches).
2. Create a branch off the **`new-pr`** branch (not `master`).
3. Add `io.github.navyas321.Vibemis.yml` and its sibling files (`.metainfo.xml`, `.desktop`,
   `flathub.json`, `VkLayer_FROG_gamescope_wsi.x86_64.json`) from `packaging/flatpak/` to the
   fork root.
4. Open a PR against `flathub/flathub` **`new-pr`**, titled `Add io.github.navyas321.Vibemis`.
5. Iterate with reviewers (async, a few rounds — permissions and metainfo quality are the
   usual topics).
6. On merge you get a dedicated `flathub/io.github.navyas321.Vibemis` repo to push updates to.
   The manifest's `x-checker-data` (git tag-pattern) will file automated update PRs there when
   a new bare stable tag lands.
7. Claim the **Verified** badge via GitHub ownership in the Flathub Developer Portal (the
   `io.github.*` id maps to the GitHub account — no website needed).

## Notes

- The shared dependency modules (libplacebo, libdecor, SDL3, SDL2-compat, SDL2_ttf, dav1d,
  ffmpeg, gamescope-wsi) are copied near-verbatim from upstream
  [`flathub/com.moonlight_stream.Moonlight`](https://github.com/flathub/com.moonlight_stream.Moonlight).
  Re-sync them from upstream on each Moonlight rebase; only Vibemis's final module differs.
- The manifest makes **no changes to `app/` source**. It reconciles the in-tree app-id
  (`com.vibemis.Vibemis`, still used by the AppImage build) with the Flathub app-id
  (`io.github.navyas321.Vibemis`) entirely in the `vibemis` module's `post-install` step. The
  full in-tree app-id rename (metainfo/.desktop/icons/CI) is tracked separately and is not
  part of this packaging task.
- The **AppImage** (GitHub Releases) stays the beta / any-distro channel; Flathub is the
  stable one-click channel for SteamOS/Discover.
