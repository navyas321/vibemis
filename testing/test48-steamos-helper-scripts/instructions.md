# Test48 Instructions — SteamOS helper scripts bundle (P3.2 + P3.10)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Verify the bundle of `scripts/` SteamOS helpers. This **consolidates** the previously
separate script test cycles (test30/38/42/43/44/45/46) into one — same scripts, one PR.

**Script-only cycle.** Mostly Desktop Mode, no sudo. Some steps need a paired host/network.

---

## Setup

```bash
cd ~/vibemis
git fetch origin test48-steamos-helper-scripts
git checkout test48-steamos-helper-scripts && git pull
chmod +x scripts/*.sh
APPIMAGE=$(ls -1 testing/test*/Vibemis*.AppImage | tail -1)   # any existing AppImage
```

## The scripts & quick checks

1. **install-vibemis-desktop.sh** — `./scripts/install-vibemis-desktop.sh "$APPIMAGE"` →
   creates `~/Applications/Vibemis.AppImage` + `vibemis.desktop` (Name=Vibemis). Appears as
   "Vibemis" in the launcher / Add-to-Steam.
2. **vibemis-update.sh** — `./scripts/vibemis-update.sh --check` prints the latest release tag +
   AppImage URL; without `--check` it downloads to `~/Applications/Vibemis.AppImage`.
3. **add-game-to-steam.sh** — `./scripts/add-game-to-steam.sh "MyHost" "Desktop"` →
   `~/.local/share/applications/vibemis-game-desktop.desktop` with `Exec=… stream "MyHost" "Desktop"`.
4. **add-all-games-to-steam.sh** — `./scripts/add-all-games-to-steam.sh "<paired-host>"` (dry run)
   lists the host's apps; `--confirm` creates a launcher per app. **Report the raw list output** so
   the parser can be confirmed.
5. **pair-host.sh** — `./scripts/pair-host.sh "<host>"` runs the pair CLI + shows the PIN
   (only run with a host you may pair).
6. **uninstall-vibemis-desktop.sh** — dry-run lists what it'd remove; `--yes` removes the
   AppImage + .desktop entries + icon (keeps Steam shortcuts + settings).
7. **vibemis-doctor.sh** — `./scripts/vibemis-doctor.sh [host]` prints env diagnostics
   (GPU/Mesa, VAAPI, FUSE, install state, optional host reachability). **Paste its output.**

## What to check and report

| # | Script | Check | Expected |
|---|--------|-------|----------|
| 1 | install | clean Name=Vibemis desktop entry + ~/Applications AppImage | Yes |
| 2 | update --check | prints latest tag + URL; download works | Yes |
| 3 | add-game | correct Exec/quoting/slug `.desktop` | Yes |
| 4 | add-all (dry) | parsed app names match host (report raw output) | report |
| 5 | pair | usage/error handling; (optional) shows PIN | Yes |
| 6 | uninstall | dry-run lists; --yes removes; settings kept | Yes |
| 7 | doctor | runs clean; paste output | Yes |
| 8 | all | bash; no sudo; only ~/.local & ~/Applications touched | Yes |

## Report format
Commit `testing/test48-steamos-helper-scripts/report.md` on
`diagnostic/test48-steamos-helper-scripts-report`; PR targets the test branch.

## Safety rules (standing)
- No package installs, no `sudo`. Only pair with a permitted host.
