---
description: Create a self-verified Vibemis feature test PR (branch → commit → push → PR → checklist)
argument-hint: <testNN-slug> "<feature title>"
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
---

Ship a new feature as a numbered test PR for the Legion Go test agent. Target: `$ARGUMENTS`
(first token = `testNN-slug` branch name, rest = human feature title).

Do this in order; stop and report if any step fails:

1. **Branch.** From an up-to-date `vibemis-main`: `git checkout vibemis-main && git pull --ff-only`,
   then `git checkout -b <testNN-slug>`. Never develop on `vibemis-main` directly.
2. **Implement** the smallest correct change. For a `StreamingPreferences` setting, wire all of:
   header enum/member/`Q_PROPERTY`/NOTIFY signal, `.cpp` SER_ key + load + save, the consumer, and a
   `SettingsView.qml` control. Mirror an existing nearby feature's pattern exactly.
3. **Self-verify locally if feasible** (`qmake6 + make` clean). If a full local build is too costly,
   rely on CI compile-sanity — but you MUST then run `/verify-ci <testNN-slug>` before stacking
   anything on this branch.
4. **Instructions.** Write `testing/<testNN-slug>/instructions.md`: md5/env setup, a launcher-only
   Tier 1 (setting persists), and a Tier 2 (in-stream behaviour) marked optional/N-A if it needs a
   host the agent may not have. Reports go on `diagnostic/<testNN-slug>-report`.
5. **Commit + push.** Conventional `feat(testNN): …` message ending with the Co-Authored-By trailer.
   Push the branch — CI auto-builds its 🔬 alpha pre-release (the test agent pulls that).
6. **PR.** `gh pr create --base vibemis-main` with a body describing changes + the test plan link.
7. **Checklist.** Add the row to `testing/TEST_CHECKLIST.md` under the right phase group
   (branch · feature · PR# · base · ☐) and commit it to `vibemis-main` with `[skip ci]`.
8. **Verify CI** with `/verify-ci <testNN-slug>` and report the alpha tag once green.

Respect the CI tier rules in CLAUDE.md: only `vibemis-main` produces beta; `test**` produces alpha.
Keep features single-purpose — if it grows past one concern, split it into another testNN.
