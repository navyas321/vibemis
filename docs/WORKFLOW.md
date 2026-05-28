# Vibemis — Development & Testing Workflow (SOP)

This is the standard operating procedure for all Claude agent sessions on the Vibemis project.
CLAUDE.md in the repo root orients fresh sessions and lists the keyword shortcuts that invoke this SOP.

---

## Keyword: `hostdevelop` — Build host session

**Means:** You are a Claude agent running on the Windows build host (WSL2 Ubuntu 24.04).
Continue or start development work.

### Session startup — do this every time

```bash
# 1. Read the plan (local to the maintainer, not in repo)
# C:\Users\navya\.claude\plans\pure-purring-pillow.md

# 2. See what landed recently
git fetch --all
git log origin/vibemis-main --oneline -8

# 3. See in-flight PRs
gh pr list --state open

# 4. See if any test reports need reading
ls testing/          # look for any task dirs with a report.md but no acted-on commit
gh pr list --state open | grep diagnostic   # report PRs from the Linux agent

# 5. Check the task list for in_progress / pending items
# (task list is visible in the FleetView session panel)
```

Then pick up the highest-priority unblocked work from the plan.

---

### Development flow

1. **Branch** off `vibemis-main`: `feat/<slug>`, `fix/<slug>`, `docs/<slug>`, `chore/<slug>`
2. **Plan mode** for non-trivial changes — explain each step before running it
3. **Build**: `qmake6 vibemis.pro CONFIG+=release && make -j$(nproc) release`
4. **AppImage**: use `bash /root/build-test<N>.sh` (build scripts live in `/root/`) or `scripts/build-appimage.sh` if linuxdeploy is in PATH
5. **Commit, push, open PR** — see conventions below
6. **Start a test cycle** if the change needs real-hardware verification (see below)

---

### Commit message format

```
<type>(<optional scope>): <short description>

<body — what AND why>
<references: test reports, related PRs, issue numbers>
```

Types: `feat`, `fix`, `docs`, `chore`, `testing`, `refactor`

Examples:
- `fix: surgical libva symlink to avoid Qt version collision (test5)`
- `testing: commit test5 AppImage for Linux agent pickup`
- `docs: rewrite README as Vibemis-native document`

---

### PR body — four-test scorecard

Every feature/fix PR must include this section:

```markdown
## Summary
- <bullet 1 — what changed>
- <bullet 2 — why>

## Test scorecard
- [ ] Build: clean build on this branch (qmake6 + make, exit 0)
- [ ] Smoke: <what was tested and the result>
- [ ] Regression: <prior features verified still working>
- [ ] Negative: <what happens when the precondition is missing>
```

Build and negative tests can often be done on the build host.
Smoke and regression tests that need a real display/GPU require the Legion Go S Z2 (see `clienttest`).

---

### Starting a test cycle

When a fix or feature needs real-hardware verification:

1. **Build** the AppImage (see AppImage naming convention below)
2. **Write** `testing/<task>/instructions.md` using the template below
3. **Commit** the AppImage to `testing/<task>/` (tracked via `!testing/**/*.AppImage` in `.gitignore`)
4. **Push** to a **`test<N>-<slug>`** branch (see naming rule below — this is critical)
5. **Tell the user** (or leave a PR comment): "Test cycle `<task>` is ready — pull the branch on the Legion Go S Z2 and run `clienttest`"
6. **Wait** for the report PR from the Linux agent before iterating on a code fix

Test task naming: `test<N>-<short-slug>` where N increments monotonically. Example: `test7-streamsegue-fix`.

**Branch naming rule — the Linux agent depends on this:**
The branch that carries the test AppImage MUST be named `test<N>-<slug>`, not `fix/<slug>` or `feat/<slug>`. Reason: the `testing/test<N>/` directory only exists on the feature branch — `vibemis-main` does not have it. If the branch is named `fix/something`, the Linux agent has no reliable way to know which branch to check out, and will try `vibemis-main` (where the test directory doesn't exist).

Procedure:
- When a fix branch is ready for a test cycle, create a new branch named `test<N>-<slug>` from the fix branch tip.
- Commit the AppImage + instructions on that `test<N>-<slug>` branch.
- The instructions file's `git checkout` command must reference `test<N>-<slug>` by name.
- The original `fix/<slug>` branch remains open as the PR target; `test<N>-<slug>` is just the delivery vehicle for the test artifacts.

#### instructions.md template

```markdown
# Test<N> Instructions — <what is being tested>

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Prior report:** `<path>` or N/A
**Goal:** <one sentence>

---

## Background
<what changed since the last test and why you expect it to work>

---

## Artifact

**AppImage:** `testing/<task>/Vibemis-<version>-x86_64.AppImage`
**md5:** `<hash>`

Verify before running:
```bash
md5sum testing/<task>/*.AppImage
```

---

## Test procedure

### Setup
```bash
cd ~/vibemis
git fetch origin <branch>
git checkout <branch> && git pull
chmod +x testing/<task>/*.AppImage
```

### Tier 1 — <name of main test>
<exact commands, including log capture and kill after N seconds>

### Tier 2 — control run / escape hatch
<exact commands for the A/B baseline>

---

## What to check and report
<numbered list, each with the exact grep/check command and expected output>

---

## Report format
Commit `testing/<task>/report.md` on branch `diagnostic/<task>-report` and open a PR.

Required sections in the report: TL;DR table, results per tier, recommendation.

---

## Safety rules (standing)
- No package installs, no sudo outside read-only inspection
- Do not modify the AppImage
- Do not attempt to pair or stream unless the instructions explicitly ask for it
- If a step needs a permission or capability outside these rules, stop and ask
```

---

## Keyword: `clienttest` — Linux test agent session

**Means:** You are a Claude agent running in SteamOS Desktop Mode on the
Lenovo Legion Go S Z2. Run the current pending test cycle and file a report.

### Hard constraints — never violate

- **No `sudo`** except for read-only inspection (`sudo cat /var/log/...`). Never `sudo apt`, `sudo pacman`, or any system modification.
- **No package installs.** The rootfs is immutable anyway.
- **Do not modify the AppImage.** Run it exactly as committed.
- **Do not pair or start a stream** unless the instructions file explicitly asks for it. Seeing the host in the Computers list is fine; do not click Connect.
- If an instruction step would require breaking any of these rules, **stop and report the blocker** rather than working around it.

### Session startup — do this every time

```bash
cd ~/vibemis   # or wherever you cloned the repo

# 1. Get the latest
git fetch origin

# 2. Find the active test branch — always named test<N>-<slug>
git branch -a | grep "remotes/origin/test" | sort | tail -5
# Pick the highest test number (e.g. test7-streamsegue-fix)

# 3. Check out that branch — NOT vibemis-main
git checkout test<N>-<slug>
git pull

# 4. Find the instructions
ls testing/
# Read the newest instructions.md in testing/test<N>-<slug>/
```

**Important:** test AppImages are committed to the `test<N>-<slug>` branch, NOT to `vibemis-main`. If `ls testing/` doesn't show the expected test directory, you are on the wrong branch.

Read the entire instructions file before running any commands.
Note the AppImage filename, md5, and the exact commands — do not improvise.

---

### Test execution flow

1. **Verify md5** — if it doesn't match, stop and report. Do not run an unverified AppImage.
   ```bash
   md5sum testing/<task>/*.AppImage
   ```
2. **Run Tier 1** (default run) exactly as written in the instructions, capturing all output.
3. **Run Tier 2** (control / escape hatch) exactly as written, capturing output.
4. **Check each signal** listed in the "What to check and report" section using the exact commands provided.
5. **Write the report** (see format below).
6. **Commit and push** on `diagnostic/<task>-report`, open a PR.

---

### Writing the report

**File:** `testing/<task>/report.md`
**Branch:** `diagnostic/<task>-report` (create off the feature branch being tested)
**PR target:** the feature branch (not `vibemis-main`)

Keep the report under ~150 lines. Full log files stay in `/tmp/` on the device — only paste relevant excerpts (10–20 lines max per excerpt). The build agent reads the report, not the raw logs.

#### Report template

```markdown
# Test<N> Report — <what was tested>

**Artifact tested:** `<AppImage filename>`
**md5:** `<hash>` ✓ verified
**Branch:** `<branch>` (commit `<sha8>`)
**Device:** Lenovo Legion Go S Z2, SteamOS <version>, Mesa <version>
**Test date:** <YYYY-MM-DD>
**Prior report:** <path or N/A>

---

## 1. Headline TL;DR

| Goal | Status | Summary |
|------|--------|---------|
| **Goal A — <main goal>** | PASS / FAIL / PARTIAL | <one line> |
| **Goal B — no regression** | PASS / FAIL / N/A | <one line> |

---

## 2. <Tier 1 — main test results>

<Hook line or relevant diagnostic output>

<Log excerpt — only the relevant lines, not the whole log>

---

## 3. <Tier 2 — control run results>

<Confirm the escape hatch works / baseline still behaves>

---

## 4. Other findings

<Any unexpected log lines, environmental notes>

---

## 5. Recommended next step

MERGE / ITERATE (with specific suggestion) / ESCALATE (with what's unknown)
```

---

## Branch and file naming conventions

| Purpose | Pattern | Example |
|---------|---------|---------|
| Feature | `feat/<slug>` | `feat/video-scale-mode` |
| Bug fix | `fix/<slug>` | `fix/appimage-vaapi-driver-paths` |
| Docs | `docs/<slug>` | `docs/rewrite-readme` |
| Maintenance | `chore/<slug>` | `chore/sync-upstream` |
| Test report | `diagnostic/<task>-report` | `diagnostic/test5-libva-surgical-report` |

### AppImage naming

```
Vibemis-<semver>-<slug>-x86_64.AppImage
```

For test builds the slug includes the test number and a short description:
- `Vibemis-0.6.7-vibemis-test5-libva-surgical-x86_64.AppImage`

For release builds, just the version:
- `Vibemis-0.7.0-x86_64.AppImage`

---

## Infrastructure reference

| Role | Machine | How to reach |
|------|---------|-------------|
| Build agent | Windows host, WSL2 Ubuntu 24.04 | Direct — this is the primary dev machine |
| Test agent | Lenovo Legion Go S Z2, SteamOS 3.x | Via git — commit instructions/AppImage, pull report |
| Streaming host | Navid-PC running Vibepollo | LAN — used in streaming smoke tests |

**Build tools in WSL2:**
- Compiler: `gcc`/`g++` (system GCC)
- Build system: `qmake6` (Qt 6.4.2), `make`
- AppImage bundler: `/usr/local/bin/linuxdeploy.AppImage` + `/usr/local/bin/linuxdeploy-plugin-qt.AppImage`
- GitHub CLI: `gh`

**Per-test build scripts** live in `/root/` on the WSL2 host (e.g. `/root/build-test5.sh`).
The canonical AppImage build script is `scripts/build-appimage.sh` in the repo.

---

## Four-test scorecard — when each can run on which machine

| Test | Description | Build host OK? | Legion Go S Z2 required? |
|------|-------------|:--------------:|:------------------------:|
| Build | `qmake6 + make`, exit 0, binary present | ✅ always | — |
| Smoke | Feature works on happy path | Only for logic-only changes (no display/GPU) | For any AppImage / streaming / display feature |
| Regression | Prior features still work | Only for logic-only changes | For any AppImage / streaming / display feature |
| Negative | Feature degrades cleanly when precondition missing | ✅ usually (host offline, setting disabled, etc.) | If it requires a real display state |
