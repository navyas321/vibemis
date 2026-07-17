# Vibemis Flatpak packaging (`io.github.navyas321.Vibemis`)

Authored for a **deferred** Flathub submission. Full context, the pre-submission
checklist, and the submission steps live in [`docs/FLATHUB.md`](../../docs/FLATHUB.md).

Files here:

- `io.github.navyas321.Vibemis.yml` — the Flatpak manifest.
- `io.github.navyas321.Vibemis.metainfo.xml` — AppStream metainfo (Flathub app-id).
- `io.github.navyas321.Vibemis.desktop` — desktop entry (Flathub app-id).
- `flathub.json` — `only-arches: [x86_64]`.
- `VkLayer_FROG_gamescope_wsi.x86_64.json` — gamescope WSI Vulkan layer for Game Mode.

Do not submit to Flathub yet: it is maintainer-gated and blocked on the public repo
split + a security audit. See `docs/FLATHUB.md`.

Quick local checks:

```bash
# Validate the metainfo (appstreamcli, part of AppStream):
appstreamcli validate io.github.navyas321.Vibemis.metainfo.xml

# Validate the desktop entry:
desktop-file-validate io.github.navyas321.Vibemis.desktop

# Build locally (needs flatpak + flatpak-builder on a Linux host):
flatpak-builder --force-clean --install --user build-dir \
  io.github.navyas321.Vibemis.yml
```
