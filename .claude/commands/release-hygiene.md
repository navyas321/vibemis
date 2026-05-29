---
description: Audit the GitHub Releases page for noise and confirm the auto-prune policy is holding
allowed-tools: Bash
---

Check that the Releases list is tidy and the workflow's prune policy is working.

Expected steady state:
- **Exactly one** 🧪 Beta, marked **Latest** (the newest `vibemis-main` build).
- **At most one** 🔬 Alpha **per active `test**` branch** (each new push to a test branch replaces
  its own alpha; other branches' alphas are untouched).
- Production ✅ Release tags are never pruned.

Steps:
1. `gh release list --limit 40` — eyeball tiers.
2. Count by prerelease flag:
   `gh release list --limit 200 --json isPrerelease --jq 'group_by(.isPrerelease)[] | "prerelease=\(.[0].isPrerelease): \(length)"'`
3. **Betas must be 1.** If more than one beta exists, the prune step didn't fire (older workflow, or
   a manual release). Delete all but the newest:
   `NEWEST=$(gh release list --limit 200 --json tagName,createdAt --jq '[.[]|select(.tagName|test("-beta\\."))]|sort_by(.createdAt)|last|.tagName')`
   then delete every other `-beta.` tag with `gh release delete <tag> --yes --cleanup-tag`.
4. Drop any stray `-dev.`/`-hotfix.` prereleases (those branches shouldn't build at all now).
5. Confirm the prune step still exists in `.github/workflows/dev-build.yml` (`Prune superseded releases`).

Report the final release list and whether the policy is holding.
