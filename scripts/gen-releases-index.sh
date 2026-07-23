#!/usr/bin/env bash
# generate RELEASES.md — the CHRONOLOGICAL build timeline (newest first).
# GitHub's own Releases/Tags pages sort by SemVer PRECEDENCE (alpha < beta < rc < stable
# for the same base version, spec §11), which is spec-correct but buries the newest
# alpha below every beta. This index is the date-ordered view for humans.
# Usage: scripts/gen-releases-index.sh [owner/repo] > RELEASES.md   (needs gh auth)
set -euo pipefail
REPO="${1:-navyas321/vibemis}"

channel() {
  case "$1" in
    *-alpha.*) echo "🔬 Alpha" ;;
    *-beta.*)  echo "🧪 Beta" ;;
    *-rc.*)    echo "🎯 RC" ;;
    *-dev.*)   echo "🔧 Dev" ;;
    *)         echo "✅ Stable" ;;
  esac
}

echo "# Vibemis build timeline"
echo
echo "**Newest build first, by publish date** — the chronological view GitHub's Releases page"
echo "can't show (it sorts by SemVer precedence, so alphas always sink below betas of the same"
echo "version; see the README's Downloads section)."
echo
echo "Regenerated in full and force-pushed to this \`releases-index\` branch on every release"
echo "cut. **Do not edit by hand** — the next cut overwrites it. It lives on a branch rather"
echo "than on \`vibemis-main\` because that branch is protected and the release job runs as"
echo "\`github-actions[bot]\`; the bot-PR workaround could never satisfy branch protection"
echo "(GitHub does not attribute \`workflow_dispatch\` check runs to a \`GITHUB_TOKEN\` PR), so it"
echo "left an unmergeable PR after every cut. See \`RELEASES.md\` on \`vibemis-main\`."
echo
echo "| Published (UTC) | Build | Channel | Artifact |"
echo "|---|---|---|---|"

gh api "repos/$REPO/releases?per_page=100" --paginate \
  --jq '.[] | [.published_at, .tag_name, (if (.assets|length) > 0 then "yes" else "marker" end)] | @tsv' \
  | sort -r \
  | while IFS=$'\t' read -r at tag has_asset; do
      ch="$(channel "$tag")"
      if [ "$has_asset" = "yes" ]; then
        art="[AppImage](https://github.com/$REPO/releases/tag/$tag)"
      else
        art="history marker"
      fi
      echo "| ${at/T/ } | [\`$tag\`](https://github.com/$REPO/releases/tag/$tag) | $ch | $art |"
    done
