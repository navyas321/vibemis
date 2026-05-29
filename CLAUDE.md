# CLAUDE.md — orientation for Claude agents working on Vibemis

This file is read at the start of every Claude session in this repo. Keep it short — link out to longer docs (the plan, the testing workflow, etc.) rather than duplicating their content here.

## Keyword shortcuts

When the user's first message is one of these keywords, follow the corresponding SOP in [`docs/WORKFLOW.md`](docs/WORKFLOW.md) — do the session startup checklist, then continue work without asking what to do:

| Keyword | Role | What to do |
|---------|------|-----------|
| **`hostdevelop`** | Build agent on WSL2 (Windows host) | Read plan → `git fetch` → `gh pr list` → check `testing/` for unread reports → pick up highest-priority work from the task list / plan |
| **`clienttest`** | Test agent on Legion Go S Z2 (SteamOS Desktop Mode) | `git fetch` → checkout the **`test<N>-<slug>`** branch (NOT `vibemis-main`) → find `testing/test<N>-<slug>/instructions.md` → run the test tiers → write and commit `testing/<task>/report.md` on `diagnostic/<task>-report` → open PR |

Full procedures, templates, and conventions are in [`docs/WORKFLOW.md`](docs/WORKFLOW.md).

## What this repo is

**Vibemis** is a Linux-focused fork of [Vibemis Qt](https://github.com/navyas321/vibemis) (which is itself a fork of [Moonlight Qt](https://github.com/moonlight-stream/moonlight-qt)). It's a desktop / Steam Deck / handheld streaming client tuned to pair with **Vibepollo** (a Sunshine fork). C++ / Qt 6 / QML, built with qmake6.

- **Default branch:** `vibemis-main` — long-running integration branch where work lands.
- **Original upstream mirror:** `develop` — mirror of wjbeckett's Vibemis Qt `develop` at the time of fork. Don't push to it.
- **Submodule of note:** `moonlight-common-c/moonlight-common-c` points at [ClassicOldSong's Apollo-lineage fork](https://github.com/ClassicOldSong/moonlight-common-c), NOT mainline `moonlight-stream/moonlight-common-c`. Whenever upstream moonlight-qt rebase happens, the wrapper `.pro` must be checked for upstream's new symbols that ClassicOldSong's fork doesn't expose (e.g. `src/rswrapper.c`, `nanors/`, `LiSendControllerTouchEvent2`, `LI_CCAP_DUAL_TOUCHPAD`, `LiGetMicroseconds`).

## The plan

The canonical project plan lives at `C:\Users\navya\.claude\plans\pure-purring-pillow.md` on the build host (NOT in this repo — it's intentionally local to the maintainer). Read it at the start of every session. It contains:
- Phase roadmap with status (Phase 1, 1.5 done; Phase 2 in progress; Phase 8.5 SteamOS features pending)
- User decisions locked in (build host, branch model, rebrand scope, upstream strategy, testing setup)
- Working agreement (PR-per-feature, four-test discipline)
- Test-handoff workflow (this repo ↔ Legion Go S Z2 test device, via in-repo files)

If the plan and this CLAUDE.md disagree, the plan wins. If you can't see the plan (different machine, etc.), ask the user.

## Testing workflow (in-repo, agent-to-agent)

- Build agent (on WSL2) writes `testing/<task>/instructions.md` AND the test artifact (AppImage or similar) in the same directory.
- AppImages inside `testing/<task>/` are tracked in git (see `!testing/**/*.AppImage` in `.gitignore`); root-level build outputs stay ignored.
- Linux test agent (on the Legion Go S Z2) pulls the branch, runs the instructions, commits `testing/<task>/report.md` (or top-level `DIAGNOSTIC_REPORT_<task>.md` if short) on a separate `diagnostic/<task>-report` branch, opens a PR.
- Build agent pulls the report PR and acts on it.
- See `pure-purring-pillow.md` "Test-handoff workflow" section for the canonical version.

**Branch naming for test cycles — IMPORTANT:**
The feature branch carrying a test AppImage MUST be named `test<N>-<slug>` (e.g. `test7-streamsegue-fix`), NOT `fix/<slug>` or `feat/<slug>`. The Linux test agent looks for the newest `test<N>-*` branch when running `clienttest`. Using `fix/` or `feat/` branches confuses the agent because `vibemis-main` doesn't have the `testing/test<N>/` directory — the artifacts only exist on the feature branch, and the agent won't know which branch to check out without this convention.

Build agent rule: before starting a test cycle, rename (or create fresh from) the feature branch as `test<N>-<slug>`, commit the AppImage + instructions there, and target that branch in the instructions' `git checkout` command.

## Development priority: Game Mode over Desktop Mode

**Primary target is SteamOS Game Mode (Gamescope), not Desktop Mode (KDE Plasma).**

Game Mode uses Gamescope — Valve's micro-compositor that runs games in a nested Wayland
session with a single Vulkan surface. Key implications:

- **Separate OS windows do not work in Gamescope.** A `QQuickView` with
  `Qt::WindowStaysOnTopHint` will not appear in Game Mode. Gamescope owns all z-ordering
  through its own Vulkan surface.
- **SDL-internal overlay rendering is the only correct approach for Game Mode.** This is
  exactly what moonlight-qt does: it renders overlays (stats, warnings) as SDL textures
  composited inside `sdlvid.cpp` via `SDL_RenderCopy` after the video frame. No separate
  window; no focus or z-order issues.
- The current Quick Menu QQuickView approach is a Desktop Mode workaround. It works
  tolerably in KDE Plasma windowed mode but is architecturally wrong for Game Mode.

**Long-term Quick Menu architecture:** Migrate to SDL-internal overlay rendered as a
texture in `sdlvid.cpp`, driven by a `QOffscreenSurface` + `QQuickRenderControl` pipeline
(render QML offscreen → upload as SDL texture → composite into stream frame). This will
work in both Game Mode and Desktop Mode without any window management hacks.

**When testing:** prioritise Game Mode. Desktop Mode results are informative but secondary.
If a feature works only in Desktop Mode, it's not ready.

## CI / AppImage release rules — READ BEFORE PUSHING

The CI smart-build check (`setup-version` → `check-changes`) sets `should_build=false`
when the HEAD commit only touches `.md` files. When `should_build=false`, the AppImage
build and `create-dev-release` jobs are **skipped entirely** — no AppImage is produced.

**This trips us constantly.** The pattern that breaks things:

```
git commit -m "fix: real code change"        ← code touches .cpp/.h/.qml
git commit -m "test: add testN instructions" ← only .md files
git push                                     ← CI sees HEAD = .md only → skips
```

The test agent downloads from GitHub Releases and finds the OLD AppImage (from the
commit before the fix), not the new one.

**Rules:**

1. **The last commit before a push that is meant to produce a new release MUST touch a
   code file** (`.cpp`, `.h`, `.qml`, `.yml`, `.pro`). `.md`-only commits set
   `should_build=false` and no AppImage is built.

2. **When you want the test agent to pick up a build:** make sure the code fix commit
   (`fix: ...`) is the LAST commit in the push, or bundle test instructions into the
   same commit as the code change.

3. **Test instruction commits (`test: ...`) should come BEFORE the fix commit**, not after.
   Order matters because CI evaluates the HEAD commit only.

4. **If you've already pushed a docs-only commit and need to force a new build:** make a
   trivial meaningful code change (e.g. add/update a comment in a `.cpp` file) with
   `fix:` in the commit title and push it. Do NOT use `workflow_dispatch` alone —
   it still goes through the smart-build check and will skip if HEAD is docs-only.

5. **The `create-dev-release` job only runs on `fix/**` and `vibemis-main`.** Other branch
   prefixes (`test**`, `verify/**`, `chore/**`) build the AppImage as a CI artifact but
   do NOT publish it to GitHub Releases. Test agents can only download from Releases.

## Working agreement

- Plan mode for non-trivial changes — explain each step before running it.
- **One feature per branch, one PR at a time.**
- Every feature PR carries a four-test scorecard in its body: **build / smoke / regression / negative**.
- Stop and ask before any destructive command (force push, branch delete, hard reset, `git checkout` over uncommitted work).
- Stop and ask if a step needs the user to do something physical (plug in hardware, set Vibepollo permission, etc.).

## Model selection — what's appropriate when

**Default for routine work: Sonnet (current latest).** Reading code, making targeted edits, running shell commands, parsing logs, writing PR descriptions — Sonnet handles all of it well, and it's roughly 3× cheaper per token than Opus.

**Upgrade to Opus (current latest) when about to do any of:**

- A multi-file architectural decision (rebase vs merge, take-ours-wholesale, refactor across 10+ files). The Phase 1.5 upstream sync was the prototypical Opus moment — picking the right strategy among Option A/B/C/D matters more than the per-file mechanical work that follows.
- Cross-system debugging where the root cause spans 3+ distinct layers (e.g. the libva 1.20 vs `__vaDriverInit_1_22` ABI gap involved the bundled lib, the system mesa-va driver, AND the libva dlsym walk semantics — three independent moving parts).
- Reviewing a stack of conflict resolutions / merge choices for soundness before pushing.
- Designing a new Phase from scratch when there's no template (Phase 8.5 SteamOS-features research will be this — it requires synthesizing online docs + assessing trade-offs across a candidate set, then proposing a vetted shortlist).
- The first session after a long pause where there's a lot of accumulated context to absorb.

**If you (the Claude agent) think a task feels Opus-worthy, FLAG IT before starting.** A one-line "this feels like an Opus task because [reason] — want to switch?" lets the user decide. It's cheaper than blundering through with Sonnet, getting stuck, and re-doing the work later.

**For the Linux test device on the Legion Go S Z2:** default to Sonnet. The test-report-writing job is bounded enough that Sonnet handles it well (see `DIAGNOSTIC_REPORT_test3.md` for quality reference). Don't downgrade to Haiku — the agent needs to find subtle signals in big log files. Don't upgrade to Opus unless a test cycle is unusually open-ended.

## Quick orientation for a fresh session

1. Read the plan at `C:\Users\navya\.claude\plans\pure-purring-pillow.md` (build host).
2. `git fetch && git log --oneline -10` to see recent activity.
3. `gh pr list --state open` to see in-flight PRs.
4. Look at `testing/` for any open test cycle the Linux agent is or should be working on.
5. Check the task list for the in-progress / pending items.

Then pick up where the previous session left off.
