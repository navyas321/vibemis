# Test5 Instructions — Surgical libva symlink fix

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.8.5)
**Prior report:** `testing/test4-libva-host-preference/report.md` (PR diagnostic/test4-libva-host-pref-report)
**Goal:** Verify that the revised apprun-hook (temp-dir symlink, surgical libva-only override) resolves the VAAPI hardware decode warning **without** the Qt platform plugin crash seen in test4.

---

## Background

Test4 confirmed the LD_LIBRARY_PATH prepend approach fires correctly (`[vibemis-apprun-hook] preferring host libva.so.2 from /usr/lib64`) but is too broad: prepending `/usr/lib64` surfaces system Qt 6.9.1 ahead of the AppImage-bundled Qt 6.4.2, crashing at platform plugin init with:

```
Qt Fatal: "Ignoring QPA plugin due to mismatching Qt versions 395520 394240"
```

Test5 replaces the whole-dir prepend with a temp-dir containing **only symlinks to the three libva shared objects** (`libva.so.2`, `libva-drm.so.2`, `libva-x11.so.2`). The temp-dir is prepended to `LD_LIBRARY_PATH` instead — everything except libva still resolves from the AppImage's `DT_RUNPATH`.

---

## Artifact

**AppImage:** `testing/test5-libva-surgical-symlink/Vibemis-0.6.7-vibemis-test5-libva-surgical-x86_64.AppImage`
(This file will be committed to the repo on the `fix/appimage-vaapi-driver-paths` branch before this test cycle begins. Run `git pull` to receive it.)

**md5:** `db7878509c27ed7e9d76d07c08700641`

Verify before running:
```bash
md5sum testing/test5-libva-surgical-symlink/Vibemis-0.6.7-vibemis-test5-libva-surgical-x86_64.AppImage
# must match the md5 listed above
```

---

## Test procedure

### Setup

```bash
cd ~/vibemis   # or wherever you cloned the repo
git fetch origin fix/appimage-vaapi-driver-paths
git checkout fix/appimage-vaapi-driver-paths
git pull
# confirm the AppImage is present
ls -lh testing/test5-libva-surgical-symlink/
```

Make the AppImage executable:
```bash
chmod +x testing/test5-libva-surgical-symlink/Vibemis-0.6.7-vibemis-test5-libva-surgical-x86_64.AppImage
```

### Tier 1 — default run (surgical hook active)

```bash
LIBVA_TRACE=/tmp/vibemis-libva-test5 \
  ./testing/test5-libva-surgical-symlink/Vibemis-0.6.7-vibemis-test5-libva-surgical-x86_64.AppImage \
  > /tmp/vibemis-run-test5.log 2>&1 &
APP_PID=$!
sleep 15
kill $APP_PID 2>/dev/null; wait $APP_PID 2>/dev/null
```

### Tier 2 — control run (escape hatch, should replicate test4 Tier 2 / test3)

```bash
VIBEMIS_SKIP_HOST_LIBVA=1 \
  ./testing/test5-libva-surgical-symlink/Vibemis-0.6.7-vibemis-test5-libva-surgical-x86_64.AppImage \
  > /tmp/vibemis-run-test5-skipped.log 2>&1 &
APP_PID=$!
sleep 15
kill $APP_PID 2>/dev/null; wait $APP_PID 2>/dev/null
```

---

## What to check and report

For **Tier 1 (default)**:

1. **No Qt crash** — confirm there is NO `Qt Fatal` / `mismatching Qt versions` line:
   ```bash
   grep -i "Qt Fatal\|mismatching Qt\|failed to start" /tmp/vibemis-run-test5.log || echo "(no Qt crash — good)"
   ```

2. **Hook diagnostic line** — the new format should reference a temp dir:
   ```bash
   grep "vibemis-apprun-hook" /tmp/vibemis-run-test5.log
   # Expected: [vibemis-apprun-hook] preferring host libva from /usr/lib64 (via /tmp/tmp.XXXXXX)
   ```

3. **VAAPI result** — did the hardware decoder initialize successfully?
   ```bash
   grep -i "vaapi\|vaInitialize\|hardware accelerated\|VDPAU\|No functioning" /tmp/vibemis-run-test5.log | head -20
   ```
   - **Pass:** no "No functioning hardware accelerated video decoder" warning, and/or VAAPI initializes with no error.
   - **Fail:** same error as test3/test4-skipped (`__vaDriverInit_1_0` errors, `VA_STATUS_ERROR_UNKNOWN`).

4. **App reaches Computers screen** — did the app actually start and show the Computers screen (even briefly)?
   ```bash
   grep -i "Discovered mDNS\|Processing new PC\|Navid-PC" /tmp/vibemis-run-test5.log
   ```

5. **Libva trace** — what did libva actually do?
   ```bash
   ls -la /tmp/vibemis-libva-test5* 2>/dev/null
   cat /tmp/vibemis-libva-test5* 2>/dev/null | head -30
   ```

For **Tier 2 (VIBEMIS_SKIP_HOST_LIBVA=1)**:

6. **Hook absent** — no hook diagnostic line:
   ```bash
   grep "vibemis-apprun-hook" /tmp/vibemis-run-test5-skipped.log || echo "(hook absent — correct)"
   ```

7. **Matches test3/test4 behavior** — same `__vaDriverInit_1_0` errors, same mDNS discovery at ~3s.

---

## Report format

Commit `testing/test5-libva-surgical-symlink/report.md` on branch `diagnostic/test5-libva-surgical-report` and open a PR (or push to the same `diagnostic/test5-libva-surgical-report` branch if a PR already exists).

**Required sections in the report:**
1. TL;DR table (Goal A: no Qt crash, Goal B: VAAPI works, Goal C: mDNS regression-free)
2. Tier 1 — hook output (exact text of the diagnostic line)
3. Tier 1 — Qt crash present or absent (critical gate)
4. Tier 1 — VAAPI result (pass/fail with log excerpt)
5. Tier 1 — mDNS (Navid-PC.local. found or not)
6. Tier 2 — confirms escape hatch still works
7. Recommendation (merge PR #4, iterate, or escalate)

Keep the report under ~150 lines. Full log files stay in `/tmp/` on the device; only relevant excerpts go in the report.

---

## Safety rules (standing)

- Do not install any packages or modify the system.
- Do not run with `sudo`.
- Do not modify the AppImage.
- If the app asks to pair with a host or requests network access, that is expected and safe — the app is designed to stream games over LAN.
- If Navid-PC.local. appears in the Computers screen, do NOT attempt to pair or start a stream in this test cycle — this test only checks decoder initialization, not streaming.
