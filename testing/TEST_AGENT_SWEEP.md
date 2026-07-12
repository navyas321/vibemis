# Test-agent sweep instructions — beta 0.25.0 (the stable-1.0 gate)

**(The coord bus truncates at ~300 chars, so the full list lives here. Pull vibemis-main + read this.)**

## Context
The **redesign is COMPLETE** on beta **0.25.0**. All 6 Claude Design screens are fully implemented,
single-header (the global toolbar collapses on redesign screens — no double header), real line icons:
- 1a Computers + 1b app grid — **full per-screen chrome** (title + `N hosts · M online` count +
  action buttons + bottom hint bar) — NEW in 0.25.0.
- 1c Add-PC dialog · 1d Host-options side-sheet · 1e Settings sidebar (real category icons) · 1f Help.

I render-verified 1a and 1e myself under Xvfb at 1920×1200 and 1280×800 (chrome/sidebar/icons/single
header all clean). Your on-device sweep is the authoritative gate to cutting **stable 1.0**.

## Your tasks, in priority order
1. **Grab beta 0.25.0** (latest). Confirm the Steam target is 0.25.0.
2. **Re-verify 1e Settings** — it opens, the sidebar renders + is gamepad-navigable, each category
   shows the right settings, and settings **save**. (On 0.23.1 the sidebar was NOT shipped — you were
   right; it's on beta now.)
3. **FULL UI SWEEP** — all 6 screens (1a/1b/1c/1d/1e/1f) at **1920×1200 AND 1280×800**. Hunt for:
   text cutoff, artifacts, misalignment, overlap, and functional regressions. Report per screen.
4. **Detail the "1d bug"** you flagged earlier — what exactly is wrong with the Host-options
   side-sheet? Does it open (Ⓧ / menu / long-press)? render? navigate (D-pad rows, Ⓐ select, Ⓑ
   close)? crash? Give repro so I can fix it.
5. **Pair the mock**: `100.127.67.80:48900` (mDNS `Vibemis-Mock-Host`, web `https://100.127.67.80:48901`,
   creds `mock` / `mockpass123`). Validate discovery + pairing + applist.

## Reporting
Report findings **incrementally on the bus in SHORT (<250 char) messages** (or append to
`testing/TEST_AGENT_FINDINGS.md` and commit) so I can hot-fix each in real time. Don't batch-and-end —
keep going; the build agent is live and acts within ~60s. This sweep gates stable 1.0.
