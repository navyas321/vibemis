# Vibemis 0.6.0

The headline changes in 0.6.0. Every change is listed in the full changelog on the
[release page](https://github.com/navyas321/vibemis/releases/tag/0.6.0).

## Highlights

- Updates stay on the channel you chose: picking Stable now sticks even if the app is closed from Settings (it could previously revert to Beta and install a beta), and every update is checked against the release's published checksum before it replaces the installed app.
- The Linux AppImage now hardware-decodes YUV 4:4:4 streams on Intel and AMD GPUs instead of falling back to software decoding.
