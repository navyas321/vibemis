#!/usr/bin/env bash
# Generate a release-body changelog for one cut.
#
# Usage: scripts/gen-changelog.sh <version-or-ref> [previous-tag]
#        (writes markdown to stdout; run from a full-history clone)
#
# WHY THIS IS A SCRIPT AND NOT A `run:` BLOCK IN dev-build.yml
# ------------------------------------------------------------
# It used to be ~100 lines of shell embedded in the workflow, which meant the ONLY way
# to find out what a release body would say was to cut a release and read it. Three
# separate regressions shipped that way (raw subjects instead of notes on
# 0.5.0-beta.004; internal CI mechanics presented as user-facing "Bug Fixes" on
# 0.5.0-beta.005; and a "What's new" section that never existed in the generator at
# all and was hand-pasted onto individual releases with `gh release edit`, so it
# vanished again on the very next cut). As a script it is executable locally and is
# covered by scripts/check-changelog-invariants.sh, which builds a synthetic repo and
# asserts the real output — so the format is verified BEFORE a cut, not after.
#
# OUTPUT CONTRACT (the thing the user actually asked for)
# ------------------------------------------------------
#   ## 🎯 What's new for you      <- plain language, ALWAYS present, human-written
#   ## 🚧 Development Build Changelog  <- categorized technical detail w/ hashes
#   <details> 🔩 Internal / build plumbing </details>   <- collapsed, out of the way
#
# The hero section is built EXCLUSIVELY from `Changelog:` lines that a human wrote in
# the commit body. It never falls back to commit subjects, because a commit subject is
# written for other developers and reads like one -- "CI consolidation + release gating
# + stable gate + changelog regression" is a true sentence and a useless release note.
# If nobody wrote a note, the hero says so honestly rather than promoting jargon; the
# PR-time `changelog-note` check in dev-build.yml is what stops that from happening on
# a user-facing change.
set -euo pipefail

# Classification rules are shared with scripts/check-pr-changelog-note.sh so the PR-time
# nag and the release-time output can never disagree about what counts as user-facing.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-changelog.sh
. "$SCRIPT_DIR/lib-changelog.sh"

CURRENT_VERSION="${1:?usage: gen-changelog.sh <version-or-ref> [previous-tag]}"
PREV_TAG_OVERRIDE="${2:-}"

# ── Range selection ────────────────────────────────────────────────────────────
# A promoted release must NOT drop the changelist of the pre-releases it was cut from.
# Anchoring to the most-recent tag by date regardless of tier made a beta cut right
# after an alpha span only alpha..beta, losing every commit the alpha introduced (same
# for the rc/stable chain). Anchor to the previous tag of the SAME-OR-HIGHER stability
# tier so the range covers the full promotion window.
tier_rank() {  # $1 = tag/version -> stability rank (higher = more stable)
  case "$1" in
    *-alpha.*) echo 1 ;;
    *-beta.*)  echo 2 ;;
    *-rc.*)    echo 3 ;;
    *-dev.*)   echo 0 ;;
    *)         echo 4 ;;  # bare (no pre-release suffix) = stable
  esac
}

# Only a real version tag may anchor a range. tier_rank() calls anything without a
# pre-release infix "stable" (rank 4), which is right for `0.4.3` and catastrophically
# wrong for `nightly`, `latest`, `backup-2026-07-01` or `pre-refactor`: each outranks a
# beta, wins the previous-tag search, and silently truncates the range to whatever that
# marker happens to point at. A repo with a `nightly` tag published a beta whose notes
# listed 1 of its 3 commits, with nothing in the output hinting that two were missing.
is_version_tag() {  # $1 = tag -> 0 if it parses as v?MAJOR.MINOR.PATCH...
  case "$1" in
    v[0-9]*|[0-9]*) ;;
    *) return 1 ;;
  esac
  printf '%s' "$1" | grep -qE '^v?[0-9]+\.[0-9]+\.[0-9]+([-+.][0-9A-Za-z.-]+)?$'
}

# Previewing the NEXT cut ("what will the release body say if I cut now?") is the most
# useful local invocation there is, and its tag by definition does not exist yet -- that
# used to die with a raw `fatal: ambiguous argument`. Resolve to HEAD instead.
#
# RESOLVED BEFORE the previous-tag search, not after. The search filters candidates by
# "is an ancestor of the tag being generated", and it read that commit from
# $CURRENT_VERSION -- which on the preview path resolves to nothing, so the filter was
# skipped entirely and the newest version-SHAPED tag in the repo won regardless of
# whether HEAD descends from it. In this repo that is the upstream fork marker
# `v6.1.0-vrr10`: `gen-changelog.sh 0.5.0-beta.018` selected it (tier_rank calls any tag
# without a pre-release infix "stable", so it outranks every beta), and since it is NOT
# an ancestor of HEAD the range walked thousands of unrelated commits instead of the ten
# since 0.5.0-beta.017. Anchoring on RANGE_END makes the preview use the same ancestry
# rule as a real cut.
RANGE_END="$CURRENT_VERSION"
if ! git rev-parse -q --verify "${CURRENT_VERSION}^{commit}" >/dev/null 2>&1; then
  RANGE_END="HEAD"
  echo "Note: $CURRENT_VERSION is not a commit-ish yet; previewing against HEAD" >&2
fi

PREV_TAG="$PREV_TAG_OVERRIDE"
if [ -z "$PREV_TAG" ]; then
  CUR_RANK=$(tier_rank "$CURRENT_VERSION")
  # A candidate must be (a) not this tag, (b) an ancestor of this tag's commit, and
  # (c) not cut after it. The old loop enforced only (a): it walked the whole
  # newest-first tag list, so a tag created LATER was still eligible. Regenerating
  # notes for 0.5.0-beta.004 therefore selected 0.5.0-beta.005 -- newer, equal rank --
  # and produced the inverted range beta.005..beta.004, which is empty, so the body
  # announced "no code changes since the previous release" for a build that had two.
  # At cut time the new tag is normally the newest, which is why this never showed up
  # in a release and only corrupted after-the-fact regeneration.
  #
  # (b) is the real relation being asked for -- "the previous release this one descends
  # from" -- and it also settles ties that (c) alone cannot, since two tags cut in the
  # same second (or two tags on the same commit) compare equal by date.
  CUR_COMMIT=$(git rev-parse -q --verify "${RANGE_END}^{commit}" 2>/dev/null || true)
  CUR_DATE=$(git for-each-ref --format='%(creatordate:unix)' "refs/tags/${CURRENT_VERSION}" 2>/dev/null | head -1)
  while read -r t tdate; do
    [ -z "$t" ] && continue
    [ "$t" = "$CURRENT_VERSION" ] && continue
    is_version_tag "$t" || continue
    [ -n "$CUR_DATE" ] && [ -n "$tdate" ] && [ "$tdate" -gt "$CUR_DATE" ] && continue
    if [ -n "$CUR_COMMIT" ]; then
      tc=$(git rev-parse -q --verify "${t}^{commit}" 2>/dev/null) || continue
      git merge-base --is-ancestor "$tc" "$CUR_COMMIT" 2>/dev/null || continue
    fi
    [ "$(tier_rank "$t")" -ge "$CUR_RANK" ] || continue
    PREV_TAG="$t"
    break
  done < <(git for-each-ref --sort=-creatordate --format='%(refname:short) %(creatordate:unix)' refs/tags)
fi

if [ -z "$PREV_TAG" ]; then
  SINCE_DATE=$(date -d '7 days ago' '+%Y-%m-%d' 2>/dev/null || date -v-7d '+%Y-%m-%d')
  echo "No previous same-or-higher-tier release found; using commits since $SINCE_DATE" >&2
  # Anchored on $RANGE_END, not an implicit HEAD. Without the revision argument this
  # walked HEAD regardless of which tag was being generated, so commits made AFTER a tag
  # were published in THAT tag's release notes -- the same after-the-fact-regeneration
  # corruption the tagged path above was fixed for, left behind on the fallback path.
  COMMITS=$(git log "$RANGE_END" --since="$SINCE_DATE" --pretty=format:'%h|%s' --no-merges)
else
  echo "Range: ${PREV_TAG}..${RANGE_END}" >&2
  COMMITS=$(git log "${PREV_TAG}..${RANGE_END}" --pretty=format:'%h|%s' --no-merges)
fi

# ── Per-commit classification ──────────────────────────────────────────────────
clean_subject() {  # strip everything that is addressed to developers, not users
  printf '%s' "$1" \
    | sed -E 's/ *\[(skip ci|ci skip|alpha|no ci)\]//gI' \
    | sed -E 's/ *\((BL|LIT)-[0-9]+([,/ ]+((BL|LIT)-)?[0-9]+)*\)//gI' \
    | sed -E 's/\[?(BL|LIT)-[0-9]+\]?:?[[:space:]]*//gI' \
    | sed -E 's/ *\(#[0-9]+\)[[:space:]]*$//' \
    | sed -E 's/^[a-zA-Z]+(\([^)]*\))?!?:[[:space:]]*//' \
    | sed -E 's/  +/ /g; s/^[[:space:]]+//; s/[[:space:]]+$//'
}

sentence_case() {  # capitalize the first letter, leave ACRONYMS and the rest alone
  # Guarded to an ASCII lowercase first character on purpose. The obvious
  # `sed -E 's/^(.)/\U\1/'` is both GNU-only and byte-oriented outside a UTF-8 locale:
  # with LANG unset, `.` matches the single byte 0xF0 of a leading emoji and \U rewrites
  # it to 0xD0, so a note like "🎮 Controller support" emits INVALID UTF-8 into the
  # release body and $GITHUB_OUTPUT. There is nothing to capitalize in an emoji or an
  # accented letter anyway, so simply leave any non-ASCII first character alone.
  local s="$1"
  case "$s" in
    [a-z]*) printf '%s' "${s^}" ;;
    *)      printf '%s' "$s" ;;
  esac
}

md_escape() {  # make a bullet incapable of escaping its own line or section
  # Four separate ways one commit message could rewrite the page around it:
  #   </details>  closed the collapsed Internal block early, spilling every following
  #               plumbing entry onto the visible release page (and `<!--` commented out
  #               the entire rest of the body).
  #   backtick    an ODD number of them pairs with the opener of the trailing (`hash`),
  #               so the hash escapes its code span and renders as stray text.
  #   leading - / # / >  starts a nested list, heading or blockquote inside the bullet.
  #   C0 controls a bare CR is a line ending in CommonMark, so the bullet splits in two;
  #               ESC/CSI sequences reach the terminal of anyone reading the raw body.
  # GitHub renders the entities back to literal characters, so no meaning is lost.
  printf '%s' "$1" \
    | tr -d '\000-\010\013\014\016-\037\177' \
    | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' \
          -e 's/`/\&#96;/g'
}

strip_md_structure() {
  # Runs BEFORE sentence_case, so "- nested item" becomes "Nested item" rather than
  # keeping its lowercase initial. A note starting with `-`, `*`, `#` or `>` would
  # otherwise open a nested list, heading or blockquote inside the bullet we wrap it in.
  printf '%s' "$1" | sed -E 's/^[[:space:]]*([-*+>]|#{1,6})[[:space:]]+//; s/^[[:space:]]+//'
}

INTERNAL_SUBJECT_RE="$CHANGELOG_INTERNAL_SUBJECT_RE"

# ── Does this commit touch anything a user actually receives? ──────────────────
# Subject prefixes are a STATEMENT OF INTENT and they are routinely wrong. The commit
# that produced the 0.5.0-beta.005 embarrassment was authored `fix:` and carried a
# user-flavoured note, yet its entire diff was .github/workflows/dev-build.yml,
# docs/RELEASING.md and scripts/check-pipeline-invariants.sh -- nothing that ships.
# The diff cannot lie about that, so the diff is the authority here: a commit that
# changes no shipping file is plumbing no matter how it was authored or described.
ships() {  # $1 = hash -> 0 if any changed file reaches a user
  # A here-string, NOT a pipe. changelog_any_ships returns as soon as it sees the first
  # shipping path; across a pipe that leaves `git show` still writing, so it takes
  # SIGPIPE and exits 141, and `set -o pipefail` then reports the whole pipeline as
  # failed -- i.e. "nothing ships". A commit large enough to fill the 64 KiB pipe buffer
  # with its path list (~1200 files) would therefore be silently demoted to plumbing and
  # its note dropped from the release notes. Measured: 800 files fine, 1200 files broken.
  # -c core.quotepath=false: quotepath is ON by default, so `docs/café.md` comes back as
  # the literal string "docs/cafÃ©.md" -- surrounding double quotes included. None
  # of the denylist patterns (docs/*, *.md) match a string that starts with a quote, so
  # every non-ASCII path fell through to "ships" and docs-only commits were published as
  # user-facing changes.
  changelog_any_ships <<< "$(git -c core.quotepath=false show --name-only --format='' "$1" 2>/dev/null)"
}

FEATURES=""; BUGFIXES=""; IMPROVEMENTS=""; OTHER=""; INTERNAL=""; WHATSNEW=""
have_commits=false

while IFS='|' read -r hash subject; do
  [ -z "$hash" ] && continue
  have_commits=true
  subject=$(printf '%s' "$subject" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')

  # A `Changelog: <plain-language effect>` line in the commit BODY is the ONLY source
  # for the user-facing hero. Read it by grepping the full body, NOT via %(trailers):
  # `gh pr merge --squash` reformats the message (appends GitHub's own Co-authored-by,
  # concatenates squashed commits) so the line is almost never in git's strict final
  # trailer block, and %(trailers) silently returns empty -- that regression stripped
  # the human-readable notes from 0.5.0-beta.004. A body grep is position-independent
  # and survives any squash reformatting.
  body=$(git log -1 --format='%b' "$hash" 2>/dev/null || true)

  # `Changelog!: <text>` is the opt-IN, for the rare change that ships real user-visible
  # behaviour while touching only build/docs paths (a packaging change that alters what
  # the AppImage does on a user's device). The bang mirrors conventional-commits' `feat!:`.
  #
  # Looked up UNCONDITIONALLY and given priority. It used to run only `if [ -z "$note" ]`,
  # so any plain `Changelog:` line elsewhere in the same body silently disabled the
  # override -- and because the commit was then demoted on its diff, BOTH notes were
  # dropped and the change vanished from the release notes entirely. The header called
  # the bang "the ONLY way to override the diff" while a stray sibling line defeated it.
  note_bang=$(changelog_extract_note "!" <<< "$body" || true)
  note_plain=$(changelog_extract_note "" <<< "$body" || true)
  force_user_facing=false
  if [ -n "$note_bang" ]; then
    note="$note_bang"
    force_user_facing=true
  else
    note="$note_plain"
  fi

  clean=$(clean_subject "$subject")
  # A subject that is only a conventional-commit prefix (`feat:`) or only whitespace
  # cleans to nothing. Falling back to the raw subject rendered "- Feat: (`hash`)" or an
  # empty "-  (`hash`)" bullet; say plainly that there was no description instead.
  if [ -z "$clean" ]; then
    clean=$(printf '%s' "$subject" | sed -E 's/^[a-zA-Z]+(\([^)]*\))?!?:[[:space:]]*//; s/^[[:space:]]+//; s/[[:space:]]+$//')
    [ -z "$clean" ] && clean="(no description)"
  fi

  # `Changelog: none` (or skip/internal/-) is the explicit opt-out for a change that
  # looks user-facing by its type but genuinely isn't. Checked AFTER the bang lookup so
  # `Changelog!: none` opts out too, instead of rendering a hero bullet reading "None".
  force_internal=false
  case "$(printf '%s' "$note" | tr '[:upper:]' '[:lower:]')" in
    none|skip|internal|n/a|-) force_internal=true; force_user_facing=false; note="" ;;
  esac

  # Plumbing is decided by the SUBJECT TYPE and THE DIFF -- never by whether a note
  # exists. The old rule was `if no note AND subject is ci/chore/...`, so attaching a
  # user-facing-sounding note to an internal commit PROMOTED it into "Bug Fixes".
  # That is exactly how 0.5.0-beta.005 shipped "Release notes stay human-readable
  # through squash merges, a broken guard now blocks the release..." as the single
  # thing a game-streaming user supposedly got from that build -- from a commit whose
  # entire diff was a workflow file, a doc and a CI guard script.
  if [ "$force_internal" = true ] \
     || { [ "$force_user_facing" != true ] \
          && { printf '%s' "$subject" | grep -qiE "$INTERNAL_SUBJECT_RE" || ! ships "$hash"; }; }; then
    INTERNAL="${INTERNAL}- $(md_escape "$(sentence_case "$(strip_md_structure "$clean")")") (\`${hash}\`)"$'\n'
    continue
  fi

  entry=$(md_escape "$(sentence_case "$(strip_md_structure "${note:-$clean}")")")

  if [ -n "$note" ]; then
    # Dedupe: two commits carrying the same note render one hero bullet.
    # A note is arbitrary human text that can contain `*`, `?` and `[...]`. `grep -Fx`
    # states "literal, whole line" outright. (A `case $'\n'"$W" in *$'\n'"- $entry"...`
    # form is also correct, but only because a double-quoted expansion inside a case
    # pattern is matched literally -- a rule subtle enough that a later reader could
    # reasonably think it globs and "fix" it into something that does.)
    if ! grep -qxF -- "- ${entry}" <<< "$WHATSNEW"; then
      WHATSNEW="${WHATSNEW}- ${entry}"$'\n'
    fi
  fi

  if printf '%s' "$subject" | grep -qiE '^(feat|feature|add|implement|new)[:(]'; then
    FEATURES="${FEATURES}- ${entry} (\`${hash}\`)"$'\n'
  elif printf '%s' "$subject" | grep -qiE '^(fix|bug|resolve|correct|hotfix)[:(]'; then
    BUGFIXES="${BUGFIXES}- ${entry} (\`${hash}\`)"$'\n'
  elif printf '%s' "$subject" | grep -qiE '^(improve|enhance|update|optimize|optimise|perf|refactor)[:(]'; then
    IMPROVEMENTS="${IMPROVEMENTS}- ${entry} (\`${hash}\`)"$'\n'
  else
    OTHER="${OTHER}- ${entry} (\`${hash}\`)"$'\n'
  fi
done <<< "$COMMITS"

# ── Assembly ───────────────────────────────────────────────────────────────────
# Hero FIRST and always present. Never a bare header: every branch below prints a
# real sentence, so a release body can't come out looking half-generated.
printf '## 🎯 What'"'"'s new for you\n\n'
if [ -n "$WHATSNEW" ]; then
  printf '%s\n' "$WHATSNEW"
elif [ "$have_commits" != true ]; then
  printf '%s\n\n' "_No code changes since the previous release — this build was cut from the same source (CI re-run or infrastructure-only update)._"
elif [ -z "${FEATURES}${BUGFIXES}${IMPROVEMENTS}${OTHER}" ]; then
  printf '%s\n\n' "_Internal tooling and maintenance only — nothing user-facing changed in this build._"
else
  printf '%s\n\n' "_No user-facing highlights were flagged for this build — the technical changelog below has the full detail._"
fi

printf '## 🚧 Development Build Changelog\n\n'
[ -n "$FEATURES" ]     && printf '### ✨ New Features\n%s\n' "$FEATURES"
[ -n "$BUGFIXES" ]     && printf '### 🐛 Bug Fixes\n%s\n' "$BUGFIXES"
[ -n "$IMPROVEMENTS" ] && printf '### 🔧 Improvements\n%s\n' "$IMPROVEMENTS"
[ -n "$OTHER" ]        && printf '### 📝 Other Changes\n%s\n' "$OTHER"
if [ -z "${FEATURES}${BUGFIXES}${IMPROVEMENTS}${OTHER}" ] && [ -z "$INTERNAL" ]; then
  printf '%s\n\n' "_No commits in this range._"
fi
# Plumbing last and collapsed -- present for traceability, out of the way of what a
# user actually gets from this build.
if [ -n "$INTERNAL" ]; then
  printf '<details><summary>🔩 Internal / build plumbing</summary>\n\n%s\n</details>\n' "$INTERNAL"
fi
exit 0
