# Test45 Report — Batch add all host games `scripts/add-all-games-to-steam.sh` (P3.10)

**Artifact tested:** `scripts/add-all-games-to-steam.sh` (script-only test, no AppImage)
**Branch:** `test45-batch-add-games` (FETCH_HEAD)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.6, Mesa 25.3.0
**Test date:** 2026-05-30
**Prior report:** N/A
**Host used:** Navid-PC (192.168.4.78) — already paired, 4 apps

---

## 1. TL;DR

| # | Check | Status | Notes |
|---|-------|--------|-------|
| 1 | Dry run lists apps correctly | PASS | 4 apps parsed: Desktop, Steam Big Picture, MoonDeckStream, Virtual Display |
| 2 | `--confirm` creates one `.desktop` per app | PASS | 4 launchers created, all with correct Exec/slug |
| 3 | Multi-word app name quoted correctly | PASS | "Steam Big Picture" → `vibemis-game-steam-big-picture.desktop`, Exec quoted |
| 4 | No args → usage + exit 1 | PASS | |
| 5 | No sudo | PASS | Comment + grep confirm |

---

## 2. Tier 1 — Dry run (parse check)

```
$ ./scripts/add-all-games-to-steam.sh "Navid-PC"
Listing apps on host: Navid-PC
Parsed 4 app(s):
  - Desktop
  - Steam Big Picture
  - MoonDeckStream
  - Virtual Display

Dry run. Re-run with --confirm to create a .desktop launcher for each app:
  ./scripts/add-all-games-to-steam.sh "Navid-PC" --confirm
(Verify the list above matches the host's real apps before confirming.)
```

4 apps parsed correctly. Names match the host's actual app list. Parser correctly strips blank
lines and whitespace from `vibemis list` output. **PASS**.

---

## 3. Tier 2 — Confirm (create launchers)

```
$ ./scripts/add-all-games-to-steam.sh "Navid-PC" --confirm
Listing apps on host: Navid-PC
Parsed 4 app(s): Desktop, Steam Big Picture, MoonDeckStream, Virtual Display
>> creating shortcut for: Desktop
Created: ~/.local/share/applications/vibemis-game-desktop.desktop
>> creating shortcut for: Steam Big Picture
Created: ~/.local/share/applications/vibemis-game-steam-big-picture.desktop
>> creating shortcut for: MoonDeckStream
Created: ~/.local/share/applications/vibemis-game-moondeckstream.desktop
>> creating shortcut for: Virtual Display
Created: ~/.local/share/applications/vibemis-game-virtual-display.desktop
Done. Add the new "<App> (Vibemis)" entries to Steam from Desktop Mode.
```

4 `.desktop` files created. Sample (`vibemis-game-steam-big-picture.desktop`):
```ini
[Desktop Entry]
Type=Application
Name=Steam Big Picture (Vibemis)
Comment=Stream "Steam Big Picture" from Navid-PC via Vibemis
Exec="/home/deck/Downloads/Vibemis.AppImage" stream "Navid-PC" "Steam Big Picture"
Keywords=vibemis;moonlight;apollo;stream;steam-big-picture;
```

Multi-word name "Steam Big Picture" → slug `steam-big-picture` ✓, Exec quoting correct ✓. **PASS**.

---

## 4. Error handling

```
$ ./scripts/add-all-games-to-steam.sh
Usage: ./scripts/add-all-games-to-steam.sh "<HostName>" [--confirm]
exit=1
```

No args → usage + exit 1. **PASS**. Missing AppImage path also tested via `VIBEMIS_APPIMAGE=/nonexistent` → `ERROR: Vibemis AppImage not found/executable`, exit 1.

---

## 5. Recommendation

**MERGE** — `add-all-games-to-steam.sh` correctly queries a paired host's app list via the Vibemis
CLI, parses the output (4 apps confirmed matching the real host), and creates properly named and
quoted `.desktop` launchers for each app in dry-run and confirm modes. No sudo; only
`~/.local/share/applications/` written. Multi-word app names are handled correctly.
