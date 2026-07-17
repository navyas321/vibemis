# BL-2035 cutover checklist — remaining orchestrator steps

State as of the 2026-07-16 readiness audit (third worker pass). The cutover hold continues; this
branch is kept rebased so cutover stays trivial. **This branch has NOT been re-rebased onto the
current tip yet** — see the staleness note below; a trial rebase confirmed it resolves cleanly
via the recipe.

**Branch base: `fd053081`** (origin/vibemis-main, "testing: inbox - dispatch test121 alpha.013")
— rebased from the original base `222b0187` after test119 and test120 closed and merged.
`wip/BL-2035-split-execution` holds 5 commits on that base and **is local-only (never pushed to
origin)**. The private repo `navyas321/vibemis-agent-meta` is fully populated, reconciled
through `fd053081`, and pushed.

**⚠ Base is now stale — `origin/vibemis-main` has advanced to `00e0e676` (13 commits past
`fd053081`).** The 2026-07-16 audit trial-rebased a throwaway copy onto `00e0e676` and it
resolved to a correct tree (testing/ = stub README only; test121/test119 BL fixes present;
`app/version.txt` = 0.2.0). Two things changed the rebase story since the second pass, both
because upstream landed parts of the split independently and must be reflected before the freeze
re-rebase:

- **wip commit `48a14ab6` (P4.0 step 3, extract public policy) is now AUTO-DROPPED** by rebase
  as "previously applied" — `origin/vibemis-main` landed the identical extraction via `9cdfe8cb`
  (`docs/RELEASING.md`, `docs/SELFTEST.md`, `CONTRIBUTING.md`). No conflict; it just becomes a
  no-op, leaving 4 commits to replay.
- **`CLAUDE.md` now CONFLICTS during the move-commit replay** — `origin/vibemis-main` slimmed it
  independently via `caea34d6`, so it is no longer untouched upstream (the caveat in step 3's
  recipe below is now void for CLAUDE.md *and* CONTRIBUTING.md). Resolution is trivial: the wip
  branch's final `CLAUDE.md` is **byte-identical** to `origin/vibemis-main`'s, so
  `git checkout --ours CLAUDE.md && git add CLAUDE.md`. After the move commit, the slim-CLAUDE
  commit `d5f47b44` replays without further CLAUDE.md conflict and the delta vs main shows no
  CLAUDE.md change (already slim on main).
- **INBOX drift:** `testing/BUILD_AGENT_INBOX.md` gained the 2026-07-17 test123 dispatch block
  on main (commit `00e0e676`); it was mirrored into the meta repo (`sync:` commit `0faadc9`) and
  the move commit's modify/delete on it is resolved by `git rm` as before.

---

## Reconciliation status (was the CRITICAL section)

The drift that the first pass flagged as CRITICAL is **resolved**:

- test119 (BL-2015 pointer slots) and test120 (BL-2013 d-pad dedupe) merged into vibemis-main;
  the wip branch is rebased on top, so their product-code fixes
  (`app/streaming/input/abstouch.cpp`, `input.h`, `app/gui/sdlgamepadkeynavigation.*`) are
  in the branch tree — verified present post-rebase. No fix gets reverted by merging this branch.
- Their cycle artifacts (`testing/test119-pointer-slots/`, `testing/test120-dpad-dedupe/`
  instructions + reports), the current `testing/BUILD_AGENT_INBOX.md`,
  `testing/TEST_CHECKLIST.md`, and the BL-2013-corrected `testing/automation/vinput.py` are in
  the meta repo (commit `64f80ef`), and the rebased move commit removes them from the public
  tree (testing/ = stub README.md only — the CI guard's own logic passes locally).

**Standing instruction — final reconciliation loop at cutover day.** The dev loop is still live
(test121 merged; test122 host-visual re-fix in flight; test123 dispatched (alpha.015); test124
queued), so main will keep moving. Right before cutover, repeat what this pass did:

1. `git fetch origin && git diff fd053081..origin/vibemis-main --name-status` (in the vibemis
   repo). KEEP-class changes (app/, scripts/, .github/ product files) need nothing — the rebase
   carries them.
2. For every MOVE-classified path in that diff (anything under `testing/`, the moved docs/
   files): copy current-main content into `vibemis-agent-meta` (mirrored path), commit + push
   there.
3. `git rebase origin/vibemis-main wip/BL-2035-split-execution`. Proven conflict recipe (updated
   by the 2026-07-16 trial rebase onto `00e0e676`):
   - **Move-commit stop.** Upstream-modified moved files (INBOX/CHECKLIST — vinput.py was
     untouched this time) surface as modify/delete — `git rm` each (deletion stands; step 2
     already saved the content). Upstream-ADDED testing/ files (new test dirs / reports) do NOT
     conflict — they silently survive unless removed, so explicitly `git rm -r testing/<new-dirs>`
     at the same conflict stop (this pass: `testing/test121-nav-sounds` +
     `testing/test109-gamescope-scaling/report.md`).
   - **CLAUDE.md content conflict (NEW).** Upstream slimmed CLAUDE.md itself (`caea34d6`), so it
     now conflicts at the move-commit replay. The wip branch's final CLAUDE.md is byte-identical
     to main's — resolve with `git checkout --ours CLAUDE.md && git add CLAUDE.md`. Then
     `git rebase --continue`.
   - **`48a14ab6` auto-drops** as already-applied (upstream `9cdfe8cb`); the remaining three
     commits (`d5f47b44`, `f26ce0f5`, `8130ed82` + this note) replay clean **provided upstream
     hasn't ALSO touched dev-build.yml, .gitignore, or the Group A/B fix sites.** ⚠ The earlier
     "hasn't touched CLAUDE.md or CONTRIBUTING.md" assumption is now VOID — upstream landed both
     (CLAUDE.md via `caea34d6`, CONTRIBUTING.md via `9cdfe8cb`); handled above and by the
     auto-drop respectively.
4. Re-verify: `ls testing/` = README.md only; guard logic passes; BL-fixes still in tree;
   `bash -n` scripts; version.txt untouched.

**In-flight branches carry pre-split testing/ dirs — handle at freeze.** `test121-nav-sounds`
(dispatched, alpha.013; its `testing/test121-nav-sounds/` exists only on that branch) and
test122 (shift+tab, branch pushed) still follow the pre-split protocol. Two implications:
(a) their instructions are NOT in the meta repo yet — they get the step-2 treatment when they
merge to main pre-cutover, or must be copied from their branches if cutover happens while they
are still open; (b) **post-cutover, a pre-split-style test branch merging into vibemis-main
would reintroduce `testing/` files and FAIL the new CI guard** — so the freeze (runbook step 1)
must land-or-park them, and anything parked must have its `testing/` dir migrated to the meta
repo and stripped from the branch before it merges after cutover.

---

## Runbook steps (docs/REPO_SPLIT_PLAN.md section 5) — status

**Step 1 — Freeze the loop.** OPEN (orchestrator). Post STAND DOWN on the coordination bus and
in `testing/BUILD_AGENT_INBOX.md` (now maintained in `vibemis-agent-meta`), land or park
in-flight cycles (test121/test122 — see above), take the mirror backup:
`git clone --mirror https://github.com/navyas321/vibemis.git vibemis-backup-<date>.git`.

**Step 2 — Create the private repo.** DONE. `https://github.com/navyas321/vibemis-agent-meta`
(private). Note: `.github/workflows/alert.yml` was subsequently **deleted** from it per
maintainer decision 2026-07-16 (commit `00a8321`, pushed by a concurrent session; recoverable
from seed commit `295f741`) — this resolves the plan's open question 3 as DELETE.

**Step 3 — SPLIT extractions.** DONE (`docs/RELEASING.md`, `docs/SELFTEST.md` new,
`CONTRIBUTING.md` appended) — commit `48a14ab6` on the wip branch.

**Step 4 — Seed the meta repo.** DONE and RECONCILED through `fd053081`. Meta repo commits:
`295f741` (seed, 136 files), `64f80ef` (test119/test120 artifacts + current INBOX/CHECKLIST +
BL-2013 vinput.py fix), `1cc2c93` (alert.yml reference cleanup). Vibemis-side removal is the
rebased move commit `c15a5e4e` (157 files: original 136 moves + 16 AppImage drops + the
post-base additions folded in).

**Step 5 — Reference fixes + slim public CLAUDE.md + PR into vibemis-main.** Fixes DONE
(11/12; A6 intentionally skipped as cosmetic-optional) — commit `d5f47b44`; extra
dangling-reference file `docs/RELEASE_RUNBOOK_0.2.0.md` fixed in `f26ce0f5`. **OPEN: open the
PR after the freeze** — `gh pr create --base vibemis-main` from this branch (push it only at
that point). The PR HEAD touches code files (`app/main.cpp`, `app/cli/commandlineparser.cpp`,
`app/app.pro`), so merging cuts a beta per the normal tier rules.

**Step 6 — D1/D2 protocol rework in the meta repo.** DONE — `541fbdd` + link-fix `5598441`
(run-cycle.sh two-repo mode, personas' bootstraps, ROUTINE_PROMPT, Dispatch one-liner,
ship-test-pr.md, verify-ci.md `-R` flags, release-hygiene.md rewritten report-only,
CLAUDE_CODE_PRACTICES §7 marked retired). `docs/WORKFLOW.md` got a two-repo preamble + fixes to
the load-bearing procedures; a full line-by-line pass remains nice-to-have.

**Step 7 — Update agent bootstraps living OUTSIDE the repos.** OPEN (orchestrator/maintainer):
the scheduled-routine prompt on the build host (paste from the reworked
`vibemis-agent-meta/docs/ROUTINE_PROMPT.md`), build-host memory notes, and the coordination-bus
announcement to @test-agent. The announcement content is pre-written: point the agent at
`vibemis-agent-meta/docs/BOOTSTRAP.md` (the definitive two-repo clone commands + both agents'
cold-start sequences + the transitional instructions-resolution rule).

**Step 8 — Verify test-agent cold-start end-to-end.** PARTIAL, now SCRIPTED. Done off-device:
fresh clone of the meta repo → clean tree, zero broken relative links (full sweep), all scripts
pass `bash -n`/`py_compile`; HANDOFF.md and all cycle artifacts verified content-identical to
main. The check is now mechanical: `vibemis-agent-meta/scripts/verify-cold-start.sh
<meta-path> <vibemis-path>` asserts the full bootstrap surface in both repos (37 checks; its
vibemis-side section expects the POST-cutover tree, so pre-merge point it at this branch's
checkout — a pre-cutover vibemis-main correctly fails 4 checks). OPEN: the real on-device pass
— fresh-clone both repos side by side on the Legion Go (or clean sim), run the verifier, then
one real `testing/run-cycle.sh <current-slug>` (network/Releases access is not assertable
offline) — before un-freezing.

**Step 9 — Secrets audit gate.** OPEN, separate day, pre-publication: `gitleaks detect` +
`trufflehog git` over ALL vibemis history before BL-1556 flips visibility.

**Step 10 — Post-split CI guard.** DONE — in `d5f47b44` (dev-build.yml step on vibemis-main
pushes; its logic verified passing against the rebased tree locally).

### Condensed remaining list (orchestrator)

1. Freeze the loop (STAND DOWN, land-or-park test121/test122, mirror backup).
2. Final reconciliation loop (see standing instruction above) if main moved past `fd053081`.
3. Push `wip/BL-2035-split-execution` + open the PR into vibemis-main; merge.
4. Step 7 external bootstraps + bus announcement (content ready: meta repo `docs/BOOTSTRAP.md`).
5. Step 8 on-device cold-start verification (`scripts/verify-cold-start.sh` in the meta repo +
   one real run-cycle); fix-forward under the freeze; un-freeze.
6. (Separate day) Step 9 secrets audit → BL-1556 visibility flip.

---

## Maintainer decisions absorbed / questions still open

Resolved since the first pass:
- **`docs/design/redesign/HANDOFF.md` → PRIVATE** (maintainer, 2026-07-16). Already the plan's
  default and already executed: verified in the meta repo (content identical to main) and
  removed from the public branch. No action was needed.
- **`alert.yml` → DELETE from the meta repo** (maintainer, 2026-07-16, executed as `00a8321` by
  a concurrent session; references cleaned up in `1cc2c93`). The public-side removal was always
  part of the move commit.

Still open (plan section 6):
1. **testing/ instructions public-vs-private** — executed per the plan default (all private);
   flag only if the maintainer wants per-cycle instructions public, which would reopen D1.
2. **`docs/RELEASE_RUNBOOK_0.2.0.md`** (new, from execution): stays public with genericized
   pointers for now, but it is heavily agent-process-flavored — consider adding it to the MOVE
   inventory in a plan revision.

---

## Deviations from the plan/runbook (cumulative, both passes)

1. Worktree path typo on first creation, self-corrected immediately (no lasting effect).
2. `.gitignore` B6 removed the orphaned comment line along with the specified un-ignore line.
3. A6 (`scripts/gamescope-lease.sh:15`) left unchanged — plan marks it cosmetic/optional and
   the `clienttest` example value is still meaningful post-split.
4. `docs/RELEASE_RUNBOOK_0.2.0.md` fixed though absent from the plan's Group A/B inventory
   (two dangling references to moved paths) — see open question 2.
5. `.claude/commands/release-hygiene.md` rewritten (not just moved): its delete-releases steps
   contradicted release permanence (BL-1736) — plan Appendix A itself flagged this fix.
6. `verify-ci.md` + `CLAUDE_CODE_PRACTICES.md` §7 fixed beyond the plan's explicit D1/D2 list
   (wrong-repo `gh` defaults post-split; a live instruction to fire the retired alert channel).
7. Two pre-existing broken relative links to WORKFLOW.md fixed in both persona files (the link
   target pointed inside `docs/personas/` instead of one level up) — caught by the clone-fresh
   link sweep.
8. Rebase reconciliation (this pass): modify/delete conflicts on `BUILD_AGENT_INBOX.md`,
   `TEST_CHECKLIST.md`, `automation/vinput.py` resolved as delete (content flowed to the meta
   repo first); upstream-added `test119-pointer-slots/` + `test120-dpad-dedupe/` dirs explicitly
   `git rm`'d into the replayed move commit. All four other commits replayed clean.
9. Concurrent-session absorption (this pass): meta repo gained `00a8321` (alert.yml deletion)
   from another session mid-task; adopted it and cleaned the four stale "kept for reference"
   mentions rather than resurrecting the file.
