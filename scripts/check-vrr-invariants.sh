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

  # ---- VRR pacing path routing ---------------------------------------------
  #
  # RATIFICATION (2026-07-29, maintainer directive "no divergences at all"):
  # BL-2529's three-mode pacing gate (AdaptivePaced/AdaptiveUnpaced/Fixed) was
  # deliberately replaced with Nonary's two-mode model (AdaptivePaced/Fixed).
  # VRR always creates the worker when active, matching upstream. The Frame
  # pacing switch is inert under VRR — the worker runs regardless.
  #
  # BL-2529's original motivation (hardware-measured best combo on Legion Go:
  # V-Sync on, frame pacing off, VRR on) is superseded by the Nonary alignment,
  # which prevents the ~20% throughput loss via dropFrameForEnqueue() that the
  # unpaced path caused. If this trade-off needs revisiting, the decision record
  # is in DAILY-WORK-REVIEW-2026-07-29.md (vibemis-agent-meta).
  grep -qF 'VrrPacingPolicy::select(' "$pacer_init_source" ||
    err "Pacer no longer routes the VRR decision through the tested pacing-mode policy"
  grep -qF 'isAdaptivePresentationActive()' "$session_source" ||
    err "Session no longer consults adaptive-presentation state"

  # ---- BL-2531/BL-2522: pre-wait stale-queue skip -------------------------
  #
  # A queued frame older than one source interval with a fresher successor is
  # stale content and must be skipped BEFORE the render wait, recovering with
  # noteSubmission(false, false, 0) -- never rebase() -- so the successor keeps
  # the learned cadence (Nonary 3bf0dfca hunk 2; regression test
  # testQueuedStaleFrameYieldsToFreshSuccessor). Removing it re-paints stale
  # frames on fast pans, which the device shows as ghosting.
  grep -qF 'scheduleAgeUs > decision.sourcePeriodUs && hasQueuedFrame()' "$pacer_source" ||
    err "the pre-wait stale-queue skip is gone from the VRR worker"
  if ! grep -A6 'scheduleAgeUs > decision.sourcePeriodUs' "$pacer_source" | grep -qF 'noteSubmission(false, false, 0)'; then
    err "the pre-wait stale skip no longer recovers with noteSubmission(false,false,0) (cadence-preserving, no re-anchor)"
  fi

  # ---- BL-2541: every frame discard must be counted -----------------------
  #
  # dropFrameForEnqueue() freed frames with no telemetry call. It is the path
  # taken whenever there is no VsyncSource and no VRR worker -- i.e. the
  # DEFAULT on X11/Gamescope (SteamOS Game Mode) with frame pacing off -- so
  # ~15% of the stream could vanish while the overlay reported ~5% drops. An
  # uncounted discard is worse than a bug: it hides bugs. If a new discard
  # path appears, it counts, or this guard fails.
  # Comment lines are stripped first: the function documents WHY it records,
  # and a guard that its own explanation satisfies proves nothing (this guard
  # failed exactly that way on first write).
  if ! sed -n '/void Pacer::dropFrameForEnqueue/,/^}/p' "$pacer_init_source" | grep -v '^[[:space:]]*//' | grep -qF 'recordLegacyDrop'; then
    err "Pacer::dropFrameForEnqueue drops frames without recording them (invisible loss)"
  fi

  # ---- BL-2531: Gamescope VRR prefers Mailbox -----------------------------
  #
  # The device A/B (test146, host frame-generation off) measured Mailbox at
  # 0.22% paced-drop vs stock FIFO's 2.03% on the Gamescope WSI path (+2.2%
  # of source frames recovered); the VRR-off legacy path already ran Mailbox
  # on the same surface. The VRR branch must try Mailbox first and keep FIFO
  # only as the unsupported-Mailbox fallback.
  if ! grep -B6 'Gamescope WSI: using Mailbox presentation' "$vulkan_source" | grep -qF 'm_VkPresentMode = VK_PRESENT_MODE_MAILBOX_KHR'; then
    err "the Gamescope VRR branch no longer prefers Mailbox (re-introduces the FIFO rendered-FPS cost)"
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

  # ---- BL-2546: the pipeline sampler must cover EVERY pacing path ---------
  #
  # A mid-session stall could not be attributed client-vs-host (a finding had
  # to be withdrawn over exactly this), so the sampler emits per-second deltas
  # for every pipeline stage from its own thread. These guards pin the parts
  # that die silently: the worker path's early return in initialize() (losing
  # it makes vrr-worker sessions -- the ones under investigation -- the only
  # unsampled mode), the decoder-side stage ticks, the shutdown-before-
  # teardown ordering, and the five per-line signals. All greps strip //
  # comments first; a guard a comment can satisfy proves nothing.
  sampler_calls=$(grep -v '^[[:space:]]*//' "$pacer_init_source" |
    grep -cF 'startPipelineSamplerIfRequested();')
  if [ "${sampler_calls:-0}" -lt 2 ]; then
    err "the pipeline sampler no longer starts on both Pacer::initialize() paths (worker early-return + legacy)"
  fi
  grep -v '^[[:space:]]*//' app/streaming/video/ffmpeg.cpp |
    grep -qF 'noteFrameReceived();' ||
    err "the decoder no longer ticks frame arrivals for the pipeline sampler"
  grep -v '^[[:space:]]*//' app/streaming/video/ffmpeg.cpp |
    grep -qF 'noteFrameDecoded();' ||
    err "the decoder no longer ticks decodes for the pipeline sampler"
  if ! sed -n '/m_Shutdown = true;/,/m_Stopping = true;/p' "$pacer_init_source" | grep -v '^[[:space:]]*//' | grep -qF 'stopPipelineSampler();'; then
    err "Pacer::shutdown no longer stops the sampler before tearing down what it reads"
  fi
  if ! grep -v '^[[:space:]]*//' "$pacer_init_source" | grep -qF 'recv +%llu dec +%llu pres +%llu'; then
    err "the sampler line lost its per-stage deltas (stall attribution needs recv/dec/pres together)"
  fi
  if ! grep -v '^[[:space:]]*//' "$pacer_init_source" | grep -qF 'queue %llu'; then
    err "the sampler line no longer reports render-queue depth"
  fi

  # ---- BL-2543: the queue-delay statistic must be un-poisonable -----------
  #
  # The legacy path printed 40838.61 ms / 16175.61 ms on identically
  # configured arms: an unguarded (beforeRender - pkt_dts) wraps a uint64 by
  # ~1.8e19 us on one bad stamp and the narrowing ms cast scrambles it into a
  # stable-looking number. Queue delay is the statistic that cracked BL-2541;
  # a garbage value there misdirects the next investigation. The source must
  # validate the stamp, and the report must divide by the delay-sample count
  # -- never by renderedFrames, which includes sampleless frames.
  if ! grep -v '^[[:space:]]*//' "$pacer_init_source" | grep -qF 'pacerTimeValid'; then
    err "Pacer::renderFrame feeds the queue-delay accumulator without validating the decode stamp"
  fi
  if ! grep -v '^[[:space:]]*//' "$stats_source" | grep -qF 'stats.pacerTimeSampledFrames != 0'; then
    err "the queue-delay report is no longer gated on having any delay samples"
  fi
  if grep -v '^[[:space:]]*//' "$stats_source" | grep -qF 'stats.totalPacerTime / stats.renderedFrames'; then
    err "the queue-delay average divides by renderedFrames again (includes sampleless frames)"
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo "One or more VRR invariants failed." >&2
  exit 1
fi

echo "All VRR invariants hold."
