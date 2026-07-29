#!/usr/bin/env bash
# Shared changelog classification rules.
#
# Sourced by scripts/gen-changelog.sh (which writes the release body) and
# scripts/check-pr-changelog-note.sh (which nags at PR time). They MUST agree: the PR
# check exists to promise "this change will appear in the release notes as prose", and
# it can only make that promise if it classifies commits exactly like the generator.
# Keeping the rules in one file is the only way that stays true.

# Conventional-commit types that are plumbing by definition. `docs:` is included --
# README and handoff churn is not shipped behaviour. Any type carrying a
# (ci)/(build)/(release)/(deps)/(workflow) scope is plumbing whatever the type says.
CHANGELOG_INTERNAL_SUBJECT_RE='^(ci|chore|build|docs|test|tests|style|meta)(\(|!?:)|^[a-z]+\((ci|build|release|deps|workflow)\)!?:'

# Does one changed path reach a user? Returns 0 (yes) / 1 (no).
#
# A DENYLIST, deliberately: an unrecognised new path counts as shipping. A wrongly
# promoted entry is visible in the release body and someone fixes it; a wrongly hidden
# one is invisible and nobody ever finds out.
changelog_path_ships() {
  case "$1" in
    '') return 1 ;;
    .github/*|docs/*|tests/*|testing/*)                 return 1 ;;
    .gitignore|.gitattributes|.gitmodules|.editorconfig) return 1 ;;
    CLAUDE.md|*.md)                                      return 1 ;;
    # Most of scripts/ DOES ship: vibemis-update.sh, install-vibemis-desktop.sh,
    # vibemis-doctor.sh, vibemis-setup.sh, pair-host.sh and friends are user-run tools
    # documented in the README. Only the CI-side generators and guards are plumbing.
    scripts/check-*-invariants.sh|scripts/check-pr-changelog-note.sh) return 1 ;;
    scripts/gen-changelog.sh|scripts/gen-releases-index.sh|scripts/lib-changelog.sh) return 1 ;;
    *) return 0 ;;
  esac
}

# Does any path on stdin reach a user? Returns 0 (yes) / 1 (no).
changelog_any_ships() {
  local f
  # `|| [ -n "$f" ]` so a final line with no trailing newline is still examined --
  # dropping it would silently mark a shipping commit as plumbing and hide it from
  # the release notes, which is the exact failure this whole file exists to prevent.
  while IFS= read -r f || [ -n "$f" ]; do
    changelog_path_ships "$f" && return 0
  done
  return 1
}

# First `Changelog:` / `Changelog!:` note in the text on stdin, or empty.
#
# Read by grepping the whole body, NOT via %(trailers:key=Changelog): `gh pr merge
# --squash` rewrites the message (appends GitHub's own Co-authored-by, concatenates
# the squashed commits) so the line almost never survives inside git's strict final
# trailer block, and %(trailers) then returns empty. That is precisely how
# 0.5.0-beta.004 lost its human-readable notes and fell back to raw commit subjects.
# A body grep is position-independent and survives any squash reformatting.
#
# ANCHORED AT COLUMN 0, deliberately. Allowing leading whitespace made an INDENTED
# occurrence match -- and a 4-space indent is markdown for "code block", which is
# exactly how this trailer gets written when someone quotes an example. The failure
# message in check-pr-changelog-note.sh prints an indented specimen note; pasting that
# block into a PR description used to satisfy the guard AND become the release's hero
# bullet, publishing "Fixes stuttering and choppy video on AMD handhelds" on a build
# that did nothing of the kind. `grep -m1` takes the FIRST match, so the quoted example
# even beat the real note further down. A real trailer is never indented.
CHANGELOG_NOTE_RE='^Changelog:'
CHANGELOG_BANG_NOTE_RE='^Changelog!:'

# `Changelog-Major: <text>` is the SEVERITY marker, and it only matters on a stable cut.
#
# A pre-release hero answers "what landed since the last beta?", so every note belongs in
# it. A production hero answers a different question -- "should I install this?" -- and a
# 40-bullet wall of individually-true fix sentences answers it badly: 0.5.0 shipped with
# 28 hero bullets, 26 of them fixes, and nothing in that list told a reader what the
# release WAS. So a stable hero carries features plus the handful of fixes that resolve a
# genuinely major issue, and this trailer is how an author says "this fix is one of them".
# Everything else stays in the full technical changelog, which is complete either way.
CHANGELOG_MAJOR_NOTE_RE='^Changelog-Major:'

# A NOTE MAY WRAP ACROSS LINES.
#
# This used to read exactly one line (`grep -m1 | sed`), and 0.5.0-beta.017 shipped the
# consequence on its release page:
#
#   - Fixes VRR streams staying on the slower, more conservative
#   - Fixes up to one frame of extra latency added to Wayland and X11 VRR
#
# Both sentences stopped mid-thought, because their authors had wrapped them at 72
# columns in the commit body — which is git's own convention for a commit message and
# the natural thing to write. Silently deleting the rest of someone's user-facing copy
# is the bug; demanding single-line notes would just move it onto the author.
#
# So the note runs from the key to the first BLANK LINE or the next TRAILER KEY, and the
# wrap collapses to a single space. Those two stop conditions are what keep it from
# eating the `Co-authored-by:` GitHub appends to a squash merge, or the next paragraph
# of developer prose. A trailer key is deliberately narrow — one unspaced token of
# letters/digits/hyphens then a colon — so ordinary continuation prose cannot look like
# one. An INDENTED continuation is absorbed too (that is git's folded-trailer form);
# only the note's FIRST line must sit at column 0, for the code-block reason below.
CHANGELOG_TRAILER_KEY_RE='^[A-Za-z][A-Za-z0-9-]*!?:([ \t]|$)'

changelog_extract_note() {  # $1 = key variant: "" (Changelog:), "!" (Changelog!:),
                            #      "-major" (Changelog-Major:).  Body text on stdin.
  local bang="${1:-}"
  # Case-INsensitive on the key, and the key is stripped with the SAME spellings it is
  # matched with. A previous version allowed case variation only on the first letter
  # (`[Cc]hangelog`), so `CHANGELOG:` and `ChangeLog:` matched but survived the strip and
  # published the key itself as the release note: a hero bullet reading
  # "CHANGELOG: fixes the audio crackle". Comparing a lowercased fixed-length prefix
  # cannot drift apart that way — one expression does both the match and the strip.
  awk -v key="changelog${bang}:" -v keyre="$CHANGELOG_TRAILER_KEY_RE" '
    BEGIN { klen = length(key); found = 0; out = "" }
    {
      line = $0
      sub(/\r$/, "", line)          # a CRLF body must not leave \r inside the note
      if (!found) {
        # Anchored at column 0 (see the comment above): an indented occurrence is a
        # markdown code block, i.e. someone quoting an example.
        if (substr(tolower(line), 1, klen) == key) { found = 1; out = substr(line, klen + 1) }
        next
      }
      if (line ~ /^[ \t]*$/) exit   # blank line ends the note
      if (line ~ keyre) exit        # the next trailer ends the note
      out = out " " line
    }
    END {
      if (!found) exit 0            # print nothing, exactly as the old grep did
      gsub(/[ \t]+/, " ", out); sub(/^ +/, "", out); sub(/ +$/, "", out)
      print out
    }
  '
}
