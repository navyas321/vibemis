#!/usr/bin/env bash
# Release-notes readability guard (BL-2431, BL-2467, BL-2472).
#
# Unlike the other check-*-invariants.sh guards, this one does not grep source for a
# pattern -- it BUILDS A SYNTHETIC GIT REPO, runs the real scripts/gen-changelog.sh
# over it, and asserts the actual markdown. Every changelog regression so far shipped
# because the only way to see the output was to cut a release:
#
#   * 0.5.0-beta.004 -- the `Changelog:` note lookup used %(trailers:key=Changelog),
#     which requires the line to sit in git's strict final trailer block. `gh pr merge
#     --squash` rewrites the message, so the lookup silently returned empty and the
#     body fell back to raw commit subjects.
#   * 0.5.0-beta.005 -- an internal CI/release-plumbing PR was authored `fix:` and
#     carried a note, and the demotion rule only fired when a note was ABSENT. So the
#     single "Bug Fix" a game-streaming user was shown that build was
#     "Release notes stay human-readable through squash merges, a broken guard now
#     blocks the release, and a stray branch push can no longer cut an unapproved
#     stable" -- pure internal mechanics.
#   * Every cut -- the "What's new for you" hero section was never generated at all.
#     It was pasted onto individual releases by hand with `gh release edit`, so it
#     disappeared again on the next cut. That is the loop this guard exists to break.
#
# Run from the repo root.
set -uo pipefail

GEN="scripts/gen-changelog.sh"
fail=0
err() { echo "FAIL: $*" >&2; fail=1; }
ok()  { echo "  ok: $*"; }

[ -f "$GEN" ] || { echo "FAIL: $GEN is missing — the release body generator must stay a testable script, not an inline workflow run: block" >&2; exit 1; }

# ── Static guards (cheap, catch a rewrite that reintroduces a known defect) ─────
if grep -q 'trailers:key=Changelog' "$GEN" .github/workflows/dev-build.yml 2>/dev/null; then
  err "generator uses %(trailers:key=Changelog) — squash-merged commits lose the note (grep the commit body instead)"
fi
grep -qE "grep -m1 -iE '\^\[\[:space:\]\]\*Changelog:'" "$GEN" \
  || err "generator no longer greps the commit body for a Changelog: line"
grep -q "What's new for you" "$GEN" \
  || err "generator no longer emits the '🎯 What's new for you' hero section (that is the whole point — do not hand-edit releases instead)"
grep -q 'gen-changelog.sh' .github/workflows/dev-build.yml \
  || err "dev-build.yml no longer calls scripts/gen-changelog.sh — the release body must come from the tested generator"

# ── Behavioural test against a synthetic repo ──────────────────────────────────
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkrepo() {
  cd "$TMP"; rm -rf "$TMP/r"; mkdir -p "$TMP/r"; cd "$TMP/r"; t0=$fail
  git init -q -b main .
  git config user.name  "guard"
  git config user.email "guard@example.com"
  git config commit.gpgsign false
  git config core.autocrlf false
  echo seed > f.txt; git add f.txt
  git commit -qm "chore: seed"
  git tag 0.1.0-beta.001
}
commit() {  # commit <subject> [body-paragraph...]  -- each extra arg is its own -m,
            # which git renders as a separate blank-line-separated paragraph.
  local subject="$1"; shift
  local args=(-q -m "$subject") line
  for line in "$@"; do args+=(-m "$line"); done
  echo "$RANDOM$RANDOM" >> f.txt
  git add f.txt
  git commit "${args[@]}"
}
gen() { git tag -f "$1" >/dev/null 2>&1; bash "$ROOT/$GEN" "$1" 2>/dev/null; }

ROOT="$PWD"

# --- 1. a user-facing fix WITH a note: the note is the hero bullet, and the raw
#        developer-facing subject never reaches the user.
mkrepo
commit "fix(BL-2408): enable RFI by default on AMD/Gallium (mirror upstream d3c23b55)" \
       "Mechanism lives here." "Changelog: Fixes stuttering and choppy video on AMD handhelds"
out=$(gen 0.1.0-beta.002)
grep -q "^## 🎯 What's new for you" <<<"$out" || err "1: no hero section"
grep -q "^- Fixes stuttering and choppy video on AMD handhelds$" <<<"$out" || err "1: hero is missing the human-written note"
grep -q "Gallium" <<<"$out" && err "1: the raw technical subject leaked into the release body"
grep -q "### 🐛 Bug Fixes" <<<"$out" || err "1: the fix did not land in Bug Fixes"
[ "$fail" = "$t0" ] && ok "note-bearing fix -> hero bullet, technical subject suppressed"

# --- 2. THE beta.005 REGRESSION: internal work is demoted even when it carries a
#        note. A note must never promote plumbing into the user-facing sections.
mkrepo
commit "ci: consolidate invariant jobs and gate the release on the guard" \
       "Changelog: Release notes stay human-readable through squash merges"
out=$(gen 0.1.0-beta.002)
awk '/^## 🚧/{exit} {print}' <<<"$out" | grep -qi "human-readable" \
  && err "2: an internal ci: commit with a note was promoted into the user-facing hero (the 0.5.0-beta.005 regression)"
grep -q "🔩 Internal / build plumbing" <<<"$out" || err "2: internal commit is not in the collapsed Internal section"
grep -q "### 🐛 Bug Fixes" <<<"$out" && err "2: an internal ci: commit was routed into Bug Fixes"
grep -q "Internal tooling and maintenance only" <<<"$out" || err "2: an internal-only cut must say so honestly in the hero"
[ "$fail" = "$t0" ] && ok "internal-only cut -> demoted, honest hero, nothing fake in Bug Fixes"

# --- 3. explicit opt-out for a change that looks user-facing by type but isn't.
mkrepo
commit "fix: correct the release counter race" "Changelog: none"
out=$(gen 0.1.0-beta.002)
grep -q "🔩 Internal / build plumbing" <<<"$out" || err "3: 'Changelog: none' did not demote the commit"
grep -q "### 🐛 Bug Fixes" <<<"$out" && err "3: 'Changelog: none' commit still reached Bug Fixes"
[ "$fail" = "$t0" ] && ok "'Changelog: none' opt-out demotes a fix: commit"

# --- 4. no note -> NOT in the hero (a commit subject is written for developers and
#        reads like one), but still listed, cleaned, in the technical section.
mkrepo
commit "fix: Quick Menu selection wraps around at the top and bottom (BL-2443) (#287) [skip ci]"
out=$(gen 0.1.0-beta.002)
grep -q "No user-facing highlights were flagged" <<<"$out" || err "4: hero should honestly report that no note was written"
awk '/^## 🚧/{exit} {print}' <<<"$out" | grep -q "Quick Menu" && err "4: an un-noted subject leaked into the hero"
grep -q "^- Quick Menu selection wraps around at the top and bottom (\`" <<<"$out" \
  || err "4: technical bullet not cleaned (expected the fix:/BL-tag/PR-ref/[skip ci] scrubs)"
[ "$fail" = "$t0" ] && ok "un-noted commit -> cleaned technical bullet, honest hero, no jargon promoted"

# --- 5. the squash-merge shape: `Changelog:` is NOT the last line (GitHub appends its
#        own Co-authored-by), so a strict trailer read would miss it.
mkrepo
commit "fix: something technical" \
       "Changelog: Pairing no longer fails on first attempt" \
       "Co-authored-by: Someone <s@example.com>"
out=$(gen 0.1.0-beta.002)
grep -q "^- Pairing no longer fails on first attempt$" <<<"$out" \
  || err "5: note not found when it is not the final trailer (the 0.5.0-beta.004 regression)"
[ "$fail" = "$t0" ] && ok "note survives squash-merge message reformatting"

# --- 6. two commits, same note -> one hero bullet.
mkrepo
commit "fix: part one" "Changelog: Audio no longer crackles"
commit "fix: part two" "Changelog: Audio no longer crackles"
out=$(gen 0.1.0-beta.002)
n=$(awk '/^## 🚧/{exit} /^- Audio no longer crackles$/{c++} END{print c+0}' <<<"$out")
[ "$n" = "1" ] || err "6: expected 1 deduped hero bullet, got $n"
[ "$fail" = "$t0" ] && ok "duplicate notes dedupe to one hero bullet"

# --- 7. a cut with no commits at all still reads as a finished document.
mkrepo
out=$(gen 0.1.0-beta.002)
grep -q "^## 🎯 What's new for you" <<<"$out" || err "7: hero header missing on an empty range"
grep -q "No code changes since the previous release" <<<"$out" || err "7: empty range must say so"
[ "$fail" = "$t0" ] && ok "empty range renders an honest, complete body"

# --- 8. hero is always first, before the technical changelog.
mkrepo
commit "feat: add a thing" "Changelog: You can now do the thing"
out=$(gen 0.1.0-beta.002)
hero_line=$(grep -n "What's new for you" <<<"$out" | head -1 | cut -d: -f1)
tech_line=$(grep -n "Development Build Changelog" <<<"$out" | head -1 | cut -d: -f1)
[ -n "$hero_line" ] && [ -n "$tech_line" ] && [ "$hero_line" -lt "$tech_line" ] \
  || err "8: the hero section must come before the technical changelog"
grep -q "### ✨ New Features" <<<"$out" || err "8: feat: did not route to New Features"
[ "$fail" = "$t0" ] && ok "hero precedes the technical changelog"

# --- 9. THE #289 CASE, and the reason subject prefixes alone are not enough.
#        Authored `fix:`, carrying a confident user-facing note -- but the entire diff
#        is a workflow file, a doc and a CI guard. Nothing ships. The diff wins.
mkrepo
mkdir -p .github/workflows docs scripts
echo a > .github/workflows/dev-build.yml
echo b > docs/RELEASING.md
echo c > scripts/check-pipeline-invariants.sh
git add -A
git commit -q -m "fix: CI consolidation + release gating + stable gate (BL-2458/2459/2460) (#289)" \
  -m "Changelog: Release notes stay human-readable through squash merges, a broken guard now blocks the release"
out=$(gen 0.1.0-beta.002)
awk '/^## 🚧/{exit} {print}' <<<"$out" | grep -qi "human-readable" \
  && err "9: a commit whose whole diff is .github/docs/CI-scripts was promoted to the user-facing hero"
grep -q "### 🐛 Bug Fixes" <<<"$out" && err "9: non-shipping commit routed into Bug Fixes despite the fix: prefix"
grep -q "🔩 Internal / build plumbing" <<<"$out" || err "9: non-shipping commit is not in the Internal section"
[ "$fail" = "$t0" ] && ok "non-shipping diff demotes a fix: commit even when it carries a note (#289 case)"

# --- 10. the matching opt-in: `Changelog!:` overrides the diff for the rare
#         build-only change that really does alter what a user's device does.
mkrepo
mkdir -p .github/workflows
echo a > .github/workflows/dev-build.yml
git add -A
git commit -q -m "build: link against an older glibc" \
  -m "Changelog!: The AppImage now runs on older distributions without a glibc upgrade"
out=$(gen 0.1.0-beta.002)
grep -q "^- The AppImage now runs on older distributions without a glibc upgrade$" <<<"$out" \
  || err "10: 'Changelog!:' opt-in did not reach the hero"
[ "$fail" = "$t0" ] && ok "'Changelog!:' opt-in promotes a genuinely user-visible build change"

# --- 11. a shipping commit is NOT demoted just because it also touches docs/CI.
mkrepo
mkdir -p app docs
echo x > app/main.cpp
echo y > docs/notes.md
git add -A
git commit -q -m "fix: stream no longer drops on resume" -m "Changelog: Streams no longer drop when you resume from sleep"
out=$(gen 0.1.0-beta.002)
grep -q "^- Streams no longer drop when you resume from sleep$" <<<"$out" \
  || err "11: a commit touching real source was wrongly demoted because it also touched docs"
[ "$fail" = "$t0" ] && ok "mixed source+docs commit stays user-facing"

# --- 12. notes are arbitrary human text. Glob metacharacters must not be treated as
#         patterns by the dedupe, and shell metacharacters must not be interpreted.
mkrepo
commit "fix: channel picker" "Changelog: Fixes the [beta] channel picker and * wildcards"
commit "fix: pairing"        "Changelog: Pairing works again"
commit "fix: quotes"         'Changelog: Handles a `backtick`, $(not-a-subshell) and "quotes"'
out=$(gen 0.1.0-beta.002)
grep -qxF -- "- Fixes the [beta] channel picker and * wildcards" <<<"$out" \
  || err "12: a note containing glob metacharacters was mangled or dropped"
grep -qxF -- "- Pairing works again" <<<"$out" \
  || err "12: a later bullet was swallowed by a glob-pattern dedupe match"
grep -qxF -- '- Handles a `backtick`, $(not-a-subshell) and "quotes"' <<<"$out" \
  || err "12: shell metacharacters in a note were not passed through literally"
grep -q "not-a-subshell" <<<"$out" || err "12: command substitution in a note was evaluated"
[ "$fail" = "$t0" ] && ok "notes with glob and shell metacharacters survive intact"

cd "$ROOT"
if [ "$fail" = 0 ]; then
  echo "changelog invariants: OK"
else
  echo "changelog invariants: FAILED — release bodies would regress to developer jargon" >&2
fi
exit "$fail"
