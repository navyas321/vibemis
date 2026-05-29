# Test43 Instructions — Uninstall/desktop-cleanup helper (P3.10)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Verify `scripts/uninstall-vibemis-desktop.sh` lists (dry run) and removes (`--yes`) the
desktop entries / installed AppImage created by the install + add-game scripts.

**Script-only cycle.** Desktop Mode. No streaming/host needed.

---

## Setup

```bash
cd ~/vibemis
git fetch origin test43-uninstall-script
git checkout test43-uninstall-script && git pull
chmod +x scripts/uninstall-vibemis-desktop.sh scripts/install-vibemis-desktop.sh scripts/add-game-to-steam.sh
```

Create some integration to remove (from earlier test cycles' scripts):
```bash
APPIMAGE=$(ls -1 testing/test*/Vibemis*.AppImage | tail -1)
./scripts/install-vibemis-desktop.sh "$APPIMAGE"
./scripts/add-game-to-steam.sh "MyHost" "Desktop"
```

## Tier 1 — Dry run

```bash
./scripts/uninstall-vibemis-desktop.sh
```
Confirm it **lists** (without deleting) `~/Applications/Vibemis.AppImage`, `vibemis.desktop`,
`vibemis-game-desktop.desktop`, and the icon, and notes it won't touch Steam/settings.
Verify nothing was deleted:
```bash
ls ~/Applications/Vibemis.AppImage ~/.local/share/applications/vibemis*.desktop
```

## Tier 2 — Actual removal

```bash
./scripts/uninstall-vibemis-desktop.sh --yes
```
Confirm it prints `removed: …` for each, and the files are gone:
```bash
ls ~/Applications/Vibemis.AppImage 2>&1            # should be: No such file
ls ~/.local/share/applications/vibemis*.desktop 2>&1
```
Confirm settings are **kept**: `ls -d ~/.config/Vibemis` still exists.

## Tier 3 — Nothing to remove

1. Run it again → prints "Nothing to remove" and exits 0.

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | Dry run lists targets, deletes nothing | Yes |
| 2 | `--yes` removes AppImage + .desktop + game launchers + icon | Yes |
| 3 | Settings (~/.config/Vibemis) preserved | Yes |
| 4 | Re-run → "Nothing to remove", exit 0 | Yes |
| 5 | No sudo | Yes |

## Report format
Commit `testing/test43-uninstall-script/report.md` on `diagnostic/test43-uninstall-script-report`;
PR targets the test branch.

## Safety rules (standing)
- No package installs, no `sudo`. Only ~/Applications and ~/.local touched.
