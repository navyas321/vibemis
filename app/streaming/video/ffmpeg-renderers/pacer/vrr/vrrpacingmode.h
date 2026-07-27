#pragma once

#include "../../ivrrframepresenter.h"
#include "streaming/vrrratepolicy.h"

// BL-2529: the single place that decides WHICH pacing path a session builds.
//
// Why this exists
// ---------------
// Before BL-2529 the "Frame pacing" preference reached Pacer::initialize() as
// `enablePacing` and was then ignored on the VRR branch: VRR selected its
// pacing worker purely from `enableVrr`, and every VRR *rejection* ran
// `enablePacing = enablePacing || enableVsync`. Because VRR requires V-sync,
// that second line forced pacing back on for exactly the users who had turned
// it off. The combination a user could measure as best on their own hardware
// -- V-Sync on, frame pacing off, VRR on -- was unreachable in the app.
//
// The decision surface is small but it is genuinely three-valued, so it is
// pulled out of Pacer into a pure function with no SDL_Window, renderer, or
// FFmpeg dependency. tests/vrr/tst_vrrpacingmode.cpp drives it against
// FakeVrrFramePresenter.
//
// The three modes
// ---------------
// AdaptivePaced   VRR is available and frame pacing is on. The VRR pacing
//                 worker owns presentation timing: target wait, readiness
//                 budget, its own frame queue.
//
// AdaptiveUnpaced VRR is available and frame pacing is OFF. No worker is
//                 created. The renderer keeps the adaptive present mode and
//                 swapchain depth it already selected from
//                 DECODER_PARAMETERS::enableVrr, and Pacer's ordinary render
//                 thread drives it: submitFrame() enqueues straight onto the
//                 render queue, the render thread calls waitToRender() and
//                 renderFrame(). Nothing is left half-configured -- the
//                 adaptive swapchain has a driver, it is just not paced.
//
// Fixed           VRR was not requested, or was rejected. The legacy fixed
//                 path runs and `fixedPacing` says whether it gets a V-sync
//                 source. That value is the caller's preference, unmodified.
//
// Why AdaptiveUnpaced does not restore fixed presentation
// ------------------------------------------------------
// The Vulkan present mode is immutable for a swapchain's lifetime and is
// chosen in PlVkRenderer::initialize(), which runs BEFORE Pacer exists. Undoing
// it here (the InsufficientHeadroom branch's restoreFixedPresentation() path)
// would also drop the swapchain depth VrrSwapchainPolicy picked for this
// session -- and on Gamescope WSI that depth-2 FIFO selection is precisely
// what stopped libplacebo's swap_buffers() from serializing each preparation
// behind the previous display completion. Collapsing to legacy FIFO depth 1
// would hand a user who turned frame pacing off the throughput cliff that
// selection exists to avoid. So the presentation stays; only the pacing layer
// is removed, which is what the preference actually names.
//
// Insufficient adaptive-refresh headroom is different and still restores fixed
// presentation regardless of the pacing preference: there the adaptive mode
// itself is unsafe (immediate flips tear at near-refresh rates), not merely
// unpaced.

enum class VrrPacingMode {
    AdaptivePaced,
    AdaptiveUnpaced,
    Fixed,
};

// Whether a session in this mode HOLDS adaptive presentation, as opposed to
// whether the pacing worker runs. The two adaptive modes both keep the
// renderer's adaptive present mode and qualified refresh snapshot, so both
// need the refresh-drift guard (BL-2296/BL-2337) and neither should raise the
// VRR-fallback notice. Keying either of those on the worker instead would make
// them wrong for exactly the AdaptiveUnpaced sessions BL-2529 made reachable.
inline bool vrrPacingModeHoldsAdaptivePresentation(VrrPacingMode mode)
{
    return mode != VrrPacingMode::Fixed;
}

inline const char* vrrPacingModeName(VrrPacingMode mode)
{
    switch (mode) {
    case VrrPacingMode::AdaptivePaced:
        return "adaptive paced";
    case VrrPacingMode::AdaptiveUnpaced:
        return "adaptive unpaced";
    case VrrPacingMode::Fixed:
        return "fixed";
    }

    return "unknown";
}

struct VrrPacingSelection {
    VrrPacingMode mode = VrrPacingMode::Fixed;

    // Why VRR pacing was declined. NoFallback on the two adaptive modes.
    VrrFallbackReason fallbackReason = VrrFallbackReason::NoFallback;

    // The caller should construct and start a VrrPacingWorker.
    bool createWorker = false;

    // Whether the legacy fixed path should build a V-sync pacing source. This
    // is the caller's `enablePacing` verbatim: a VRR rejection never promotes
    // it, because a user who turned frame pacing off asked for the same
    // unpaced fixed path they would have had without ever enabling VRR.
    bool fixedPacing = false;

    // Set when the presenter was asked to abandon its adaptive presentation.
    bool restoreFixedPresentationRequested = false;
    bool restoreFixedPresentationFailed = false;
};

class VrrPacingPolicy
{
public:
    // `presenter` may be null (renderer has no VRR support). It is only
    // consulted when VRR was requested and passed the rate checks, so a
    // non-VRR session never touches the renderer here.
    static VrrPacingSelection select(bool enableVrr,
                                     bool enablePacing,
                                     bool enableVsync,
                                     int streamRateHz,
                                     int displayRefreshHz,
                                     IVrrFramePresenter* presenter)
    {
        VrrPacingSelection selection;

        // Established first and never rewritten below. Everything that follows
        // may change WHICH path runs, never whether the user wanted pacing.
        selection.fixedPacing = enablePacing;

        if (!enableVrr) {
            return selection;
        }

        // The rejection order below is load-bearing and matches the order the
        // session applies at qualification time, so the renderer, the session
        // and the pacer all agree on the reason a session was declined.
        if (!enableVsync) {
            selection.fallbackReason = VrrFallbackReason::IneffectiveVsync;
            return selection;
        }

        if (displayRefreshHz <= 0) {
            selection.fallbackReason = VrrFallbackReason::InvalidRefresh;
            return selection;
        }

        if (!VrrRatePolicy::hasAdaptiveHeadroom(streamRateHz, displayRefreshHz)) {
            selection.fallbackReason = VrrFallbackReason::InsufficientHeadroom;

            // Unlike the pacing preference, this rejects the PRESENTATION mode
            // itself, so an already-selected adaptive swapchain has to go back
            // to fixed presentation even when no worker was going to run.
            if (presenter != nullptr &&
                    presenter->checkSupport() == VrrFallbackReason::NoFallback) {
                selection.restoreFixedPresentationRequested = true;
                selection.restoreFixedPresentationFailed =
                    !presenter->restoreFixedPresentation(selection.fallbackReason);
            }
            return selection;
        }

        if (presenter == nullptr) {
            selection.fallbackReason = VrrFallbackReason::UnsupportedRenderer;
            return selection;
        }

        const VrrFallbackReason support = presenter->checkSupport();
        if (support != VrrFallbackReason::NoFallback) {
            selection.fallbackReason = support;
            return selection;
        }

        // The renderer really does have adaptive presentation for this
        // session. The frame-pacing preference is the only thing left, and it
        // decides whether a worker paces that presentation.
        if (!enablePacing) {
            selection.mode = VrrPacingMode::AdaptiveUnpaced;
            return selection;
        }

        selection.mode = VrrPacingMode::AdaptivePaced;
        selection.createWorker = true;
        return selection;
    }
};
