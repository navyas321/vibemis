# Test124 Instructions — one-click Steam library launch: host-game shortcut sync (BL-1786)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** `scripts/steam-sync-host-games.py` turns host games into real Steam library tiles
that stream on one click. Safety-critical file: `shortcuts.vdf` (script backs it up itself).

## Background

New script (from this alpha's repo tree, `scripts/steam-sync-host-games.py`): reads
`vibemis list <host> --csv`, writes/updates non-Steam shortcuts targeting
`vibemis stream <host> "<app>"`, wires grid art from the CLI's resolved Boxart column.
**Dry-run by default; `--apply` required to write.** Built-in guards: timestamped
shortcuts.vdf backup, round-trip self-check before writing, Steam-must-be-closed guard,
byte-for-byte readback verification. `--appimage <path>` points it at the alpha under test
(don't rely on a PATH `vibemis`).

**Build tier: ALPHA (BL-2016). Hashes stamped at dispatch.**

## Test procedure

### Tier 0 — integrity + boot
md5/sha256 exact vs dispatch; `selftest --json` PASS exit 0.

### Tier 1 — dry-run safety (launcher only, no stream needed)
1. Record `stat -c %Y ~/.steam/steam/userdata/<id>/config/shortcuts.vdf` (baseline mtime).
2. `python3 scripts/steam-sync-host-games.py Navid-PC --appimage <alpha>` (NO --apply):
   prints the would-apply plan (host games enumerated), exits 0, shortcuts.vdf mtime
   UNCHANGED, no backup file created.
3. Steam-running guard: with Steam OPEN, run the same + `--apply` → refuses with the
   Steam-must-be-closed message, exit nonzero, shortcuts.vdf mtime UNCHANGED.
4. `--list` mode: shows zero Vibemis-managed shortcuts pre-apply.

### Tier 2 — apply + one-click E2E (this is the point of the feature)
1. CLOSE Steam fully. Run with `--apply`: timestamped backup created next to
   shortcuts.vdf; readback-verification message; exit 0. Re-run `--apply` immediately →
   idempotent (0 changes, no duplicate tiles).
2. Start Steam → host games appear as library tiles WITH box art (screenshot).
3. **One-click E2E (real content flow — the launch itself is the verdict):** click ONE
   tile → Vibemis session starts → the actual host game is on screen and interactive
   (screenshot mid-stream). Coordinate with @host on the bus before this row so the host
   game can be launched/quit cleanly.
4. Quit stream cleanly → back to Steam library, no orphan session.

### Teardown
`--prune-missing` after removing the host from reach (or restore the timestamped backup);
`--list` shows zero managed shortcuts again; shortcuts.vdf byte-identical to backup
baseline OR contains only pre-existing entries. Steam library visually clean (screenshot).

## What to check and report
Tier 1 rows 1-4, Tier 2 rows 1-4, teardown — per-row verdicts. Any shortcuts.vdf
corruption symptom (Steam rewrites it, tiles vanish, library fails to load) is an
IMMEDIATE FAIL + restore backup + report.

## Report
`testing/test124-steam-oneclick/report.md` on `diagnostic/test124-steam-oneclick-report`,
PR targets `test124-steam-oneclick`.

## Safety rules (standing)
No sudo/installs; don't modify the AppImage; keep the script's own backup until teardown
verifies clean; streaming required for Tier 2 row 3.
