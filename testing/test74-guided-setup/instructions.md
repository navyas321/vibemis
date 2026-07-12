# test74 — Guided one-command setup `scripts/vibemis-setup.sh` (P3.10)

**Branch:** `test74-guided-setup` · **Base:** `vibemis-main` · **Type:** script (launcher-only for
Tiers 1–2; the real end-to-end run is host-dependent → deferred ledger).
**What changed:** adds `scripts/vibemis-setup.sh`, the "single guided flow" that chains the existing
helpers: `vibemis-doctor.sh` → `vibemis-update.sh` → `install-vibemis-desktop.sh` → *(if `--host`)*
`pair-host.sh` → `add-all-games-to-steam.sh --confirm`. No sudo; orchestration only (no new
privileged behavior).

This is a **script test** — verify the script directly from the branch checkout (no AppImage needed).

---

## Tier 1 — static + interface checks (no host, no install)

Run on the device (or any Linux shell) from the repo root after `git checkout test74-guided-setup`:

```bash
chmod +x scripts/vibemis-setup.sh
bash -n scripts/vibemis-setup.sh                 # syntax
command -v shellcheck >/dev/null && shellcheck -S warning scripts/vibemis-setup.sh   # if available
bash scripts/vibemis-setup.sh --help             # usage
bash scripts/vibemis-setup.sh --dry-run          # prints 3-step plan, runs nothing
bash scripts/vibemis-setup.sh --dry-run --host 100.64.0.5   # prints 5-step plan (adds pair + add-games)
bash scripts/vibemis-setup.sh --bogus ; echo "exit=$?"      # expect exit=2
```

**PASS signals:**
- `bash -n` clean; shellcheck (if present) no errors.
- `--help` prints the usage block.
- `--dry-run` lists steps 1–3 and **executes nothing** (every step shows `(dry-run: not executed)`).
- `--dry-run --host …` additionally lists steps 4 (pair) and 5 (add games).
- `--bogus` exits **2**.
- **Safety scan:** confirm the script contains **no `sudo`**, writes nothing outside `$HOME`, and only
  calls sibling `scripts/*.sh`. Quick check:
  ```bash
  grep -nE "sudo|/etc/|/usr/|rm -rf /" scripts/vibemis-setup.sh || echo "no sudo / no system paths — good"
  ```

## Tier 2 — `--update-only` happy path (optional, no host, network needed)

If the device has internet, `bash scripts/vibemis-setup.sh --update-only` should run doctor + fetch
the latest AppImage to `~/Applications/Vibemis.AppImage` and stop before any host steps. Mark **N/A**
if you'd rather not touch the installed AppImage on the test device.

## Tier 3 — full guided run (HOST REQUIRED → deferred)

`bash scripts/vibemis-setup.sh --host <your-host>` end-to-end (install → pair via PIN → add games).
**N/A unless a host is available.** This is tracked in the *Deferred verification ledger* in
`TEST_CHECKLIST.md`; the maintainer/test agent runs it once a host is on hand.

## Report

`testing/test74-guided-setup/report.md`: TL;DR (Tier 1 / Tier 2 / Tier 3) → evidence (paste the
`--dry-run` plan + the sudo/path scan result) → recommendation. Tick the `test74` row in
`TEST_CHECKLIST.md`. Tier 1 PASS (static + interface + safety) is enough to **MERGE**; Tier 3 stays
on the ledger.
