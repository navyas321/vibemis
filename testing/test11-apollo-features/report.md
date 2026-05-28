# Test11 Report — Apollo Feature Verification (BLOCKED by stream-launch SEGV)

**Artifact tested:** `Vibemis-0.6.7-alpha.vibemis-main.20260528.0657+7c4a2db-x86_64.AppImage`
**md5:** `4cbd20f916b6888c7aee13786760ca13` (latest pre-release at test time)
**Source:** GitHub Releases — `0.6.7-alpha.vibemis-main.20260528.0657+7c4a2db` (published 2026-05-28 07:02 UTC)
**Branch:** `verify/apollo-features`
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0, AMD Ryzen Z2 Go (radeonsi, no NVIDIA hardware)
**Test date:** 2026-05-28
**Stream host:** Navid-PC running Vibepollo (Apollo 7.1.431)

---

## 1. TL;DR

**STREAM LAUNCH CRASHES WITH SEGV.** Interactive feature checks (Quick Menu, Clipboard, Server Commands, OTP, Bitrate) could not be exercised — the app SEGVs ~1-2 s after the user clicks an app to stream. App startup, mDNS discovery, pair-status fetch, and applist refresh all work fine.

| Check | Status | Notes |
|---|---|---|
| **#1 — Stream baseline** | **FAIL (SEGV)** | App boots, polls Apollo, gets applist OK. On stream attempt, FFmpeg's `hevc_cuvid` decoder fails to load `libnvcuvid.so.1` (expected — AMD device) and the cleanup path SEGVs in `libavcodec.so.58`. |
| **#2 — Quick Menu** | **BLOCKED** | Requires an active stream. |
| **#3 — Clipboard Sync** | **BLOCKED** | Requires an active stream. |
| **#4 — Server Commands** | **BLOCKED** | Quick Menu unreachable. |
| **#5 — OTP Pairing** | **NOT TESTED** | Skipped per "don't risk losing pairing" guidance in instructions. |
| **#6 — Bitrate / Refresh** | **BLOCKED** | Stream cannot start. |

Latest AppImage was verified — also tried the older `+33cadd7` build, same crash.

---

## 2. Reproduction

Identical crash on **two consecutive pre-release builds** of this branch:

- `+33cadd7` (06:39 UTC) — 3 SEGVs in a row (PIDs 3148, 3347, 5239 at 03:08–03:10).
- `+7c4a2db` (07:02 UTC) — 1 SEGV (PID 6394 at 03:15) on the very next attempt.

All crashes have the same log fingerprint (final lines before SEGV):

```
00:01:43 - SDL: Initialized VAAPI 1.22 (Mesa Gallium driver 25.3.0 for AMD Ryzen Z2 Go [radeonsi])
00:01:43 - SDL Warn: Deprioritizing VAAPI on Gallium driver. Set FORCE_VAAPI=1 to override.
00:01:43 - SDL: Trying PlVkRenderer for codec hevc_cuvid due to compatible pixel format: 0x17
00:01:44 - SDL: Vulkan rendering device chosen: AMD Ryzen Z2 Go (RADV REMBRANDT)
00:01:44 - SDL: Using Immediate present mode with V-Sync disabled
00:01:44 - SDL: Using Vulkan renderer
00:01:44 - FFmpeg: [hevc_mp4toannexb] The input looks like it is Annex B already
00:01:44 - FFmpeg: [hevc_cuvid] Format nv12 chosen by get_format()
00:01:44 - FFmpeg: [hevc_cuvid] Cannot load libnvcuvid.so.1
00:01:44 - FFmpeg: [hevc_cuvid] Failed loading nvcuvid.
                                                       ⟵ SEGV here, no Qt handler caught it
```

systemd journal:
```
May 28 03:15:04 systemd-coredump: Process 6394 (AppRun.wrapped) of user 1000 dumped core.
May 28 03:15:07 drkonqi-coredump-launcher: Nothing handled the dump :O
```

---

## 3. Crash diagnosis (without root + symbols)

`coredumpctl info 6394` exposes a single-frame trace from the crashing thread:

```
Stack trace of thread 6515:
#0  0x00007f3809890af4 n/a (/tmp/.mount_VibemiLlCCch/usr/lib/libavcodec.so.58 + 0x90af4)
```

Resolving the offset against the AppImage's bundled `libavcodec.so.58` (FFmpeg 4.x — soname `.58`):

| Symbol | Address |
|---|---|
| nearest before | `av_dct_end` @ `0x8b2a7` |
| nearest after | `avpriv_ac3_parse_header` @ `0x157640` |

The crash is in an **internal (non-exported) FFmpeg function** between those two, at +`0x584D` past `av_dct_end`. Combined with the log fingerprint, this is almost certainly the **CUVID hardware-decoder init/teardown path** (`libavcodec/cuvid.c` family) — the failed `dlopen("libnvcuvid.so.1")` leaves an uninitialised context that the cleanup path dereferences.

Crashing module attribution:
- Bundled `libavcodec.so.58` (FFmpeg) — stripped, no build-id.
- **Not** Vibemis's own `session.cpp` / SDL renderer code.

---

## 4. Why this didn't reproduce in test10

Test10 (commit `504e938`) streamed successfully on this same hardware with the same `Failed loading nvcuvid.so.1` warnings — but the previous decoder probe order used VAAPI/EGLRenderer first and never reached the `PlVkRenderer + hevc_cuvid` pairing.

This build (commit `7c4a2db`, on top of `33cadd7` / `59244be` / `13e6c48` / `8dd4404b`) prefers **PlVkRenderer (Vulkan) + hevc_cuvid** for `pixel format 0x17` (`AV_PIX_FMT_CUDA`). The chosen renderer succeeds (`RADV REMBRANDT` is a valid Vulkan device), then `hevc_cuvid` is paired with it, fails its `dlopen`, and the cleanup SEGVs.

Suspect commits to bisect (all merged onto `vibemis-main` between test10 and test11):

- `13e6c48` — `ci: re-enable AppImage build with linuxdeploy; wire to release on vibemis-main (#24)` (changed build config / bundled libs?)
- `33cadd7` — `chore: remove flatpak/rpi CI, fix release 403, fix README attribution (#25)` (probably no functional impact, but on the path)
- `7c4a2db` — most-recent develop-branch tip; build the report was tested against.
- Less likely but worth a look: `59244be` (rename) — if anything in the SDL/FFmpeg decoder enumeration was string-matching on "artemis", a rename could re-order probes.

---

## 5. Suggested fixes (for the build agent — not implemented by me)

In order of decreasing risk:

1. **Filter the decoder probe by host capability before pairing with the renderer.** On systems without `libnvcuvid.so.1`, don't add `hevc_cuvid` / `av1_cuvid` / `h264_cuvid` to the probe list at all. This avoids the FFmpeg crash entirely and matches the test10 behaviour.
2. **Catch the FFmpeg load failure earlier in `Session::testHwDecoder` / decoder enumeration** and skip the renderer pairing when the codec context isn't usable.
3. **Workaround:** export `FORCE_VAAPI=1` to bypass the Vulkan deprioritisation and stay on the VAAPI path — would confirm the crash is unique to the Vulkan + CUVID combination, but is not a real fix.

A real backtrace would need:
- `sudo` access to `/var/lib/systemd/coredump/core.*.zst` (root-owned, mode 0640), OR
- A debug build of `libavcodec.so.58` in the AppImage, OR
- Reproducing under `gdb --args ./Vibemis.AppImage` and clicking through to a stream.

Any of those is straightforward on the build host; I left them alone per the test-agent role boundary.

---

## 6. Other observations

- **App startup, mDNS, pairing, HTTPS handshake, applist all work** on the latest build — the SEGV is strictly on stream-launch decoder enumeration.
- `VirtualDisplayCapable=true`, `VirtualDisplayDriverReady=true`, `PairStatus=1` — host side is healthy.
- VAAPI 1.22 / Mesa 25.3 / libva surgical hook still firing correctly: `[vibemis-apprun-hook] preferring host libva from /usr/lib64`.
- No QML TypeErrors (test8/9/10 cleanup remains regression-free).
- HDR-capability gate (PR #11) still working — no HDR codec attempted, matches test9 fix.

---

## 7. Recommendation

**BLOCKER — ITERATE.**

- Cannot exercise any Apollo-feature checks until stream-launch is restored.
- The fix is on the build side (FFmpeg decoder probe filtering or graceful failure). Once test12 is published on this branch, I can re-run the full Apollo feature matrix.
- Latest AppImage was confirmed (`md5: 4cbd20f9...` from release `+7c4a2db`). Build agent should be aware the regression spans at least `+33cadd7` and `+7c4a2db` — bisecting against test10's commit `504e938` should localise it quickly.
