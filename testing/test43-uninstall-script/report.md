# Test43 Report — Uninstall/desktop-cleanup `scripts/uninstall-vibemis-desktop.sh` (P3.10)

**Artifact tested:** `scripts/uninstall-vibemis-desktop.sh` (script-only test, no AppImage)
**Branch:** `test43-uninstall-script` (FETCH_HEAD)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.6, Mesa 25.3.0
**Test date:** 2026-05-30
**Prior report:** N/A (depends on test30 + test38 scripts having created desktop entries)

---

## 1. TL;DR

| # | Check | Status | Notes |
|---|-------|--------|-------|
| 1 | Dry run lists targets, deletes nothing | PASS | 5 files listed; all still present after dry run |
| 2 | `--yes` removes AppImage + .desktop entries + game launchers + icon | PASS | All 5 removed with `removed:` prefix |
| 3 | Settings (`~/.config/Vibemis Project/`) preserved | PASS | Dir still exists after uninstall |
| 4 | Re-run → "Nothing to remove", exit 0 | PASS | Exact message; exit=0 |
| 5 | No sudo | PASS | Comment + grep confirm |

---

## 2. Setup — files created (test30 + test38)

Before running the uninstall script, the following files existed (created by
`install-vibemis-desktop.sh` and `add-game-to-steam.sh` in the test30/38 runs):

```
~/Applications/Vibemis.AppImage (87 MB, rwx--x--x)
~/.local/share/applications/vibemis.desktop
~/.local/share/applications/vibemis-game-big-picture.desktop
~/.local/share/applications/vibemis-game-desktop.desktop
~/.local/share/icons/hicolor/256x256/apps/vibemis.png
```

---

## 3. Tier 1 — Dry run

```
$ ./scripts/uninstall-vibemis-desktop.sh
These would be removed (re-run with --yes to delete):
  /home/deck/Applications/Vibemis.AppImage
  /home/deck/.local/share/applications/vibemis.desktop
  /home/deck/.local/share/applications/vibemis-game-big-picture.desktop
  /home/deck/.local/share/applications/vibemis-game-desktop.desktop
  /home/deck/.local/share/icons/hicolor/256x256/apps/vibemis.png

Note: this does not remove Steam shortcuts or your settings (~/.config/Vibemis).
```

All 5 targets listed correctly. All files verified still present after dry run. **PASS**.

---

## 4. Tier 2 — Actual removal

```
$ ./scripts/uninstall-vibemis-desktop.sh --yes
removed: /home/deck/Applications/Vibemis.AppImage
removed: /home/deck/.local/share/applications/vibemis.desktop
removed: /home/deck/.local/share/applications/vibemis-game-big-picture.desktop
removed: /home/deck/.local/share/applications/vibemis-game-desktop.desktop
removed: /home/deck/.local/share/icons/hicolor/256x256/apps/vibemis.png
Done. (Remove any Vibemis Steam shortcuts from Steam manually; settings kept.)
```

All 5 files removed. `~/Applications/Vibemis.AppImage` → `No such file or directory`.
`~/.local/share/applications/vibemis*.desktop` → no matches. **PASS**.

Settings preserved: `~/.config/Vibemis Project/` still exists. **PASS**.

---

## 5. Tier 3 — Nothing to remove

```
$ ./scripts/uninstall-vibemis-desktop.sh
Nothing to remove — no Vibemis desktop integration found.
$ echo $?
0
```

Clean exit with informative message when nothing installed. **PASS**.

---

## 6. Recommendation

**MERGE** — `uninstall-vibemis-desktop.sh` correctly lists targets in dry-run mode, removes all
integration files with `--yes`, preserves user settings, and exits cleanly with "Nothing to remove"
on re-run. No sudo. Only `~/Applications/` and `~/.local/share/` touched. Works correctly with
files created by both `install-vibemis-desktop.sh` (test30) and `add-game-to-steam.sh` (test38).
