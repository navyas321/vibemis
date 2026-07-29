# Releasing — versioning, CI tiers, and the AppImage pipeline

This is the public record of Vibemis's release policy: SemVer rules, the release-tier matrix,
the CI smart-build behavior, and the README-update rule.

## Versioning — Semantic Versioning 2.0.0

`app/version.txt` holds the **next stable version** (e.g. `0.5.0`); CI derives every tag:

- **Bump policy: STRICT SEMVER.** Patch = bug fixes only;
  minor = ANY new feature (backward-compatible); major = breaking changes.
- **Stable** = the bare version itself, non-prerelease, takes Latest; cut via
  workflow_dispatch `release_type=stable`. Hotfix patches via the `version_override`
  input (`0.5.1`). **Bump version.txt to the next stable right after every cut.**
- **When each tier cuts** (rules effective 2026-07-21 — deterministic, content-based,
  merge-method-agnostic; the authoritative logic lives in the header comments and
  `check-changes` step of `.github/workflows/dev-build.yml`):
  | Tier | Trigger | Who decides |
  |------|---------|-------------|
  | alpha | ANY `test**` push whose diff vs `vibemis-main` touches non-docs paths (no `[alpha]` marker needed — the branch name is the intent; empty/no-op branches skip) | automatic |
  | beta | ANY push to `vibemis-main` touching non-docs paths — merge commit, squash, rebase, or direct push all count (content-based, not merge-method-based); or plain dispatch on `vibemis-main` | automatic |
  | rc | dispatch `release_type=rc` when the next stable is feature-complete and betas are green | maintainer discretion |
  | stable | dispatch `release_type=stable` | **MAINTAINER APPROVAL REQUIRED** (rc must already exist) |

  ⚠ **Stable cuts are approval-gated: never dispatch
  `release_type=stable` (or push `release/**`/`main`/`master`) without the
  maintainer explicitly approving that specific cut.**
  Alphas, betas and RCs can be cut per the matrix above.
  **CI-enforced:** a stable dispatch additionally requires the input
  `stable_confirm=CONFIRM-STABLE` — without it the run fails at Setup Version
  before anything builds. Type the phrase only when relaying the maintainer's
  explicit approval of that specific cut.

  ⚠ **rc-before-stable (maintainer 2026-07-17): a MINOR or MAJOR stable release MUST be
  promoted from a release candidate — you cannot cut a feature/breaking stable straight
  from a beta.** The train is beta → **rc** → stable: dispatch `release_type=rc` (builds
  `<version>-rc.NNN`), verify it green, THEN cut stable. **CI-enforced:** the `Enforce
  rc-before-stable gate` step in `dev-build.yml` fails a minor/major `release_type=stable`
  dispatch unless a matching `<version>-rc.*` tag already exists (rc tags only appear after
  a successful rc build, so this also proves the candidate built green).
  **HOTFIX EXEMPTION (maintainer 2026-07-17): PATCH releases (X.Y.Z with Z>0, e.g. 0.3.1,
  0.3.2) are hotfixes and go STRAIGHT to stable WITHOUT an rc** — the gate detects Z>0 and
  skips the rc requirement. Only minor/major cuts (X.Y.0) need the rc. So: a minor/major
  stable needs BOTH `stable_confirm=CONFIRM-STABLE` AND a pre-existing rc; a patch/hotfix
  needs only `stable_confirm=CONFIRM-STABLE`.
- **Beta** = `0.5.0-beta.NNN` (vibemis-main), **alpha** = `0.5.0-alpha.NNN` (test
  branches), dev = `0.5.0-dev.<run>.<branch>`. NNN is dense + zero-padded, computed
  from existing tags — never delete a tag. **Page-ordering decision:
  tags stay clean and the GitHub Releases/Tags pages
  keep their SemVer-precedence order** (alphas list after betas of the same base —
  spec §11.4; GitHub has no page-sort setting; an ordinal-first tag scheme fixed the
  ordering but was reverted as too ugly). Chronological views: the build timeline on the
  `releases-index` branch (republished every cut), the releases Atom feed, the API, and the in-app
  channels — all date-ordered. Don't reopen this trade-off without new options.
- All suffixed builds are GitHub-prerelease; only bare stables are full releases.
- **Releases are PERMANENT, like tags.** Every cut
  stays on the Releases page forever — SemVer §3 released-version immutability; the
  Releases list mirrors the Tags list. Never delete a release. (This supersedes the
  earlier auto-prune policy; the prune step was removed from dev-build.yml.)
- The first stable is bare `0.1.0` (Latest). The full historical catalog (0.1.0
  alpha/beta/rc trains incl. the folded interim-scheme cuts rc.001-006) is documented
  in `docs/RELEASE_HISTORY.md` — never prune or reuse it.
- **A release number is NEVER reused for different bits** — a burnt number stays burnt.
- Release titles are uniform: `Vibemis release <tag>`.
- Betas publish **on every `vibemis-main` push that touches non-docs paths, regardless
  of merge method** (BL-2270 — the old merge-commit-only rule silently skipped squash
  merges). Docs-only pushes never release;
  `gh workflow run dev-build.yml --ref vibemis-main` still builds immediately.
- **Release builds are never concurrency-cancelled** (BL-2270): `vibemis-main`/stable
  builds queue behind each other instead of being killed by a follow-up push. Only
  `test**` alpha builds keep cancel-in-progress (a newer alpha supersedes an older one).

## CI / AppImage release rules — READ BEFORE PUSHING

The CI smart-build check (`setup-version` → `check-changes`) decides `should_build` by
**content, not commit shape** (BL-2270). When `should_build=false`, the AppImage build
and `create-dev-release` jobs are **skipped entirely** — no AppImage is produced.

**Rules:**

1. **`vibemis-main`**: the WHOLE PUSH (`event.before → HEAD`) is inspected. If it changes
   any non-docs path (anything except `.md`/`.txt`/non-workflow `.yml`/`.yaml`;
   `.github/workflows/` counts as meaningful), a 🧪 beta cuts — merge commit, squash,
   rebase, or direct push alike. Commit ORDER inside the push no longer matters (the old
   HEAD-commit-only check that punished a trailing docs commit is gone). A docs-only
   push builds nothing.

2. **`test**`**: the branch's DIFF vs the merge-base with `vibemis-main` is inspected.
   Any push builds a 🔬 alpha when that diff touches non-docs paths — no `[alpha]`
   marker commit, no per-commit gate. A branch with no diff vs `vibemis-main`
   (empty/no-op) skips.

3. **If a docs-only push built nothing and you still need a build:** use
   `gh workflow run dev-build.yml --ref vibemis-main` — a manual dispatch ALWAYS builds.

4. **Release builds are never cancelled by follow-up pushes**: `vibemis-main` and stable
   builds queue (`cancel-in-progress: false` for those refs); only `test**` alpha builds
   may be superseded mid-flight by a newer alpha.

5. **The `create-dev-release` job publishes only from `test**`, `vibemis-main`,
   `main`/`master`, `release/**`, or a stable dispatch.** Other branch prefixes
   (`fix/**`, `feat/**`, `verify/**`, `chore/**`) never push-trigger the workflow at all; a
   manual dispatch on them builds a `dev`-tier CI artifact that is NOT published to
   Releases.

## Changelog language — say what changed FOR THE USER

Release bodies are auto-generated from commit subjects (`create-dev-release` in
`dev-build.yml`). **A changelog entry must state the user-visible effect, not the internal
mechanism.** "enable RFI by default on AMD/Gallium (mirror upstream d3c23b55)" tells a user
nothing; "fixes the stuttering/choppy video on AMD handhelds" tells them whether to update.

### The `Changelog:` note is not optional — it is the whole hero section

The release body opens with **`## 🎯 What's new for you`**, and that section is built
**exclusively** from `Changelog:` lines written by a human. It never falls back to commit
subjects. That is deliberate: a commit subject is written for other developers and reads
like one. "CI consolidation + release gating + stable gate + changelog regression" is a
perfectly true sentence and a completely useless release note.

So the rule is simple: **anything a user could notice needs a `Changelog:` line.** CI
enforces it — the `Changelog note` check fails a PR that changes shipping files without
one (`scripts/check-pr-changelog-note.sh`). Plumbing-only PRs are exempt automatically.

On a **stable** cut the hero is curated down to features and major-marked fixes — see
[A stable hero is curated](#a-stable-hero-is-curated-a-pre-release-hero-is-complete) below.

If nobody writes a note, the hero honestly says no highlights were flagged rather than
promoting jargon into it. **Do not fix that after the fact with `gh release edit`.** That
is what used to happen — `0.5.0-beta.001`, `0.4.3` and `0.5.0-beta.004` all had their
hero sections pasted in by hand — and it does not persist to the next cut, which is why
the format kept "not sticking". Write the note in the PR instead.

1. **Write the commit subject user-first** — effect, then mechanism:
   `fix: stuttering video on AMD handhelds (enable RFI by default)`.
2. **Add a `Changelog:` trailer** to the commit body (or the PR description — `gh pr merge
   --squash` uses it as the commit body). Required for the hero; also **overrides** the
   subject in the technical section, so the mechanism can stay in the subject:

   ```
   fix(BL-XXXX): enable RFI by default on AMD/Gallium (mirror upstream d3c23b55)

   <body explaining the mechanism, upstream refs, RCA links...>

   Changelog: Fixes stuttering/choppy video on AMD handhelds (Legion Go S, Steam Deck)
   Co-Authored-By: ...
   ```

   The generator finds this by grepping the commit **body** for a `Changelog:` line, so
   its position in the message does not matter — put it anywhere in the body/PR description.
   (It used to read `%(trailers:key=Changelog)`, which requires the line to be in git's
   strict final trailer block; `gh pr merge --squash` reformats the message — appends
   GitHub's own `Co-authored-by:`, concatenates squashed commits — so the line almost never
   lands there, and every squash-merged release fell back to raw subjects. That regression
   stripped the human-readable notes from `0.5.0-beta.004`; the body grep fixes it.)

Anything a user could notice — video, audio, input, UI, updates, pairing — needs one of the
two.

### How a change gets demoted to "Internal / build plumbing"

Plumbing lands in a collapsed `<details>` section and needs no note. A change is plumbing
when **either**:

- its subject type is `ci:`, `chore:`, `build:`, `docs:`, `test:`/`tests:`, `style:` or
  `meta:`, or carries a `(ci)`/`(build)`/`(release)`/`(deps)`/`(workflow)` scope; **or**
- **its diff touches nothing that ships** — only `.github/`, `docs/`, `tests/`, `*.md`, or
  the CI-side generator/guard scripts.

The second rule is the important one, because subject types are a statement of intent and
they are routinely wrong. `0.5.0-beta.005` presented this to users as its one Bug Fix:

> Release notes stay human-readable through squash merges, a broken guard now blocks the
> release, and a stray branch push can no longer cut an unapproved stable

That came from a commit authored `fix:` with a confident note attached — whose entire diff
was `dev-build.yml`, `docs/RELEASING.md` and a CI guard script. The old rule only demoted
a commit when it had *no* note, so attaching one *promoted* plumbing into "Bug Fixes". The
diff cannot lie about whether something ships, so the diff decides.

Two explicit overrides exist for the genuine edge cases:

| Trailer | Meaning |
|---|---|
| `Changelog: none` | Looks user-facing by type but is not (pure refactor, internal-only fix). Demotes it. |
| `Changelog!: <text>` | Really is user-visible despite touching only build/docs paths (e.g. a packaging change that alters what the AppImage does on the device). Promotes it. |
| `Changelog-Major: <text>` | This fix resolves a **major** issue and should headline the next **stable** release. Carries the note text as well — do not also write a plain `Changelog:` line. |

### A stable hero is curated; a pre-release hero is complete

The two tiers are read by different people asking different questions, so they get
different hero sections. The technical changelog is identical either way and always lists
**every** commit — nothing is ever dropped, only moved.

| | Pre-release (`-alpha`/`-beta`/`-rc`) | Stable (bare `X.Y.Z`) |
|---|---|---|
| Hero contains | every `Changelog:` note | `feat:` notes + `Changelog-Major:` notes |
| Technical changelog | `## 🚧 Development Build Changelog`, expanded | collapsed into one `<details>`, plumbing inside it |

A beta reader is a tester tracking the cycle — "what changed since the last build?" — and
every note belongs in that answer. A stable reader is deciding whether to install.
`0.5.0`, the first production release cut by this generator, answered them with **28 hero
bullets, 26 of them fixes**, each a forty-word sentence about a frame-pacing internal.
Every line was true; the section as a whole said nothing about what the release *was*.

So: **write `Changelog-Major:` on the fixes that are the reason to ship a release.** If a
stable cut has no feature and no major-marked fix, the hero says so honestly — it is a
maintenance roll-up, and that is a real and useful thing to tell someone.

### Upstream attribution never reaches the hero

Fork and maintainer handles (`Nonary`, `wjbeckett`, `cgutman`, `moonlight-qt`) are
**developer provenance**, and the generator keeps a note that names one out of the hero on
every tier — it still appears in full in the technical changelog. `0.5.0`'s second hero
bullet was *"Adopt Nonary VRR10 active-wait fix: remove the fixed yield-count limit
(4096)…"*: a sentence addressed to whoever tracks the fork graph, published to people who
wanted to know whether their handheld stutters less. Put the attribution in the commit
body and write the *effect* in the note.

Host types and protocols — **Artemis, Apollo, Sunshine, Moonlight** — are a genuine
user-facing choice and are deliberately *not* filtered.

**The trailer must start at column 0.** An indented line is a markdown code block — i.e.
someone quoting an example — and is ignored on purpose. Before that rule existed, pasting
the specimen note out of the CI failure message (which prints it indented) both satisfied
the PR check and published *"Fixes stuttering and choppy video on AMD handhelds"* as the
hero bullet of a build that did nothing of the kind.

**Do not "fix" a jargon-y release body afterwards with `gh release edit`.** It does not
persist to the next cut — that is precisely the loop that made this problem recur. Fix the
generator or write the note; `scripts/check-changelog-invariants.sh` renders the real
markdown against a synthetic repo, so you can verify a format change locally before cutting:

```bash
bash scripts/gen-changelog.sh 0.5.0-beta.005   # exactly what the release body will say
bash scripts/check-changelog-invariants.sh     # the format contract
```

## ⚠ Never put `[skip ci]` on a code merge to `vibemis-main` (BL-2460)

GitHub **natively** skips the `push` and `pull_request` events for any commit whose message
contains one of its documented markers — no workflow runs, so **no beta is cut and the code
gets no beta soak**. The full set GitHub honours is:

```
[skip ci]  [ci skip]  [no ci]  [skip actions]  [actions skip]
```

plus a `skip-checks: true` trailer at the end of the message. This is platform behaviour,
decided **before** any workflow is selected. It has already bitten four times on
`vibemis-main`: `970cfb94` (#272 — a Quick Menu rendering fix that then went straight into
stable `0.4.2` with no beta at all), `f2fb187b` (#274), `02fff5aa` (#275) and `80b2e731`
(#276). Never put a marker on a commit that touches code.

### Why there is no in-YAML guard for this

`setup-version` used to carry its own `[skip ci]` arm. It was **dead code**: if the marker is
present, the run does not exist, so nothing inside it can execute. It was deleted, and
`scripts/check-pipeline-invariants.sh` guard #6 now fails the build if anything shaped like it
reappears — a guard that cannot run is worse than none, because the green tick still claims
coverage.

### What catches it instead — the `skip-ci-guard` job

| when | what it does |
| --- | --- |
| `pull_request` | **Rejects.** `gh pr merge --squash` defaults the merge subject to the **PR title**, and a PR title is not a commit message, so GitHub's native skip does not see it — this is the one moment the marker can still be removed. It scans the PR title and every commit subject on the branch. The PR body is deliberately *not* scanned, or every PR documenting this behaviour (including the one that added the job) would fail itself. |
| `push` | **Audits.** The merge subject is typed at merge time, after the PR check has passed, and the resulting push is dropped before any workflow exists to notice. So the *next* push that does run looks backwards over every commit since the last release tag — a superset of its own `event.before..HEAD` range, precisely because the skipped push's commits are missing from it — and fails loudly naming the commits that cut no build. It is **not** in `create-dev-release`'s `needs`, so the beta that heals the gap still publishes. |

The audit only flags commits that touch code: a docs-only commit cuts no beta anyway (the
build decides by content), so flagging one would just teach people to ignore the job.

### The remaining hole, and the lever that closes it

If the marker is in the PR's **head commit** rather than the title, GitHub suppresses the
`pull_request` event too — `skip-ci-guard` never runs, so it cannot report. That is not silent
failure, it is the opposite: **a required check that never reports leaves the PR's merge box
permanently "Expected — Waiting for status to be reported"**, which blocks the merge. Use it:

> **Repo setting (must be done in the GitHub UI, not in this file):** add **`Skip-CI Guard`**
> to the required status checks on `vibemis-main`, alongside `AppImage Build`,
> `Compile Sanity (Linux)`, `Invariants` and `VRR Tests`.

The same signature identifies an already-merged incident: a commit on `vibemis-main` with **no
checks at all** against it (not red — *absent*) is a push GitHub dropped.

There is no longer any legitimate use of a skip marker on `vibemis-main`. The build timeline
used to be merged in by a bot with `[skip ci]`, but it is now force-pushed to the unprotected
`releases-index` branch, which matches no workflow trigger and so needs no marker — and
therefore **no bot allowlist is needed anywhere in this pipeline.**

## Tests that gate a release

Two jobs must be green before `create-dev-release` will publish, and both are in its `needs`
so they gate the **cut**, not just the merge — a `workflow_dispatch` or a direct push never
goes through a PR, so a merge-only gate would not cover it:

- **`Invariants`** — every `scripts/check-*-invariants.sh`, globbed. Adding a guard is zero
  workflow change: drop in a new `check-<x>-invariants.sh` and it runs.
- **`VRR Tests`** — builds `tests/vrr/vrr.pro` against system Qt 6 and runs all six binaries
  (`tst_vrrtimingcontroller`, `tst_vrrratepolicy`, `test_vrrratepolicy`,
  `test_vrrrefreshguard`, `test_vrrswapchainpolicy`, `tst_vrrpacingworker`). Each is named
  explicitly and a **missing** binary fails the job — globbing whatever happens to be
  executable would let a target drop out of `vrr.pro` and leave the job green while covering
  less. That matters here: this suite existed for months without any workflow building it,
  through a run of releases that were almost entirely VRR fixes.

`tests/tests.pro` is opt-in — it only descends into its `SUBDIRS` when qmake is given
`CONFIG+=tests` — so the job points qmake straight at `tests/vrr/vrr.pro`. To run it locally:

```bash
mkdir -p build-vrr-tests && cd build-vrr-tests
qmake6 ../tests/vrr/vrr.pro && make -j"$(nproc)"
./tst_vrrtimingcontroller && ./tst_vrrratepolicy && ./test_vrrratepolicy \
  && ./test_vrrrefreshguard && ./test_vrrswapchainpolicy && ./tst_vrrpacingworker
```

Needs `qt6-base-dev qt6-base-dev-tools qt6-declarative-dev libavutil-dev libsdl2-dev` and a
C++17 compiler, **plus the `moonlight-common-c` submodule checked out** — `pacingworker.pro`
puts it on the include path and `vrrpacingworker.cpp` does `#include <Limelight.h>`, which
exists nowhere else in the tree, so a submodule-less checkout builds five of the six targets
and then dies. The console tests print **nothing** on success and communicate purely through
their exit status; only `tst_vrrratepolicy` (QtTest) prints `PASS` lines.

## The RELEASES.md timeline never opens a pull request (BL-2394/BL-2461/BL-2472)

Do not "fix" the build-timeline publish by making it open a bot PR and merge it with
`gh pr merge --auto`. That recommendation is written down in more than one place and it is
**wrong** — enabling `--auto` and exiting 0 would leave the PR open forever, which is the
complaint it was meant to solve. The measurement that settles it: on PR **#290** all three
required contexts (`AppImage Build`, `Compile Sanity (Linux)`, `Invariants`) completed green
on the PR's exact head SHA and its `statusCheckRollup` was still **empty** — GitHub does not
attribute `workflow_dispatch` check runs to a pull request, and a `GITHUB_TOKEN`-authored PR
never emits the `pull_request` event that would create attributable ones. Branch protection
therefore saw its requirements as permanently *expected*: plain merge returned "base branch
policy prohibits the merge" (#278, #279, #284, #285) and `--auto` never fired (#288, #290).
Six cuts produced six phantom PRs while `RELEASES.md` sat six releases stale.

The timeline is instead a single-file **orphan commit force-pushed to the unprotected
`releases-index` branch** (`git hash-object` → `git mktree` → `git commit-tree` →
`git push --force`). No PR, no protection to fight, no PAT, no `[skip ci]` marker, and the
branch matches no workflow trigger so it starts nothing. It is idempotent — each cut
republishes the whole timeline, so a skipped run self-heals. The release job's token no
longer has `pull-requests: write`, so it *cannot* open one, and
`check-pipeline-invariants.sh` guard #2 fails the build if `gh pr create`/`gh pr merge`
reappears in that job.

## Stable release notes are CUMULATIVE — hotfixes included

**Every bare-semver stable release — `X.Y.0` *and* every `X.Y.Z` hotfix — must carry the full
changelog for its whole minor line, not just the commits since the last tag.** (Maintainer
directive, BL-2373, re-stated after 0.4.3 shipped without it.)

Someone installing `0.4.3` may be coming from `0.3.x`, not from `0.4.2`. The auto-generated body
only lists commits since the previous same-tier tag, so a hotfix's notes show one or two lines
and hide everything the minor line actually delivers. Stable notes are the user's complete
picture of what they are getting — not a diff.

Required shape for a stable body:

1. A short plain-language highlight of **this** cut (what changed for you).
2. The auto-generated commit changelog for this cut.
3. `## 🎉 What's new in X.Y (cumulative — everything in X.Y.0 … X.Y.Z-1 is included in this build)`
   — the whole minor line's user-facing features. Carry the previous patch's cumulative section
   forward and prepend the new fix; never rewrite it from scratch.
4. Collapsed `<details>` blocks with the commit-level changelog of each earlier patch in the line
   (`Full X.Y.0 detailed changelog`, `Full X.Y.1 …`), so nothing is lost.

Prereleases (alpha/beta/rc) do **not** need this — they are for testers tracking a moving line.

Until CI assembles this automatically, apply it right after the cut with
`gh release edit <tag> --notes-file <file>` (this is how 0.4.2 and 0.4.3 were built).

## README update rule — required at every release

After merging a feature to `vibemis-main`, update `README.md` before the release.
The README is NOT a changelog and NOT a build-specific status page — it describes what
Vibemis IS and DOES right now, in **evergreen, version-less terms only**:

- **Features section** — add any new user-visible features under the right heading
  (From Moonlight Qt / From Artemis / Apollo / Added by Vibemis)
- **Downloads section** — reflect the channel / release-tier model only if the *policy*
  itself changed (channels, SemVer rules) — never a specific "current" version number
- **Keyboard/Gamepad shortcuts** — update if anything changed

**The README must contain NO Known-Issues table, NO Known-Limitations table, and NO
version-specific content.** No "current stable is X.Y.Z", no per-build bug/status list, no
known-limitations table, no version enumerations — every one of those rots the moment the next
build ships. That content lives outside the README:

- **Current known issues & limitations** — hand-maintained in `docs/KNOWN_ISSUES.md` (which has
  a `## Confirmed bugs`, a `## Limitations`, and an `## Experimental` section). Update that file
  (not the README) when bugs or limitations are found, worked around, or fixed.
- **Per-release changes** ("what was fixed/added in this release") — `docs/release-notes-*.md`
  and the GitHub Release for that tag. Never in the README.

Do NOT re-add a Known-Issues or Known-Limitations table, or a current-version line, to the
README. The README is always the present-tense, version-less description of what the current
build is and does.
