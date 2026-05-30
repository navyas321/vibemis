#!/usr/bin/env bash
# Vibemis test-agent helper (run ON the Legion Go S Z2, SteamOS).
# Fetches the AppImage for a test branch, verifies it, and runs the headless smoke checks so you
# can start a cycle with one command. It does NOT pair or stream — that stays manual per the
# branch's instructions.md. See docs/TEST_AUTOMATION.md and docs/personas/test-agent.md.
#
#   Usage:  ./testing/run-cycle.sh <test-branch-slug>
#   e.g.    ./testing/run-cycle.sh test52-selftest-cli
#           ./testing/run-cycle.sh test22-quickmenu-overlay
#
# Prereqs: run `git fetch origin` first; `gh` authenticated (for alpha downloads).
set -u
SLUG="${1:?usage: run-cycle.sh <test-branch-slug>   (e.g. test52-selftest-cli)}"
OUT="${HOME}/Downloads"; mkdir -p "$OUT"
APP=""

# gh is often installed at ~/.local/bin and not on PATH in non-interactive shells (SteamOS).
# Resolve it explicitly so alpha auto-fetch works. (Reported by the test agent, test52 cycle.)
export PATH="$HOME/.local/bin:$PATH"
GH="$(command -v gh 2>/dev/null || echo "$HOME/.local/bin/gh")"

echo "### Vibemis cycle helper for: $SLUG"

# 1) Prefer a committed AppImage on the branch (older cycles ship one in testing/<slug>/).
COMMITTED=$(git ls-tree -r --name-only "origin/${SLUG}" 2>/dev/null \
            | grep -iE "testing/${SLUG}/.*\.AppImage$" | head -1)
if [ -n "$COMMITTED" ]; then
  echo "Found committed AppImage: $COMMITTED"
  git show "origin/${SLUG}:${COMMITTED}" > "$OUT/Vibemis-${SLUG}.AppImage" 2>/dev/null \
    && APP="$OUT/Vibemis-${SLUG}.AppImage"
fi

# 2) Otherwise download the branch's alpha pre-release (newer cycles auto-publish one).
if [ -z "$APP" ]; then
  TAG=$("$GH" release list --limit 100 --json tagName --jq '.[].tagName' 2>/dev/null \
        | grep "alpha\.${SLUG}\." | head -1)
  if [ -n "$TAG" ]; then
    echo "Downloading alpha release: $TAG"
    "$GH" release download "$TAG" --dir "$OUT" --pattern '*.AppImage' --clobber \
      && APP=$(ls -t "$OUT"/*.AppImage 2>/dev/null | head -1)
  fi
fi

if [ -z "$APP" ] || [ ! -f "$APP" ]; then
  echo "ERROR: no AppImage for '$SLUG' (no committed artifact and no alpha release)."
  echo "       Check the branch name, or ask the build agent to push so CI publishes an alpha."
  exit 1
fi

chmod +x "$APP"
echo "=== artifact ==="
echo "AppImage: $APP"
md5sum "$APP"

echo "=== environment ==="
grep VERSION= /etc/os-release 2>/dev/null
(glxinfo 2>/dev/null | grep -i "OpenGL version") || true

# Headless smoke test (only meaningful once test52/test54 are in the build under test).
echo "=== selftest --json (needs test52+; 'Invalid action' just means this build predates it) ==="
"$APP" selftest --json; echo "selftest exit=$?"

echo "=== bounded 18s launch log -> /tmp/vibemis-${SLUG}.log ==="
timeout 22s "$APP" > "/tmp/vibemis-${SLUG}.log" 2>&1 &
PID=$!; sleep 18; kill "$PID" 2>/dev/null; wait "$PID" 2>/dev/null
grep -iE "EGLRenderer|renderer|error|SEGV|critical|overlay" "/tmp/vibemis-${SLUG}.log" | head -20

echo
echo "### Next: open testing/${SLUG}/instructions.md and run its tiers (pair/stream only if it says to)."
echo "### Full launch log: /tmp/vibemis-${SLUG}.log"
