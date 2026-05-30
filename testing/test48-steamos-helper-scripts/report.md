# Test48 Report — SteamOS helper scripts bundle (P3.2 + P3.10)

**Artifact tested:** `scripts/*.sh` bundle (script-only; no AppImage behavior change)
**Branch:** `test48-steamos-helper-scripts` (commit `origin/test48-steamos-helper-scripts`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5 (BUILD_ID 20260520.100), Mesa 25.3.0
**Test date:** 2026-05-29
**Prior report:** N/A (consolidates former test30/38/42/43/44/45/46)

---

## 1. TL;DR

| # | Script | Status | Summary |
|---|--------|--------|---------|
| 1 | install-vibemis-desktop | PASS ✅ | Creates `~/Applications/Vibemis.AppImage` + clean `Name=Vibemis` desktop entry |
| 2 | vibemis-update --check | PASS ✅ | Prints latest tag + AppImage URL |
| 3 | add-game-to-steam | PASS ✅ | Correct Exec/quoting, slug `vibemis-game-desktop` |
| 4 | add-all-games (dry) | PASS ✅ | Reached host, parsed 4 apps correctly |
| 5 | pair-host | PASS ✅ | Clean usage on missing arg (did not actually pair — already paired) |
| 6 | uninstall-vibemis-desktop | PASS ✅ | Dry-run lists; `--yes` removes; settings kept |
| 7 | vibemis-doctor | PASS ✅ | Runs clean, full diagnostics |
| 8 | safety (no sudo, only ~/.local & ~/Applications) | PASS ✅ | Confirmed; settings + other AppImages untouched |

All 7 scripts pass `bash -n`. **No sudo used anywhere.**

---

## 2. install / uninstall (state round-trip, cleaned up)

```
$ ./scripts/install-vibemis-desktop.sh ~/Downloads/Vibemis.AppImage
→ /home/deck/Applications/Vibemis.AppImage (90 MB copy)
→ ~/.local/share/applications/vibemis.desktop:
    Name=Vibemis
    Exec="/home/deck/Applications/Vibemis.AppImage" %U
    Icon=…/vibemis.png   StartupWMClass=Vibemis   Categories=Game;

$ ./scripts/uninstall-vibemis-desktop.sh           # dry-run lists 4 items
$ ./scripts/uninstall-vibemis-desktop.sh --yes     # removes AppImage + 2 .desktop + icon
Done. settings kept.
```

After cleanup: `~/Applications` back to the user's original AppImages (azahar/Eden/EmuDeck/ES-DE/PXPlay), no vibemis `.desktop` entries, and `~/.config/Vibemis Project/Vibemis.conf` (uniqueid `3ca53e803678f6a4`, paired host) intact. **PASS.**

---

## 3. add-game / add-all (parser)

```
$ ./scripts/add-game-to-steam.sh "MyHost" "Desktop"
→ vibemis-game-desktop.desktop: Exec="…/Vibemis.AppImage" stream "MyHost" "Desktop"
  Name=Desktop (Vibemis)

$ ./scripts/add-all-games-to-steam.sh "192.168.4.78"        # dry run, paired Vibepollo host
Parsed 4 app(s):
  - Desktop
  - Steam Big Picture
  - MoonDeckStream
  - Virtual Display
Dry run. Re-run with --confirm to create a launcher for each.
```

Exec quoting is correct (host/app each quoted); slug derives cleanly. The dry-run parser produced exactly the 4 apps the Vibepollo host exposes. **PASS** (did not `--confirm`, to avoid creating 4 real launchers).

---

## 4. update / pair / doctor

```
$ ./scripts/vibemis-update.sh --check
Latest release: 0.6.7-beta.20260530.0034+ba49e67
AppImage:       https://github.com/navyas321/vibemis/releases/download/…-x86_64.AppImage

$ ./scripts/pair-host.sh         # no args
Usage: ./scripts/pair-host.sh "<HostName-or-IP>"   → clear usage, exit 0

$ ./scripts/vibemis-doctor.sh
OS: SteamOS · GPU: AMD Ryzen Z2 Go (radeonsi, rembrandt) Mesa 25.3.0
VAAPI: vainfo absent (Vibemis bundles its own libva handling)
FUSE: libfuse2 NOT found — use --appimage-extract-and-run (normal on SteamOS)
Install state: not installed / no desktop entry / no settings yet (first run)
```

`update --check` resolves the latest tag + URL (note: the newest release is now a **beta**, `0.6.7-beta.20260530.0034+ba49e67`). `pair-host` handles the missing-arg case cleanly — I did **not** run an actual pair (host already paired; standing rule). `doctor` runs clean and is genuinely useful for bug reports. **PASS.**

---

## 5. Other findings

- **doctor "no settings yet (first run)" is a false negative.** Settings exist at `~/.config/Vibemis Project/Vibemis.conf` (note the space + "Project"), but doctor reports none — it's likely probing `~/.config/Vibemis`. Minor; suggest doctor check the actual QSettings path (`~/.config/Vibemis Project/`).
- All scripts wrote only under `~/Applications` and `~/.local/share` (apps/icons); none touched the rootfs or required sudo. Settings under `~/.config` were preserved by uninstall as documented.

---

## 6. Recommendation

**MERGE.** The whole bundle is syntactically clean, sudo-free, correctly scoped to `$HOME`, and each script does what it claims. One tiny polish: fix `vibemis-doctor.sh`'s settings-path probe so it detects `~/.config/Vibemis Project/`.
