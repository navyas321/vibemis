# test69 — One-command Tailscale setup for remote play (P3.7) — PRIORITY

**Feature:** `scripts/setup-tailscale.sh` — gets this device onto a Tailscale tailnet with one
command and minimal input (a single browser login). Detects an existing Tailscale and just brings
it up; otherwise installs via Tailscale's official installer (sudo), falling back to a **userspace**
install under `~/.local` (no sudo) on locked-down/immutable systems like SteamOS. Prints the device's
Tailscale IP and the exact next steps in Vibemis. Completes the P3.7 remote-play story alongside
test28 (Add-PC hint) and test51 (prefer Tailscale addresses).
**Branch:** `test69-tailscale-oneclick-setup` · **Base:** `vibemis-main` · **Script-only** (no AppImage
behavior change). The branch carries the script; no alpha needed to test it.

> The test agent must NOT run sudo, authenticate, or join a real tailnet. Use the safe checks below.
> Full setup is a **user** action (it requires a Tailscale account login).

## Tier 1 — script is valid & safe (no sudo, no network)
1. `git fetch origin && git checkout test69-tailscale-oneclick-setup`
2. `bash -n scripts/setup-tailscale.sh` → ✅ PASS if no syntax errors. Confirm it's executable
   (`ls -l scripts/setup-tailscale.sh` shows the `x` bit).
3. `./scripts/setup-tailscale.sh --check` → ✅ PASS if it prints one of:
   `tailscale: not installed …` / `tailscale: installed …` / `tailscale: up`, and **exits on its
   own** (no prompt, no hang, no sudo). This is the non-blocking status mode.

## Tier 2 — read-through correctness (no execution)
1. Read the script. Confirm: (a) it tries an existing install first, (b) the official-installer
   branch is guarded by `have sudo`, (c) the userspace fallback writes only to `~/.local` (never the
   rootfs), (d) it prints the Tailscale IP + Vibemis next-steps.
   - ✅ PASS if those hold and nothing writes outside `$HOME`/`~/.local` without sudo.

## Tier 3 — full setup (USER ONLY — mark N/A for the agent)
A human with a Tailscale account runs `./scripts/setup-tailscale.sh`, logs in via the printed URL,
and confirms a `100.x` IP is shown. **N/A** for the test agent (no account / no sudo).

## Report
Write `testing/test69-tailscale-oneclick-setup/report.md`, update the `test69` row in
`testing/TEST_CHECKLIST.md`, commit both on `diagnostic/test69-tailscale-oneclick-setup-report`,
open a PR targeting `test69-tailscale-oneclick-setup`.
