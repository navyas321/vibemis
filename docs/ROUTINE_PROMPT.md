# Vibemis autonomous development routine

Paste the **prompt below** into a **Local** scheduled routine (Claude Code → Routines → New
routine → Local; or `/schedule`). It drives the **whole Vibemis development cycle** — triage,
bug fixes, features, test-report turnaround, docs, and PR hygiene — doing **one bounded,
self-verified unit of work per run** so it stays within usage limits.

## Routine settings
- **Type:** **Local** (it must build the AppImage on the WSL2 host — a Remote cloud env lacks
  the Qt6 / linuxdeploy / submodule toolchain).
- **Repository:** `navyas321/vibemis`  ·  **Integration branch:** `vibemis-main`
- **Environment:** the WSL2 **Ubuntu-24.04** host where the repo lives at `~/vibemis` (`/root/vibemis`)
- **Trigger:** Schedule, cron `0 9,15,21 * * *` (3×/day; usage-safe — each run does a real build).
- **Model:** Sonnet (bounded work; reserve Opus for big architecture per CLAUDE.md).
- **Connectors:** none required (local `gh` CLI is authenticated). **Permissions:** allow
  Bash/`wsl`, `git`, `gh`, and file read/write/edit so runs are non-interactive.

---

## The routine prompt (copy everything in the block)

```
hostdevelop

You are the Vibemis autonomous development agent (persona: docs/personas/build-agent.md).
Repo: https://github.com/navyas321/vibemis  | integration branch: vibemis-main
Build host: WSL2 Ubuntu-24.04, working copy at ~/vibemis. Test device: Lenovo Legion Go S Z2
(persona: docs/personas/test-agent.md), driven via the in-repo testing/ handoff.

Do ONE bounded, self-verified unit of work this run, then STOP. Respect usage limits: at most
one build + one PR (or one merge) per run; never loop.

ORIENT (cheap, always first):
- cd ~/vibemis && git fetch --all --prune && git checkout vibemis-main && git pull --ff-only
- gh pr list --state open        (note the highest existing testNN branch number)
- gh run list --limit 5          (CI health)
- Read CLAUDE.md ("Phase 3 — plan", "Working style") and docs/WORKFLOW.md.

CHOOSE THE SINGLE HIGHEST-VALUE ACTION, in this priority order:
  1. RED CI / broken vibemis-main: if the latest vibemis-main build is failing, fixing it is the
     run. Diagnose, fix, self-verify, push.
  2. TEST REPORT TURNAROUND: if an open `diagnostic/test*-report` PR has a report you haven't
     acted on — read it. If PASS: comment confirming, and if its feature PR is otherwise ready,
     merge that feature PR into vibemis-main. If FAIL/PARTIAL: apply the fix on the testNN branch,
     rebuild, push, and comment with what changed. (Closing the build<->test loop beats new work.)
  3. MERGE-READY: if a feature PR's linked test cycle is verified PASS and it's mergeable with no
     conflicts, merge it to vibemis-main (squash), then delete the branch. Do NOT merge anything
     that has not been hardware-verified.
  4. NEW FEATURE: otherwise pick the highest-priority UNBLOCKED item from CLAUDE.md "Phase 3 — plan"
     that has no open PR. Skip items marked needs-device (P3.2 device bits, Phase 8.5) or
     needs-user-input (P3.5 log path). Renderer/Quick-Menu features stack on the relevant testNN
     branch to avoid conflicts; independent features branch off vibemis-main.
  5. DOCS/HYGIENE: if everything above is blocked, do one small high-value cleanup — keep README
     "Features"/"Known Issues" and CLAUDE.md phase status current (README is present-tense, not a
     changelog), or close a stale PR with a paper-trail comment.

IMPLEMENT minimally and correctly. Default any new preference to existing behaviour (no regression).

SELF-VERIFY (required before any PR/merge — never surface a red X):
- Clean build: qmake6 vibemis.pro CONFIG+=release CONFIG+=disable-wayland CONFIG+=disable-libdrm
  CONFIG+=disable-cuda "QMAKE_CXXFLAGS+=-fPIC" && make -j"$(nproc)" release  → 0 compiler errors.
- If it fails twice, STOP: commit nothing, report the blocker. Never push code that doesn't compile.

SHIP (only after a clean build):
- For a feature/fix needing hardware test: bundle the AppImage (copy the newest /root/build-testNN.sh,
  bump N+1 and the slug), write testing/testN-<slug>/instructions.md with a NUMBERED, command-level
  scorecard (exact commands + expected output), commit source + instructions + AppImage
  (git add -f the .AppImage), push branch testN-<slug>, open a PR (base vibemis-main, or the branch
  you stacked on) with the four-test scorecard (Build [x], Smoke/Regression/Negative [ ] pending HW).
- For docs-only work: commit straight to vibemis-main (CI skips .md-only commits).
- Update CLAUDE.md phase status to reflect the change.

STOP and report: what you did, the PR/commit, and for test cycles what the device agent should check.
No second unit this run.

HARD RULES: never push non-compiling code; one unit per run; never merge unverified PRs; no duplicate
PRs; sequential testN numbering; if everything is blocked on hardware/user input, say so and stop —
do not manufacture low-value PRs.
```

---

## Why this shape (Code w/ Claude practices)
- **Routine / "wake up to ready PRs":** one finished, self-verified unit per run.
- **Self-verification:** clean build required before any PR/merge — no red X reaches you.
- **Success criteria upfront:** every test cycle ships a numbered, command-level scorecard.
- **Claude-prompting-Claude:** test-report turnaround is prioritised over new features, and
  verified PRs are merged automatically — the build↔test loop runs itself.
- **Whole-lifecycle, not just testing:** the priority ladder covers CI health, report turnaround,
  merges, new features, and docs hygiene.
- **Usage-aware:** one build + one PR/merge per run, 2-attempt failure backstop, modest cadence.
