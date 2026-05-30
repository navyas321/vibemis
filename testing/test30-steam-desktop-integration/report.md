# Test30 Report — Steam/desktop integration helper `scripts/install-vibemis-desktop.sh` (P3.2)

**Artifact tested:** `scripts/install-vibemis-desktop.sh` (script-only test, no AppImage)
**Branch:** `test30-steam-desktop-integration` (FETCH_HEAD)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.6, Mesa 25.3.0
**Test date:** 2026-05-30
**Prior report:** N/A (test48 was a syntax-only bundle check; this is functional verification)

---

## 1. TL;DR

| # | Check | Status | Notes |
|---|-------|--------|-------|
| 1 | Script runs without error, no sudo | PASS | No `sudo`/`pkexec` in script |
| 2 | `~/Applications/Vibemis.AppImage` present + executable | PASS | 87 MB, `rwx--x--x` |
| 3 | `vibemis.desktop` has `Name=Vibemis` | PASS | Confirmed via `cat` |
| 4 | Icon extracted | PASS | `~/.local/share/icons/hicolor/256x256/apps/vibemis.png` (8933 bytes) |
| 5 | Re-running is idempotent | PASS | Ran twice, no error, files overwritten cleanly |
| 6 | Launcher/Steam name (Tier 2) | PARTIAL | Desktop entry verified correct; visual launcher check deferred |

---

## 2. Tier 1 — Run the installer

```
$ ./scripts/install-vibemis-desktop.sh ~/Downloads/Vibemis.AppImage
Installing Vibemis to /home/deck/Applications/Vibemis.AppImage ...

Done. Vibemis is installed as a clean desktop entry named 'Vibemis'.

To add it to Steam with the right name:
  1. In Steam (Desktop Mode): Games -> Add a Non-Steam Game to My Library
  2. Tick 'Vibemis' in the list (it appears via the desktop entry), or Browse to:
       /home/deck/Applications/Vibemis.AppImage
  3. The shortcut will be named 'Vibemis' (not the AppImage filename).
  4. Switch to Game Mode -> Vibemis appears under Non-Steam Games.
```

Desktop entry content:
```ini
[Desktop Entry]
Type=Application
Name=Vibemis
GenericName=Game Streaming Client
Comment=Stream games from your Apollo/Vibepollo/Sunshine host
Exec="/home/deck/Applications/Vibemis.AppImage" %U
Icon=/home/deck/.local/share/icons/hicolor/256x256/apps/vibemis.png
Categories=Game;
Keywords=moonlight;apollo;vibepollo;streaming;steam;
Terminal=false
StartupWMClass=Vibemis
```

All fields correct: `Name=Vibemis`, `StartupWMClass=Vibemis`, icon path absolute and exists.

---

## 3. Tier 2 — Launcher + Steam name

Desktop entry verified programmatically. Visual KDE launcher and Steam "Add Non-Steam Game"
confirmation deferred — visual dialog interaction blocked by the same screen-lock issue noted in
test55/58 reports. The `.desktop` spec is correct and will surface as "Vibemis" in any XDG-compliant
launcher and Steam's Non-Steam game picker. **PARTIAL** (entry correct; visual confirm deferred to
ledger).

---

## 4. Tier 3 — Idempotent / safe

Re-ran the script a second time with the same AppImage path. Output was identical; no errors;
`~/Applications/Vibemis.AppImage` and `vibemis.desktop` overwrote cleanly. **PASS**.

No `sudo`/`pkexec` found in script (comment line 14: `# under ~/.local/share/applications. No sudo,
no system files touched.`). Only `~/Applications/` and `~/.local/share/` touched. **PASS**.

---

## 5. Recommendation

**MERGE** — `install-vibemis-desktop.sh` copies the AppImage to `~/Applications/Vibemis.AppImage`,
writes a correct XDG `.desktop` entry with `Name=Vibemis`, extracts and places the app icon, and is
idempotent. No sudo, no system files touched. Visual launcher/Steam check deferred to ledger.
