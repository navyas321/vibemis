# P4.0 — Two-repo split: migration plan (BL-1565)

**Status: PLAN ONLY — nothing moves until the maintainer green-lights the execution day.**
Companion tooling: [`scripts/repo-split-dryrun.sh`](../scripts/repo-split-dryrun.sh) (prints every
move/stub this plan implies; `--execute` performs the *local* moves only, never any GitHub
operation).

## 1. Context and goal

Flathub publication (BL-1556) will eventually make this repo public. Today the repo mixes two
kinds of content:

1. **The product** — Vibemis source, build system, CI, user/developer docs, design assets.
2. **Agent-orchestration meta** — CLAUDE.md session governance, agent personas, SOPs, the
   build-agent/test-agent inbox/outbox channels, per-cycle test instructions and reports,
   slash commands, and ~1.27 GB of tracked test AppImages.

The decision of record (`docs/PHASE_STATUS.md`, P4.0, deferred post-1.0): **two-repo split** —
keep `navyas321/vibemis` as the (future-public) code repo so Releases/AppImages stay
downloadable at their current URLs (the in-app updater depends on that), and move the agent
meta into a new **private** repo `navyas321/vibemis-agent-meta` that both agents also clone.

Repo scale for reference: 561 tracked files; `testing/` holds 127 of them (16 are ~79 MB
AppImages); `docs/` holds 55.

---

## 2. Inventory — keep-public / move-private / split-content

Verdicts: **KEEP** = stays in vibemis (public), **MOVE** = migrates wholesale to
vibemis-agent-meta, **SPLIT** = product-relevant content is extracted into a public doc first,
remainder moves, **DROP** = removed from the tree and not migrated (still in history and/or
GitHub Releases).

### 2.1 Root

| Path | Verdict | Rationale |
|---|---|---|
| `CLAUDE.md` | **SPLIT** | Mostly agent governance (keyword shortcuts, personas, model selection, session handoff, phase plan) = private. BUT it is today the *only* home of repo-level product policy: the SemVer 2.0.0 versioning rules, the release-tier matrix, the CI smart-build rules, the README-update rule. That policy must survive publicly -> extract to `docs/RELEASING.md` (+ CONTRIBUTING pointers) before the move. A slim public CLAUDE.md (build commands, branch model, "agent meta lives elsewhere") replaces it — public CLAUDE.md files are normal practice and it keeps drive-by Claude sessions oriented. |
| `README.md`, `CONTRIBUTING.md`, `LICENSE`, `RELEASES.md` | **KEEP** | Product docs. README has no references to agent meta (verified). CONTRIBUTING gains the commit/PR conventions extracted from WORKFLOW.md. |
| `.gitignore` | **KEEP** (1-line edit) | Drop the `!testing/theme-review/*.zip` un-ignore once theme-review moves. |
| `.gitmodules`, `vibemis.pro`, `globaldefs.pri`, `setup-deps.*`, `config.tests/`, `app/`, `AntiHooking/`, submodules (`moonlight-common-c/`, `qmdnsengine/`, `soundio/`, `h264bitstream/`) | **KEEP** | The product. |
| `scripts/` (all 23 files) | **KEEP** | User/dev tooling (installers, Steam helpers, doctor, build-appimage, qmlrender). Two comment-level references to meta need edits (section 3). `gamescope-lease.sh` / `gamescope-emulate.sh` are device-test helpers but are generic and harmless public; keeping them avoids breaking device workflows. |
| `.github/` (workflows, templates) | **KEEP**, except `alert.yml` | CI is product infrastructure. `dev-build.yml` has one comment mentioning CLAUDE.md (edit). |
| `.github/workflows/alert.yml` | **MOVE** (or delete) | "Build Agent Alert" @mention push channel — pure agent infra, and per maintainer directive 2026-07-13 the channel is retired. Recommend delete rather than migrate; preserved in history either way. Open question 6.3. |

Root debris (not agent meta, but pre-publication hygiene — see Appendix A):
`config.log` (upstream author's local build log), `test_changes.md`, `test_hash.py`,
`test_otp_hash.cpp`, `find_passphrase.py` (OTP hash brute-force debug script — bad look
public), `create_feature_branch.sh`, `AV1_DETECTION_ANALYSIS.md` (product analysis; fold into
docs/ or drop).

### 2.2 docs/

| Path | Verdict | Rationale |
|---|---|---|
| `docs/WORKFLOW.md` | **SPLIT** | The hostdevelop/clienttest SOP, session startup checklists, and test-cycle handoff protocol are agent meta -> private. Extract first: commit-message format + PR four-test-scorecard conventions -> `CONTRIBUTING.md` (they apply to human contributors too). |
| `docs/personas/` (README + build-agent + test-agent) | **MOVE** | Pure agent orchestration: cold-start bootstraps, device identities, channel protocol. Nothing product-facing. |
| `docs/ROUTINE_PROMPT.md` | **MOVE** | The scheduled-routine prompt for unattended development; references maintainer-local paths. Pure agent meta. |
| `docs/CLAUDE_CODE_PRACTICES.md` | **MOVE** | "How we use Claude Code on this repo" rationale. Pure agent meta. |
| `docs/TEST_AUTOMATION.md` | **SPLIT** | Framed as test-agent SOP (-> private), but it documents real product surfaces: `vibemis selftest` / `selftest --json`, CLI verbs (`list`, `quit`), log-signal assertions. Extract those into a public `docs/SELFTEST.md` — two app-code comments point at this file today (section 3). |
| `docs/PHASE_STATUS.md` | **MOVE** | Phase tracker + blockers + research backlog + BL-ids + maintainer decisions = fleet/PM state, not product description. (Product-facing history lives in RELEASE_HISTORY/release notes, which stay.) |
| `docs/SESSION_HANDOFF_2026-07-13.md` | **MOVE** | Point-in-time agent session handoff. |
| `docs/UI_DEFECT_CHECKLIST.md` | **MOVE** | Manual-testing defect ledger (QA state, companion to the session handoff). |
| `docs/RELEASE_HISTORY.md`, `docs/release-notes-v*.md`, `RELEASES.md` | **KEEP** | Product release record — explicitly public per the release-permanence policy. |
| `docs/BUILD_SYSTEM.md`, `docs/DEVELOPMENT.md`, `docs/DISTRIBUTION.md`, `docs/DESIGN_SYSTEM.md`, `docs/REMOTE_PLAY_TAILSCALE.md`, `docs/WINDOWS_ARM64.md`, `docs/DEVICE_LOG_CAPTURE.md` | **KEEP** | Product/developer documentation. DEVELOPMENT.md + BUILD_SYSTEM.md need reference edits (section 3). DEVICE_LOG_CAPTURE.md is a genuinely useful SteamOS debugging technique (scrub its one BL-id in passing). |
| `docs/design/` (tokens, previews, logo, original-ui) | **KEEP** | The app's actual design assets/spec — product. |
| `docs/design/redesign/CLAUDE_CODE_PROMPT.txt` | **MOVE** | An agent prompt artifact that rode along with the design drop. |
| `docs/design/redesign/HANDOFF.md` | **MOVE** | Agent-to-agent design handoff narrative (the *spec* it describes — previews/tokens — stays). Borderline; cheap to keep private. |

### 2.3 testing/ — moves wholesale (with one DROP class)

The whole `testing/` tree is the agent-to-agent handoff surface. Verdict: **MOVE the tree,
DROP the binaries**, leave a stub README.

| Path | Verdict | Rationale |
|---|---|---|
| `testing/BUILD_AGENT_INBOX.md`, `testing/TEST_AGENT_OUTBOX.md` | **MOVE** | The two agent coordination channels. Pure orchestration; also carry infra details (tailnet IPs, host names, hashes). |
| `testing/TEST_CHECKLIST.md` | **MOVE** | The agents' ordered verification queue, alpha-tier rules, BL-ids. |
| `testing/TEST_AGENT_FINDINGS.md`, `TEST_AGENT_SWEEP.md`, `REDESIGN_CORRECTION.md`, `FINAL_REPORT_1.0.0.md` | **MOVE** | Agent QA reports/escalations; include device/tailnet/host specifics. |
| `testing/test*/instructions.md` (76) + `report.md` (4) | **MOVE** | The brief's counter-argument is fair — they describe product behavior and would be harmless public. But they are *cycle artifacts of the agent loop* (alpha tags, md5/sha256 hashes, device paths, BL-ids, maintainer escalations), their public documentation value is near zero, and cherry-picking "clean" ones creates an endless review burden. One rule ("testing/ is private") is enforceable; per-file judgment is not. If a public test story is ever wanted, write a fresh `docs/TESTING.md` instead. |
| `testing/**/*.AppImage` (16 files, ~1.27 GB) | **DROP** | Release artifacts, never source. Every one exists in GitHub Releases (and in git history regardless). Migrating them would bloat the private repo for no benefit; current policy already bans committing AppImages (.gitignore comment) — these are legacy from the early `!testing/**/*.AppImage` era. |
| `testing/theme-review/` (jpg/zip/THEME-AUDIT.md) | **MOVE** | Agent design-audit evidence (zips exist solely as a Claude-Design upload vehicle). Remove the matching `.gitignore` un-ignore line. |
| `testing/stable-gate-1.0.0/` (8 png + report) | **MOVE** | Agent QA evidence for the 1.0.0 gate. |
| `testing/automation/` (README, selfhost-smoke.sh, vinput.py) | **MOVE** | Device-agent harness tooling (mock-host smoke, uinput injector). Written for the agent loop, not end users. |
| `testing/run-cycle.sh` | **MOVE** | Test-agent cycle bootstrap; needs a two-repo rework anyway (section 3, tricky ref #1). |

### 2.4 .claude/

| Path | Verdict | Rationale |
|---|---|---|
| `.claude/commands/ship-test-pr.md`, `verify-ci.md`, `release-hygiene.md` | **MOVE** | Claude Code slash commands = agent meta. NOTE: `release-hygiene.md` still describes the *retired* auto-prune policy (deletes betas) which contradicts the release-permanence rule (BL-1736) — fix or retire it when it lands in the meta repo. |

### 2.5 Summary counts

- **MOVE:** ~124 files (all of `testing/` minus AppImages = 111, `docs/` meta = 8 files + personas dir, `.claude/commands/` = 3, `alert.yml` = 1)
- **SPLIT:** 3 files (CLAUDE.md, docs/WORKFLOW.md, docs/TEST_AUTOMATION.md) — extraction targets: `docs/RELEASING.md` (new), `CONTRIBUTING.md` (append), `docs/SELFTEST.md` (new)
- **DROP:** 16 AppImages (~1.27 GB working-tree / ~1.2 GB packfile weight)
- **KEEP:** everything else (~420 files)

---

## 3. Reference graph — what breaks and how it gets fixed

Method: repo-wide grep for the moving names/paths (`CLAUDE.md`, `WORKFLOW.md`, `personas`,
`ROUTINE_PROMPT`, `CLAUDE_CODE_PRACTICES`, `TEST_AUTOMATION`, `PHASE_STATUS`,
`BUILD_AGENT_INBOX`, `TEST_AGENT_OUTBOX`, `TEST_CHECKLIST`, `run-cycle`, `.claude/commands`,
`hostdevelop`, `clienttest`, `testing/`). 59 files match; the overwhelming majority are
*moving files referencing other moving files* (Group C below), which keep working because the
meta repo mirrors the directory layout.

### 3.1 Group A — product code / CI / scripts (KEEP) -> moved files. 6 sites, comment-level.

| # | Site | Reference | Fix |
|---|---|---|---|
| A1 | `app/main.cpp:663` | comment: "See docs/TEST_AUTOMATION.md" | point at new public `docs/SELFTEST.md` |
| A2 | `app/cli/commandlineparser.cpp:196` | comment: "(see docs/TEST_AUTOMATION.md)" | same |
| A3 | `app/app.pro:603` | comment: version cadence "see CLAUDE.md" | point at new public `docs/RELEASING.md` |
| A4 | `.github/workflows/dev-build.yml:195` | comment: "(CLAUDE.md tier matrix)" | point at `docs/RELEASING.md` |
| A5 | `scripts/vibepollo-log.sh:53` | echo: "add that path to CLAUDE.md (P3.5)" | reword to "the agent-meta repo" or drop the hint |
| A6 | `scripts/gamescope-lease.sh:15` | example env value `clienttest` | cosmetic only, no break — optional reword |

None are functional; the build, CI, and scripts run unchanged even with zero fixes. Fix them
anyway so the public tree has no dangling pointers.

### 3.2 Group B — public docs (KEEP) -> moved files. 6 sites across 4 files.

| # | Site | Reference | Fix |
|---|---|---|---|
| B1 | `docs/DEVELOPMENT.md:3` | "SOP ... is in WORKFLOW.md" | replace with CONTRIBUTING.md pointer |
| B2 | `docs/DEVELOPMENT.md:20-29` | repo-tree diagram lists `testing/`, `docs/WORKFLOW.md`, `CLAUDE.md` | redraw tree post-split |
| B3 | `docs/BUILD_SYSTEM.md:3` | "see WORKFLOW.md" | CONTRIBUTING.md pointer |
| B4 | `docs/design/README.md:7` | "see docs/PHASE_STATUS.md -> P3.18" | drop or reword (pipeline detail lives private) |
| B5 | `docs/design/README.md:23` | "via testing/BUILD_AGENT_INBOX.md" | reword ("tell the build agent") |
| B6 | `.gitignore:84` | `!testing/theme-review/*.zip` | delete line with the move |

### 3.3 Group C — moved files -> moved files (no break by construction)

CLAUDE.md <-> WORKFLOW.md <-> personas/* <-> ROUTINE_PROMPT <-> CLAUDE_CODE_PRACTICES <->
TEST_AUTOMATION <-> PHASE_STATUS <-> TEST_CHECKLIST <-> INBOX/OUTBOX <-> run-cycle.sh <->
.claude/commands/* — dozens of links, including relative paths like
`docs/personas/test-agent.md` -> `../../testing/TEST_CHECKLIST.md`. **Design rule: the meta
repo mirrors the vibemis directory layout exactly** (`CLAUDE.md`, `docs/...`, `testing/...`,
`.claude/commands/...`), so every intra-cluster relative link keeps resolving.

### 3.4 Group D — protocol-level breaks (the real work). 3 items — also the "trickiest 3".

**D1 — `testing/run-cycle.sh` and the instructions-on-the-test-branch protocol.**
Today the test agent checks out code-repo branch `test<N>-<slug>` and finds
`testing/test<N>-<slug>/instructions.md` *on that branch*; `run-cycle.sh` even has a fallback
that extracts a committed AppImage via `git show origin/<slug>:testing/<slug>/...`. After the
split, instructions live in the *meta* repo while the code branch lives in *vibemis* — the
1:1 "branch carries its own instructions" property is lost.
*Fix:* two side-by-side clones. `run-cycle.sh` (now in the meta repo) gains
`VIBEMIS_CODE_DIR` (default `../vibemis`): artifact download still comes from the *code*
repo's Releases (`gh release download` in the code dir or `-R navyas321/vibemis`), while
instructions are read from the meta repo path `testing/<slug>/instructions.md` on the meta
repo's main branch. The committed-AppImage fallback is deleted (all post-test47 cycles use
alpha releases anyway). The build agent's cycle prep becomes: push code branch to vibemis,
push instructions to vibemis-agent-meta main, announce in the INBOX (same commit).

**D2 — root CLAUDE.md auto-load / agent bootstrap.**
Claude Code auto-reads `./CLAUDE.md` from the working directory. Post-split, a session opened
in the vibemis checkout sees only the slim public CLAUDE.md — the agents' governance is in
the meta repo. *Fix:* the slim public CLAUDE.md stays agent-agnostic but functional
(build/run instructions, branch model); the agents' bootstrap (personas "cold-start" sections
+ the Dispatch one-liner + ROUTINE_PROMPT) changes to: clone BOTH repos side by side, start
sessions in the *meta* repo root (its CLAUDE.md is the governance file) or symlink/copy the
meta CLAUDE.md into the code checkout as a git-ignored local file. Recommended: work from the
meta repo as cwd; it references `../vibemis` for code operations. Both agents' persona files
get the new bootstrap in the same migration commit.

**D3 — repo policy currently living ONLY in CLAUDE.md.**
The SemVer rules, tier matrix (alpha/beta/rc/stable + the CONFIRM-STABLE gate), release
permanence, and the CI smart-build (".md-only HEAD skips the build") rules are enforced by
`dev-build.yml` but *documented* only in CLAUDE.md. Moving CLAUDE.md without extraction
leaves the public repo with CI behavior no public contributor can understand.
*Fix:* create `docs/RELEASING.md` from CLAUDE.md's "Versioning" + "CI / AppImage release
rules" + "README update rule" sections before the move (SPLIT action, section 2.1); A3/A4
comment fixes point there.

### 3.5 Tally

- **12 concrete edit sites** in files that stay public (A1-A6, B1-B6)
- **3 protocol-level reworks** (D1 run-cycle/instructions flow, D2 bootstrap/CLAUDE.md
  auto-load, D3 policy extraction)
- **0 functional references** from product code/CI to moved files (all comment-level)

---

## 4. The history question — filter or not?

**Recommendation: do NOT rewrite vibemis history. Accept that pre-split agent meta (and the
1.2 GB of AppImage blobs) remains visible in the public repo's history, and gate the
visibility flip on a secrets audit instead.**

Reasoning:

1. **Tag/release permanence is repo law.** Maintainer policy (BL-1736, 2026-07-13; CLAUDE.md
   "Releases are PERMANENT, like tags"): never delete a release or tag. `git filter-repo`
   rewrites every SHA from the first touched commit forward — every existing tag would either
   dangle or need force-re-tagging onto rewritten commits, which is exactly the mutation the
   policy forbids. The in-app updater and `RELEASES.md`/Atom feed also key off those tags.
2. **A rewrite un-anchors every deployed binary.** Old AppImages self-update by querying the
   existing repo's Releases; any scheme that replaces the repo (fresh "clean-cut" public repo)
   either breaks the update chain for the oldest deployed binaries or forces keeping the old
   repo alive anyway — at which point its history is still there.
3. **The content is embarrassing-at-worst, not secret.** The meta is process narrative,
   device names, tailnet CGNAT IPs (100.64/10 — unroutable outside the tailnet), backlog ids,
   and artifact hashes. No credentials were found in the sampled meta; the runbook still
   mandates a full `gitleaks`/`trufflehog` sweep of ALL history before the flip. If that
   sweep ever finds a real secret, **rotate the secret** — rewriting history is the last
   resort, not the default response.
4. **The real cost of no-rewrite is clone weight, and it is mitigable.** ~1.2 GB of dead
   AppImage blobs ride along in full clones. Mitigation: document
   `git clone --filter=blob:none` (or `--depth 1`) in the public README/CONTRIBUTING; GitHub
   serves partial clones natively, so contributors never download the blobs unless they
   check out the old test branches.

Trade-off acknowledged: "accepts historical meta as visible" means the agent workflow
(personas, prompts, escalations) is public archaeology forever. The maintainer explicitly
listed a squashed/clean-cut start as the alternative — that buys a pristine public history at
the price of (a) breaking the updater's release continuity or (b) running two repos where the
"old" one still exposes everything it was supposed to hide. Neither is worth it for content
of this sensitivity class. If a pristine history ever becomes a hard requirement (e.g.
Flathub review flags the blobs), the fallback is: filter-repo on a *rename* (`vibemis` stays
frozen+private as the release archive at first, a filtered `vibemis` successor goes public) —
a coordinated one-day operation with an updater compatibility shim, planned separately.

---

## 5. Execution runbook (split day — likely just before open-sourcing)

Prereqs: maintainer approval; a quiet fleet; `gh` authenticated as navyas321.

1. **Freeze the loop.** Post STAND DOWN on the coordination bus + `BUILD_AGENT_INBOX.md`
   (ironically its last vibemis entry). Land or park all open `diagnostic/*` and `test*` PRs;
   no in-flight cycle should straddle the move. Take a full mirror backup:
   `git clone --mirror git@github.com:navyas321/vibemis.git vibemis-backup-<date>.git`.
2. **Create the private repo** (GitHub op, execution day only):
   `gh repo create navyas321/vibemis-agent-meta --private --description "Vibemis agent-orchestration meta (personas, SOPs, test-cycle handoff)"`.
3. **Extract public content first** (SPLIT actions, on a vibemis branch `p4.0-split`):
   - `docs/RELEASING.md` <- CLAUDE.md "Versioning" + "CI / AppImage release rules" + "README
     update rule" sections.
   - `CONTRIBUTING.md` += WORKFLOW.md commit-format + PR four-test-scorecard conventions.
   - `docs/SELFTEST.md` <- TEST_AUTOMATION.md selftest/CLI/log-assertion recipes.
4. **Seed the meta repo.** Run `scripts/repo-split-dryrun.sh --execute --meta-dir ../vibemis-agent-meta`
   from the vibemis root: copies every MOVE path into the meta working tree (mirrored layout),
   `git rm`s them (and the 16 DROP AppImages) from vibemis, and writes the stub files. In the
   meta repo: add a README ("history prior to <split-sha> lives in navyas321/vibemis"),
   `git add -A && git commit && git push -u origin main`. (Simple snapshot seeding — no
   filter-repo needed; vibemis history remains the pre-split archive.)
5. **Apply the 12 reference fixes** (A1-A6, B1-B6) and write the new slim public `CLAUDE.md`
   on the same vibemis branch. Commit, push, PR, merge to `vibemis-main`. HEAD of this PR must
   touch a code file if a release build is desired (CI .md-only rule) — it does (main.cpp,
   commandlineparser.cpp, app.pro).
6. **Rework the D1/D2 protocol files in the meta repo:** run-cycle.sh two-repo mode
   (`VIBEMIS_CODE_DIR`), personas' cold-start sections ("clone both repos"), ROUTINE_PROMPT,
   the Dispatch one-liner, `.claude/commands/ship-test-pr.md` (instructions now push to the
   meta repo). One meta-repo commit.
7. **Update the two agents' bootstrap instructions** where they live outside the repo:
   memory notes / scheduled-routine prompts on the build host, and announce the new layout on
   the coordination bus (@test-agent) with the exact clone commands.
8. **Verify test-agent cold-start end-to-end** before un-freezing: on the device (or a clean
   sim), fresh-clone both repos side by side, run the meta repo's
   `testing/run-cycle.sh <current-test-slug>` -> it must find instructions in the meta repo
   and download the alpha from vibemis Releases; then a build-agent session-start checklist
   pass (fetch, pr list, inbox read). Fix-forward anything broken while the freeze holds.
9. **Secrets audit gate (pre-publication, separate day):** `gitleaks detect` +
   `trufflehog git` over ALL vibemis history; review hits; rotate anything real. Only after a
   clean sweep may BL-1556 flip the repo public. Document `--filter=blob:none` cloning in
   README at that point.
10. **Post-split guard:** add a lightweight CI check on vibemis PRs that fails if
    `testing/**`, `docs/personas/**`, or a non-slim `CLAUDE.md` reappears (one grep step in
    dev-build.yml's check job) so meta never drifts back in.

Rollback: step 4/5 are one revert-PR away until merged; the mirror backup covers everything
after. The meta repo can be deleted freely pre-announcement (it is private and additive).

---

## 6. Open questions for the maintainer

1. **testing/ instructions public-vs-private:** this plan moves ALL of `testing/` private on
   the "one enforceable rule" argument (2.3). If you would rather keep per-cycle
   instructions public as product test documentation, say so before split day — it changes
   D1's design (instructions could then stay on code-repo test branches).
2. **`docs/design/redesign/HANDOFF.md`:** moved private here (agent handoff narrative), but
   it is also the closest thing to a written design spec. Keep public instead?
3. **`alert.yml`:** delete (channel retired 2026-07-13) or migrate to the meta repo as
   reference? Plan default: delete.
4. **Meta repo name:** `vibemis-agent-meta` assumed per the backlog item. Confirm.
5. **Timing:** execute at BL-1556 readiness, or earlier during a quiet week? (Plan assumes
   just-before-public; nothing blocks doing it sooner.)

---

## Appendix A — pre-publication hygiene debris (separate cleanup, not part of the split)

Root-level files that are neither product nor agent-meta and should be deleted (or relocated)
before the repo goes public. They are listed by `repo-split-dryrun.sh` as REVIEW items but
never touched by it:

| File | What it is | Suggested action |
|---|---|---|
| `config.log` | Upstream author's local macOS qmake config log (predates the fork) | delete |
| `test_changes.md` | Ad-hoc dev notes | delete |
| `test_hash.py`, `test_otp_hash.cpp` | OTP hash debug harnesses | delete (or move under a `tools/debug/` dir if still used) |
| `find_passphrase.py` | OTP passphrase brute-force debug script | delete — bad optics public |
| `create_feature_branch.sh` | One-off branch helper for a long-merged feature | delete |
| `AV1_DETECTION_ANALYSIS.md` | Product bug analysis (AV1 capability detection) | fold conclusions into docs/ or delete |
| `.claude/commands/release-hygiene.md` | Describes the retired beta-prune policy (contradicts release permanence) | rewrite or retire when it lands in the meta repo |

Appendix B — the machine-readable MOVE/DROP/STUB lists live in
[`scripts/repo-split-dryrun.sh`](../scripts/repo-split-dryrun.sh) and are the source of truth
for the mechanical part of split day; keep them in sync with section 2 if the inventory
changes.
