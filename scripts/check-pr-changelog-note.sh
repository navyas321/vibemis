#!/usr/bin/env bash
# PR-time guard: a change a user can notice must ship with a sentence a user can read.
#
# Usage: scripts/check-pr-changelog-note.sh <base-sha> <head-sha>
#        (PR_TITLE and PR_BODY come from the environment)
#
# WHY THIS EXISTS
# ---------------
# scripts/gen-changelog.sh builds the "🎯 What's new for you" section EXCLUSIVELY from
# `Changelog:` lines a human wrote. It never falls back to commit subjects, because a
# commit subject is written for other developers and reads like one -- "CI consolidation
# + release gating + stable gate + changelog regression" is a true sentence and a
# useless release note. That design only produces good release notes if the notes
# actually get written, and for months they mostly did not: the hero section was pasted
# onto individual releases by hand with `gh release edit` and disappeared again on the
# next cut.
#
# So this runs on every PR and fails when a user-visible change carries no note. It is
# the difference between "the generator can render prose" and "the release notes ARE
# prose" -- checked at the one moment someone is still in a position to write it.
#
# It models the SQUASH COMMIT, because that is what lands: `gh pr merge --squash` builds
# the commit subject from the PR title and the body from the PR description, so the note
# is accepted from the PR body as well as from any individual commit.
set -uo pipefail

BASE="${1:?usage: check-pr-changelog-note.sh <base-sha> <head-sha>}"
HEAD="${2:?usage: check-pr-changelog-note.sh <base-sha> <head-sha>}"
PR_TITLE="${PR_TITLE:-}"
PR_BODY="${PR_BODY:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-changelog.sh
. "$SCRIPT_DIR/lib-changelog.sh"

# github.event.pull_request.base.sha is the base branch tip as of the last sync, which
# is not necessarily the merge base -- diffing against it would attribute unrelated
# commits that landed on the base branch to this PR. Ask git for the real fork point.
BASE=$(git merge-base "$BASE" "$HEAD" 2>/dev/null || printf '%s' "$BASE")

# Anchored at column 0 to match the generator: an indented `Changelog:` is a markdown
# code block, i.e. someone quoting an example -- including the specimen note printed by
# this script's own failure message. Accepting it would let a copy-pasted example both
# satisfy this guard and become the release's hero bullet.
note_in() { printf '%s\n' "$1" | grep -qiE '^Changelog!?:[[:space:]]*[^[:space:]]'; }

# 1. Does this PR change anything a user receives?
#
# FAIL CLOSED. `git diff` writing "fatal: bad object" to stderr and nothing to stdout is
# indistinguishable from "this PR changed no files" if you only look at the pipe -- so a
# shallow checkout, a force-push between the event and the checkout, or a stale fork merge
# ref would make this guard print OK and exit 0 on every PR forever. A check whose only
# failure mode is "green" is not a check. Capture the status explicitly.
if ! CHANGED=$(git diff --name-only "$BASE" "$HEAD" 2>&1); then
  echo "FAIL: could not diff $BASE..$HEAD — refusing to pass by default." >&2
  printf '%s\n' "$CHANGED" >&2
  echo "(If this is a shallow checkout, the job needs fetch-depth: 0.)" >&2
  exit 1
fi
if ! changelog_any_ships <<< "$CHANGED"; then
  echo "OK: this PR changes no shipping files (CI, docs and guards only) — no release note needed."
  echo "    It will appear in the collapsed '🔩 Internal / build plumbing' section."
  exit 0
fi

# 2. Is it authored as plumbing anyway? Then it is already demoted and needs no note.
if printf '%s' "$PR_TITLE" | grep -qiE "$CHANGELOG_INTERNAL_SUBJECT_RE"; then
  echo "OK: PR title is a plumbing type — the entry is demoted to the Internal section."
  exit 0
fi

# 3. A note anywhere that will survive into the squash commit is enough.
if note_in "$PR_BODY"; then
  echo "OK: found a Changelog: note in the PR description."
  exit 0
fi
while IFS= read -r h; do
  [ -z "$h" ] && continue
  if note_in "$(git log -1 --format='%B' "$h" 2>/dev/null)"; then
    echo "OK: found a Changelog: note in commit $h."
    exit 0
  fi
done < <(git log --format='%H' --no-merges "$BASE..$HEAD" 2>/dev/null)

# 4. Nothing. Explain precisely what to write and where.
FILES=$(while IFS= read -r f || [ -n "$f" ]; do changelog_path_ships "$f" && echo "  - $f"; done <<< "$CHANGED" | head -10)
cat >&2 <<EOF
FAIL: this PR changes files that reach users, but no 'Changelog:' note was written.

Shipping files changed:
$FILES

The release body's "🎯 What's new for you" section is built ONLY from Changelog: notes.
Without one, this change is invisible to that section and the release just says no
highlights were flagged — which is how release notes quietly rot back into commit
subjects. Commit subjects describe the mechanism to developers; this describes the
effect to the person deciding whether to update.

Fix it by adding ONE line to the PR description (it becomes the squash commit body).
It must start at column 0 -- an indented line is a markdown code block, so a quoted
example cannot masquerade as a real note:

Changelog: Fixes stuttering and choppy video on AMD handhelds (Legion Go S, Steam Deck)

Write the effect, not the mechanism. "Enable RFI by default on AMD/Gallium" is the
mechanism; the line above is what actually changed for someone using the app.

Escape hatches, when they genuinely apply:
  Changelog: none    - looks user-facing by its type but truly is not (pure refactor,
                       internal-only fix). Demotes it to the Internal section.
  retitle as ci:/chore:/build:/docs:/test:  - plumbing; also needs no note.
EOF
exit 1
