#!/usr/bin/env bash
# Release-pipeline reliability guards (BL-2457, BL-2461).
# Two defects that already shipped and were fixed; this keeps them fixed.
# Run from the repo root.
set -u
fail=0
err() { echo "PIPELINE-INVARIANT FAIL: $1" >&2; fail=1; }

WF=".github/workflows/dev-build.yml"
[ -f "$WF" ] || { echo "missing $WF" >&2; exit 1; }

# 1. BL-2457: the concurrency group must NOT include github.event_name, or a push and
#    a workflow_dispatch on the same ref run concurrently and race on the version
#    counter (collided beta cut, 2026-07-23). Key on the ref alone so they serialize.
if grep -E '^\s*group:\s*dev-build-' "$WF" | grep -q 'event_name'; then
  err "concurrency group includes github.event_name — push+dispatch on a ref will race the version counter"
fi

# 2. BL-2394/BL-2461/BL-2472: the release job must NEVER open a pull request.
#
#    This guard used to assert the opposite — that the RELEASES.md refresh called
#    `gh pr merge --auto` — because the theory was that auto-merge would eventually
#    satisfy branch protection. It cannot, and the evidence is unambiguous: on PR #290
#    all three required contexts ("AppImage Build", "Compile Sanity (Linux)",
#    "Invariants") completed GREEN as check runs on the PR's exact head SHA, and the
#    PR's statusCheckRollup was still EMPTY. GitHub does not attribute
#    workflow_dispatch check runs to a pull request, and a GITHUB_TOKEN-authored PR
#    never emits the pull_request event that would create attributable ones. So
#    protection saw its requirements as permanently "expected": a plain merge returned
#    "base branch policy prohibits the merge" (#278, #279, #284, #285) and --auto simply
#    never fired (#288, #290). Six bot PRs opened and closed after six consecutive cuts
#    while RELEASES.md sat six releases stale.
#
#    The timeline is now force-pushed to the unprotected `releases-index` branch, which
#    needs no PR at all. Re-introducing a bot PR here would resurrect the phantom-PR
#    loop, so this asserts the release job stays PR-free.
rel_job=$(awk '/^  create-dev-release:/{f=1} f&&/^  [a-z][a-z-]*:$/&&!/create-dev-release/{exit} f{print}' "$WF")
if [ -n "$rel_job" ]; then
  printf '%s' "$rel_job" | grep -qE 'gh pr (create|merge)' \
    && err "the release job opens or merges a pull request again — a GITHUB_TOKEN PR can never satisfy branch protection (its statusCheckRollup stays empty), so this leaves a phantom PR after every cut. Push the timeline to the unprotected releases-index branch instead."
  printf '%s' "$rel_job" | grep -q 'releases-index' \
    || err "the release job no longer publishes the build timeline to the releases-index branch"
  # The publish must stay off any branch that triggers a build, or the timeline push
  # would cut a release of its own.
  printf '%s' "$rel_job" | grep -qE 'push --force origin .*refs/heads/' \
    || err "the timeline publish no longer force-pushes an explicit refs/heads/ ref"
fi
# The trigger list must not grow to include the index branch, or publishing the
# timeline would start a build (and that build would publish a timeline, and so on).
if awk '/^on:/{f=1} f&&/^[a-z]/&&!/^on:/{exit} f{print}' "$WF" | grep -q 'releases-index'; then
  err "releases-index appears in the workflow triggers — publishing the timeline would start a build loop"
fi

# 3. BL-2459: the consolidated 'invariants' job must exist AND gate the release.
#    A red semantic guard has to block publishing, not just merging.
grep -qE '^\s+invariants:\s*$' "$WF" \
  || err "the consolidated 'invariants:' job is gone — guards would stop running"
grep -qF 'scripts/check-*-invariants.sh' "$WF" \
  || err "the invariants job no longer globs scripts/check-*-invariants.sh"
grep -qF 'bash "$s"' "$WF" \
  || err "the invariants job no longer runs each globbed guard script"
# create-dev-release must list invariants in needs so a failed guard skips the publish.
crd=$(awk '/^  create-dev-release:/{f=1} f{print} f&&/^    runs-on:/{exit}' "$WF")
printf '%s' "$crd" | grep -q 'needs:.*invariants' \
  || err "create-dev-release no longer 'needs: invariants' — a red guard would still publish (BL-2459)"

# 4. BL-2458: a bare stable must be minted ONLY by an explicit release_type=stable
#    dispatch, never by a branch name — a push carries no dispatch inputs, so a
#    ref-triggered stable bypasses the CONFIRM-STABLE + rc-before-stable gates.
#    Extract the stable arm's guard condition (the first if-condition between the
#    tier-default assignment and RELEASE_TIER="release") and assert it does not
#    test BRANCH_NAME. Robust to single- or multi-line conditions.
region=$(awk '/RELEASE_TIER="dev"/{f=1} f{print} /RELEASE_TIER="release"/{exit}' "$WF")
stable_cond=$(printf '%s' "$region" | awk '/if \[\[/{c=1} c{print} /\]\]; then/{exit}')
if [ -z "$stable_cond" ]; then
  err "could not locate the stable tier-arm condition — this guard is not actually checking anything"
elif printf '%s' "$stable_cond" | grep -q 'BRANCH_NAME'; then
  err "the stable tier arm tests BRANCH_NAME — a push to release/**/main/master would cut an ungated stable (BL-2458)"
fi

# 5. Release-body CONTENT rules (the `Changelog:` body grep, the "What's new for you"
#    hero, plumbing demotion) moved out of this file when the generator stopped being
#    inline shell in the workflow. They now live in scripts/check-changelog-invariants.sh,
#    which asserts the RENDERED MARKDOWN against a synthetic repo instead of grepping
#    this YAML for an implementation detail. Both run in the same `invariants` job.
#    What stays here is the structural half: the workflow must still delegate to the
#    tested generator rather than growing a second copy inline.
grep -q 'scripts/gen-changelog.sh' "$WF" \
  || err "the release job no longer calls scripts/gen-changelog.sh — the body would come from untested inline shell again"
if grep -qE '^\s+(FEATURES|BUGFIXES|INTERNAL)=' "$WF"; then
  err "changelog assembly is inline in the workflow again — keep it in scripts/gen-changelog.sh where it is testable"
fi

if [ "$fail" -ne 0 ]; then
  echo "One or more release-pipeline invariants failed." >&2
  exit 1
fi
echo "All release-pipeline invariants hold."
