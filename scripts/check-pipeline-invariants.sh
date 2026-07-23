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

# 2. BL-2461: the RELEASES.md refresh must use auto-merge. A plain 'gh pr merge' on the
#    bot PR is blocked by branch protection (required checks show expected/pending on a
#    GITHUB_TOKEN PR), so it always fail-closes and the timeline stops updating.
if grep -q 'name: Refresh RELEASES.md build timeline' "$WF"; then
  # Look at the refresh step region for the merge invocation.
  refresh=$(awk '/name: Refresh RELEASES.md build timeline/{f=1} f{print} f&&/^  [a-z].*:$/&&!/Refresh RELEASES/{c++} c>1{exit}' "$WF")
  printf '%s' "$refresh" | grep -q 'gh pr merge' \
    || err "refresh step no longer calls 'gh pr merge' — cannot verify the merge path"
  printf '%s' "$refresh" | grep 'gh pr merge' | grep -q -- '--auto' \
    || err "refresh 'gh pr merge' is missing --auto — a plain merge is blocked by branch protection on the bot PR"
  # The refresh merge must stay [skip ci] so the docs merge never cuts a beta.
  printf '%s' "$refresh" | grep -q '\[skip ci\]' \
    || err "refresh merge subject lost [skip ci] — a docs refresh merge could now trigger a beta"
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

# 5. Changelog generator must read the `Changelog:` note from the commit BODY, not
#    via %(trailers). gh pr merge --squash reformats the message so the note is almost
#    never in git's strict final trailer block; %(trailers) then misses it and the
#    release falls back to raw subjects (that regression hit 0.5.0-beta.004).
if grep -q 'trailers:key=Changelog' "$WF"; then
  err "changelog generator still uses %(trailers:key=Changelog) — squash-merged commits lose the note (use a body grep)"
fi
grep -qE "grep -m1 -iE '\^\[\[:space:\]\]\*Changelog:'" "$WF" \
  || err "changelog generator no longer greps the commit body for a Changelog: line"

if [ "$fail" -ne 0 ]; then
  echo "One or more release-pipeline invariants failed." >&2
  exit 1
fi
echo "All release-pipeline invariants hold."
