# Vibemis autonomous development routine

Paste the **prompt below** into a scheduled routine (Claude Code `/schedule`, or the
Routines feature) to keep Vibemis moving while you're away — each run lands **one
self-verified, ready-to-test PR**, the way Anthropic's "wake up to ready-to-merge PRs"
demo works.

## Recommended cadence (respect usage limits)
- **Frequency:** a few runs per day at most (e.g. every 3–4 hours, or 2–3×/day). Do **not**
  run it every few minutes — each run does a real build (several minutes of compute) and a
  full agent turn, which burns the 5-hour rolling and weekly usage windows fast.
- **Bounded per run:** the prompt instructs exactly **one feature → one PR → stop**. It will
  not loop or chain multiple builds in a single run.
- **Back off on trouble:** if a run can't produce a clean build in 2 attempts, it stops and
  leaves a note instead of burning cycles.
- If you're close to a usage limit, pause the routine — the work is all in PRs, nothing is lost.

---

## The routine prompt (copy everything in the block)

```
hostdevelop

You are the Vibemis build agent (see docs/personas/build-agent.md). Run ONE bounded unit of
work this session, then stop. Respect usage limits: exactly one feature and one test PR per run.

1. ORIENT (cheap, do first):
   - cd ~/vibemis; git fetch --all --prune
   - gh pr list --state open   (note the highest testNN branch number)
   - ls testing/   and   gh pr list --search "diagnostic" --state open
     If a NEW diagnostic/test report PR exists that you haven't acted on: STOP feature work and
     instead read that report, apply the fix on the relevant testNN branch, rebuild, push, and
     comment on the PR. That is this run's unit of work. (Acting on test results > new features.)
   - Otherwise read CLAUDE.md "Phase 3 — plan" and pick the highest-priority UNBLOCKED item
     that does NOT already have an open test PR. Skip items marked needs-device or needs-user-input
     (P3.2 done via script; P3.5 needs the Windows log path; Phase 8.5 needs the device).

2. PLAN (one sentence): state the single feature you'll implement and which branch it stacks on
   (independent → off vibemis-main; Quick-Menu/renderer features → stack on test22 or test25 to
   avoid conflicts). Name the new branch testN-<slug> (N = previous highest + 1).

3. IMPLEMENT: make the minimal correct change. Keep it bounded — one coherent feature. Default
   any new pref to the existing behaviour so there's no regression.

4. SELF-VERIFY (required before any PR — never surface a red X):
   - Build: bash /root/build-verify-<slug>.sh  (qmake6 + make release; 0 compiler errors).
   - If it fails: fix and rebuild. If still failing after 2 attempts, STOP — commit nothing,
     leave a short note in the chat describing the blocker. Do not push broken code.

5. PACKAGE + SHIP (only after a clean build):
   - Build the AppImage with a testN build script (copy the newest build-testNN.sh, bump N/slug).
   - Write testing/testN-<slug>/instructions.md with a TESTABLE scorecard (numbered checks with
     exact commands + expected output — success criteria upfront, not "make it better").
   - Commit the source + instructions + AppImage (git add -f the .AppImage). Push the branch.
   - Open a PR (base = vibemis-main, or the branch you stacked on) with the four-test scorecard;
     mark Build [x] and Smoke/Regression/Negative [ ] pending hardware.
   - Update CLAUDE.md phase status / the task list to reflect the new PR.

6. STOP. Report: the PR number, the branch, the one-line feature summary, and what the test agent
   should check. Do not start a second feature this run.

Hard rules: never push code that doesn't compile; one PR per run; don't duplicate an existing
open test PR; sequential testN numbering; .md-only commits are fine on vibemis-main (CI skips
them). If everything is blocked on hardware/user input, say so and stop — don't manufacture
low-value PRs.
```

---

## Why this shape (the Code w/ Claude practices it bakes in)
- **Routine / "wake up to ready PRs":** one finished, pushed, test-ready PR per run.
- **Self-verification:** step 4 requires a clean build before any PR — the test agent never
  receives a broken artifact (no red X).
- **Success criteria upfront:** every PR ships a numbered, command-level test scorecard.
- **Claude-prompting-Claude:** prioritises acting on the Legion Go test agent's report PRs over
  new features, closing the build↔test loop automatically.
- **Usage-aware:** bounded to one build + one PR per run, with a 2-attempt failure backstop.
