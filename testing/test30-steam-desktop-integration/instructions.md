# Test30 Instructions — Steam/desktop integration helper (P3.2)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Verify `scripts/install-vibemis-desktop.sh` installs Vibemis under a clean name so it
shows as **"Vibemis"** (not the long AppImage filename) in the app launcher and when added to Steam.

> **No new AppImage** in this cycle — the script works with any Vibemis AppImage you already
> have (e.g. the one from test27/test28). This is a **Desktop Mode** test. No streaming needed.

---

## Setup

```bash
cd ~/vibemis
git fetch origin test30-steam-desktop-integration
git checkout test30-steam-desktop-integration && git pull
chmod +x scripts/install-vibemis-desktop.sh
```

Use any Vibemis AppImage you already downloaded, e.g. from a previous test cycle:
```bash
APPIMAGE=$(ls -1 testing/test*/Vibemis*.AppImage 2>/dev/null | tail -1)
echo "Using: $APPIMAGE"
```

---

## Tier 1 — Run the installer

```bash
./scripts/install-vibemis-desktop.sh "$APPIMAGE"
```

Confirm:
1. It prints "Done ... installed as a clean desktop entry named 'Vibemis'".
2. `~/Applications/Vibemis.AppImage` exists and is executable:
   ```bash
   ls -l ~/Applications/Vibemis.AppImage
   ```
3. The desktop entry exists with `Name=Vibemis`:
   ```bash
   cat ~/.local/share/applications/vibemis.desktop
   ```
4. (If an icon extracted) `~/.local/share/icons/hicolor/256x256/apps/vibemis.png` exists.

## Tier 2 — Launcher + Steam name

1. Open the KDE application launcher / menu and search **"Vibemis"** — it should appear with
   the clean name (and icon if extracted). Launching it should start Vibemis.
2. In Steam (Desktop Mode) → **Add a Non-Steam Game** → confirm **"Vibemis"** appears in the
   list (or browse to `~/Applications/Vibemis.AppImage`). The resulting shortcut should be
   named **Vibemis**, not the long filename.
3. (Optional) Switch to Game Mode and confirm it shows as "Vibemis" under Non-Steam Games.

## Tier 3 — Idempotent / safe

1. Run the script again — it should overwrite cleanly with no errors (idempotent).
2. Confirm it used **no sudo** and touched only `~/Applications` and `~/.local/share`.

---

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | Script runs without error, no sudo | Yes |
| 2 | `~/Applications/Vibemis.AppImage` present + executable | Yes |
| 3 | `vibemis.desktop` has `Name=Vibemis` | Yes |
| 4 | Appears as "Vibemis" in the app launcher | Yes |
| 5 | Steam shows the shortcut as "Vibemis" | Yes |
| 6 | Re-running is idempotent | Yes |

Report SteamOS version. Screenshots of the launcher entry and the Steam shortcut name are ideal.

---

## Report format

Commit `testing/test30-steam-desktop-integration/report.md` on
`diagnostic/test30-steam-desktop-integration-report`; PR targets the test branch.

---

## Safety rules (standing)
- No package installs, no `sudo`. The script must not require sudo — if it does, that's a bug; report it.
- The script only writes under `~/Applications` and `~/.local/share`.
