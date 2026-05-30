# Working with Claude Code on Vibemis — practices

How we drive Claude Code effectively on this repo: when to plan, when to split work into tasks or
agents, and how we keep development fast and verifiable. Distilled from Anthropic's official
guidance (sources at the bottom) and adapted to Vibemis's build↔test workflow. The short version
lives in `CLAUDE.md` → "How we use Claude Code"; this is the rationale.

## 1. The core loop: Explore → Plan → Implement → Commit
- **Explore** the relevant code first (read the nearby feature you're mirroring). Don't edit blind.
- **Plan** before implementing **when** the change touches multiple files, the area is unfamiliar,
  or the approach is uncertain. Use plan mode for those. **Skip the plan** when you can state the
  exact diff in one sentence — most Vibemis single-setting/UI features qualify.
- **Implement** the smallest correct change that mirrors existing patterns.
- **Commit** with a conventional message; let CI build the artifact.

## 2. When to break work into tasks (TodoWrite/Task)
Create tasks when a job has **≥3 distinct steps**, **spans multiple files**, or **must survive a
context reset**. Keep exactly one task `in_progress`. Encode **real dependencies** so parallel work
can't collide and unverified work can't be built on:
- e.g. `verify CI green (testNN)` **blocks** `stack testN+? on testNN`.
- e.g. `test22 verified` **blocks** the Quick-Menu-content rows that stack on it.
Mark a task `completed` only when it's *fully* done (build green / tests pass) — never with a
partial or red build.

## 3. When to spawn a subagent (and when not)
Subagents have **isolated context** and report back only a summary — ideal for:
- **Wide read-only searches** ("find every caller of `uniqueAddresses`", "where is the overlay
  positioned across all renderers").
- **Genuinely independent, parallelizable slices** that don't share state.
- **Context-heavy sifts** where most of what's read is noise.

Do **not** spawn a subagent for ordinary multi-step work you can do inline — a cold subagent
re-derives context you already hold and costs more. Our standing decomposition is the two-agent
split: **`hostdevelop`** (build agent, this machine) writes features + instructions;
**`clienttest`** (test agent, Legion Go) runs the checklist and files reports. See
`docs/personas/`.

## 4. CLAUDE.md is ~70% reliable — safety needs enforcement
Prose guidance is followed most of the time, which is fine for style but **not** for invariants.
Anything that must hold *every* time is enforced by mechanism, not just documented:
- "Only `vibemis-main` ships a beta; `test**` ships an alpha" → enforced by the CI tier logic +
  branch filters in `.github/workflows/dev-build.yml`.
- "Releases page stays tidy" → enforced by the workflow's `Prune superseded releases` step.
- **Proposed hook (not yet enabled):** a `PreToolUse` Bash guard that blocks `git push origin
  vibemis-main` when the diff contains non-doc files without a PR, and a `PostToolUse` hint that
  runs `qmake6 -nocache` parse / a QML lint after edits. Hooks live in `.claude/settings.json`.
  *Rule:* never block `Edit`/`Write` mid-plan — validate in `PostToolUse`/pre-commit instead, or
  the model loses its place.

## 5. Tests are the oracle (TDD-adapted)
A model's self-judgment degrades as context fills; an external check does not. We don't do literal
red-green unit TDD on this GUI/streaming client, but we apply the same principle:
- Every test PR ships a **command-level scorecard** (exact commands + expected output) in its
  `testing/<branch>/instructions.md`, not "make it better".
- **CI compile-sanity is the build oracle.** We **never stack** a new test branch on one whose CI
  hasn't gone green (`/verify-ci`). A green compile is trusted; our own "looks right" is not.
- The test agent's `report.md` (TL;DR table → per-tier → recommendation) is the runtime oracle.

## 6. Rapid development habits
- **Single-purpose PRs.** One concern per testNN; if it grows, split it. Small diffs review and
  verify fast and isolate regressions.
- **Mirror, don't invent.** Copy the structure of the nearest existing feature (e.g. a new pref
  mirrors `showPerformanceOverlay` end-to-end). Fewer surprises, faster compiles.
- **Let CI build the artifact.** Pushing a `test**` branch auto-publishes its alpha — no need to
  build + commit an AppImage locally for every cycle.
- **Parallelize independent tool calls** in one message (multiple reads/greps at once); only
  serialize when a later step needs an earlier result.
- **Background long waits.** Run `gh run watch` / long builds in the background and keep working;
  act on the completion notification instead of polling.
- **Reusable workflows are slash commands** (`.claude/commands/`): `/ship-test-pr`, `/verify-ci`,
  `/release-hygiene`. Encode a workflow once, stop re-deriving it.
- **Self-verify before handoff.** The owner / test agent should never see a red X.

## 7. Alerting the maintainer hands-off (GitHub bot @mention → mobile push)
When an unattended agent needs to reach the maintainer (build failed, test agent went silent, a
decision is needed), the reliable channel here is a **GitHub Actions workflow that posts an @mention
as `github-actions[bot]`** — because the bot is a *different actor* than the maintainer, GitHub's
"no notifications for your own actions" rule does **not** suppress it, so it delivers a real push to
the GitHub mobile app. Verified working on this repo.
- Workflow: [`.github/workflows/alert.yml`](../.github/workflows/alert.yml) ("Build Agent Alert",
  `workflow_dispatch` with `message` + `severity`). It **creates a fresh issue** that `@`-mentions
  the maintainer (the mention delivers the push *at creation time*) and then **closes it
  immediately**. Inputs are passed via **env** (not inline `${{ }}`) to stay injection-safe.
- Fire it: `gh workflow run "Build Agent Alert" --ref vibemis-main -f message="..." -f severity="error"`.
- **Why create-then-close, not a standing open issue:** a permanently-open "alerts" issue is a
  standing inbox — injected web/email content surfaced into a comment could be read back by the agent
  as instructions. Transient create-then-close issues carry the same push but leave **no open channel
  to inject through**. (The old standing channel, issue #99, was closed for this reason.)
- **Pitfalls learned:** (a) a *self*-authored `gh issue` create/comment/mention (token authed as the
  maintainer) does NOT notify them — only the **bot**-posted mention does, so always alert via the
  workflow. (b) Repo issues must be enabled. (c) The Gmail connector available here is **draft-only**
  (no send), and `PushNotification` needs Remote Control paired — both are weaker than the GitHub
  channel for true hands-off delivery. (d) On the phone: GitHub app → Settings → Notifications →
  Push → "Direct mentions" must be on.
- A background watcher can fire this itself on a condition (e.g. "no new test report in 45 min")
  since `gh workflow run` is just a CLI call.

## 8. Periodically audit your own verification, coverage & safety mechanisms
An autonomous agent accumulates mechanisms — coverage gates, alert channels, watchers, merge
hygiene, CI rules. **Don't build them once and trust them forever.** Revisit them in lulls and after
any incident, and ask: *"is this still sound, and is anything slipping through it?"*
- **Coverage gating is the easy one to get wrong.** Be explicit about *partial* verification. If you
  merge on a launcher-only/Tier-1 PASS while a host/stream/controller/network tier is N/A, that
  deferred tier must land in an **active queue** (here: the *Deferred verification ledger* in
  `testing/TEST_CHECKLIST.md`), not just a now-closed report. Ticking the main row must not "hide"
  an unverified tier. Add the ledger row **at merge time**, not later.
  - *Merge-on-launcher is the right default* when the deferred behavior is gated/safe (default-off
    setting, observation-only, non-destructive) and can't be exercised without absent hardware —
    blocking would stall the whole pipeline. *Gate strictly* only for active/risky runtime behavior.
- **Re-test the alert path** (create-then-close GitHub issue → iOS push) occasionally — a silent
  break means you think you're reachable when you're not.
- **Watch the watcher:** confirm it's still running and deduping correctly (SHA-based, so a *re-test*
  push on the same branch re-fires; a name-based dedup would miss it). A missed report is invisible.
- **Merge hygiene:** spot-check that "keep-both" conflict resolutions still compile on the trunk
  (the post-merge trunk build is the safety net — watch it).
- **CI rules:** confirm invariants still hold (e.g. beta builds *only* on a real PR merge, not every
  push — regressions here resurface as noise).
- When you add or improve a mechanism, record it here **and** in your durable memory.

## Sources
- [Anthropic — Claude Code best practices](https://www.anthropic.com/engineering/claude-code-best-practices)
- [Anthropic — Building agents with the Claude Agent SDK](https://www.anthropic.com/engineering/building-agents-with-the-claude-agent-sdk)
- [Anthropic — Introduction to subagents](https://anthropic.skilljar.com/introduction-to-subagents)
- [DataCamp — Planning, context transfer, TDD](https://www.datacamp.com/tutorial/claude-code-best-practices)
- [Plan Mode in Claude Code](https://codewithmukesh.com/blog/plan-mode-claude-code/)
- [awesome-claude-code (hooks/commands/agents)](https://github.com/hesreallyhim/awesome-claude-code)
