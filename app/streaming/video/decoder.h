#pragma once

#include <Limelight.h>
#include "SDL_compat.h"
#include "settings/streamingpreferences.h"

// Vibemis (BL-2212): ClassicOldSong's moonlight-common-c fork (the Apollo
// lineage we use) doesn't export LiGetMicroseconds() like mainline does.
// The VRR pacing code (vendored from Nonary's moonlight-qt) relies on it as
// its shared monotonic pacing clock. The implementation lives in the wrapper
// static lib (moonlight-common-c/limelight_compat.c); declare it here so
// every VRR consumer (pacer, worker, plvk, ffmpeg) sees it via decoder.h.
#ifdef __cplusplus
extern "C" {
#endif
uint64_t LiGetMicroseconds(void);

// Vibemis (BL-2417): the final negotiated reference-frame-invalidation state,
// read from moonlight-common-c's internal isReferenceFrameInvalidationEnabled()
// (server SDP capability AND test-decoder capability). Returns 1 = on,
// 0 = off, -1 = not yet negotiated. Implemented in the wrapper static lib
// (moonlight-common-c/limelight_compat.c), which is the only place with access
// to Limelight-internal.h. Values match DecoderStatus::RfiState.
//
// Do NOT re-derive this from the live renderer's getDecoderCapabilities(): the
// capabilities actually sent to the host come from the throwaway test decoder
// in Session::populateDecoderProperties(), and the server half is not visible
// app-side at all. See BL-2408.
int VibemisGetRfiState(void);
#ifdef __cplusplus
}
#endif

#define SDL_CODE_FRAME_READY 0

#define MAX_SLICES 4

typedef struct _VIDEO_STATS {
    uint32_t receivedFrames;
    uint32_t decodedFrames;
    uint32_t renderedFrames;
    uint32_t totalFrames;
    uint32_t networkDroppedFrames;
    uint32_t pacerDroppedFrames;
    // VRR pacing telemetry (BL-2212, vendored from Nonary v6.1.0-vrr9.1).
    // Merged into decoder-owned windows from coherent cumulative Pacer
    // snapshots. These remain zero on non-VRR pacing paths.
    bool vrrTelemetryActive;
    uint64_t vrrPacingDroppedFrames;
    uint64_t vrrEligibleFrames;
    uint64_t vrrPrepareLateFrames;
    uint64_t vrrTargetWaitEntryLateFrames;
    uint64_t vrrPresentFailedFrames;
    uint64_t vrrPresentCancelledFrames;
    uint64_t vrrSpacingCorrections;
    uint64_t vrrPrepareLatenessP50Us;
    uint64_t vrrPrepareLatenessP95Us;
    uint64_t vrrPrepareLatenessP99Us;
    int64_t vrrSubmitErrorP50Us;
    int64_t vrrSubmitErrorP95Us;
    int64_t vrrSubmitErrorP99Us;
    int64_t vrrSubmitErrorMaxUs;
    uint64_t vrrSwapWaitP95Us;
    uint64_t vrrImageAcquireP95Us;
    uint64_t vrrRenderSubmitP95Us;
    uint64_t vrrStateSequence;
    uint64_t vrrStateSampleTimeUs;
    int64_t vrrReadinessBudgetUs;
    uint64_t vrrTimingBudgetUs;
    uint64_t vrrRenderLeadUs;
    uint64_t vrrRenderWakeLeadUs;
    uint64_t vrrTargetWakeLeadUs;
    uint64_t vrrGuardUs;
    uint64_t vrrSourcePeriodUs;
    uint16_t minHostProcessingLatency;
    uint16_t maxHostProcessingLatency;
    uint32_t totalHostProcessingLatency;
    uint32_t framesWithHostProcessingLatency;
    uint32_t totalReassemblyTime;
    uint32_t totalDecodeTime;
    uint32_t totalPacerTime;
    uint32_t totalRenderTime;
    uint32_t lastRtt;
    uint32_t lastRttVariance;
    float totalFps;
    float receivedFps;
    float decodedFps;
    float renderedFps;
    uint32_t measurementStartTimestamp;
} VIDEO_STATS, *PVIDEO_STATS;

typedef struct _DECODER_PARAMETERS {
    SDL_Window* window;
    StreamingPreferences::VideoDecoderSelection vds;

    int videoFormat;
    int width;
    int height;
    int frameRate;
    bool enableVsync;
    bool enableFramePacing;
    // VRR is an opt-in, session-snapshotted third pacing mode (BL-2212).
    bool enableVrr;
    // Strictly obtained during Session initialization. A value of zero means
    // the session was not qualified for VRR; Pacer must not substitute a
    // legacy 60 Hz fallback when this path is requested.
    int vrrDisplayRefreshHz;
    bool testOnly;
} DECODER_PARAMETERS, *PDECODER_PARAMETERS;

#define WINDOW_STATE_CHANGE_SIZE 0x01
#define WINDOW_STATE_CHANGE_DISPLAY 0x02
#define WINDOW_STATE_CHANGE_MINIMIZED 0x04
#define WINDOW_STATE_CHANGE_RESTORED 0x08
#define WINDOW_STATE_CHANGE_SUSPENDED 0x10

typedef struct _WINDOW_STATE_CHANGE_INFO {
    SDL_Window* window;
    uint32_t stateChangeFlags;

    // Populated if WINDOW_STATE_CHANGE_SIZE is set
    int width;
    int height;

    // Populated if WINDOW_STATE_CHANGE_DISPLAY is set
    int displayIndex;
} WINDOW_STATE_CHANGE_INFO, *PWINDOW_STATE_CHANGE_INFO;

class IVideoDecoder {
public:
    virtual ~IVideoDecoder() {}
    virtual bool initialize(PDECODER_PARAMETERS params) = 0;
    virtual bool isHardwareAccelerated() = 0;
    virtual bool isAlwaysFullScreen() = 0;
    virtual bool isHdrSupported() = 0;
    virtual int getDecoderCapabilities() = 0;
    virtual int getDecoderColorspace() = 0;
    virtual int getDecoderColorRange() = 0;
    virtual QSize getDecoderMaxResolution() = 0;
    virtual int submitDecodeUnit(PDECODE_UNIT du) = 0;
    virtual void renderFrameOnMainThread() = 0;
    virtual void setHdrMode(bool enabled) = 0;
    virtual bool notifyWindowChanged(PWINDOW_STATE_CHANGE_INFO info) = 0;

    // True when the decoder's Pacer is running the VRR pacing worker
    // (BL-2212).
    virtual bool isVrrActive() {
        return false;
    }

    // BL-2529: true when the session holds adaptive presentation at all --
    // worker-paced or unpaced. This, not isVrrActive(), is what Session's
    // refresh-drift guard and VRR-fallback notice consult: with frame pacing
    // off the worker never runs, but the presentation is still adaptive and
    // its qualified refresh rate can still go stale. Defaults to isVrrActive()
    // because decoders without the unpaced mode have no gap between the two.
    virtual bool isAdaptivePresentationActive() {
        return isVrrActive();
    }
};
