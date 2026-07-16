#!/usr/bin/env bash
# repo-split-dryrun.sh -- BL-1565 / P4.0 two-repo split, mechanical part.
#
# Companion to docs/REPO_SPLIT_PLAN.md (the plan is the narrative; the lists
# below are the machine-readable source of truth -- keep them in sync).
#
# DEFAULT IS A DRY RUN: prints every MOVE / DROP / STUB / SPLIT / EDIT /
# REVIEW action it would take and touches NOTHING.
#
#   ./scripts/repo-split-dryrun.sh                  # dry run (safe, read-only)
#   ./scripts/repo-split-dryrun.sh --execute        # perform LOCAL moves only
#   ./scripts/repo-split-dryrun.sh --meta-dir PATH  # target working tree
#                                                   # (default ../vibemis-agent-meta)
#
# --execute does ONLY local filesystem/git-index operations:
#   1. copies every tracked MOVE file into the meta working tree (same layout),
#      skipping *.AppImage (DROP class -- they live in GitHub Releases),
#   2. `git rm -r` the MOVE paths from this repo (DROPs go with them),
#   3. writes the two stub pointer files and stages them.
# It NEVER commits, NEVER pushes, and NEVER performs any GitHub/network
# operation. Creating the private repo, committing, and pushing are manual
# runbook steps (docs/REPO_SPLIT_PLAN.md section 5).
set -euo pipefail

META_DIR="../vibemis-agent-meta"
EXECUTE=0
PRIVATE_REPO="navyas321/vibemis-agent-meta"

while [ $# -gt 0 ]; do
  case "$1" in
    --execute) EXECUTE=1; shift ;;
    --meta-dir) META_DIR="${2:?--meta-dir needs a path}"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1 (see --help)" >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------- inventory
# MOVE: migrates wholesale to the private meta repo (mirrored layout).
MOVE_PATHS=(
  "CLAUDE.md"
  "docs/WORKFLOW.md"
  "docs/personas"
  "docs/ROUTINE_PROMPT.md"
  "docs/CLAUDE_CODE_PRACTICES.md"
  "docs/TEST_AUTOMATION.md"
  "docs/PHASE_STATUS.md"
  "docs/SESSION_HANDOFF_2026-07-13.md"
  "docs/UI_DEFECT_CHECKLIST.md"
  "docs/design/redesign/CLAUDE_CODE_PROMPT.txt"
  "docs/design/redesign/HANDOFF.md"
  "testing"
  ".claude/commands"
  ".github/workflows/alert.yml"
)

# DROP: removed from the tree, NOT migrated (release artifacts; every one is
# on the GitHub Releases page and in pre-split git history regardless).
DROP_PATTERN='\.AppImage$'

# SPLIT: extract the public-relevant content into a public doc BEFORE the
# move (manual runbook step 3). Format: "source|destination".
SPLIT_ACTIONS=(
  "CLAUDE.md|docs/RELEASING.md (versioning + tier matrix + CI release rules + README rule)"
  "CLAUDE.md|new slim public CLAUDE.md (build commands, branch model)"
  "docs/WORKFLOW.md|CONTRIBUTING.md (commit format + PR four-test scorecard)"
  "docs/TEST_AUTOMATION.md|docs/SELFTEST.md (selftest CLI, --json, log-assertion recipes)"
)

# EDIT: reference fixes in files that STAY public (manual runbook step 5).
EDIT_SITES=(
  "app/main.cpp:663|comment points at docs/TEST_AUTOMATION.md -> docs/SELFTEST.md"
  "app/cli/commandlineparser.cpp:196|comment points at docs/TEST_AUTOMATION.md -> docs/SELFTEST.md"
  "app/app.pro:603|comment 'see CLAUDE.md' (version cadence) -> docs/RELEASING.md"
  ".github/workflows/dev-build.yml:195|comment '(CLAUDE.md tier matrix)' -> docs/RELEASING.md"
  "scripts/vibepollo-log.sh:53|hint 'add that path to CLAUDE.md' -> reword (agent-meta repo)"
  "scripts/gamescope-lease.sh:15|example agent id 'clienttest' -- cosmetic, optional"
  "docs/DEVELOPMENT.md:3|WORKFLOW.md pointer -> CONTRIBUTING.md"
  "docs/DEVELOPMENT.md:20-29|repo tree diagram lists testing/ + WORKFLOW.md + CLAUDE.md -> redraw"
  "docs/BUILD_SYSTEM.md:3|WORKFLOW.md pointer -> CONTRIBUTING.md"
  "docs/design/README.md:7|PHASE_STATUS.md P3.18 pointer -> drop/reword"
  "docs/design/README.md:23|BUILD_AGENT_INBOX.md mention -> reword"
  ".gitignore:84|delete '!testing/theme-review/*.zip' un-ignore line"
)

# REVIEW: root debris -- pre-publication hygiene, deliberately NOT touched by
# this script (see plan Appendix A).
REVIEW_ITEMS=(
  "config.log|upstream author's local build log -- delete"
  "test_changes.md|ad-hoc dev notes -- delete"
  "test_hash.py|OTP debug harness -- delete or tools/debug/"
  "test_otp_hash.cpp|OTP debug harness -- delete or tools/debug/"
  "find_passphrase.py|OTP brute-force debug script -- delete (bad optics public)"
  "create_feature_branch.sh|one-off helper for a merged feature -- delete"
  "AV1_DETECTION_ANALYSIS.md|product bug analysis -- fold into docs/ or delete"
)

# STUB files written (execute) / announced (dry run) after the moves.
stub_claude_md() {
  cat <<EOF
# CLAUDE.md

Agent-orchestration meta for this project (session governance, personas,
SOPs, the test-cycle handoff) lives in the private repo
${PRIVATE_REPO} -- agents clone it side by side with this one
and start sessions from its root.

Contributors: see CONTRIBUTING.md and docs/ (DEVELOPMENT.md, BUILD_SYSTEM.md,
RELEASING.md). This placeholder is replaced by a slim public CLAUDE.md in
runbook step 5 (docs/REPO_SPLIT_PLAN.md).
EOF
}
stub_testing_readme() {
  cat <<EOF
# testing/

The in-repo agent test-cycle handoff (per-cycle instructions, reports, the
test checklist, and the build/test agent message channels) moved to the
private repo ${PRIVATE_REPO} (same directory layout).

Test AppImages were never meant to be committed; download builds from this
repo's GitHub Releases page instead.
EOF
}
STUB_FILES=("CLAUDE.md" "testing/README.md")

# ---------------------------------------------------------------- helpers
say()  { printf '%s\n' "$*"; }
act()  { printf '%-6s %s\n' "$1" "$2"; }

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$ROOT" ]; then
  echo "ERROR: not inside a git repository" >&2; exit 1
fi
cd "$ROOT"
if [ ! -f vibemis.pro ]; then
  echo "ERROR: $ROOT does not look like the vibemis repo root (no vibemis.pro)" >&2
  exit 1
fi

MODE="DRY RUN"
[ "$EXECUTE" -eq 1 ] && MODE="EXECUTE (local moves only)"
say "== repo-split-dryrun (BL-1565 / P4.0) =="
say "mode:     $MODE"
say "repo:     $ROOT"
say "meta dir: $META_DIR"
say ""

if [ "$EXECUTE" -eq 1 ]; then
  BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  if [ "$BRANCH" = "vibemis-main" ]; then
    echo "ERROR: refusing to execute on vibemis-main -- use a work branch" >&2
    exit 1
  fi
  if [ -n "$(git status --porcelain)" ]; then
    echo "ERROR: working tree not clean -- commit or stash first" >&2
    exit 1
  fi
fi

# ---------------------------------------------------------------- 1. moves
say "-- 1. MOVE (tracked files -> $META_DIR, mirrored layout) / DROP (not migrated)"
move_count=0
drop_count=0
drop_bytes=0
for path in "${MOVE_PATHS[@]}"; do
  if ! git ls-files --error-unmatch "$path" >/dev/null 2>&1 \
     && [ -z "$(git ls-files -- "$path")" ]; then
    act "SKIP" "$path (not tracked -- inventory drift, update this script)"
    continue
  fi
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if printf '%s' "$f" | grep -Eq "$DROP_PATTERN"; then
      sz=0
      [ -f "$f" ] && sz=$(wc -c < "$f" | tr -d '[:space:]')
      drop_bytes=$((drop_bytes + sz))
      drop_count=$((drop_count + 1))
      act "DROP" "$f ($((sz / 1048576)) MB; kept in Releases + git history)"
    else
      move_count=$((move_count + 1))
      act "MOVE" "$f -> $META_DIR/$f"
      if [ "$EXECUTE" -eq 1 ]; then
        mkdir -p "$META_DIR/$(dirname "$f")"
        cp -p "$f" "$META_DIR/$f"
      fi
    fi
  done < <(git ls-files -- "$path")
done

if [ "$EXECUTE" -eq 1 ]; then
  for path in "${MOVE_PATHS[@]}"; do
    if [ -n "$(git ls-files -- "$path")" ]; then
      git rm -r -q -- "$path"
    fi
  done
fi

# ---------------------------------------------------------------- 2. stubs
say ""
say "-- 2. STUB pointer files (written after the moves)"
for s in "${STUB_FILES[@]}"; do
  act "STUB" "$s"
done
if [ "$EXECUTE" -eq 1 ]; then
  stub_claude_md      > "CLAUDE.md"
  mkdir -p testing
  stub_testing_readme > "testing/README.md"
  git add CLAUDE.md testing/README.md
fi

# ---------------------------------------------------------------- 3. manual
say ""
say "-- 3. SPLIT extractions (do these BEFORE executing the moves -- manual)"
for s in "${SPLIT_ACTIONS[@]}"; do
  act "SPLIT" "${s%%|*} -> ${s#*|}"
done

say ""
say "-- 4. EDIT reference fixes in files that stay public (manual)"
for e in "${EDIT_SITES[@]}"; do
  act "EDIT" "${e%%|*} -- ${e#*|}"
done

say ""
say "-- 5. REVIEW root debris (separate pre-publication cleanup, never touched here)"
for r in "${REVIEW_ITEMS[@]}"; do
  f="${r%%|*}"
  if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    act "REVIEW" "$f -- ${r#*|}"
  fi
done

# ---------------------------------------------------------------- summary
say ""
say "== summary =="
say "MOVE:  $move_count tracked files"
say "DROP:  $drop_count AppImages (~$((drop_bytes / 1048576)) MB)"
say "STUB:  ${#STUB_FILES[@]} pointer files"
say "SPLIT: ${#SPLIT_ACTIONS[@]} extractions (manual, pre-move)"
say "EDIT:  ${#EDIT_SITES[@]} reference-fix sites (manual, post-move)"
if [ "$EXECUTE" -eq 1 ]; then
  say ""
  say "Local moves DONE. Nothing was committed and nothing touched GitHub."
  say "Next (runbook, docs/REPO_SPLIT_PLAN.md section 5):"
  say "  1. review 'git status' here, then commit on this branch"
  say "  2. cd $META_DIR && git init/add/commit and push to the (manually created) private repo"
  say "  3. apply the EDIT fixes + real public CLAUDE.md, then PR into vibemis-main"
else
  say ""
  say "Dry run only -- nothing was changed. Re-run with --execute (on a work"
  say "branch, clean tree) to perform the local moves."
fi
