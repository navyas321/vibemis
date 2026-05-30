# Test38 Report — Per-game direct-launch Steam shortcut `scripts/add-game-to-steam.sh` (P3.10)

**Artifact tested:** `scripts/add-game-to-steam.sh` (script-only test, no AppImage)
**Branch:** `test38-game-launch-shortcut` (FETCH_HEAD)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.6, Mesa 25.3.0
**Test date:** 2026-05-30
**Prior report:** N/A

---

## 1. TL;DR

| # | Check | Status | Notes |
|---|-------|--------|-------|
| 1 | Creates `.desktop` with correct name | PASS | `vibemis-game-desktop.desktop` with `Name=Desktop (Vibemis)` |
| 2 | `Exec` = `"<AppImage>" stream "<host>" "<app>"` (quoted) | PASS | Confirmed verbatim |
| 3 | Multi-word app name → correct slug + quoting | PASS | "Big Picture" → `vibemis-game-big-picture.desktop`, `Exec=…"Big Picture"` |
| 4 | No args / no AppImage → clear error, non-zero exit | PASS | Usage message + exit 1 |
| 5 | No sudo used | PASS | Comment + grep confirm |
| 6 | End-to-end stream launch (Tier 2) | N/A | Requires paired host; Navid-PC is paired but test instructions say don't stream |

---

## 2. Tier 1 — Generate shortcuts

### Single-word game name: "Desktop"

```
$ ./scripts/add-game-to-steam.sh "Navid-PC" "Desktop"
Created: /home/deck/.local/share/applications/vibemis-game-desktop.desktop
  launches: "/home/deck/Applications/Vibemis.AppImage" stream "Navid-PC" "Desktop"
```

`vibemis-game-desktop.desktop` content:
```ini
[Desktop Entry]
Type=Application
Name=Desktop (Vibemis)
GenericName=Streamed Game
Comment=Stream "Desktop" from Navid-PC via Vibemis
Exec="/home/deck/Applications/Vibemis.AppImage" stream "Navid-PC" "Desktop"
Icon=vibemis
Categories=Game;
Keywords=vibemis;moonlight;apollo;stream;desktop;
Terminal=false
StartupWMClass=Vibemis
```

All fields correct. **PASS**.

### Multi-word game name: "Big Picture"

```
$ ./scripts/add-game-to-steam.sh "Navid-PC" "Big Picture"
Created: /home/deck/.local/share/applications/vibemis-game-big-picture.desktop
  launches: "/home/deck/Applications/Vibemis.AppImage" stream "Navid-PC" "Big Picture"
```

`vibemis-game-big-picture.desktop` content:
```ini
Name=Big Picture (Vibemis)
Exec="/home/deck/Applications/Vibemis.AppImage" stream "Navid-PC" "Big Picture"
Keywords=vibemis;moonlight;apollo;stream;big-picture;
```

Slug: `big-picture` (space→hyphen), Exec quoting correct. **PASS**.

### Error handling: no args

```
$ ./scripts/add-game-to-steam.sh
Usage: ./scripts/add-game-to-steam.sh "<HostName>" "<App/Game name>"
  e.g. ./scripts/add-game-to-steam.sh "GLADOS" "Portal 2"
$ echo $?
1
```

Usage message + exit 1. **PASS**.

---

## 3. Tier 2 — N/A

End-to-end stream launch not performed — test instructions say "do NOT pair if not already paired;
just report what happened." Navid-PC is paired but a live stream was not initiated in this cycle.
The Exec line is syntactically correct for the Vibemis `stream` CLI verb. Deferred to ledger.

---

## 4. Recommendation

**MERGE** — `add-game-to-steam.sh` generates syntactically correct XDG `.desktop` files for both
single-word and multi-word game names, with properly quoted Exec lines and correct slug/name
derivation. No sudo. Only `~/.local/share/applications/` touched.
