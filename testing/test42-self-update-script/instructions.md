# Test42 Instructions — Self-update helper (P3.10)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Verify `scripts/vibemis-update.sh` finds the latest GitHub release AppImage and
(optionally) downloads it to `~/Applications/Vibemis.AppImage`.

**Script-only cycle** (no new AppImage). Needs network. **No streaming/host needed.**

---

## Setup

```bash
cd ~/vibemis
git fetch origin test42-self-update-script
git checkout test42-self-update-script && git pull
chmod +x scripts/vibemis-update.sh
```

## Tier 1 — Check (no download)

```bash
./scripts/vibemis-update.sh --check
```
Confirm it prints `Latest release: <tag>` and an `AppImage: https://...AppImage` URL (no download).

## Tier 2 — Download

```bash
./scripts/vibemis-update.sh
```
Confirm:
1. It downloads with a progress bar and prints `Done. Updated ~/Applications/Vibemis.AppImage to <tag>`.
2. The file exists, is executable, and runs:
   ```bash
   ls -l ~/Applications/Vibemis.AppImage
   ~/Applications/Vibemis.AppImage --appimage-extract-and-run &   # should launch Vibemis
   ```

## Tier 3 — Error handling

1. (Optional) Temporarily disable network → script prints a clear "failed to query / network" error, non-zero exit, and does not leave a partial file in ~/Applications.

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | `--check` prints latest tag + AppImage URL | Yes |
| 2 | Download writes an executable ~/Applications/Vibemis.AppImage | Yes |
| 3 | Downloaded AppImage launches | Yes |
| 4 | Offline → clean error, no partial file | Yes |
| 5 | No sudo used | Yes |

Report SteamOS version and the release tag it found.

## Report format
Commit `testing/test42-self-update-script/report.md` on
`diagnostic/test42-self-update-script-report`; PR targets the test branch.

## Safety rules (standing)
- No package installs, no `sudo`. Downloads only to ~/Applications.
