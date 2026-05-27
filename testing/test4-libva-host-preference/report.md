# Test4 Report — `LD_LIBRARY_PATH` prefer-host-libva fix on Legion Go S Z2

**Artifact tested:** `Vibemis-0.6.7-vibemis-test4-libva-host-pref-x86_64.AppImage`
**md5:** `b8c4e4f4c094b07e75032645dfcd53d9` ✓ verified
**Branch:** `fix/appimage-vaapi-driver-paths` (commit 785c5bd1)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0, Qt system 6.9.1 / bundled 6.4.2
**Test date:** 2026-05-27
**Prior report:** `DIAGNOSTIC_REPORT_test3.md` (PR #6)

---

## 1. Headline TL;DR

| Goal | Status | Summary |
|---|---|---|
| **Goal A — HW decode works (VAAPI warning gone)** | **FAIL — new crash** | Tier 1 (default) aborts with Qt Fatal before reaching the Computers screen. The `LD_LIBRARY_PATH` prepend is too broad: system Qt 6.9.1 gets loaded instead of bundled Qt 6.4.2, breaking platform plugins. |
| **Goal B — no regression vs test3 elsewhere** | **N/A** | App never reaches the Computers screen in Tier 1. Tier 2 (control) confirms mDNS and everything else are intact under the old code path. |

---

## 2. Default run — "preferring host libva" line present?

**Yes.** The hook fired on the very first line of output:

```
[vibemis-apprun-hook] preferring host libva.so.2 from /usr/lib64
```

`/usr/lib64/libva.so.2` (system, 1.22.0) exists on this device, so the hook matched on its first candidate and prepended `/usr/lib64` to `LD_LIBRARY_PATH`. The escape hatch was not set.

---

## 3. Default run — libva errors / VA init status

**Not reached.** The app crashed at Qt platform plugin initialization before libva was ever probed. There are no `libva error` or `vaInitialize` lines in `/tmp/vibemis-run-test4.log` — the log is only 31 lines and ends with a Qt Fatal.

Full Tier 1 log (31 lines):
```
[vibemis-apprun-hook] preferring host libva.so.2 from /usr/lib64
00:00:00 - Qt Debug: Got keys from plugin meta data QList("xcb")
00:00:00 - Qt Debug: Ignoring QPA plugin due to mismatching Qt versions 395520 394240
00:00:00 - Qt Debug: checking directory path "/tmp/.mount_VibemieBCNpi/usr/bin/platforms" ...
00:00:00 - Qt Debug: Attempting to load Qt platform plugin "wayland" with arguments QList()
00:00:00 - Qt Warning: Could not find the Qt platform plugin "wayland" in ""
00:00:00 - Qt Debug: Attempting to load Qt platform plugin "xcb" with arguments QList()
00:00:00 - Qt Warning: Could not find the Qt platform plugin "xcb" in ""
00:00:00 - Qt Fatal: This application failed to start because no Qt platform plugin
           could be initialized. Reinstalling the application may fix this problem.
```

Root cause decoded:
- `395520` → Qt 6.9.0 (the version loaded at runtime = **system** libQt6Core from `/usr/lib64/libQt6Core.so.6.9.1`)
- `394240` → Qt 6.4.0 (the version the bundled xcb platform plugin was compiled against = **bundled** Qt 6.4.2)

The hook prepends `/usr/lib64` to `LD_LIBRARY_PATH`. Because `artemis` uses `DT_RUNPATH` (not `DT_RPATH`), `LD_LIBRARY_PATH` takes precedence in the linker — so system `libQt6Core.so.6.9.1` gets loaded before the bundled `libQt6Core.so.6.4.2`. System Qt 6.9 fails to find the bundled xcb plugin (built for 6.4) and has no compatible system fallback it can locate with the current `QT_PLUGIN_PATH`. Fatal.

---

## 4. Default run — mDNS discovery

Not reached (crash before Qt event loop starts).

---

## 5. Default run — "No functioning HW decoder" warning present or absent?

Not reached (crash before any streaming logic runs).

---

## 6. Skipped run — control confirms test3 behavior

`VIBEMIS_SKIP_HOST_LIBVA=1` run behaves exactly as test3:

```
# Hook absent (correct):
# grep "preferring host libva" /tmp/vibemis-run-test4-skipped.log → (no output)

# libva errors (identical to test3):
libva error: /usr/lib64/dri/radeonsi_drv_video.so has no function __vaDriverInit_1_0
libva error: /usr/lib/dri/radeonsi_drv_video.so has no function __vaDriverInit_1_0
# (repeated ~5× as in test3)

# SDL VAAPI result:
00:00:01 - SDL Warn (0): Skipping VAAPI fallback driver names due to LIBVA_DRIVER_NAME
00:00:01 - SDL Error (0): Failed to initialize VAAPI: -1
00:00:01 - SDL Info (0): 'VAAPI' failed to initialize. It will not be tried again.
```

libva trace (both threads, identical to test3):
```
[ctx none]==========va_TraceInitialize
[ctx none]=========vaInitialize ret = VA_STATUS_ERROR_UNKNOWN, unknown libva error
[ctx none]==========va_TraceTerminate
[ctx none]=========vaTerminate ret = VA_STATUS_SUCCESS, success (no error)
```

mDNS in the skipped run still works:
```
00:00:03 - Qt Info: Discovered mDNS host: "Navid-PC.local."
00:00:05 - Qt Info: Processing new PC "Navid-PC.local." from mDNS with local address "192.168.4.78:47989"
```

The escape hatch functions as designed. The skipped run is a clean control sample.

---

## 7. Other unexpected log lines

**System Qt version conflict is the only new finding.** Not unexpected given the mechanism, but worth stating clearly:

- System `libQt6Core.so.6` at `/usr/lib64/` is **6.9.1** on this SteamOS 3.8.5 device.
- Bundled Qt (from the AppImage linuxdeployqt bundle) is **6.4.2**.
- These are a full five minor versions apart; SteamOS ships a newer Qt than the AppImage was built against.
- System Qt 6.9 plugins exist at `/usr/lib64/qt6/plugins/platforms/` (libqxcb.so, libqwayland-*.so confirmed present), but the app's `QT_PLUGIN_PATH` is not configured to reach them — and even if it were, mixing system Qt 6.9 plugin binaries with an app compiled against Qt 6.4 would likely fail too.

No other unexpected lines in either run beyond what was present in test3.

---

## 8. Root cause — Goal A still failing

The test4 fix correctly identifies the mechanism (system libva via `LD_LIBRARY_PATH` wins over bundled libva because `DT_RUNPATH` loses to `LD_LIBRARY_PATH`) and the diagnostic output proves the hook fires. The implementation of the fix is **too broad**: prepending a whole system lib directory overrides not just libva but also Qt and potentially other libs the AppImage bundles for its own ABI stability.

On this device, the collision is:
```
/usr/lib64/libQt6Core.so.6.9.1  ← system, surfaced by LD_LIBRARY_PATH prepend
vs.
$APPIMAGE_MOUNT/usr/lib/libQt6Core.so.6.4.2  ← bundled, normally loaded via RUNPATH
```

The fix needs to be **surgical**: override only the three libva shared objects (`libva.so.2`, `libva-drm.so.2`, `libva-x11.so.2`), leaving everything else in the AppImage's RUNPATH-resolved paths.

---

## 9. Recommended next step — test5 patch

**Do not merge PR #4 as-is.** Replace the `LD_LIBRARY_PATH` prepend block in `01-libva-driver-paths.sh` with one of these two approaches:

### Option A — temp-dir symlink (recommended)

Creates a throwaway directory containing only the three libva symlinks, then prepends that directory. Surgical: only libva gets overridden; Qt, SDL2, and everything else still resolve from the AppImage RUNPATH.

```bash
if [ -z "$VIBEMIS_SKIP_HOST_LIBVA" ]; then
    for _v_d in /usr/lib64 /usr/lib/x86_64-linux-gnu /usr/lib; do
        if [ -e "$_v_d/libva.so.2" ]; then
            _v_tmp=$(mktemp -d)
            for _v_so in libva.so.2 libva-drm.so.2 libva-x11.so.2; do
                [ -e "$_v_d/$_v_so" ] && ln -sf "$_v_d/$_v_so" "$_v_tmp/"
            done
            export LD_LIBRARY_PATH="$_v_tmp${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
            echo "[vibemis-apprun-hook] preferring host libva.so.2 from $_v_d (via $_v_tmp)" 1>&2
            unset _v_tmp _v_so
            break
        fi
    done
    unset _v_d
fi
```

### Option B — LD_PRELOAD (simpler, slightly less targeted)

Preloads just the libva objects. Bypasses linker search order entirely for these three files. No temp dir needed.

```bash
if [ -z "$VIBEMIS_SKIP_HOST_LIBVA" ]; then
    for _v_d in /usr/lib64 /usr/lib/x86_64-linux-gnu /usr/lib; do
        if [ -e "$_v_d/libva.so.2" ]; then
            _v_preload="$_v_d/libva.so.2"
            [ -e "$_v_d/libva-drm.so.2" ] && _v_preload="$_v_preload:$_v_d/libva-drm.so.2"
            [ -e "$_v_d/libva-x11.so.2"  ] && _v_preload="$_v_preload:$_v_d/libva-x11.so.2"
            export LD_PRELOAD="${_v_preload}${LD_PRELOAD:+:$LD_PRELOAD}"
            echo "[vibemis-apprun-hook] preloading host libva from $_v_d" 1>&2
            unset _v_preload
            break
        fi
    done
    unset _v_d
fi
```

Option A is preferred because `LD_PRELOAD` applies to every subprocess the app spawns (a minor hygiene concern) and some security policies strip it. Option A's temp dir is cleaned when the FUSE mount unmounts.

---

## 10. Artifact paths

| File | Lines | Size | Notes |
|---|---|---|---|
| `/tmp/vibemis-run-test4.log` | 31 | 1.6 KB | Tier 1 (default): crash at Qt platform init |
| `/tmp/vibemis-run-test4-skipped.log` | 190 | 16 KB | Tier 2 (VIBEMIS_SKIP_HOST_LIBVA=1): test3-identical behavior |
| `/tmp/vibemis-libva-test4-skipped.log.184154.thd-*` | 4 | — | Tier 2 libva trace thread 1: `VA_STATUS_ERROR_UNKNOWN` |
| `/tmp/vibemis-libva-test4-skipped.log.184155.thd-*` | 4 | — | Tier 2 libva trace thread 2: `VA_STATUS_ERROR_UNKNOWN` |
| No Tier 1 libva trace | — | — | App crashed before libva was probed; no trace file produced |
