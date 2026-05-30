# Test69 Report — One-command Tailscale setup script (P3.7, PRIORITY)

**Artifact tested:** `scripts/setup-tailscale.sh` (script-only; no AppImage)
**Branch:** `test69-tailscale-oneclick-setup` (commit `7ea6c84`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5 (BUILD_ID 20260520.100), Mesa 25.3.0
**Test date:** 2026-05-29
**Prior report:** N/A

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — valid & safe (Tier 1) | PASS ✅ | `bash -n` clean, executable, `--check` reports status and exits 0, no sudo/hang |
| B — read-through correctness (Tier 2) | PASS ✅ | Existing-install-first, sudo-guarded installer, userspace fallback under `~/.local`, prints IP + next-steps |
| C — full setup (Tier 3) | N/A | Requires a Tailscale account login + browser — user-only, not run by the agent |

---

## 2. Tier 1 — script is valid & safe (no sudo, no network)

```
$ ls -l scripts/setup-tailscale.sh
-rwxr-xr-x ... scripts/setup-tailscale.sh        # executable bit set ✓

$ bash -n scripts/setup-tailscale.sh; echo $?
0                                                # no syntax errors ✓

$ ./scripts/setup-tailscale.sh --check; echo "exit=$?"
tailscale: not installed (run without --check to set it up)
exit=0                                           # status-only, returned on its own, no sudo/prompt ✓
```

`--check` is correctly non-blocking: it never installs, never calls `sudo`, never runs `tailscale up` (which would block on browser login). **PASS.**

---

## 3. Tier 2 — read-through correctness (no execution)

Reviewed all 123 lines. The four required properties hold:

| Property | Where | Verdict |
|---|---|---|
| (a) tries existing install first | lines 73–82: `if TS=$(ts_cli)` → `bring_up_and_report`, before any install | ✅ |
| (b) official installer guarded by `have sudo` | line 86: `if have sudo && curl … | sh` | ✅ |
| (c) userspace fallback writes only to `~/.local` | `STATE_DIR=~/.local/state/vibemis-tailscale`, `LOCAL_BIN=~/.local/bin`; copies binaries there; `--tun=userspace-networking` (no root/TUN); `mktemp` temp dir cleaned up | ✅ |
| (d) prints Tailscale IP + Vibemis next-steps | `bring_up_and_report` lines 44–53: `This device's Tailscale IP: $IP` + 3-step Vibemis guidance | ✅ |

**No writes outside `$HOME`/`~/.local` without sudo.** The only `sudo` path is the official installer (line 86), explicitly gated by `have sudo` and is the canonical route on normal distros. On SteamOS (no sudo offered here) it cleanly falls through to the userspace branch. Idempotent / safe to re-run as documented. **PASS.**

Minor (non-blocking): `--check` only inspects `$1`, so it must be the first argument (documented usage). `set -u` + `${1:-}` handle the no-arg case safely.

---

## 4. Other findings

- Userspace mode honestly warns it provides SOCKS5/HTTP-proxy reachability, not full transparent routing, and points to the official root install for full routing — accurate for SteamOS.
- Version pin `TS_VERSION=1.78.1` (overridable via `VIBEMIS_TS_VERSION`) is a reasonable known-good default.

---

## 5. Recommendation

**MERGE.** Tier 1 + Tier 2 pass; the script is syntactically valid, safe (no rootfs writes, sudo properly gated), and the SteamOS userspace fallback is correct. Tier 3 (real tailnet join) is a user action and remains N/A for the agent — recommend the maintainer run `./scripts/setup-tailscale.sh` once with a Tailscale account to confirm the end-to-end login + `100.x` IP path.
