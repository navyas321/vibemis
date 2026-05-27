# Test5 Report — Surgical libva symlink fix on Legion Go S Z2

**Artifact tested:** `Vibemis-0.6.7-vibemis-test5-libva-surgical-x86_64.AppImage`
**md5:** `db7878509c27ed7e9d76d07c08700641` ✓ verified
**Branch:** `fix/appimage-vaapi-driver-paths` (commit 6a286427)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0, Qt system 6.9.1 / bundled 6.4.2
**Test date:** 2026-05-27
**Prior reports:** test3 (PR #6), test4 (PR #7)

---

## 1. TL;DR

| Goal | Status | Evidence |
|---|---|---|
| **Goal A — No Qt platform crash** | **PASS** | No `Qt Fatal` / `mismatching Qt versions` in Tier 1 log |
| **Goal B — VAAPI HW decode works** | **PASS** | `Initialized VAAPI 1.22`, Mesa 25.3.0 radeonsi; `vaInitialize ret = VA_STATUS_SUCCESS`; "No functioning HW decoder" warning absent |
| **Goal C — mDNS regression-free** | **PASS** | `Navid-PC.local.` discovered at 2s, HTTP serverinfo 200 |

**Recommendation: merge PR #4.** The fix is verified working end-to-end on the target hardware.

---

## 2. Tier 1 — hook output

Hook fired correctly on the first output line:

```
[vibemis-apprun-hook] preferring host libva from /usr/lib64 (via /tmp/tmp.A9xCptftyP)
```

`/usr/lib64/libva.so.2` (system, 1.22.0) matched the first candidate. Temp dir `/tmp/tmp.A9xCptftyP` was created with symlinks to `libva.so.2`, `libva-drm.so.2`, `libva-x11.so.2` and prepended to `LD_LIBRARY_PATH`.

---

## 3. Tier 1 — Qt crash present or absent

**Absent. PASS.**

```bash
grep -i "Qt Fatal\|mismatching Qt\|failed to start" /tmp/vibemis-run-test5.log
# → (no output)
```

The surgical temp-dir approach keeps Qt (and all other non-libva libs) resolving from the AppImage's `DT_RUNPATH`, so system Qt 6.9.1 is never surfaced. The test4 crash does not occur.

---

## 4. Tier 1 — VAAPI result

**Full success.** VAAPI 1.22 initialised with the Mesa 25.3.0 radeonsi driver.

From `/tmp/vibemis-run-test5.log`:
```
00:00:01 - SDL Info (0): Initialized VAAPI 1.22
00:00:01 - SDL Warn (0): VAAPI driver is affected by RFI latency bug
00:00:01 - FFmpeg: [AVHWDeviceContext @ ...] VAAPI driver: Mesa Gallium driver 25.3.0 for AMD
           Ryzen Z2 Go (radeonsi, rembrandt, LLVM 20.1.8, DRM 3.64,
           6.16.12-valve21-1-neptune-616-g6e6a05c0d53f).
```
(Repeated 5× — once per decode context probed by SDL/FFmpeg.)

From `/tmp/vibemis-libva-test5.230457.thd-0x00004c28` (trace):
```
[ctx none]==========va_TraceInitialize
[ctx none]==========  VA-API vendor string: Mesa Gallium driver 25.3.0 for AMD Ryzen Z2 Go
             (radeonsi, rembrandt, LLVM 20.1.8, DRM 3.64, 6.16.12-valve21-1-neptune-616-...)
[ctx none]=========vaInitialize ret = VA_STATUS_SUCCESS, success (no error)
[ctx none]==========va_TraceCreateSurfaces
[ctx none]  width = 1280, height = 720
[ctx none]=========vaCreateSurfaces ret = VA_STATUS_SUCCESS, success (no error)
[ctx none]==========va_TraceExportSurfaceHandle
[ctx none]  fourcc = 808530000 (NV12), modifier = 0x200000010401b03
[ctx none]  object 0, fd = 26, size = 2949120
```

`vaInitialize`, `vaCreateSurfaces`, and `vaExportSurfaceHandle` all return `VA_STATUS_SUCCESS`. DRM PRIME surface export is working — this is the full decode path Artemis uses for zero-copy frame delivery.

No `libva error` lines anywhere in the Tier 1 log.

---

## 5. Tier 1 — mDNS

**Working. PASS.**

```
00:00:02 - Qt Info: Discovered mDNS host: "Navid-PC.local."
00:00:04 - Qt Info: Processing new PC "Navid-PC.local." from mDNS with local address "192.168.4.78:47989"
00:00:04 - Qt Info: getServerInfo response: "...status_code=\"200\"...<PairStatus>0</PairStatus>..."
```

Host discovered at 2s, HTTP serverinfo returned 200. No mDNS regression.

---

## 6. Tier 2 — escape hatch confirms reversion to test3 behavior

`VIBEMIS_SKIP_HOST_LIBVA=1`:

```
# Hook absent (correct):
grep "vibemis-apprun-hook" /tmp/vibemis-run-test5-skipped.log → (no output)

# libva errors — identical to test3:
libva error: /usr/lib64/dri/radeonsi_drv_video.so has no function __vaDriverInit_1_0
libva error: /usr/lib/dri/radeonsi_drv_video.so has no function __vaDriverInit_1_0
```

The escape hatch still functions. The surgical hook is the sole differentiator between working VAAPI and the original failure.

---

## 7. Recommendation

**Merge PR #4.** All goals verified on target hardware:

- VAAPI initialises with Mesa 25.3.0 / libva 1.22 — the `__vaDriverInit_1_22` gap is bridged.
- Qt platform plugins unaffected — the surgical temp-dir approach correctly isolates the libva override from the rest of the library search order.
- mDNS discovery unchanged.
- Escape hatch (`VIBEMIS_SKIP_HOST_LIBVA=1`) intact.

One minor note: the `VAAPI driver is affected by RFI latency bug` warning is a known Mesa advisory (not specific to this fix) and does not affect correctness. Hardware decode is functional.

---

## Artifacts

| File | Lines | Size | Notes |
|---|---|---|---|
| `/tmp/vibemis-run-test5.log` | 568 | 49 KB | Tier 1 default — full run, no crash |
| `/tmp/vibemis-run-test5-skipped.log` | 171 | 13 KB | Tier 2 VIBEMIS_SKIP_HOST_LIBVA=1 — test3 reversion confirmed |
| `/tmp/vibemis-libva-test5.230457.thd-0x00004c28` | — | 2.4 KB | Tier 1 libva trace thread 1: vaInitialize SUCCESS, surface creation, DRM PRIME export |
| `/tmp/vibemis-libva-test5.230458.thd-0x00004c28` | — | 44 KB | Tier 1 libva trace thread 2: full decode context trace |
