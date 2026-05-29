# Test46 Instructions — Diagnostics helper (P3.10)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Verify `scripts/vibemis-doctor.sh` runs read-only environment checks and reports useful
diagnostics (Mesa/GPU, VAAPI, FUSE, install state, optional host reachability).

**Script-only cycle.** Read-only, no sudo, no changes.

---

## Setup

```bash
cd ~/vibemis
git fetch origin test46-doctor-script
git checkout test46-doctor-script && git pull
chmod +x scripts/vibemis-doctor.sh
```

## Tier 1 — Environment report

```bash
./scripts/vibemis-doctor.sh
```
Confirm it prints sections without crashing: OS/kernel, GPU/Mesa, VAAPI, FUSE, Vibemis install
state. Each line is `[ok]/[warn]/[info]`. On SteamOS, FUSE is likely `[warn] libfuse2 NOT found`
(expected) and VAAPI/GPU should reflect the AMD APU.

## Tier 2 — Host reachability (optional)

```bash
./scripts/vibemis-doctor.sh <your-host-ip-or-name>
```
Confirm it adds a "Host reachability" section (ping + port 47984 check).

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | Runs to "=== done ===" without errors | Yes |
| 2 | GPU/Mesa + VAAPI lines reflect the AMD APU | Yes |
| 3 | FUSE line correct for SteamOS (warn = no libfuse2) | Yes |
| 4 | Install-state lines correct | Yes |
| 5 | With a host arg, reachability section appears | Yes |
| 6 | No sudo, nothing modified | Yes |

**Please paste the full doctor output** — it's a useful baseline for the device's environment.

## Report format
Commit `testing/test46-doctor-script/report.md` on `diagnostic/test46-doctor-script-report`;
PR targets the test branch.

## Safety rules (standing)
- Read-only checks only; no package installs, no `sudo`.
