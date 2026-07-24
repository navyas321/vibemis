#!/usr/bin/env bash
# VRR presentation-path reliability guards (BL-2517).
# Run from the repository root. This script is picked up automatically by CI.
set -u

fail=0
err() { echo "VRR-INVARIANT FAIL: $1" >&2; fail=1; }

policy_test="app/test_vrrswapchainpolicy.cpp"
policy_header="app/streaming/video/ffmpeg-renderers/vrrswapchainpolicy.h"
stats_source="app/streaming/video/ffmpeg.cpp"
vulkan_source="app/streaming/video/ffmpeg-renderers/plvk.cpp"
pacer_source="app/streaming/video/ffmpeg-renderers/pacer/vrrpacingworker.cpp"

for path in "$policy_test" "$policy_header" "$stats_source" \
            "$vulkan_source" "$pacer_source"; do
  [ -f "$path" ] || err "missing $path"
done

if [ "$fail" -eq 0 ]; then
  temp_bin="${TMPDIR:-/tmp}/vibemis-vrrswapchainpolicy-$$"
  if ! g++ -std=c++17 -Iapp "$policy_test" -o "$temp_bin"; then
    err "swapchain policy regression test did not compile"
  elif ! "$temp_bin"; then
    err "swapchain policy regression test failed"
  fi
  rm -f "$temp_bin"

  grep -qF 'Frames dropped by frame pacing:' "$stats_source" ||
    err "performance overlay no longer identifies local frame-pacing drops"
  if grep -qF 'Frames dropped due to network jitter:' "$stats_source"; then
    err "performance overlay mislabels local pacer drops as network jitter"
  fi
  grep -qF 'VrrSwapchainPolicy::depthForSession(' "$vulkan_source" ||
    err "Vulkan production path bypasses the tested swapchain-depth policy"
  grep -qF 'createSwapchain(swapchainDepth)' "$vulkan_source" ||
    err "Vulkan production path does not apply the selected swapchain depth"
  grep -qF 'preparation.nativePreparationTimingValid' "$pacer_source" ||
    err "VRR worker no longer publishes native preparation-stage timing"
  grep -qF 'VRR prepare p95 swap/acquire/render:' "$stats_source" ||
    err "performance overlay no longer exposes native preparation-stage p95"
fi

if [ "$fail" -ne 0 ]; then
  echo "One or more VRR invariants failed." >&2
  exit 1
fi

echo "All VRR invariants hold."
