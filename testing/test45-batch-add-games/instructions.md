# Test45 Instructions — Batch add all host games to Steam (P3.10 #5)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Verify `scripts/add-all-games-to-steam.sh` lists a host's apps (dry run) and, with
`--confirm`, creates a per-game `.desktop` launcher for each (via add-game-to-steam.sh).

**Script-only cycle.** Needs a **paired host** for the real list; arg/error handling works without.
Uses `.desktop` files only (no Steam `shortcuts.vdf` editing). No sudo.

---

## Setup

```bash
cd ~/vibemis
git fetch origin test45-batch-add-games
git checkout test45-batch-add-games && git pull
chmod +x scripts/add-all-games-to-steam.sh scripts/add-game-to-steam.sh
export VIBEMIS_APPIMAGE="$(ls -1 testing/test*/Vibemis*.AppImage | tail -1)"
```

## Tier 1 — Dry run (parse check) — **most important**

```bash
./scripts/add-all-games-to-steam.sh "<your-paired-host>"
```
1. Confirm it prints `Parsed N app(s):` followed by the app names.
2. **Compare that list to the host's real apps** (and to `"$VIBEMIS_APPIMAGE" list "<host>"`).
   - If the parsed names match → the parser is correct.
   - If they're garbled / include header lines → **report the raw `list` output format** so the
     parser can be adjusted. (This is the key thing to verify; nothing is written in dry run.)

## Tier 2 — Confirm (create launchers)

```bash
./scripts/add-all-games-to-steam.sh "<your-paired-host>" --confirm
ls ~/.local/share/applications/vibemis-game-*.desktop
```
Confirm one `vibemis-game-<slug>.desktop` per app, each with
`Exec="…/Vibemis.AppImage" stream "<host>" "<app>"`.

## Tier 3 — Error handling (no host needed)

```bash
./scripts/add-all-games-to-steam.sh ; echo "exit=$?"                  # no args -> usage, exit 1
./scripts/add-all-games-to-steam.sh "NoSuchHost123"                   # no apps -> clear message, exit 1
```

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | Dry run lists parsed app names | Yes |
| 2 | Parsed names match the host's real apps | **report match/mismatch + raw `list` format** |
| 3 | `--confirm` creates one .desktop per app with correct Exec | Yes |
| 4 | No args / unknown host → clear errors, exit 1 | Yes |
| 5 | No sudo; only ~/.local touched | Yes |

## Report format
Commit `testing/test45-batch-add-games/report.md` on `diagnostic/test45-batch-add-games-report`;
PR targets the test branch. **Please paste the raw `vibemis list <host>` output** so the parser
can be confirmed/tuned.

## Safety rules (standing)
- No package installs, no `sudo`. Do not pair if not already paired (listing needs an already-paired host).
