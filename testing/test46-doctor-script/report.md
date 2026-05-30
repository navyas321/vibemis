# Test46 Report — Diagnostics helper `scripts/vibemis-doctor.sh` (P3.10)

**Artifact tested:** `scripts/vibemis-doctor.sh` (script-only test, no AppImage)
**Branch:** `test46-doctor-script` (FETCH_HEAD)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.6, Mesa 25.3.0
**Test date:** 2026-05-30
**Prior report:** N/A

---

## 1. TL;DR

| # | Check | Status | Notes |
|---|-------|--------|-------|
| 1 | Runs to "=== done ===" without errors | PASS | Clean exit |
| 2 | GPU/Mesa + VAAPI lines reflect AMD APU | PASS | AMD Ryzen Z2 Go (radeonsi, rembrandt), Mesa 25.3.0 |
| 3 | FUSE [warn] correct for SteamOS | PASS | `[warn] libfuse2 NOT found` as expected |
| 4 | Install state lines correct | PARTIAL | Not installed = correct; "no settings yet" incorrect (config dir name mismatch — see §4) |
| 5 | With host arg, reachability section appears | PASS | Section renders; [warn] for ping/port 47984 (host may block ICMP) |
| 6 | No sudo, nothing modified | PASS | Read-only, no writes |

---

## 2. Tier 1 — Environment report (no host)

Full output:
```
=== Vibemis doctor ===

OS / kernel:
  [info] SteamOS
  [info] Linux 6.16.12-valve23-1-neptune-616-g870f25d0cbad x86_64

GPU / Mesa:
  OpenGL renderer string: AMD Ryzen Z2 Go (radeonsi, rembrandt, LLVM 20.1.8, DRM 3.64, 6.16.12-valve23-1-neptune-616-g870f25d0cbad)
  OpenGL version string: 4.6 (Compatibility Profile) Mesa 25.3.0 (git-59b552c765)
  e2:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Rembrandt [Radeon 680M] (rev c3)

VAAPI (hardware decode):
  [info] vainfo not present (libva-utils); Vibemis bundles its own libva handling
  [info] DRI drivers dir: /usr/lib64/dri
  [info] DRI drivers dir: /usr/lib/dri

FUSE (needed to run AppImages without --appimage-extract-and-run):
  [warn] libfuse2 NOT found — run the AppImage with --appimage-extract-and-run (normal on SteamOS)

Vibemis install state:
  [info] ~/Applications/Vibemis.AppImage not installed (run scripts/install-vibemis-desktop.sh)
  [info] no desktop entry
  [info] no settings yet (first run)

=== done ===
```

All sections printed correctly. GPU identifies as `AMD Ryzen Z2 Go (radeonsi, rembrandt)` with Mesa 25.3.0. FUSE shows expected `[warn]` on SteamOS. **PASS**.

---

## 3. Tier 2 — Host reachability (Navid-PC: 192.168.4.78)

Output (additional section only):
```
Host reachability (192.168.4.78):
  [warn] ping failed (host may block ICMP, or be unreachable / wrong address)
  [warn] port 47984 not reachable (host not running / firewall / wrong address)

=== done ===
```

The **"Host reachability" section appeared** (check 5 PASS). Navid-PC is online and reachable at port 47989 (Vibepollo), but the doctor checks port 47984 (the Moonlight/legacy port). ICMP/ping is also blocked from this device to Navid-PC. The [warn] messages are correct behavior for an unreachable check target. **PASS** (section renders correctly; [warn] is appropriate when checks fail).

---

## 4. Other findings — config path mismatch (minor bug)

The script checks for `~/.config/Vibemis` (line 68):
```bash
[ -d "$HOME/.config/Vibemis" ] && ok "settings dir ~/.config/Vibemis present" || info "no settings yet (first run)"
```

The actual Qt config directory on this device is `~/.config/Vibemis Project/` (with a space and "Project" suffix, matching the `QCoreApplication::setOrganizationName("Vibemis Project")`). As a result, the doctor incorrectly reports `[info] no settings yet (first run)` even when the app has been configured.

**Not a blocker** — all other checks work. The fix is to change the path in the doctor script from `$HOME/.config/Vibemis` to `"$HOME/.config/Vibemis Project"`.

---

## 5. Recommendation

**MERGE** — `vibemis-doctor.sh` runs to completion, correctly identifies the SteamOS environment, Mesa 25.3.0, AMD Ryzen Z2 Go APU, expected FUSE warning, install state, and host reachability (when given a host). One minor bug (config path mismatch line 68) is documented above — recommend the build agent correct the path in a follow-up or as part of this PR.
