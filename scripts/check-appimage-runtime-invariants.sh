#!/usr/bin/env bash
# BL-2516 modern-libplacebo-in-the-AppImage regression guard.
# RCA: vibemis-agent-meta docs/engineering/claude_vrr_rca2.md.
#
# The shipped Linux artifact is the AppImage. It used to bundle the Ubuntu 22.04
# apt libplacebo 4.192 (2022), which predates VK_EXT_swapchain_maintenance1. On the
# Legion Go S under gamescope's FROG WSI layer that stale libplacebo destroys and
# recreates the swapchain on transient VK_SUBOPTIMAL_KHR — a blocking hitch that
# reads as ~1 Hz VRR judder yet leaves every submit-side pacer counter clean, so it
# was invisible for months. The fix source-builds the SAME modern haasn libplacebo
# that Nonary v6.1.0-vrr9.1.1 ships (and applies the same gamescope#2261 crash-guard
# patch), so the AppImage present path matches the known-smooth reference.
#
# This guard fails CI if that modern-libplacebo build is ever silently dropped from
# the AppImage job (e.g. by an upstream/CI merge re-adding apt libplacebo-dev to it).
# Run from the repo root.
set -u
fail=0
err() { echo "APPIMAGE-RUNTIME-INVARIANT FAIL: $1" >&2; fail=1; }

WF=".github/workflows/dev-build.yml"
PATCH="app/deploy/linux/appimage/libplacebo-disable-internally-synchronized-queues.patch"

[ -f "$WF" ] || { echo "APPIMAGE-RUNTIME-INVARIANT FAIL: $WF missing" >&2; exit 1; }

# 1. The AppImage must source-build libplacebo from haasn upstream (not apt).
grep -qF 'haasn/libplacebo.git' "$WF" \
  || err "$WF: AppImage no longer source-builds haasn/libplacebo (stale apt libplacebo would return)"

# 2. A concrete commit pin must be present (a moving ref would silently drift).
grep -Eq '2d0979fb54e025e904c7372666fffbf5dae40f66' "$WF" \
  || err "$WF: libplacebo commit pin missing/changed — re-verify it is maintenance1-aware before updating this guard"

# 3. The crash-guard patch must exist and actually disable the feature.
if [ -f "$PATCH" ]; then
  grep -qF '.internallySynchronizedQueues = false' "$PATCH" \
    || err "$PATCH: does not disable internallySynchronizedQueues (gamescope#2261 guard neutered)"
else
  err "$PATCH: gamescope#2261 crash-guard patch is missing"
fi

# 4. The AppImage build must apply that patch to the libplacebo tree.
grep -qF 'libplacebo-disable-internally-synchronized-queues.patch' "$WF" \
  || err "$WF: AppImage build does not apply the gamescope#2261 crash-guard patch"

if [ "$fail" -ne 0 ]; then
  echo "One or more BL-2516 AppImage-runtime invariants failed." >&2
  echo "See vibemis-agent-meta docs/engineering/claude_vrr_rca2.md before changing anything." >&2
  exit 1
fi
echo "All BL-2516 AppImage-runtime invariants hold."
