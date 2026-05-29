# Test44 Instructions — CLI pair helper (P3.10)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Verify `scripts/pair-host.sh` invokes the Vibemis `pair` CLI and surfaces the PIN.

**Script-only cycle.** This one **does** initiate pairing (CLI), so only run Tier 1 if you have a
host you're permitted to pair with; otherwise just verify the arg/error handling (Tier 2).

---

## Setup

```bash
cd ~/vibemis
git fetch origin test44-pair-script
git checkout test44-pair-script && git pull
chmod +x scripts/pair-host.sh
# ensure ~/Applications/Vibemis.AppImage exists, or:
export VIBEMIS_APPIMAGE="$(ls -1 testing/test*/Vibemis*.AppImage | tail -1)"
```

## Tier 1 — Pair (only if you have a permitted host)

```bash
./scripts/pair-host.sh "<your-host-ip-or-name>"
```
Confirm it prints the pairing guidance and then a **PIN** (from the Vibemis CLI). Enter the PIN
in the host's Pair-Client web UI to complete pairing. (If you should not pair, Ctrl-C out — the
goal is just to confirm the PIN is shown.)

## Tier 2 — Arg / error handling (always)

```bash
./scripts/pair-host.sh ; echo "exit=$?"                       # no args -> usage, exit 1
VIBEMIS_APPIMAGE=/nonexistent ./scripts/pair-host.sh H ; echo "exit=$?"   # missing AppImage -> error, exit 1
```

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | No args → usage message, exit 1 | Yes |
| 2 | Missing AppImage → clear error, exit 1 | Yes |
| 3 | (if tested) prints guidance + a PIN from the CLI | Yes |
| 4 | Works with an IP and a Tailscale/MagicDNS name | report |

## Report format
Commit `testing/test44-pair-script/report.md` on `diagnostic/test44-pair-script-report`;
PR targets the test branch.

## Safety rules (standing)
- No package installs, no `sudo`. Only pair with a host you're permitted to.
