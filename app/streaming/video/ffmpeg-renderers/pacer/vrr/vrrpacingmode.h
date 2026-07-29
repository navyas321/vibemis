#pragma once

#include "../../ivrrframepresenter.h"
#include "streaming/vrrratepolicy.h"

// The single place that decides WHICH pacing path a session builds.
//
// Two modes
// ---------
// AdaptivePaced   VRR is available. The VRR pacing worker owns presentation
//                 timing: target wait, readiness budget, its own frame queue.
//
// Fixed           VRR was not requested, or was rejected. The legacy fixed
//                 path runs and `fixedPacing` says whether it gets a V-sync
//                 source.

enum class VrrPacingMode {
    AdaptivePaced,
    Fixed,
};

inline bool vrrPacingModeHoldsAdaptivePresentation(VrrPacingMode mode)
{
    return mode != VrrPacingMode::Fixed;
}

inline const char* vrrPacingModeName(VrrPacingMode mode)
{
    switch (mode) {
    case VrrPacingMode::AdaptivePaced:
        return "adaptive paced";
    case VrrPacingMode::Fixed:
        return "fixed";
    }

    return "unknown";
}

struct VrrPacingSelection {
    VrrPacingMode mode = VrrPacingMode::Fixed;

    VrrFallbackReason fallbackReason = VrrFallbackReason::NoFallback;

    bool createWorker = false;

    bool fixedPacing = false;

    bool restoreFixedPresentationRequested = false;
    bool restoreFixedPresentationFailed = false;
};

class VrrPacingPolicy
{
public:
    static VrrPacingSelection select(bool enableVrr,
                                     bool enablePacing,
                                     bool enableVsync,
                                     int streamRateHz,
                                     int displayRefreshHz,
                                     IVrrFramePresenter* presenter)
    {
        VrrPacingSelection selection;

        selection.fixedPacing = enablePacing;

        if (!enableVrr) {
            return selection;
        }

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

        selection.mode = VrrPacingMode::AdaptivePaced;
        selection.createWorker = true;
        return selection;
    }
};
