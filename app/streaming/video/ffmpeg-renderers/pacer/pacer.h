#pragma once

#include "../../decoder.h"
#include "../renderer.h"
#include "pacertelemetry.h"
#include "vrr/vrrpacingmode.h"
#include "vrr/vrrtypes.h"

#include <QQueue>
#include <QMutex>
#include <QWaitCondition>

#include <atomic>
#include <memory>

class VrrPacingWorker;

// The maximum number of frames pacer will ever hold is:
// - 3 frames in the pacing queue
// - 1 frame removed from the render queue in the process of rendering
// - 1 frame for deferred free
#define PACER_MAX_OUTSTANDING_FRAMES (3 + 1 + 1)

class IVsyncSource {
public:
    virtual ~IVsyncSource() {}
    virtual bool initialize(SDL_Window* window, int displayFps) = 0;

    // Asynchronous sources produce callbacks on their own, while synchronous
    // sources require calls to waitForVsync().
    virtual bool isAsync() = 0;

    virtual void waitForVsync() {
        // Synchronous sources must implement waitForVsync()!
        SDL_assert(false);
    }
};

class Pacer
{
public:
    Pacer(IFFmpegRenderer* renderer);

    ~Pacer();

    // Stop all producer threads before a final telemetry snapshot is merged
    // by the decoder. It is safe to call this more than once.
    void shutdown();

    PacerTelemetrySnapshot telemetrySnapshot() const;

    // Only the active VRR worker consumes the decoder-facing pacing metadata.
    void submitFrame(PacedFrame&& frame);

    void submitFrame(AVFrame* frame);

    bool isVrrActive() const;

    // BL-2529: true when this session holds ADAPTIVE PRESENTATION -- the VRR
    // worker pacing it, or the render thread driving it unpaced. Distinct from
    // isVrrActive(), which reports only the worker: the refresh-drift guard
    // and the session's fallback notice care about the presentation, and
    // keying them on the worker made both wrong for unpaced VRR sessions.
    bool isAdaptivePresentationActive() const;

    // BL-2541: present-timestamp trace for the NON-worker paths.
    //
    // MOONLIGHT_VRR_TRACE is opened by VrrPacingWorker, so only worker
    // sessions could ever be measured for cadence. That made the unpaced and
    // VRR-off paths -- including the default on every platform without a
    // VsyncSource -- structurally unmeasurable for judder, which is the one
    // property that decides whether a viewer sees ghosting. VIBEMIS_PRESENT_TRACE
    // writes one microsecond timestamp per presented frame from
    // Pacer::renderFrame(), which every non-worker path funnels through.
    // Diagnostic only, flag-gated, no effect when unset.
    void openPresentTraceIfRequested();
    void closePresentTrace();

    // BL-2529: terse, screen-sized name of the pacing path this session
    // actually built, for the performance overlay. Resolved after
    // initialize(); "none" before it runs.
    //
    //   "vrr-worker"  the VRR pacing worker owns presentation timing
    //   "vrr-unpaced" adaptive presentation retained, no pacing layer
    //   "vsync"       legacy V-sync source is pacing the render queue
    //   "none"        frames go straight to the renderer as they decode
    const char* pacingModeName() const;

    // BL-2546: cumulative pipeline-stage tick marks for the sampler below.
    // The decoder calls these from its thread; they are lock-free.
    void noteFrameReceived();
    void noteFrameDecoded();

    bool initialize(SDL_Window* window, int maxVideoFps,
                    bool enablePacing, bool enableVsync,
                    bool enableVrr, int vrrDisplayRefreshHz);

    void notifyWindowChanged(PWINDOW_STATE_CHANGE_INFO info);

    void signalVsync();

    void renderOnMainThread();

private:
    static int vsyncThread(void* context);

    static int renderThread(void* context);

    void handleVsync(int timeUntilNextVsyncMillis);

    void enqueueFrameForRenderingAndUnlock(AVFrame* frame);

    void renderFrame(AVFrame* frame);

    void dropFrameForEnqueue(QQueue<AVFrame*>& queue);

    // BL-2546: flag-gated ~1s pipeline sampler, active on EVERY pacing path.
    //
    // A mid-session stall could not previously be attributed: incoming,
    // decode, and render rates exist only as end-of-session aggregates, and
    // both trace facilities record per-frame events -- which go silent
    // exactly when the pipeline does. This sampler runs on its own thread,
    // so during a total stall it keeps emitting "+0" deltas per stage, and
    // the first stage whose delta is zero names the culprit: recv +0 means
    // frames stopped arriving (host/network), recv >0 dec +0 means decode,
    // dec >0 pres +0 with a standing queue means presentation.
    //
    // Gated on VIBEMIS_PIPELINE_SAMPLER; one SDL_LogInfo line per second.
    // Diagnostic only, no effect when unset.
    void startPipelineSamplerIfRequested();
    void stopPipelineSampler();
    size_t pipelineQueueDepth();
    static int samplerThread(void* context);
    void runPipelineSampler();

    QQueue<AVFrame*> m_RenderQueue;
    QQueue<AVFrame*> m_PacingQueue;
    QQueue<int> m_PacingQueueHistory;
    QQueue<int> m_RenderQueueHistory;
    QMutex m_FrameQueueLock;
    QWaitCondition m_RenderQueueNotEmpty;
    QWaitCondition m_PacingQueueNotEmpty;
    QWaitCondition m_VsyncSignalled;
    SDL_Thread* m_RenderThread;
    SDL_Thread* m_VsyncThread;
    AVFrame* m_DeferredFreeFrame;
    bool m_Stopping;
    bool m_Shutdown;

    IVsyncSource* m_VsyncSource;
    IFFmpegRenderer* m_VsyncRenderer;
    int m_MaxVideoFps;
    int m_DisplayFps;
    int m_RendererAttributes;
    PacerTelemetry m_Telemetry;
    VrrPacingMode m_PacingMode = VrrPacingMode::Fixed;
    std::unique_ptr<VrrPacingWorker> m_VrrWorker;

    // BL-2541: see openPresentTraceIfRequested(). Written only from the render
    // thread inside renderFrame(); null unless VIBEMIS_PRESENT_TRACE is set.
    std::FILE* m_PresentTraceFile = nullptr;

    // BL-2546: see startPipelineSamplerIfRequested(). The counters are
    // cumulative for the whole session; the sampler thread computes deltas.
    std::atomic<uint64_t> m_ReceivedFrameTicks { 0 };
    std::atomic<uint64_t> m_DecodedFrameTicks { 0 };
    SDL_Thread* m_SamplerThread = nullptr;
    std::atomic_bool m_SamplerStopping { false };
};
