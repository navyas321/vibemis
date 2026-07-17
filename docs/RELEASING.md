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
- **When each tier cuts:**
  | Tier | Trigger | Who decides |
  |------|---------|-------------|
  | alpha | `test**` push whose HEAD commit carries `[alpha]` | automatic (on request) |
  | beta | PR merge into `vibemis-main` touching code; or plain dispatch on `vibemis-main` | automatic |
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
- Betas publish **only on PR merge commits that touch code** — a direct push never
  releases; `gh workflow run dev-build.yml --ref vibemis-main` builds immediately.

## CI / AppImage release rules — READ BEFORE PUSHING

The CI smart-build check (`setup-version` → `check-changes`) sets `should_build=false`
when the HEAD commit only touches `.md` files. When `should_build=false`, the AppImage
build and `create-dev-release` jobs are **skipped entirely** — no AppImage is produced.

**This trips people up constantly.** The pattern that breaks things:

```
git commit -m "fix: real code change"        ← code touches .cpp/.h/.qml
git commit -m "docs: update release notes"    ← only .md files
git push                                     ← CI sees HEAD = .md only → skips
```

A downstream consumer that expects a fresh AppImage from GitHub Releases will instead find
the OLD one (from the commit before the fix).

**Rules:**

1. **The last commit before a push that is meant to produce a new release MUST touch a
   code file** (`.cpp`, `.h`, `.qml`, `.yml`, `.pro`). `.md`-only commits set
   `should_build=false` and no AppImage is built.

2. **Order matters:** put the code fix commit last in the push, or bundle any accompanying
   docs/test-instruction changes into the same commit as the code change, not after it.

3. **If you've already pushed a docs-only commit and need a new build:** either make a
   trivial meaningful code change (e.g. a constraint comment in a `.cpp` file) with
   `fix:` in the title and push it, or — on `vibemis-main` only — use
   `gh workflow run dev-build.yml --ref vibemis-main`: a manual dispatch ALWAYS builds
   (it bypasses the docs-only skip — verified against dev-build.yml).
   Push-triggered runs on a docs-only HEAD still skip.

4. **The `create-dev-release` job publishes only from `test**`, `vibemis-main`,
   `main`/`master`, `release/**`, or a stable dispatch.** Other branch prefixes
   (`fix/**`, `feat/**`, `verify/**`, `chore/**`) never push-trigger the workflow at all; a
   manual dispatch on them builds a `dev`-tier CI artifact that is NOT published to
   Releases.

## README update rule — required at every release

After merging a feature to `vibemis-main`, update `README.md` before the release.
The README is NOT a changelog — it describes what Vibemis IS and DOES right now:

- **Features section** — add any new user-visible features under the right heading
  (Inherited from Moonlight Qt / Artemis Qt / Added by Vibemis)
- **Known Issues table** — list current confirmed bugs with workaround and status
- **Downloads section** — reflect current release tier model if it changed
- **Keyboard/Gamepad shortcuts** — update if anything changed

Do NOT list "what was fixed in this release" — that belongs in commit messages and PRs.
The README is always the present-tense description of the current build.
