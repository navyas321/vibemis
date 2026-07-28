#include "pacer.h"
#include "vrrpacingworker.h"
#include "vrr/vrrpacingmode.h"
#include "../ivrrframepresenter.h"
#include "streaming/streamutils.h"
#include "streaming/vrrratepolicy.h"

#ifdef Q_OS_WIN32
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#include "dxvsyncsource.h"
#endif

#ifdef HAS_WAYLAND
#include "waylandvsyncsource.h"
#endif

#include <SDL_syswm.h>

#include <utility>

// Limit the number of queued frames to prevent excessive memory consumption
// if the V-Sync source or renderer is blocked for a while. It's important
// that the sum of all queued frames between both pacing and rendering queues
// must not exceed the number buffer pool size to avoid running the decoder
// out of available decoding surfaces.
#define MAX_QUEUED_FRAMES 3
static_assert(PACER_MAX_OUTSTANDING_FRAMES == MAX_QUEUED_FRAMES + 2,
              "PACER_MAX_OUTSTANDING_FRAMES and MAX_QUEUED_FRAMES must agree");

// We may be woken up slightly late so don't go all the way
// up to the next V-sync since we may accidentally step into
// the next V-sync period. It also takes some amount of time
// to do the render itself, so we can't render right before
// V-sync happens.
#define TIMER_SLACK_MS 3

Pacer::Pacer(IFFmpegRenderer* renderer) :
    m_RenderThread(nullptr),
    m_VsyncThread(nullptr),
    m_DeferredFreeFrame(nullptr),
    m_Stopping(false),
    m_Shutdown(false),
    m_VsyncSource(nullptr),
    m_VsyncRenderer(renderer),
    m_MaxVideoFps(0),
    m_DisplayFps(0)
{

}

Pacer::~Pacer()
{
    shutdown();
}

void Pacer::shutdown()
{
    if (m_Shutdown) {
        return;
    }
    m_Shutdown = true;

    // BL-2541: commit the buffered present-trace tail before the threads that
    // write it are torn down below.
    closePresentTrace();

    if (m_VrrWorker != nullptr) {
        // The VRR worker owns the renderer context and releases it from its
        // own thread after cancelling any prepared frame.
        m_VrrWorker.reset();
        return;
    }

    m_Stopping = true;

    // Stop the V-sync thread
    if (m_VsyncThread != nullptr) {
        m_PacingQueueNotEmpty.wakeAll();
        m_VsyncSignalled.wakeAll();
        SDL_WaitThread(m_VsyncThread, nullptr);
    }

    // Stop V-sync callbacks
    delete m_VsyncSource;
    m_VsyncSource = nullptr;

    // Stop the render thread
    if (m_RenderThread != nullptr) {
        m_RenderQueueNotEmpty.wakeAll();
        SDL_WaitThread(m_RenderThread, nullptr);
    }
    else {
        // Notify the renderer that it is being destroyed soon
        // NB: This must happen on the same thread that calls renderFrame().
        m_VsyncRenderer->cleanupRenderContext();
    }

    // Delete any remaining unconsumed frames
    while (!m_RenderQueue.isEmpty()) {
        AVFrame* frame = m_RenderQueue.dequeue();
        av_frame_free(&frame);
    }
    while (!m_PacingQueue.isEmpty()) {
        AVFrame* frame = m_PacingQueue.dequeue();
        av_frame_free(&frame);
    }
    av_frame_free(&m_DeferredFreeFrame);
}

PacerTelemetrySnapshot Pacer::telemetrySnapshot() const
{
    return m_Telemetry.snapshot();
}

void Pacer::renderOnMainThread()
{
    if (m_VrrWorker != nullptr) {
        return;
    }

    // Ignore this call for renderers that work on a dedicated render thread
    if (m_RenderThread != nullptr) {
        return;
    }

    m_FrameQueueLock.lock();

    if (!m_RenderQueue.isEmpty()) {
        AVFrame* frame = m_RenderQueue.dequeue();
        m_FrameQueueLock.unlock();

        renderFrame(frame);
    }
    else {
        m_FrameQueueLock.unlock();
    }
}

int Pacer::vsyncThread(void *context)
{
    Pacer* me = reinterpret_cast<Pacer*>(context);

#if SDL_VERSION_ATLEAST(2, 0, 9)
    SDL_SetThreadPriority(SDL_THREAD_PRIORITY_TIME_CRITICAL);
#else
    SDL_SetThreadPriority(SDL_THREAD_PRIORITY_HIGH);
#endif

    bool async = me->m_VsyncSource->isAsync();
    while (!me->m_Stopping) {
        if (async) {
            // Wait for the VSync source to invoke signalVsync() or 100ms to elapse
            me->m_FrameQueueLock.lock();
            me->m_VsyncSignalled.wait(&me->m_FrameQueueLock, 100);
            me->m_FrameQueueLock.unlock();
        }
        else {
            // Let the VSync source wait in the context of our thread
            me->m_VsyncSource->waitForVsync();
        }

        if (me->m_Stopping) {
            break;
        }

        me->handleVsync(1000 / me->m_DisplayFps);
    }

    return 0;
}

int Pacer::renderThread(void* context)
{
    Pacer* me = reinterpret_cast<Pacer*>(context);

    if (SDL_SetThreadPriority(SDL_THREAD_PRIORITY_HIGH) < 0) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "Unable to set render thread to high priority: %s",
                    SDL_GetError());
    }

    while (!me->m_Stopping) {
        // Wait for the renderer to be ready for the next frame
        me->m_VsyncRenderer->waitToRender();

        // Acquire the frame queue lock to protect the queue and
        // the not empty condition
        me->m_FrameQueueLock.lock();

        // Wait for a frame to be ready to render
        while (!me->m_Stopping && me->m_RenderQueue.isEmpty()) {
            me->m_RenderQueueNotEmpty.wait(&me->m_FrameQueueLock);
        }

        if (me->m_Stopping) {
            // Exit this thread
            me->m_FrameQueueLock.unlock();
            break;
        }

        AVFrame* frame = me->m_RenderQueue.dequeue();
        me->m_FrameQueueLock.unlock();

        me->renderFrame(frame);
    }

    // Notify the renderer that it is being destroyed soon
    // NB: This must happen on the same thread that calls renderFrame().
    me->m_VsyncRenderer->cleanupRenderContext();

    return 0;
}

void Pacer::enqueueFrameForRenderingAndUnlock(AVFrame *frame)
{
    dropFrameForEnqueue(m_RenderQueue);
    m_RenderQueue.enqueue(frame);

    m_FrameQueueLock.unlock();

    if (m_RenderThread != nullptr) {
        m_RenderQueueNotEmpty.wakeOne();
    }
    else {
        SDL_Event event;

        // For main thread rendering, we'll push an event to trigger a callback
        event.type = SDL_USEREVENT;
        event.user.code = SDL_CODE_FRAME_READY;
        SDL_PushEvent(&event);
    }
}

// Called in an arbitrary thread by the IVsyncSource on V-sync
// or an event synchronized with V-sync
void Pacer::handleVsync(int timeUntilNextVsyncMillis)
{
    // Make sure initialize() has been called
    SDL_assert(m_MaxVideoFps != 0);

    m_FrameQueueLock.lock();

    // If the queue length history entries are large, be strict
    // about dropping excess frames.
    int frameDropTarget = 1;

    // If we may get more frames per second than we can display, use
    // frame history to drop frames only if consistently above the
    // one queued frame mark.
    if (m_MaxVideoFps >= m_DisplayFps) {
        for (int queueHistoryEntry : std::as_const(m_PacingQueueHistory)) {
            if (queueHistoryEntry <= 1) {
                // Be lenient as long as the queue length
                // resolves before the end of frame history
                frameDropTarget = 3;
                break;
            }
        }

        // Keep a rolling 500 ms window of pacing queue history
        if (m_PacingQueueHistory.count() == m_DisplayFps / 2) {
            m_PacingQueueHistory.dequeue();
        }

        m_PacingQueueHistory.enqueue(m_PacingQueue.count());
    }

    // Catch up if we're several frames ahead
    while (m_PacingQueue.count() > frameDropTarget) {
        AVFrame* frame = m_PacingQueue.dequeue();

        // Drop the lock while we call av_frame_free()
        m_FrameQueueLock.unlock();
        m_Telemetry.recordLegacyDrop(LiGetMicroseconds());
        av_frame_free(&frame);
        m_FrameQueueLock.lock();
    }

    if (m_PacingQueue.isEmpty()) {
        // Wait for a frame to arrive or our V-sync timeout to expire
        if (!m_PacingQueueNotEmpty.wait(&m_FrameQueueLock, SDL_max(timeUntilNextVsyncMillis, TIMER_SLACK_MS) - TIMER_SLACK_MS)) {
            // Wait timed out - unlock and bail
            m_FrameQueueLock.unlock();
            return;
        }

        if (m_Stopping) {
            m_FrameQueueLock.unlock();
            return;
        }
    }

    // Place the first frame on the render queue
    enqueueFrameForRenderingAndUnlock(m_PacingQueue.dequeue());
}

bool Pacer::initialize(SDL_Window* window, int maxVideoFps,
                       bool enablePacing, bool enableVsync,
                       bool enableVrr, int vrrDisplayRefreshHz)
{
    m_MaxVideoFps = maxVideoFps;
    m_RendererAttributes = m_VsyncRenderer->getRendererAttributes();

    // VRR is deliberately a third pacing mode. It is selected once, before
    // any legacy V-sync source or render thread can be created, and every
    // rejection continues through the original fixed path below.
    //
    // BL-2529: the selection now consults the frame-pacing preference. See
    // vrr/vrrpacingmode.h for the three modes and why "VRR + pacing off"
    // keeps the renderer's adaptive presentation instead of undoing it.
    IVrrFramePresenter* presenter = enableVrr ?
        m_VsyncRenderer->getVrrFramePresenter() : nullptr;
    const VrrPacingSelection selection = VrrPacingPolicy::select(
        enableVrr, enablePacing, enableVsync,
        maxVideoFps, vrrDisplayRefreshHz, presenter);

    if (selection.restoreFixedPresentationFailed) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "VRR pacing lacks adaptive-refresh headroom and the presenter cannot restore fixed presentation");
        return false;
    }

    VrrFallbackReason fallbackReason = selection.fallbackReason;
    m_PacingMode = selection.mode;

    if (selection.createWorker) {
        VrrSessionConfig config;
        config.streamRateHz = maxVideoFps;
        config.displayRefreshHz = vrrDisplayRefreshHz;

        m_VrrWorker = std::make_unique<VrrPacingWorker>(
            presenter, config, &m_Telemetry);
        if (m_VrrWorker->start()) {
            m_DisplayFps = config.displayRefreshHz;
            SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                        "VRR pacing: target %d Hz with %d FPS stream",
                        m_DisplayFps, m_MaxVideoFps);
            return true;
        }

        fallbackReason = VrrFallbackReason::InitializationFailed;
        m_PacingMode = VrrPacingMode::Fixed;
        if (!presenter->restoreFixedPresentation(fallbackReason)) {
            SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                         "VRR pacing worker failed to start and the presenter cannot restore fixed presentation");
            m_VrrWorker.reset();
            return false;
        }

        m_VrrWorker.reset();
    }

    if (enableVrr) {
        if (m_PacingMode == VrrPacingMode::AdaptiveUnpaced) {
            // Not a fallback and not a downgrade: the renderer keeps the
            // adaptive present mode and swapchain depth it selected for this
            // session, and the render thread started below drives it. Only the
            // pacing layer -- target wait, readiness budget, worker queue --
            // is absent, which is what the preference names.
            SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                        "VRR pacing worker disabled by the frame-pacing preference; "
                        "the render thread drives adaptive presentation unpaced");
        }
        else {
            // Name the pacing the fallback actually gets. It used to be forced
            // on here, so "falling back to fixed V-sync pacing" was always
            // true; now it follows the preference and the log has to say which.
            SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                        "VRR pacing unavailable: %s; falling back to fixed presentation with frame pacing %s",
                        vrrFallbackReasonName(fallbackReason),
                        selection.fixedPacing ? "on" : "off");
        }
    }

    // BL-2529: this used to be `enablePacing || enableVsync` inside the VRR
    // rejection path. VRR requires V-sync, so that expression forced pacing on
    // for every VRR user regardless of their preference -- including the ones
    // who deliberately turned it off. A rejected VRR session now gets exactly
    // the fixed path a non-VRR session with the same settings would get.
    // Renderers that genuinely cannot run unpaced are still covered: the
    // decoder ORs RENDERER_ATTRIBUTE_FORCE_PACING into this argument before
    // Pacer ever sees it (see FFmpegVideoDecoder::completeInitialization).
    enablePacing = selection.fixedPacing;

    // The VRR success path uses its strict session refresh snapshot and
    // returned above. Keep the legacy fallback query out of that path so it
    // cannot invent a 60 Hz value or produce an unrelated warning.
    m_DisplayFps = StreamUtils::getDisplayRefreshRate(window);

    if (enablePacing) {
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                    "Frame pacing: target %d Hz with %d FPS stream",
                    m_DisplayFps, m_MaxVideoFps);

        SDL_SysWMinfo info;
        SDL_VERSION(&info.version);
        if (!SDL_GetWindowWMInfo(window, &info)) {
            SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                         "SDL_GetWindowWMInfo() failed: %s",
                         SDL_GetError());
            return false;
        }

        switch (info.subsystem) {
    #ifdef Q_OS_WIN32
        case SDL_SYSWM_WINDOWS:
            m_VsyncSource = new DxVsyncSource(this);
            break;
    #endif

    #if defined(SDL_VIDEO_DRIVER_WAYLAND) && defined(HAS_WAYLAND)
        case SDL_SYSWM_WAYLAND:
            m_VsyncSource = new WaylandVsyncSource(this);
            break;
    #endif

        default:
            // Platforms without a VsyncSource will just render frames
            // immediately like they used to.
            break;
        }

        SDL_assert(m_VsyncSource != nullptr || !(m_RendererAttributes & RENDERER_ATTRIBUTE_FORCE_PACING));

        if (m_VsyncSource != nullptr && !m_VsyncSource->initialize(window, m_DisplayFps)) {
            SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                        "Vsync source failed to initialize. Frame pacing will not be available!");
            delete m_VsyncSource;
            m_VsyncSource = nullptr;
        }
    }
    else {
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                    "Frame pacing disabled: target %d Hz with %d FPS stream",
                    m_DisplayFps, m_MaxVideoFps);
    }

    if (m_VsyncSource != nullptr) {
        m_VsyncThread = SDL_CreateThread(Pacer::vsyncThread, "PacerVsync", this);
    }

    // BL-2541: open the present trace once the pacing path is fully resolved,
    // so its header records which mode actually got built.
    openPresentTraceIfRequested();

    if (m_VsyncRenderer->isRenderThreadSupported()) {
        m_RenderThread = SDL_CreateThread(Pacer::renderThread, "PacerRender", this);
    }

    return true;
}

void Pacer::signalVsync()
{
    m_VsyncSignalled.wakeOne();
}

void Pacer::notifyWindowChanged(PWINDOW_STATE_CHANGE_INFO info)
{
    if (m_VrrWorker != nullptr) {
        m_VrrWorker->notifyWindowChanged(info);
        return;
    }

    // Legacy pacing has no additional window-state work. The VRR worker
    // overrides this path to discard stale work on suspension/minimize.
}

void Pacer::openPresentTraceIfRequested()
{
    // BL-2541: cadence diagnostics for the paths MOONLIGHT_VRR_TRACE cannot
    // see (unpaced adaptive, legacy V-sync, and the no-VsyncSource default).
    // One timestamp per presented frame is all the judder metrics need:
    // inter-present intervals, the repeat-beat regularity, and hitch counts.
    const char* tracePath = SDL_getenv("VIBEMIS_PRESENT_TRACE");
    if (tracePath == nullptr || tracePath[0] == '\0') {
        return;
    }

#ifdef _WIN32
    if (fopen_s(&m_PresentTraceFile, tracePath, "w") != 0) {
        m_PresentTraceFile = nullptr;
    }
#else
    m_PresentTraceFile = std::fopen(tracePath, "w");
#endif
    if (m_PresentTraceFile == nullptr) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "Unable to open VIBEMIS_PRESENT_TRACE file: %s", tracePath);
        return;
    }

    std::fprintf(m_PresentTraceFile, "present_us,pacing_mode\n");
    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "[BL-2541] present trace active (%s), pacing: %s",
                tracePath, pacingModeName());
}

void Pacer::closePresentTrace()
{
    if (m_PresentTraceFile != nullptr) {
        std::fclose(m_PresentTraceFile);
        m_PresentTraceFile = nullptr;
    }
}

void Pacer::renderFrame(AVFrame* frame)
{
    // Count time spent in Pacer's queues
    uint64_t beforeRender = LiGetMicroseconds();
    // Render it
    m_VsyncRenderer->renderFrame(frame);
    uint64_t afterRender = LiGetMicroseconds();

    // BL-2541: one line per presented frame when tracing is enabled. Buffered,
    // so this stays off the critical path; fclose() commits the tail.
    if (m_PresentTraceFile != nullptr) {
        std::fprintf(m_PresentTraceFile, "%llu,%s\n",
                     static_cast<unsigned long long>(afterRender),
                     pacingModeName());
    }

    m_Telemetry.recordLegacyFrame(
        beforeRender - static_cast<uint64_t>(frame->pkt_dts),
        afterRender - beforeRender,
        afterRender);

    // Wait until after next frame to free this one to ensure the GPU
    // doesn't stall or read garbage if the backing buffer gets returned
    // to the pool and the decoder tries to write a new frame into it
    std::swap(frame, m_DeferredFreeFrame);
    av_frame_free(&frame);

    // Drop frames if we have too many queued up for a while
    m_FrameQueueLock.lock();

    int frameDropTarget;

    if (m_RendererAttributes & RENDERER_ATTRIBUTE_NO_BUFFERING) {
        // Renderers that don't buffer any frames but don't support waitToRender() need us to buffer
        // an extra frame to ensure they don't starve while waiting to present.
        frameDropTarget = 1;
    }
    else {
        frameDropTarget = 0;
        for (int queueHistoryEntry : std::as_const(m_RenderQueueHistory)) {
            if (queueHistoryEntry == 0) {
                // Be lenient as long as the queue length
                // resolves before the end of frame history
                frameDropTarget = 2;
                break;
            }
        }

        // Keep a rolling 500 ms window of render queue history
        if (m_RenderQueueHistory.count() == m_MaxVideoFps / 2) {
            m_RenderQueueHistory.dequeue();
        }

        m_RenderQueueHistory.enqueue(m_RenderQueue.count());
    }

    // Catch up if we're several frames ahead
    while (m_RenderQueue.count() > frameDropTarget) {
        AVFrame* frame = m_RenderQueue.dequeue();

        // Drop the lock while we call av_frame_free()
        m_FrameQueueLock.unlock();
        m_Telemetry.recordLegacyDrop(LiGetMicroseconds());
        av_frame_free(&frame);
        m_FrameQueueLock.lock();
    }

    m_FrameQueueLock.unlock();
}

void Pacer::dropFrameForEnqueue(QQueue<AVFrame*>& queue)
{
    SDL_assert(queue.size() <= MAX_QUEUED_FRAMES);
    if (queue.size() == MAX_QUEUED_FRAMES) {
        AVFrame* frame = queue.dequeue();
        av_frame_free(&frame);

        // BL-2541: this drop MUST be counted. It was the only frame-discard
        // path in Pacer that freed a frame without telling telemetry, and the
        // omission is why a whole day of investigation could not see the
        // loss it causes.
        //
        // Where it bites: with no VsyncSource (every non-Wayland, non-Windows
        // platform -- including X11 under Gamescope, i.e. SteamOS Game Mode)
        // and no VRR worker, submitFrame() routes straight here. Frames then
        // arrive faster than the render thread drains them, this queue hits
        // MAX_QUEUED_FRAMES, and the oldest frame is silently freed. On device
        // (test146, host frame-gen on) the unpaced path rendered 92.03 of
        // 114.92 incoming while reporting only 4.88% pacer drops -- ~15% of
        // the stream vanished with no counter naming it, which is exactly the
        // "ghosting nothing measures" the maintainer reported.
        //
        // recordLegacyDrop() feeds pacerDroppedFrames, the same counter the
        // overlay's "Frames dropped by frame pacing" line reports, so an
        // overflowing queue is now visible instead of invisible.
        m_Telemetry.recordLegacyDrop(LiGetMicroseconds());
    }
}

void Pacer::submitFrame(AVFrame* frame)
{
    // Make sure initialize() has been called
    SDL_assert(m_MaxVideoFps != 0);

    // Queue the frame and possibly wake up the render thread
    m_FrameQueueLock.lock();
    if (m_VsyncSource != nullptr) {
        dropFrameForEnqueue(m_PacingQueue);
        m_PacingQueue.enqueue(frame);
        m_FrameQueueLock.unlock();
        m_PacingQueueNotEmpty.wakeOne();
    }
    else {
        enqueueFrameForRenderingAndUnlock(frame);
    }
}

void Pacer::submitFrame(PacedFrame&& frame)
{
    if (m_VrrWorker != nullptr) {
        m_VrrWorker->submit(std::move(frame));
        return;
    }

    submitFrame(frame.release());
}

bool Pacer::isVrrActive() const
{
    return m_VrrWorker != nullptr;
}

bool Pacer::isAdaptivePresentationActive() const
{
    // m_PacingMode is reset to Fixed on every path that restores fixed
    // presentation (including a worker start failure), so the mode alone is
    // authoritative: AdaptivePaced means the worker is pacing an adaptive
    // swapchain, AdaptiveUnpaced means the render thread is driving one.
    return vrrPacingModeHoldsAdaptivePresentation(m_PacingMode);
}

const char* Pacer::pacingModeName() const
{
    // Reported from the objects that actually exist rather than from the
    // requested configuration. On platforms with no IVsyncSource (X11) an
    // "enabled" frame-pacing preference builds no pacing at all, and the
    // overlay has to say so -- that discrepancy is exactly the kind of thing
    // this line exists to expose.
    if (m_VrrWorker != nullptr) {
        return "vrr-worker";
    }

    if (m_PacingMode == VrrPacingMode::AdaptiveUnpaced) {
        return "vrr-unpaced";
    }

    return m_VsyncSource != nullptr ? "vsync" : "none";
}
