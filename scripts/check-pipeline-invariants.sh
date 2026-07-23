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

if [ "$fail" -ne 0 ]; then
  echo "One or more release-pipeline invariants failed." >&2
  exit 1
fi
echo "All release-pipeline invariants hold."
