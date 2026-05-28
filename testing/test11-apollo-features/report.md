# Test11 Report — Apollo Feature Verification (still BLOCKED, but no longer crashing — new black-screen bug surfaced)

**Branch tested:** `verify/apollo-features` instructions, AppImages built from `vibemis-main`
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0, AMD Ryzen Z2 Go (radeonsi, no NVIDIA hardware)
**Test date:** 2026-05-28
**Stream host:** Navid-PC running Vibepollo (Apollo 7.1.431)

### Exact AppImages tested (three builds, in order)

| | **#3 — newest (after fix)** | #2 — middle | #1 — oldest |
|---|---|---|---|
| **Release tag** | `0.6.7-alpha.vibemis-main.20260528.0733+c6efc5c` | `0.6.7-alpha.vibemis-main.20260528.0657+7c4a2db` | `0.6.7-alpha.vibemis-main.20260528.0639+33cadd7` |
| **Commit SHA** | `c6efc5cb60182b8819b3c5b05defd20dc58e5bf6` (PR #29 — FORCE_VAAPI=1 hook) | `7c4a2dbe06d5a07483cab6005c7475429257c6de` (PR #26 — remove platform files) | `33cadd7955d74bb2dd6237d49106c90726578bd3` (PR #25 — CI / release fixes) |
| **Built** | 2026-05-28 07:38 UTC | 2026-05-28 07:02 UTC | 2026-05-28 06:39 UTC |
| **MD5** | `a7642de9e4a8f5fd3ff935dfbc04c7e8` | `4cbd20f916b6888c7aee13786760ca13` | `c7ce9ef85c4218afd0ffa7df97f191b9` |
| **`--version`** | `Vibemis 0.6.7` | `Vibemis 0.6.7` | `Vibemis 0.6.7` |
| **Result** | **Black screen** (no crash, stream connects, EGLRenderer shader load loop) | SEGV (1 coredump, PID 6394) | SEGV (3 coredumps, PIDs 3148/3347/5239) |

All three downloaded from GitHub Releases via `gh release download`, MD5 verified before launch.

---

## 1. TL;DR

**Build #3 (`+c6efc5c`)**: the FORCE_VAAPI=1 hook successfully prevents the previous SEGV — stream now reaches RTSP handshake, VAAPI 1.22 initialises, FFmpeg starts decoding. **But the EGLRenderer fails to load its shaders and falls into a "recreating renderer" loop → black screen, no video.** Stream session is up on the wire (control / video / audio / input all `Starting...`), but nothing renders.

**Builds #1 / #2**: still useful as the SEGV record — see §2 fingerprint. Replaced by #3 as the current head of the branch.

Interactive Apollo feature checks (Quick Menu, Clipboard, Server Commands, OTP, Bitrate) are **still blocked** — can't open the in-stream Quick Menu when there's no video.

| Check | Status | Notes |
|---|---|---|
| **#1 — Stream baseline** | **FAIL (black screen on build #3 — `+c6efc5c`)** | Connects, RTSP handshake completes, VAAPI initialises, FFmpeg creates surfaces. EGLRenderer can't load its vertex shader → infinite "recreating renderer" loop → no frames displayed. See §4. Builds #1/#2 SEGV'd before reaching this point (see §2/§3). |
| **#2 — Quick Menu** | **BLOCKED** | Requires visible stream. |
| **#3 — Clipboard Sync** | **BLOCKED** | Requires visible stream. |
| **#4 — Server Commands** | **BLOCKED** | Quick Menu unreachable. |
| **#5 — OTP Pairing** | **NOT TESTED** | Skipped per "don't risk losing pairing" guidance in instructions. |
| **#6 — Bitrate / Refresh** | **BLOCKED** | Stream never renders visibly. |

The FORCE_VAAPI=1 fix in `+c6efc5c` (PR #29) **does** resolve the original SEGV. But it reveals a separate pre-existing bug in `EGLRenderer::compileShaders()` that the previous renderer path was masking.

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

## 5. Build #3 (`+c6efc5c`) — black screen, EGLRenderer shader load fails

After PR #29 (FORCE_VAAPI=1 in the AppRun hook) shipped in `+c6efc5c`, the SEGV is gone. New AppRun line on launch:

```
[vibemis-apprun] FORCE_VAAPI=1 (host DRI: /usr/lib64/dri)
```

Stream now reaches RTSP and beyond:

```
00:00:49 - Launch response: status_code="200", sessionUrl0=rtspenc://192.168.4.78:48010
00:00:49 - SDL: RTSP port: 48010
00:00:49 - SDL: Starting RTSP handshake...
00:00:49 - SDL: Starting control stream...
00:00:49 - SDL: Starting video stream...
00:00:49 - SDL: Video stream is 1920x1200x120 (format 0x100)
00:00:49 - SDL: Starting audio stream... (2 channels)
00:00:49 - SDL: Starting input stream...
00:00:50 - SDL: Initialized VAAPI 1.22  (repeated for each decode context — works)
00:00:50 - FFmpeg: [AVHWFramesContext] Created surface 0x1.  (frames being decoded)
```

…but then the renderer goes into a tight failure loop:

```
00:00:50 - SDL Error: EGLRenderer: Cannot load shader "egl_opaque.vert":
                      0:1(1): error: syntax error, unexpected end of file
00:00:50 - SDL Warn:  Recreating renderer by internal request: 8192
[repeats — many hundreds of times — frames decoded but never displayed = black screen]
```

GLSL error `0:1(1): error: syntax error, unexpected end of file` means the compiler got a zero-byte source — the shader resource is being found but reads empty.

### Root cause (source-level)

In `app/streaming/video/ffmpeg-renderers/eglvid.cpp`, `EGLRenderer::compileShaders()` references three vertex shader files that don't exist anywhere in the source tree or the .qrc:

| Line | `compileShader(vert, frag)` call | `vert` exists in repo? |
|---|---|---|
| 365 | `("egl_nv12.vert", "egl_nv12.frag")` | ❌ no `egl_nv12.vert` |
| 376 | `("egl_opaque.vert", "egl_opaque.frag")` | ❌ no `egl_opaque.vert` |
| 391 | `("egl_overlay.vert", "egl_overlay.frag")` | ❌ no `egl_overlay.vert` |

`app/resources.qrc` registers only one EGL vertex shader: `egl.vert` (aliased to `shaders/egl.vert`). `app/shaders/` on disk contains `egl.vert` and the three matching `.frag` files only.

Upstream Moonlight Qt's `eglvid.cpp` uses the same shared `egl.vert` for all three programs (one vertex shader, three fragment shaders). The current Vibemis source is calling for per-program `.vert` filenames that were never present — Qt's resource system returns empty for the missing files, GLSL gets zero bytes, the compile fails, the renderer requests recreation, and the loop never exits.

The Vulkan+CUVID code path in builds #1/#2 was masking this — it crashed before EGLRenderer was reached. With `FORCE_VAAPI=1` we now always land on EGLRenderer, exposing the pre-existing shader bug.

### Suggested fix (for the build agent — not implemented by me)

Change all three call sites in `app/streaming/video/ffmpeg-renderers/eglvid.cpp` to use the shared `egl.vert`:

```cpp
// line 365:  compileShader("egl_nv12.vert",    "egl_nv12.frag");    →  compileShader("egl.vert", "egl_nv12.frag");
// line 376:  compileShader("egl_opaque.vert",  "egl_opaque.frag");  →  compileShader("egl.vert", "egl_opaque.frag");
// line 391:  compileShader("egl_overlay.vert", "egl_overlay.frag"); →  compileShader("egl.vert", "egl_overlay.frag");
```

This matches the upstream Moonlight Qt convention, matches what `app/resources.qrc` and `app/shaders/` actually ship, and requires no other file changes.

---

## 6. Suggested fixes for the original SEGV (builds #1/#2)

PR #29 (`+c6efc5c`) already addresses this with the FORCE_VAAPI=1 hook. Two more durable alternatives that would let the Vulkan renderer be usable on AMD too, in case that's wanted later:

1. **Filter the decoder probe by host capability.** On systems without `libnvcuvid.so.1`, don't add `hevc_cuvid` / `av1_cuvid` / `h264_cuvid` to the probe list at all.
2. **Catch the FFmpeg load failure earlier in `Session::testHwDecoder` / decoder enumeration** and skip the renderer pairing when the codec context isn't usable.

A real backtrace for the SEGV would need:
- `sudo` access to `/var/lib/systemd/coredump/core.*.zst` (root-owned, mode 0640), OR
- A debug build of `libavcodec.so.58` in the AppImage, OR
- Reproducing under `gdb --args ./Vibemis.AppImage` and clicking through to a stream.

---

## 7. Other observations

- **App startup, mDNS, pairing, HTTPS handshake, applist all work** on the `+c6efc5c` build — the stream-side issue is now purely the renderer-shader bug.
- `VirtualDisplayCapable=true`, `VirtualDisplayDriverReady=true`, `PairStatus=1` — host side is healthy.
- VAAPI 1.22 / Mesa 25.3 / libva surgical hook still firing correctly: `[vibemis-apprun-hook] preferring host libva from /usr/lib64`.
- New FORCE_VAAPI hook from PR #29 fires correctly: `[vibemis-apprun] FORCE_VAAPI=1 (host DRI: /usr/lib64/dri)`.
- No QML TypeErrors (test8/9/10 cleanup remains regression-free).
- HDR-capability gate (PR #11) still working: log shows `Vulkan device 'RADV REMBRANDT' does not support HDR10` and `No suitable HDR-capable Vulkan devices found!` — correctly detected, no HDR requested.

---

## 8. Recommendation

**ITERATE — concrete one-file fix available.**

- The original SEGV (`+33cadd7` / `+7c4a2db`) is **resolved** in `+c6efc5c` (PR #29). Confirmed on hardware: app no longer crashes when an app is clicked.
- A separate, pre-existing bug in `eglvid.cpp` is now exposed (was masked by the Vulkan+CUVID path that crashed before EGLRenderer ran). See §5 for the file/line/fix.
- Apollo feature checks (#2-#6) remain blocked until the renderer produces visible frames; once test12 ships with the `eglvid.cpp` fix I can re-run the full matrix.
- All three test cycles used the latest GitHub Release on each iteration; md5sums verified before launch.
