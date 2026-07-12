---
description: Watch a branch's latest CI run to completion and report pass/fail + the published artifact
argument-hint: <branch-name>
allowed-tools: Bash
---

Verify the GitHub Actions build for branch `$ARGUMENTS` and report the outcome. This gates stacking:
do NOT build a new test branch on top of one whose CI hasn't gone green.

Steps:
1. Resolve the latest run id:
   `RID=$(gh run list --branch "$ARGUMENTS" --limit 1 --json databaseId --jq '.[0].databaseId')`
2. Watch it to completion (run in the background so the turn isn't blocked):
   `gh run watch "$RID" --exit-status --interval 30`
   Note: `gh run watch` occasionally exits non-zero on a transient error while the run is still
   `in_progress`. If that happens, re-check with `gh run view "$RID" --json status,conclusion` and
   re-attach the watcher rather than trusting the early exit.
3. On `conclusion=success`: confirm the artifact published —
   `gh release list --limit 12 --json tagName --jq '.[].tagName | select(test("'"$ARGUMENTS"'"))'`
   (a `test**` branch should yield a 🔬 alpha pre-release tag).
4. On failure: open the failing job's log (`gh run view "$RID" --log-failed`), summarise the first
   real compile error (file:line), and fix it on the branch before re-pushing.

Report: status/conclusion, the alpha tag (if any), and whether it's safe to proceed.
