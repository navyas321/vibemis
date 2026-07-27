#!/usr/bin/env bash
# VRR presentation-path reliability guards (BL-2517).
# Run from the repository root. This script is picked up automatically by CI.
set -u

fail=0
err() { echo "VRR-INVARIANT FAIL: $1" >&2; fail=1; }

policy_test="tests/vrr/tst_vrrswapchainpolicy.cpp"
policy_header="app/streaming/video/ffmpeg-renderers/vrrswapchainpolicy.h"
stats_source="app/streaming/video/ffmpeg.cpp"
vulkan_source="app/streaming/video/ffmpeg-renderers/plvk.cpp"
pacer_source="app/streaming/video/ffmpeg-renderers/pacer/vrrpacingworker.cpp"
# BL-2529: the frame-pacing gate on the VRR path.
pacing_mode_header="app/streaming/video/ffmpeg-renderers/pacer/vrr/vrrpacingmode.h"
pacing_mode_test="tests/vrr/tst_vrrpacingmode.cpp"
pacer_init_source="app/streaming/video/ffmpeg-renderers/pacer/pacer.cpp"
session_source="app/streaming/session.cpp"
decoder_status_header="app/streaming/video/decoderstatus.h"

for path in "$policy_test" "$policy_header" "$stats_source" \
            "$vulkan_source" "$pacer_source" "$pacing_mode_header" \
            "$pacing_mode_test" "$pacer_init_source" "$session_source" \
            "$decoder_status_header"; do
  [ -f "$path" ] || err "missing $path"
done

if [ "$fail" -eq 0 ]; then
  # A missing toolchain is not a broken invariant. CI always has g++; a
  # developer running this on a bare Windows/Git-Bash checkout does not, and
  # reporting that as an invariant failure hides the real greps below.
  if command -v g++ >/dev/null 2>&1; then
    temp_bin="${TMPDIR:-/tmp}/vibemis-vrrswapchainpolicy-$$"
    if ! g++ -std=c++17 -Iapp "$policy_test" -o "$temp_bin"; then
      err "swapchain policy regression test did not compile"
    elif ! "$temp_bin"; then
      err "swapchain policy regression test failed"
    fi
    rm -f "$temp_bin"
  else
    echo "note: g++ not found; skipping the swapchain policy compile+run check" >&2
  fi

  grep -qF 'Frames dropped by frame pacing:' "$stats_source" ||
    err "performance overlay no longer identifies local frame-pacing drops"
  if grep -qF 'Frames dropped due to network jitter:' "$stats_source"; then
    err "performance overlay mislabels local pacer drops as network jitter"
  fi
  grep -qF 'VrrSwapchainPolicy::depthForSession(' "$vulkan_source" ||
    err "Vulkan production path bypasses the tested swapchain-depth policy"
  grep -qF 'createSwapchain(swapchainDepth)' "$vulkan_source" ||
    err "Vulkan production path does not apply the selected swapchain depth"
  # The extra in-flight image is only justified for an application-facing FIFO
  # swapchain (Gamescope WSI). Mailbox/Immediate must stay at upstream depth 1.
  grep -qF 'm_VkPresentMode == VK_PRESENT_MODE_FIFO_KHR' "$vulkan_source" ||
    err "swapchain depth is no longer gated on application-facing FIFO presentation"
  grep -qF 'preparation.nativePreparationTimingValid' "$pacer_source" ||
    err "VRR worker no longer publishes native preparation-stage timing"
  grep -qF 'VRR prepare p95 swap/acquire/render:' "$stats_source" ||
    err "performance overlay no longer exposes native preparation-stage p95"

  # ---- BL-2529: the frame-pacing preference must reach the VRR path --------
  #
  # These pin a USER-FACING contract, not an implementation detail: with VRR
  # enabled, the Frame pacing switch decides whether the VRR pacing worker
  # runs. Before BL-2529 the VRR branch of Pacer::initialize() never read
  # enablePacing at all, so the switch was inert and the combination measured
  # as best on real hardware (V-Sync on, frame pacing off, VRR on) could not be
  # selected. If a future change needs to relax one of these, say so out loud —
  # silently dropping one restores an unreachable setting.
  grep -qF 'VrrPacingPolicy::select(' "$pacer_init_source" ||
    err "Pacer no longer routes the VRR decision through the tested pacing-mode policy"
  grep -qF 'enablePacing' "$pacing_mode_header" ||
    err "the VRR pacing-mode policy no longer consults the frame-pacing preference"

  # The override that made "off" unreachable. VRR requires V-sync, so
  # `enablePacing || enableVsync` on the VRR path is unconditionally true.
  if grep -qE 'enablePacing[[:space:]]*=[[:space:]]*enablePacing[[:space:]]*\|\|' "$pacer_init_source"; then
    err "Pacer promotes an explicitly disabled frame-pacing preference again"
  fi
  # Same override at the session boundary: pacing forced on because a VRR
  # request was rejected.
  if grep -qE 'enableFramePacing[[:space:]]*=[[:space:]]*true' "$session_source"; then
    err "Session forces frame pacing on when a VRR request is rejected again"
  fi

  # ---- BL-2529: overlay diagnostics ---------------------------------------
  #
  # Whether the VRR worker is running and which present mode the swapchain got
  # are decided once at decoder creation. Nothing displayed either, which is
  # how an inert pacing preference survived. Screen width is the constraint
  # here, so the driver string must stay off the decoder line: it is what
  # pushed the RFI verdict off the right edge of a handheld display.
  grep -qF 'formatPacingLine(' "$stats_source" ||
    err "performance overlay no longer reports the pacing mode and present mode"
  grep -qF 'getPresentationModeName' app/streaming/video/ffmpeg-renderers/plvk.h ||
    err "the Vulkan renderer no longer exposes its selected present mode to the overlay"
  grep -qF 'Decoder: %.*s%s via %.*s; RFI: %s' "$decoder_status_header" ||
    err "the overlay decoder line no longer keeps the driver string off it"
fi

if [ "$fail" -ne 0 ]; then
  echo "One or more VRR invariants failed." >&2
  exit 1
fi

echo "All VRR invariants hold."
