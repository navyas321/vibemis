# Test117 Instructions — AppView re-entry resumes the running session (BL-1756)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Prior evidence:** test110 report finding — re-entering AppView with a session running
server-side issued LAUNCH instead of RESUME.
**Goal:** after ending a stream WITHOUT quitting the app, re-activating that app from
AppView resumes the existing session instead of relaunching it.

## Background

currentGameId is only written by the serverinfo poll, and polling is suspended while the
stream window is up — so a stream that ended without quit left AppView blind to the still-
running app until the next poll. The fix stamps the running app id as the session finishes
(gated on connection success; the next poll stays authoritative). File:
app/streaming/session.cpp (+14 lines).

**Build tier: ALPHA (BL-2016). Take the newest alpha whose release body names this branch;
hashes get stamped here + inbox + bus at dispatch.**

## Test procedure

### Tier 0 — integrity + boot
md5/sha256 exact vs dispatch post; `selftest --json` PASS exit 0.

### Tier 1 — resume on re-entry (needs the Vibepollo host; no host operator required)
1. Stream any app/Desktop from Navid-PC; confirm it is up.
2. END the stream WITHOUT quitting the app (close the stream window / disconnect —
   NOT "Quit app").
3. Back in AppView immediately (before ~any serverinfo poll lands), the streamed app
   should show the RESUME badge and pressing A on it must RESUME (log shows resume, not
   launch: `grep -iE "resum|launch" /tmp/test117-t1.log`).
4. Negative: activating a DIFFERENT app must keep existing behavior (quit-prompt flow).
5. Regression: quit the app properly, re-enter — no phantom RESUME badge after the next
   poll (stale-id self-heal via the poll).

## What to check and report
1. Tier 0 verdicts; 2. resume-not-launch log evidence for step 3; 3. negative + regression
outcomes; 4. any badge/hint oddity in AppView.

## Teardown
Quit the streamed app at the end (host-side must be clean); remove /tmp/test117-*.log.

## Report
`testing/test117-resume-reentry/report.md` on `diagnostic/test117-resume-reentry-report`,
tick/annotate the checklist, PR targets `test117-resume-reentry` (stacked pattern).

## Safety rules (standing)
No sudo/package installs; don't modify the AppImage; pairing/streaming IS required here.
