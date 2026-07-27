#!/usr/bin/env bash
# BL-2526 submodule remote-agreement guard.
#
# WHY THIS EXISTS
# CI clones each submodule from the URL recorded in .gitmodules. A developer in a
# local checkout pushes to whatever that submodule's `origin` happens to be. Until
# BL-2526 those two disagreed for moonlight-common-c: .gitmodules said
# navyas321/moonlight-common-c (our fork, re-pointed by BL-2336) while the
# checked-out submodule's `origin` still said ClassicOldSong (the upstream lineage),
# with the fork reachable only under a hand-added second remote named `vibemis`.
#
# That is a live footgun, not a cosmetic mismatch. The natural `git push origin`
# aims at a repo the developer almost certainly cannot write to and would not want
# the commit landing in anyway; meanwhile the parent-pointer bump they make in the
# same breath records a SHA that CI -- cloning from .gitmodules -- can never fetch.
# The result is a green local build and a CI that dies on a submodule resolving
# nowhere. Shipping BL-2415 required a human noticing this and hand-adding a remote.
#
# THE RULE: .gitmodules is canonical. Each submodule's `origin` follows it.
#           For moonlight-common-c the ClassicOldSong lineage lives under `upstream`
#           -- it is still needed to merge upstream work, but it is NOT a push target.
# Push workflow: docs/BUILD_SYSTEM.md, "Submodule notes" section.
#
# WHERE THIS RUNS
# Both on a CI runner and in a developer checkout, so it must tolerate a submodule
# that is not initialised at all. The `Invariants` job checks out with fetch-depth 1
# and NO `submodules:` key, so every submodule directory there is empty -- those are
# SKIPPED, not failed. A freshly cloned submodule (`submodules: recursive` jobs) has
# only `origin`, set by git from .gitmodules, so it passes; the `upstream` remote is
# reported as a note when absent and is never required.
#
# Run from the repo root.
set -u
fail=0
err() { echo "SUBMODULE-INVARIANT FAIL: $1" >&2; fail=1; }
note() { echo "SUBMODULE-INVARIANT note: $1"; }

MCC="moonlight-common-c/moonlight-common-c"
FORK_EXPECT="github.com/navyas321/moonlight-common-c"
UPSTREAM_EXPECT="github.com/classicoldsong/moonlight-common-c"
MCC_BRANCH="vibemis-rtp-timestamp"

[ -f .gitmodules ] || { echo "SUBMODULE-INVARIANT FAIL: .gitmodules missing (run from the repo root)" >&2; exit 1; }

# Normalise a git URL to host/owner/repo so the guard compares remote IDENTITY, not
# transport. https://, ssh://git@, git@host: and a trailing .git all denote the same
# remote -- a developer who clones over SSH must not trip this guard.
norm() {
  printf '%s' "$1" \
    | sed -e 's#^git+##' \
          -e 's#^ssh://##' -e 's#^https\{0,1\}://##' -e 's#^git://##' \
          -e 's#^[^/@]*@##' \
          -e 's#:#/#' \
          -e 's#/*$##' -e 's#\.git$##' \
    | tr '[:upper:]' '[:lower:]'
}

# ── 1. Every submodule's configured origin must agree with .gitmodules ────────────
#
# Generic on purpose: the same footgun applies to any submodule, and a guard that
# only knew about moonlight-common-c would miss the next one to drift.
subs=$(git config -f .gitmodules --name-only --get-regexp '^submodule\..*\.url$' 2>/dev/null \
       | sed -e 's#^submodule\.##' -e 's#\.url$##')

[ -n "$subs" ] || err ".gitmodules: no submodule URLs parsed (file corrupt?)"

checked=0
while IFS= read -r name; do
  [ -n "$name" ] || continue
  declared=$(git config -f .gitmodules --get "submodule.$name.url" 2>/dev/null || true)
  path=$(git config -f .gitmodules --get "submodule.$name.path" 2>/dev/null || true)
  [ -n "$path" ] || { err ".gitmodules: submodule '$name' has no path"; continue; }
  [ -n "$declared" ] || { err ".gitmodules: submodule '$name' has no url"; continue; }

  # Superproject .git/config caches the URL and is what `git submodule sync`
  # propagates INTO the submodule's origin -- so a stale value here silently
  # re-poisons a corrected origin. Unset on a runner that never inited submodules.
  cached=$(git config --get "submodule.$name.url" 2>/dev/null || true)
  if [ -n "$cached" ] && [ "$(norm "$cached")" != "$(norm "$declared")" ]; then
    err "$path: .git/config submodule.$name.url is '$cached' but .gitmodules declares '$declared' (fix: git submodule sync -- $path)"
  fi

  # Not initialised (bare CI checkout, or a submodule the dev never inited) -> skip.
  if [ ! -e "$path/.git" ]; then
    note "$path: submodule not initialised here, origin check skipped"
    continue
  fi

  checked=$((checked + 1))
  origin=$(git -C "$path" config --get remote.origin.url 2>/dev/null || true)
  if [ -z "$origin" ]; then
    err "$path: submodule has no 'origin' remote; .gitmodules declares '$declared'"
    continue
  fi
  if [ "$(norm "$origin")" != "$(norm "$declared")" ]; then
    err "$path: origin is '$origin' but .gitmodules declares '$declared' -- CI clones the .gitmodules URL, so a commit pushed to this origin is unreachable from CI (fix: git -C $path remote set-url origin '$declared', keeping the old URL under a descriptive name such as 'upstream')"
  fi

  # A second remote aliasing the SAME repo re-creates the "which one do I push to?"
  # ambiguity that BL-2526 removed. Exactly one name for the canonical remote.
  for r in $(git -C "$path" remote 2>/dev/null || true); do
    [ "$r" = "origin" ] && continue
    rurl=$(git -C "$path" config --get "remote.$r.url" 2>/dev/null || true)
    [ -n "$rurl" ] || continue
    if [ "$(norm "$rurl")" = "$(norm "$declared")" ]; then
      err "$path: remote '$r' is a duplicate alias for origin ('$rurl') -- drop it so there is one unambiguous push target (git -C $path remote remove $r)"
    fi
  done
done <<EOF
$subs
EOF

# ── 2. moonlight-common-c is our navyas321 fork, and records its branch ───────────
#
# BL-2336 re-pointed this from ClassicOldSong to the fork; check-audio-invariants.sh
# guard #5 asserts the same URL from the audio side. The branch is recorded so
# `git submodule update --remote` resolves to the fork branch the parent pointer
# tracks instead of guessing the remote HEAD (which is upstream's master lineage).
mcc_url=$(git config -f .gitmodules --get "submodule.$MCC.url" 2>/dev/null || true)
[ "$(norm "$mcc_url")" = "$FORK_EXPECT" ] \
  || err ".gitmodules: $MCC url is '$mcc_url', expected the $FORK_EXPECT fork"

mcc_branch=$(git config -f .gitmodules --get "submodule.$MCC.branch" 2>/dev/null || true)
[ "$mcc_branch" = "$MCC_BRANCH" ] \
  || err ".gitmodules: $MCC branch is '${mcc_branch:-<unset>}', expected '$MCC_BRANCH' (fix: git config -f .gitmodules submodule.$MCC.branch $MCC_BRANCH)"

# ── 3. The ClassicOldSong lineage, if present, is named 'upstream' ───────────────
#
# NOT required to exist: a fresh CI clone has only origin, and failing that case
# would be worse than no guard at all. Only its NAME is constrained, so the upstream
# repo can never reclaim the name 'origin' (that is exactly the BL-2526 bug).
if [ -e "$MCC/.git" ]; then
  up_names=""
  for r in $(git -C "$MCC" remote 2>/dev/null || true); do
    rurl=$(git -C "$MCC" config --get "remote.$r.url" 2>/dev/null || true)
    [ "$(norm "${rurl:-}")" = "$UPSTREAM_EXPECT" ] && up_names="$up_names $r"
  done
  up_names="${up_names# }"
  case " $up_names " in
    "  ")        note "$MCC: no ClassicOldSong remote (expected on a fresh CI clone; add as 'upstream' locally to merge upstream work)" ;;
    " upstream ") : ;;
    *" upstream "*)
      err "$MCC: several remotes point at the ClassicOldSong lineage ($up_names); keep only 'upstream'" ;;
    *)
      err "$MCC: ClassicOldSong lineage is named '$up_names', expected 'upstream' -- an ambiguous name is how BL-2526 happened (fix: git -C $MCC remote rename $up_names upstream)" ;;
  esac

  # A named branch must track origin. Detached HEAD is the NORMAL post-clone state
  # on CI, so it is skipped rather than failed.
  cur=$(git -C "$MCC" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
  if [ -n "$cur" ]; then
    tracks=$(git -C "$MCC" config --get "branch.$cur.remote" 2>/dev/null || true)
    if [ -n "$tracks" ] && [ "$tracks" != "origin" ]; then
      err "$MCC: branch '$cur' tracks remote '$tracks', not 'origin' (fix: git -C $MCC branch --set-upstream-to=origin/$cur $cur)"
    fi
  else
    note "$MCC: detached HEAD, branch-tracking check skipped"
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo "One or more BL-2526 submodule invariants failed." >&2
  echo "Rule: .gitmodules is canonical; the submodule's origin follows it, and the ClassicOldSong lineage is 'upstream'." >&2
  echo "See docs/DEVELOPMENT.md, 'moonlight-common-c submodule'." >&2
  exit 1
fi
echo "All BL-2526 submodule invariants hold ($checked initialised submodule(s) checked)."
