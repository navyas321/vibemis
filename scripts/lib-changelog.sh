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
# Read by grepping the whole body, NOT via %(trailers:key=Changelog): `gh pr merge
# --squash` rewrites the message (appends GitHub's own Co-authored-by, concatenates
# the squashed commits) so the line almost never survives inside git's strict final
# trailer block, and %(trailers) then returns empty. That is precisely how
# 0.5.0-beta.004 lost its human-readable notes and fell back to raw commit subjects.
# A body grep is position-independent and survives any squash reformatting.
changelog_extract_note() {  # $1 = "" for Changelog:, "!" for Changelog!:
  local bang="${1:-}"
  grep -m1 -iE "^[[:space:]]*Changelog${bang}:" \
    | sed -E "s/^[[:space:]]*[Cc]hangelog${bang}:[[:space:]]*//; s/[[:space:]]*\$//"
}
