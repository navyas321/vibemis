# test52 — `vibemis selftest` scriptable smoke test (test-automation enabler)

**Feature:** A new headless CLI command `vibemis selftest` runs non-destructive sanity checks on the
preferences subsystem and exits **0** (all PASS) / **1** (any FAIL), printing one
`SELFTEST <name>: PASS|FAIL` line per check plus a final `SELFTEST RESULT: …`. No host, stream, GUI
window, or SDL video needed — it runs before GUI init, so it works in any session.
**Branch:** `test52-selftest-cli` · **Base:** `vibemis-main`
**Artifact:** 🔬 alpha pre-release for this branch (tag contains `test52-selftest-cli`).

> Fully **launcher-only / headless** — no pairing or streaming. This unblocks automated Tier-1
> checks (see `docs/TEST_AUTOMATION.md`).

## Setup
1. Download the alpha AppImage, `chmod +x`, record `md5sum` + SteamOS/Mesa versions.

## Tier 1 — selftest passes and is scriptable (Desktop Mode)
1. Run: `~/Downloads/Vibemis-x86_64.AppImage selftest > /tmp/vibemis-selftest.log 2>&1; echo "exit=$?"`
2. Confirm the output contains a `SELFTEST RESULT: PASS (0 failure(s))` line and `exit=0`.
   - ✅ PASS if every `SELFTEST <name>:` line says PASS, the RESULT is PASS, and exit code is 0.
3. Confirm it's non-interactive: the command **returns on its own** (no window stays open, no input
   needed). Re-run and confirm output is identical (deterministic).

## Tier 2 — headless in Game Mode session (optional but valuable)
1. From a Game Mode terminal (or via the add-to-Steam helper running it once), run the same
   `selftest` command and confirm the same PASS/exit=0 result with no on-screen window.
   - ✅ PASS if it behaves identically headlessly. Mark N/A if you can't get a Game Mode shell.

## What to capture / report
- The full `/tmp/vibemis-selftest.log`, the exit code, md5, environment.
- Whether the command ever blocked waiting for input or opened a window (it must not).

## Report
Write `testing/test52-selftest-cli/report.md`, update the `test52` row in
`testing/TEST_CHECKLIST.md` (☐→☑/✗), commit both on `diagnostic/test52-selftest-cli-report`,
open a PR targeting `test52-selftest-cli`.
