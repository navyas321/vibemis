# Test38 Instructions — Per-game direct-launch Steam shortcut (P3.10)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Verify `scripts/add-game-to-steam.sh` creates a `.desktop` that launches Vibemis
straight into a specific game's stream via the CLI.

> **Script-only cycle** (no new AppImage) — uses any Vibemis AppImage you already have.
> **Desktop Mode.** Verifying the *generated shortcut* is the goal; actually streaming a game
> requires a paired host (optional — only if you want to confirm the end-to-end launch).

---

## Setup

```bash
cd ~/vibemis
git fetch origin test38-game-launch-shortcut
git checkout test38-game-launch-shortcut && git pull
chmod +x scripts/add-game-to-steam.sh scripts/install-vibemis-desktop.sh
```

Make sure a Vibemis AppImage is installed at the stable path (from test30's script), or point at one:
```bash
# Option A: install to the standard path
APPIMAGE=$(ls -1 testing/test*/Vibemis*.AppImage | tail -1)
./scripts/install-vibemis-desktop.sh "$APPIMAGE"   # creates ~/Applications/Vibemis.AppImage
# Option B: skip install and point the next step at an AppImage directly:
#   export VIBEMIS_APPIMAGE="$APPIMAGE"
```

---

## Tier 1 — Generate a shortcut

```bash
./scripts/add-game-to-steam.sh "MyHostName" "Desktop"
```
Confirm:
1. It prints `Created: ~/.local/share/applications/vibemis-game-desktop.desktop` and the launch line.
2. The file exists and contains `Exec="…/Vibemis.AppImage" stream "MyHostName" "Desktop"`:
   ```bash
   cat ~/.local/share/applications/vibemis-game-desktop.desktop
   ```
3. Run it with a multi-word app name too: `./scripts/add-game-to-steam.sh "MyHostName" "Big Picture"`
   → a `vibemis-game-big-picture.desktop` with the app name quoted correctly in Exec.
4. Error handling: running with no args prints usage and exits non-zero; running when no
   AppImage is found prints a clear error.

## Tier 2 — (optional, needs a paired host) end-to-end launch

1. With a host paired and a known app name (check `~/Applications/Vibemis.AppImage list "MyHostName"`),
   generate a shortcut for that real app and run the .desktop / its Exec line.
2. Expected: Vibemis launches **straight into that game's stream** (or shows the pairing/connect
   step if not yet paired). Do NOT pair if not already paired — just report what happened.

---

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | Script creates a `.desktop` with the right name | Yes |
| 2 | Exec line = `"<AppImage>" stream "<host>" "<app>"` (app quoted) | Yes |
| 3 | Multi-word app name → correct slug + quoting | Yes |
| 4 | No args / no AppImage → clear error, non-zero exit | Yes |
| 5 | (optional) generated shortcut launches into the stream | report |
| 6 | No sudo used; only ~/.local/share touched | Yes |

Report SteamOS version. If the CLI `stream` verb behaves differently than expected, note it.

## Report format
Commit `testing/test38-game-launch-shortcut/report.md` on
`diagnostic/test38-game-launch-shortcut-report`; PR targets the test branch.

## Safety rules (standing)
- No package installs, no `sudo`. Do not pair if not already paired.
