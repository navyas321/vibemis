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
  ordering but was reverted as too ugly). Chronological views: `RELEASES.md`
  (auto-refreshed every cut), the releases Atom feed, the API, and the in-app
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
