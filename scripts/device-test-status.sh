#!/usr/bin/env bash
# Record the on-device test result for one commit (BL-2706, alpha-first flow).
#
# Usage: scripts/device-test-status.sh <sha|pr-number> success|failure "<summary>" [report-url]
#
# Posts the `device-test` commit status that branch protection requires before a
# code PR can merge into vibemis-main (see .github/workflows/device-gate.yml).
# A success is refused unless an ALPHA release was built from that exact commit,
# which is the whole point: the device test must have run the bits being merged,
# not an older alpha or a local build. Needs `gh` authenticated with push access.
set -euo pipefail

REPO="${REPO:-navyas321/vibemis}"
target="${1:?usage: device-test-status.sh <sha|pr-number> success|failure \"<summary>\" [report-url]}"
state="${2:?state must be success or failure}"
summary="${3:?a one-line summary of the device result is required}"
url="${4:-}"

case "$state" in
  success|failure) ;;
  *) echo "state must be success or failure, not '$state'" >&2; exit 2 ;;
esac

# A bare number is a PR: resolve it to its current head commit.
if [[ "$target" =~ ^[0-9]+$ ]]; then
  sha=$(gh pr view "$target" --repo "$REPO" --json headRefOid --jq .headRefOid)
else
  sha=$(gh api "repos/$REPO/commits/$target" --jq .sha)
fi

alpha=$(gh api --paginate "repos/$REPO/releases?per_page=100" \
  --jq ".[] | select(.target_commitish == \"$sha\" and (.tag_name | contains(\"-alpha.\"))) | .tag_name" \
  | head -1)

if [ "$state" = "success" ] && [ -z "$alpha" ]; then
  echo "Refusing: no alpha release was built from ${sha:0:8}." >&2
  echo "Push the commit to a test-* branch, wait for its alpha, and test that build." >&2
  exit 1
fi

desc="${alpha:-no alpha}: $summary"
args=(-X POST "repos/$REPO/statuses/$sha" -f state="$state" -f context=device-test -f description="${desc:0:140}")
[ -n "$url" ] && args+=(-f target_url="$url")
gh api "${args[@]}" >/dev/null
echo "device-test $state on ${sha:0:8} (${alpha:-no alpha}): $summary"
