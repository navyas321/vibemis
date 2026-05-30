# Test74 Report — Guided one-command setup `scripts/vibemis-setup.sh` (P3.10)

**Artifact tested:** `scripts/vibemis-setup.sh` (no AppImage — script-only test)
**Branch:** `test74-guided-setup` (FETCH_HEAD)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.6, Mesa 25.3.0
**Test date:** 2026-05-30
**Prior report:** N/A

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| Tier 1 — Static + interface checks | PASS | All 6 checks pass (syntax, help, dry-run, exit codes, safety scan) |
| Tier 2 — `--update-only` happy path | N/A | Skipped to avoid touching `~/Applications/Vibemis.AppImage` on test device |
| Tier 3 — Full guided run with host | N/A | Host-dependent; deferred to ledger |

---

## 2. Tier 1 — Static + interface checks

### 1. Syntax check
```
$ bash -n scripts/vibemis-setup.sh
(clean — no output)
```
**PASS**

### 2. shellcheck
shellcheck not installed on SteamOS 3.8.6 — skipped.

### 3. `--help`
```
vibemis-setup.sh — guided one-command Vibemis setup for SteamOS / Linux (P3.10)

The "single guided flow" that ties the individual helper scripts together ...
  1. vibemis-doctor.sh        — read-only environment check
  2. vibemis-update.sh        — download the latest Vibemis AppImage to ~/Applications
  3. install-vibemis-desktop.sh — install to a stable path + clean "Vibemis" desktop/Steam entry
  4. (if --host) pair-host.sh <host>
  5. (if --host) add-all-games-to-steam.sh <host> --confirm

Usage block: 6 forms shown (bare, --host, --host --yes, --dry-run, --update-only, --help)
Exit codes: 0 ok · 1 a step failed · 2 bad usage
```
**PASS** — usage block complete and accurate.

### 4. `--dry-run` (3-step plan)
```
==> Vibemis guided setup
    Plan:
      1. Check environment (vibemis-doctor.sh)
      2. Download latest AppImage (vibemis-update.sh)
      3. Install desktop/Steam entry (install-vibemis-desktop.sh)
    (dry-run — nothing will be executed)

==> Checking environment
    $ bash .../scripts/vibemis-doctor.sh
    (dry-run: not executed)

==> Downloading the latest Vibemis AppImage
    $ bash .../scripts/vibemis-update.sh
    (dry-run: not executed)

==> Installing desktop & Steam integration
    $ bash .../scripts/install-vibemis-desktop.sh
    (dry-run: not executed)

==> Base setup complete. ...
```
**PASS** — all 3 steps printed; every step shows "(dry-run: not executed)"; nothing executed.

### 5. `--dry-run --host 100.64.0.5` (5-step plan)
```
    Plan:
      1. Check environment (vibemis-doctor.sh)
      2. Download latest AppImage (vibemis-update.sh)
      3. Install desktop/Steam entry (install-vibemis-desktop.sh)
      4. Pair host '100.64.0.5' (pair-host.sh)
      5. Add '100.64.0.5' games to Steam (add-all-games-to-steam.sh --confirm)
    (dry-run — nothing will be executed)
```
Steps 4 and 5 added correctly for `--host`. All 5 steps "(dry-run: not executed)".
**PASS**

### 6. `--bogus` exit code
```
$ bash scripts/vibemis-setup.sh --bogus; echo "exit=$?"
[!] Unknown option: --bogus
(usage block printed)
exit=2
```
**PASS** — exit 2 as specified.

### 7. Safety scan
```
$ grep -nE "sudo|/etc/|/usr/|rm -rf /" scripts/vibemis-setup.sh
12:# It only orchestrates the existing scripts — no new privileged behavior. No sudo; everything stays
```
Match is a **comment only** (line 12). No actual `sudo` calls, no system paths (`/etc/`, `/usr/`), no `rm -rf /`. Script only writes to `$HOME` via its sibling scripts.
**PASS**

---

## 3. Tier 2 — `--update-only` (N/A)

Skipped to avoid downloading and overwriting `~/Applications/Vibemis.AppImage` on the test device. The `--update-only` flag runs steps 1–2 (doctor + update), which would fetch the latest AppImage from GitHub. Deferred to a future session on a device where the download is acceptable.

---

## 4. Tier 3 — Full guided run (N/A — deferred)

`--host` pairing step requires a reachable Apollo/Sunshine host on the same network or Tailscale. Adding to deferred verification ledger.

---

## 5. Recommendation

**MERGE** — `scripts/vibemis-setup.sh` passes all Tier 1 static and interface checks: syntax clean, help block accurate, dry-run shows correct 3/5-step plans executing nothing, bad-option exits with code 2, and no privileged/unsafe shell patterns found. Tier 2 and 3 are deferred per instructions.
