# Vibemis 0.6.0

The headline changes in 0.6.0. Every change is listed in the full changelog on the
[release page](https://github.com/navyas321/vibemis/releases/tag/0.6.0).

## Highlights

- Fixed a stutter of several seconds that could repeat every few minutes when streaming above 60 FPS over Wi-Fi.
- Running a second copy of the Vibemis AppImage no longer re-points your Steam library shortcut at that copy.
- The "vibemis quit" command no longer hangs after the host accepts the quit request.
- Updates stay on the channel you chose: picking Stable now sticks even if the app is closed from Settings (it could previously revert to Beta and install a beta), and every update is checked against the release's published checksum before it replaces the installed app.
- The Linux AppImage now hardware-decodes YUV 4:4:4 streams on Intel and AMD GPUs instead of falling back to software decoding.
- Better recovery from packet loss: a frame lost across several error-correction blocks, or a partly dropped keyframe, now triggers the right recovery request to the host instead of a longer stall.
- Pairing with a host is hardened against malformed certificates and challenge responses.
- On Brazilian ABNT2 keyboards, the / ? key now types / and ? on the host instead of \ and |.
