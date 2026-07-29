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

# Two checks below use Python as a helper (a UTF-8 decode assertion and a bulk
# file-creation shortcut). Resolve the interpreter instead of assuming the bare
# `python` alias exists: it does not on a stock Ubuntu/WSL or Debian image, and
# the resulting exit 127 used to be reported as "generator emitted invalid
# UTF-8" -- a guard failure that blamed the generator for a missing interpreter.
#
# `command -v` PRESENCE IS NOT ENOUGH. On Windows, %LOCALAPPDATA%\Microsoft\WindowsApps
# ships an "App execution alias" stub named python3.exe that is on PATH, resolves fine,
# and then exits 49 printing "Python was not found; run without arguments to install
# from the Microsoft Store". That is the same failure the paragraph above describes,
# arriving through a different door -- the guard failed with "16: generator emitted
# invalid UTF-8" on a perfectly good generator. Probe that the interpreter actually
# RUNS, and take the first one that does.
PY=""
for _py in python3 python; do
  if command -v "$_py" >/dev/null 2>&1 && "$_py" -c 'pass' >/dev/null 2>&1; then PY="$_py"; break; fi
done

[ -f "$GEN" ] || { echo "FAIL: $GEN is missing — the release body generator must stay a testable script, not an inline workflow run: block" >&2; exit 1; }

# ── Static guards (cheap, catch a rewrite that reintroduces a known defect) ─────
# Comment lines are stripped first: these files explain AT LENGTH why %(trailers) is
# wrong, and a naive grep flags that prose as the defect it warns about.
if cat "$GEN" scripts/lib-changelog.sh .github/workflows/dev-build.yml 2>/dev/null \
   | grep -v '^[[:space:]]*#' | grep -q 'trailers:key=Changelog'; then
  err "generator uses %(trailers:key=Changelog) — squash-merged commits lose the note (grep the commit body instead)"
fi
# This used to pin the extractor's literal implementation (`grep -m1 -iE "^Changelog…"`),
# which made it impossible to fix the wrapped-note truncation without editing the guard
# that was supposedly protecting the behaviour. Pin the PROPERTY instead: the note is
# read from the commit body handed to it on stdin, never from git metadata --
# %(trailers)/`git interpret-trailers` only see git's strict final trailer block, and
# `gh pr merge --squash` rewrites the message so the note is usually outside it (the
# 0.5.0-beta.004 regression). Cases 5, 13, 20, 21 and 25 assert the actual behaviour.
extractor=$(awk '/^changelog_extract_note\(\)/{f=1} f{print} f&&/^}$/{exit}' scripts/lib-changelog.sh)
if [ -z "$extractor" ]; then
  err "could not locate changelog_extract_note() in scripts/lib-changelog.sh — this static guard is not actually checking anything"
elif printf '%s' "$extractor" | grep -v '^[[:space:]]*#' | grep -qE '\bgit\b'; then
  err "changelog_extract_note now shells out to git — it must read the commit body from stdin, or a squash-rewritten message loses its note"
fi
grep -q "changelog_extract_note" "$GEN" \
  || err "the generator no longer uses the shared changelog_extract_note — the PR guard and the release body would drift apart"
grep -q "What's new for you" "$GEN" \
  || err "generator no longer emits the '🎯 What's new for you' hero section (that is the whole point — do not hand-edit releases instead)"
grep -q 'gen-changelog.sh' .github/workflows/dev-build.yml \
  || err "dev-build.yml no longer calls scripts/gen-changelog.sh — the release body must come from the tested generator"

# ── Behavioural test against a synthetic repo ──────────────────────────────────
TMP=$(mktemp -d)
# Hard stop if the temp dir is not a real, absolute, empty-safe path. `cd ""` SUCCEEDS in
# bash, so an empty $TMP would sail past every `cd` below and leave mkrepo running
# `git init` / `git config user.name` / `git commit` / `git tag` in the developer's REAL
# repository -- rewriting its identity config and leaving a stray commit and tag behind.
case "$TMP" in
  /*) ;;
  *) echo "FAIL: mktemp -d did not return an absolute path ($TMP); refusing to run" >&2; exit 1 ;;
esac
[ -d "$TMP" ] || { echo "FAIL: temp dir $TMP does not exist; refusing to run" >&2; exit 1; }
trap 'rm -rf "$TMP"' EXIT

mkrepo() {
  cd "$TMP" || { echo "FAIL: cannot cd to $TMP" >&2; exit 1; }
  rm -rf "$TMP/r"; mkdir -p "$TMP/r"
  cd "$TMP/r" || { echo "FAIL: cannot cd to $TMP/r" >&2; exit 1; }
  t0=$fail
  git init -q -b main .
  # THIS ALREADY HAPPENED. The $TMP guard above only validates the path this script
  # computed; it cannot see a `git init` that silently re-inits an existing repo or a cd
  # that landed somewhere else. On 2026-07-29 the identity below reached the real repo's
  # .git/config, and 21 commits were authored as "guard <guard@example.com>" and pushed
  # before anyone read an author line.
  #
  # Comparing `git rev-parse --show-toplevel` against "$TMP/r" is NOT the check: on Git
  # Bash `mktemp -d` returns /tmp/tmp.XXXX while git returns C:/Users/…/Temp/tmp.XXXX,
  # so a string compare fails every Windows run for a reason that has nothing to do with
  # safety. Assert the property that actually separates the throwaway repo from anyone's
  # real one, in any path format: it was created one line ago, so it has no commits and
  # no remotes. A repo worth protecting has both.
  if git rev-parse -q --verify HEAD >/dev/null 2>&1 || [ -n "$(git remote 2>/dev/null)" ]; then
    echo "FAIL: $PWD already has commits or remotes — this is not the throwaway repo; refusing to write identity config into it" >&2
    exit 1
  fi
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
grep -qxF -- '- Handles a &#96;backtick&#96;, $(not-a-subshell) and "quotes"' <<<"$out" \
  || err "12: shell metacharacters in a note were not passed through literally (backticks entity-escaped)"
grep -q "not-a-subshell" <<<"$out" || err "12: command substitution in a note was evaluated"
[ "$fail" = "$t0" ] && ok "notes with glob and shell metacharacters survive intact"

# --- 18. an ODD number of backticks would otherwise pair with the opener of the
#         trailing (`hash`) code span, so the hash escapes and renders as stray text.
mkrepo
commit "fix: console" 'Changelog: Press ` to toggle the console'
out=$(gen 0.1.0-beta.002)
n=$(grep -c '`' <<<"$out")
bad=$(awk '/^- /{c=gsub(/`/,"`"); if (c%2) print}' <<<"$out")
[ -z "$bad" ] || err "18: a bullet has an odd number of backticks — the (\`hash\`) code span breaks: $bad"
[ "$fail" = "$t0" ] && ok "odd backticks in a note cannot break the hash code span"

# --- 19. a note or subject must not restructure the page: no nested list, heading,
#         blockquote, or split bullet from an embedded carriage return.
mkrepo
commit "fix: a" "Changelog: - nested dash starts a sublist"
commit "fix: b" "Changelog: ## fake heading in a bullet"
out=$(gen 0.1.0-beta.002)
grep -q "^- - " <<<"$out" && err "19: a note starting with '- ' created a nested sublist"
grep -q "^- ## " <<<"$out" && err "19: a note starting with '## ' kept heading syntax inside a bullet"
grep -qxF -- "- Nested dash starts a sublist" <<<"$out" || err "19: leading dash not normalized away"
[ "$fail" = "$t0" ] && ok "markdown-structural note prefixes are neutralized"

# --- 20. THE FUZZER'S M1: any casing of the key must be stripped, not published.
mkrepo
commit "fix: one"   "CHANGELOG: Fixes the audio crackle"
commit "fix: two"   "ChangeLog: Fixes the pairing timeout"
out=$(gen 0.1.0-beta.002)
grep -qi "^- CHANGELOG:" <<<"$out" && err "20: the note KEY itself was published as the release note"
grep -qi "^- ChangeLog:" <<<"$out" && err "20: the note KEY itself was published as the release note"
grep -qxF -- "- Fixes the audio crackle" <<<"$out" || err "20: CHANGELOG: (upper) note not extracted"
grep -qxF -- "- Fixes the pairing timeout" <<<"$out" || err "20: ChangeLog: (mixed) note not extracted"
[ "$fail" = "$t0" ] && ok "any casing of the Changelog key is stripped, never published"

# --- 21. THE FUZZER'S M2: a plain Changelog: elsewhere in the body must not disable
#         the Changelog!: override (which silently dropped BOTH notes).
mkrepo
mkdir -p .github/workflows
echo a > .github/workflows/x.yml
git add -A
git commit -q -m "build: packaging change" \
  -m "Changelog!: The AppImage now runs on older distributions" \
  -m "Changelog: some other line that must not win"
out=$(gen 0.1.0-beta.002)
grep -qxF -- "- The AppImage now runs on older distributions" <<<"$out" \
  || err "21: a sibling plain Changelog: line defeated the Changelog!: override and dropped both notes"
[ "$fail" = "$t0" ] && ok "Changelog!: wins over a sibling plain Changelog: line"

# --- 22. THE FUZZER'S M3: a non-version tag (nightly/latest/backup-*) must never
#         anchor the range — it ranks as "stable" and silently truncates it.
mkrepo
commit "feat: thing one" "Changelog: Thing one"
git tag nightly
commit "feat: thing two" "Changelog: Thing two"
commit "feat: thing three" "Changelog: Thing three"
out=$(gen 0.1.0-beta.002)
for n in one two three; do
  grep -qxF -- "- Thing $n" <<<"$out" || err "22: 'nightly' tag hijacked the range — 'Thing $n' silently vanished"
done
[ "$fail" = "$t0" ] && ok "non-version tags cannot hijack the range"

# --- 23. THE FUZZER'S M4: with no previous version tag, the fallback must respect the
#         target ref instead of walking HEAD, or post-tag commits get published in an
#         earlier tag's notes.
mkrepo
git tag -d 0.1.0-beta.001 >/dev/null 2>&1
commit "feat: in the release" "Changelog: In the release"
git tag 0.1.0-beta.002
commit "feat: after the tag" "Changelog: After the tag and must not appear"
out=$(bash "$ROOT/$GEN" 0.1.0-beta.002 2>/dev/null)
grep -q "After the tag" <<<"$out" && err "23: a commit made AFTER the tag was published in that tag's notes"
grep -qxF -- "- In the release" <<<"$out" || err "23: the tagged commit is missing from its own notes"
[ "$fail" = "$t0" ] && ok "no-previous-tag fallback respects the target ref"

# --- 24. THE FUZZER'S M5: core.quotepath quotes non-ASCII paths, so the plumbing
#         denylist never matched them and docs-only commits shipped as user-facing.
mkrepo
mkdir -p docs
echo x > "docs/café.md"
git add -A
git commit -q -m "fix: unicode docs filename" -m "Changelog: Should not be user facing"
out=$(gen 0.1.0-beta.002)
grep -q "Should not be user facing" <<<"$out" \
  && err "24: a docs-only commit with a non-ASCII path was published as user-facing (core.quotepath)"
grep -q "🔩 Internal / build plumbing" <<<"$out" || err "24: non-ASCII docs-only commit not demoted"
[ "$fail" = "$t0" ] && ok "non-ASCII docs paths are still recognized as plumbing"

# --- 13. an INDENTED `Changelog:` is a markdown code block -- someone quoting an
#         example, including the specimen note this repo's own PR-failure message
#         prints. It must not be mistaken for a real note, and must not beat one.
mkrepo
commit "fix: real user change" \
       "Here is how to write a note:" \
       "    Changelog: Fixes stuttering and choppy video on AMD handhelds" \
       "Changelog: The real note"
out=$(gen 0.1.0-beta.002)
grep -q "stuttering" <<<"$out" && err "13: an indented (code-block) Changelog: example was published as a release note"
grep -qxF -- "- The real note" <<<"$out" || err "13: the genuine column-0 note lost to a quoted example"
[ "$fail" = "$t0" ] && ok "indented Changelog: example ignored; real note wins"

# --- 14. `Changelog!: none` must opt out like `Changelog: none`, not render "- None".
mkrepo
commit "build: tweak packaging" "Changelog!: none"
out=$(gen 0.1.0-beta.002)
grep -qi "^- None$" <<<"$out" && err "14: 'Changelog!: none' rendered a hero bullet reading 'None'"
grep -q "🔩 Internal / build plumbing" <<<"$out" || err "14: 'Changelog!: none' did not demote"
[ "$fail" = "$t0" ] && ok "'Changelog!: none' opts out instead of publishing 'None'"

# --- 15. raw HTML in a subject must not close the collapsed Internal block early and
#         spill the remaining plumbing entries onto the visible release page.
mkrepo
commit "ci: fix the </details> handling in the widget"
commit "ci: a second plumbing entry that must stay inside the block"
out=$(gen 0.1.0-beta.002)
opens=$(grep -c '<details>' <<<"$out"); closes=$(grep -c '</details>' <<<"$out")
[ "$opens" = "1" ] && [ "$closes" = "1" ] \
  || err "15: unbalanced details block (opens=$opens closes=$closes) — a bullet escaped its section"
[ "$fail" = "$t0" ] && ok "raw HTML in a subject cannot break out of the Internal block"

# --- 16. non-ASCII must survive byte-intact. An emoji-leading note used to be corrupted
#         by a byte-oriented uppercase of its first character, emitting invalid UTF-8
#         into the release body and $GITHUB_OUTPUT.
mkrepo
commit "fix: controller" "Changelog: 🎮 Controller support with ünïcödé and 中文"
out=$(gen 0.1.0-beta.002)
grep -qxF -- "- 🎮 Controller support with ünïcödé and 中文" <<<"$out" \
  || err "16: a non-ASCII note was mangled"
if [ -n "$PY" ]; then
  # Keep the interpreter's own stderr and print it on failure. Discarding it is what
  # made a broken/stub interpreter indistinguishable from a genuinely corrupt release
  # body, and the guard then accused the generator.
  if ! pyerr=$(printf '%s' "$out" | "$PY" -c 'import sys; sys.stdin.buffer.read().decode("utf-8")' 2>&1); then
    err "16: generator emitted invalid UTF-8 (decoder said: ${pyerr:-<no output>})"
  fi
else
  echo "  note: no python interpreter; skipping the UTF-8 decode assertion" >&2
fi
[ "$fail" = "$t0" ] && ok "emoji and non-ASCII notes survive byte-intact as valid UTF-8"

# --- 17. a commit whose changed-path list is large enough to fill a pipe buffer must
#         still be classified by its paths. Reading it across a pipe let the early
#         return hand `git show` a SIGPIPE, which pipefail turned into "nothing ships"
#         -- silently demoting a real user-facing change and dropping its note.
mkrepo
mkdir -p app docs
echo x > app/main.cpp
{ [ -n "$PY" ] && "$PY" -c "
import os
for i in range(1500): open('docs/f%05d.md' % i, 'w').write('x')
" 2>/dev/null; } || for i in $(seq 1 1500); do echo x > "docs/f$i.md"; done
git add -A
git commit -q -m "fix: a real change alongside a very large docs drop" -m "Changelog: Something a user notices"
out=$(gen 0.1.0-beta.002)
grep -qxF -- "- Something a user notices" <<<"$out" \
  || err "17: a shipping commit with a huge path list was demoted to plumbing (SIGPIPE/pipefail)"
[ "$fail" = "$t0" ] && ok "huge-diff commit still classified by its paths"

# --- 25. A WRAPPED NOTE IS PUBLISHED WHOLE. Shipped on 0.5.0-beta.017: the extractor
#         read exactly one LINE, so two notes that wrapped in the commit body appeared
#         on the release page cut off mid-thought --
#           "- Fixes VRR streams staying on the slower, more conservative"
#           "- Fixes up to one frame of extra latency added to Wayland and X11 VRR"
#         -- on the most user-facing surface the project has. Wrapping a sentence at 72
#         columns is the normal way to write a commit body (git's own convention), so
#         the answer is to absorb the continuation, not to demand one-line notes.
#         A note therefore runs until a BLANK LINE or the NEXT TRAILER KEY, and the
#         wrap collapses to a single space. Both stop conditions are asserted here:
#         swallowing them would append a Co-authored-by address, or an entire following
#         paragraph of developer prose, onto the hero bullet.
mkrepo
commit "fix(vrr): release the presentation latch once the spacing guard recovers" \
       "A transient spacing correction inflates the adaptive guard." \
       "Changelog: Fixes VRR streams staying on the slower, more conservative
presentation path long after the hiccup that triggered it had passed.
Co-authored-by: Someone <s@example.com>"
commit "fix(vrr): scope the depth-2 swapchain to Gamescope FIFO" \
       "Changelog: Fixes up to one frame of extra latency added to Wayland and X11 VRR
streaming by the Gamescope frame-rate fix, which was being applied to
every display path instead of just Gamescope." \
       "Verified: tests/vrr all six binaries pass."
out=$(gen 0.1.0-beta.002)
grep -qxF -- "- Fixes VRR streams staying on the slower, more conservative presentation path long after the hiccup that triggered it had passed." <<<"$out" \
  || err "25: a two-line Changelog: note was truncated at its first line (the 0.5.0-beta.017 regression)"
grep -qxF -- "- Fixes up to one frame of extra latency added to Wayland and X11 VRR streaming by the Gamescope frame-rate fix, which was being applied to every display path instead of just Gamescope." <<<"$out" \
  || err "25: a three-line Changelog: note was truncated"
grep -qi "Co-authored-by\|s@example.com" <<<"$out" \
  && err "25: the note absorbed the following trailer — a continuation must stop at the next trailer key"
grep -q "all six binaries" <<<"$out" \
  && err "25: the note absorbed the following paragraph — a continuation must stop at a blank line"
[ "$fail" = "$t0" ] && ok "wrapped Changelog: notes are published whole, stopping at a blank line or the next trailer"

# ── Stable-tier hero curation (26-30) ──────────────────────────────────────────
# 0.5.0 -- the first production release cut by this generator -- opened with 28 hero
# bullets, 26 of which were fixes, each a forty-word sentence about a frame-pacing
# internal. Every line was true and the section as a whole told a prospective user
# nothing about what the release WAS. A pre-release hero is a changelist for testers and
# is right to list everything; a production hero has to answer "should I install this?".
# So on a bare stable it carries features plus fixes an author marked as major, and the
# complete technical changelog collapses underneath -- nothing dropped, just not competing.
stable_hero() { awk '/^<details><summary>🚧/{exit} {print}' <<<"$1"; }
mkstable() { mkrepo; git tag 0.1.0; }   # a same-tier ancestor, so the range is 0.1.0..cut

# --- 26. the curation itself: on a stable, a plain noted fix is technical-only while a
#         feature headlines. On the SAME commits cut as a beta, both are in the hero --
#         the rule is tier-dependent, not a new way to lose a note.
mkstable
commit "feat: add a per-game bitrate override" "Changelog: You can now set a bitrate per game"
commit "fix: correct the jitter counter label" "Changelog: Corrects the mislabeled network-jitter counter"
out=$(gen 0.2.0)
stable_hero "$out" | grep -qxF -- "- You can now set a bitrate per game" || err "26: a feature note is missing from the stable hero"
stable_hero "$out" | grep -qi "jitter" && err "26: an unmarked fix reached the stable hero (the 0.5.0 wall-of-fixes)"
grep -q "Corrects the mislabeled network-jitter counter" <<<"$out" || err "26: the unmarked fix was DROPPED instead of demoted — the technical changelog must still list it"
# Rebuilt from scratch for the beta half: gen() CREATES the tag it generates, so reusing
# the repo would leave 0.2.0 sitting on HEAD as a same-or-higher-tier ancestor of
# 0.2.0-beta.001 -- an empty range, and an assertion that passes or fails for a reason
# that has nothing to do with tier curation.
c26_t0=$t0
mkrepo
t0=$c26_t0   # mkrepo re-baselines t0; keep this case's, so a stable-half failure still reports
commit "feat: add a per-game bitrate override" "Changelog: You can now set a bitrate per game"
commit "fix: correct the jitter counter label" "Changelog: Corrects the mislabeled network-jitter counter"
out=$(gen 0.1.0-beta.002)
awk '/^## 🚧/{exit} {print}' <<<"$out" | grep -qi "jitter" || err "26: a pre-release hero must still list every note"
[ "$fail" = "$t0" ] && ok "stable hero = features only; the same fix still heroes on a beta and is never lost"

# --- 27. the opt-in that makes a big fix headline a production release. Without it the
#         rule would have no way to say "this one matters" and stables would advertise
#         features only -- which is wrong for a release whose whole point is a fix.
mkstable
commit "fix: enable RFI by default on AMD/Gallium" \
       "Changelog-Major: Fixes stuttering and choppy video on AMD handhelds (Legion Go S, Steam Deck)"
out=$(gen 0.2.0)
stable_hero "$out" | grep -qxF -- "- Fixes stuttering and choppy video on AMD handhelds (Legion Go S, Steam Deck)" \
  || err "27: Changelog-Major: did not put a major fix in the stable hero"
grep -q "### 🐛 Bug Fixes" <<<"$out" || err "27: a Changelog-Major: fix must still route to Bug Fixes by its subject type"
grep -qi "Changelog-Major" <<<"$out" && err "27: the trailer key itself was published"
[ "$fail" = "$t0" ] && ok "'Changelog-Major:' promotes a fix into the stable hero without changing its routing"

# --- 28. `Changelog-Major: none` opts out like the other two spellings, rather than
#         rendering "- None" as the single headline of a production release.
mkstable
commit "fix: internal-only cleanup" "Changelog-Major: none"
out=$(gen 0.2.0)
grep -qi "^- None$" <<<"$out" && err "28: 'Changelog-Major: none' published a 'None' bullet"
grep -q "🔩 Internal / build plumbing" <<<"$out" || err "28: 'Changelog-Major: none' did not demote the commit"
[ "$fail" = "$t0" ] && ok "'Changelog-Major: none' opts out instead of publishing 'None'"

# --- 29. UPSTREAM ATTRIBUTION IS NOT NEWS. 0.5.0's second hero bullet was "Adopt Nonary
#         VRR10 active-wait fix: remove the fixed yield-count limit (4096)..." -- a
#         sentence addressed to whoever tracks the fork graph, shown to someone deciding
#         whether their handheld stutters less. Fork/maintainer handles stay in the
#         commit body and the technical changelog; they never reach the hero, on either
#         tier. Host types and protocols (Artemis, Apollo, Sunshine, Moonlight) are a
#         real user-facing choice and must NOT be caught by the same rule.
mkrepo
commit "fix(vrr): adopt the upstream active-wait bound" \
       "Changelog: Adopt Nonary VRR10 active-wait fix: remove the fixed yield-count limit (4096)"
commit "feat: show the host type on each computer card" \
       "Changelog: Host cards now show whether the PC is running Apollo, Sunshine or Artemis"
out=$(gen 0.1.0-beta.002)
awk '/^## 🚧/{exit} {print}' <<<"$out" | grep -qi "nonary" \
  && err "29: an upstream fork attribution reached the hero (the 0.5.0 Nonary bullet)"
grep -qi "nonary" <<<"$out" || err "29: the attribution was dropped entirely — the technical changelog must keep it"
awk '/^## 🚧/{exit} {print}' <<<"$out" | grep -q "Apollo, Sunshine or Artemis" \
  || err "29: the attribution filter is over-broad — host types are a user-facing choice, not fork provenance"
[ "$fail" = "$t0" ] && ok "fork/maintainer attribution stays out of the hero; host types are untouched"

# --- 30. the stable BODY shape: hero first and uncollapsed, everything technical --
#         plumbing included -- inside one <details> that is properly closed. An unclosed
#         or doubly-nested block silently swallows the rest of the release page.
mkstable
commit "feat: add a thing" "Changelog: You can now do the thing"
commit "ci: retune the guard"
out=$(gen 0.2.0)
grep -q "^## 🚧 Development Build Changelog" <<<"$out" && err "30: a production release is still headed 'Development Build Changelog'"
hero_line=$(grep -n "What's new for you" <<<"$out" | head -1 | cut -d: -f1)
det_line=$(grep -n "Full technical changelog" <<<"$out" | head -1 | cut -d: -f1)
[ -n "$hero_line" ] && [ -n "$det_line" ] && [ "$hero_line" -lt "$det_line" ] \
  || err "30: the hero must come before the collapsed technical changelog"
[ "$(grep -c '<details>' <<<"$out")" = "1" ] || err "30: expected exactly one <details> on a stable (nested collapsibles render inconsistently on GitHub)"
[ "$(grep -c '</details>' <<<"$out")" = "1" ] || err "30: the stable <details> block is not closed exactly once — the rest of the page would be swallowed"
grep -q "🔩 Internal / build plumbing" <<<"$out" || err "30: plumbing vanished instead of moving inside the collapsed block"
[ "$fail" = "$t0" ] && ok "stable body: uncollapsed hero, one closed <details> holding the full changelog and plumbing"

cd "$ROOT"
if [ "$fail" = 0 ]; then
  echo "changelog invariants: OK"
else
  echo "changelog invariants: FAILED — release bodies would regress to developer jargon" >&2
fi
exit "$fail"
