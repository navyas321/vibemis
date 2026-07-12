# Test41 Instructions — Settings export / import (P3.11)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Verify Settings can be exported to a portable file and imported back.

**No stream/host needed** — launcher-UI check.

---

## Artifact

**AppImage:** `testing/test41-settings-export-import/Vibemis-0.6.7-vibemis-test41-settings-export-import-x86_64.AppImage`
**md5:** `ad925beaf9cf2d15d358ceb5cf95450d`

```bash
md5sum testing/test41-settings-export-import/*.AppImage
```

## Setup

```bash
cd ~/vibemis
git fetch origin test41-settings-export-import
git checkout test41-settings-export-import && git pull
chmod +x testing/test41-settings-export-import/*.AppImage
./testing/test41-settings-export-import/*.AppImage --appimage-extract-and-run &
```

## Tier 1 — Export

1. In Settings, change something memorable (e.g. set a specific resolution/FPS or toggle a checkbox).
2. Scroll to the **"Settings backup"** row (in the same group as "Keep the display awake").
3. Click **Export settings**. A cyan status line shows `Exported to /home/.../vibemis-settings.ini`.
4. Confirm the file exists and contains your values:
   ```bash
   ls -l ~/vibemis-settings.ini && head -20 ~/vibemis-settings.ini
   ```

## Tier 2 — Import

1. Change a setting to something different from what you exported.
2. Click **Import settings**. Status shows `Imported from ~/vibemis-settings.ini — reopen Settings or restart…`.
3. **Reopen Settings** (back out and in) or restart the app — confirm the imported values are now in effect
   (matching what you exported in Tier 1).
4. With no backup present (`rm ~/vibemis-settings.ini`), Import shows `No backup found…` and changes nothing.

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | "Export settings" writes ~/vibemis-settings.ini with current values | Yes |
| 2 | Export status path shown | Yes |
| 3 | Import restores exported values (after reopen/restart) | Yes |
| 4 | Import with no file → clear "No backup found" message, no change | Yes |
| 5 | No regression elsewhere in Settings | Yes |

Note: imported values may not refresh live in the open Settings page (known limitation) — they take
effect after reopening Settings / restart and on the next stream. Report whether that matches.

## Report format
Commit `testing/test41-settings-export-import/report.md` on
`diagnostic/test41-settings-export-import-report`; PR targets the test branch.

## Safety rules (standing)
- No package installs, no `sudo`. The feature only reads/writes ~/vibemis-settings.ini.
