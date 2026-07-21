#pragma once

#include <QAtomicInt>
#include <QSemaphore>
#include <QWindow>

#include <Limelight.h>
#include <opus_multistream.h>
#include "settings/streamingpreferences.h"
#include "input/input.h"
#include "video/decoder.h"
#include "audio/renderers/renderer.h"
#include "video/overlaymanager.h"

#include "backend/quickmenumanager.h"
#include "backend/servercommandmanager.h"
#include "backend/clipboardmanager.h"

class QuickMenuManager;
class ServerCommandManager;
class ClipboardManager;

class SupportedVideoFormatList : public QList<int>
{
public:
    operator int() const
    {
        int value = 0;

        for (const int & v : *this) {
            value |= v;
        }

        return value;
    }

    void
    removeByMask(int mask)
    {
        int i = 0;
        while (i < this->length()) {
            if (this->value(i) & mask) {
                this->removeAt(i);
            }
            else {
                i++;
            }
        }
    }

    void
    deprioritizeByMask(int mask)
    {
        QList<int> deprioritizedList;

        int i = 0;
        while (i < this->length()) {
            if (this->value(i) & mask) {
                deprioritizedList.append(this->takeAt(i));
            }
            else {
                i++;
            }
        }

        this->append(std::move(deprioritizedList));
    }

    int maskByServerCodecModes(int serverCodecModes)
    {
        int mask = 0;

        const QMap<int, int> mapping = {
            {SCM_H264, VIDEO_FORMAT_H264},
            {SCM_H264_HIGH8_444, VIDEO_FORMAT_H264_HIGH8_444},
            {SCM_HEVC, VIDEO_FORMAT_H265},
            {SCM_HEVC_MAIN10, VIDEO_FORMAT_H265_MAIN10},
            {SCM_HEVC_REXT8_444, VIDEO_FORMAT_H265_REXT8_444},
            {SCM_HEVC_REXT10_444, VIDEO_FORMAT_H265_REXT10_444},
            {SCM_AV1_MAIN8, VIDEO_FORMAT_AV1_MAIN8},
            {SCM_AV1_MAIN10, VIDEO_FORMAT_AV1_MAIN10},
            {SCM_AV1_HIGH8_444, VIDEO_FORMAT_AV1_HIGH8_444},
            {SCM_AV1_HIGH10_444, VIDEO_FORMAT_AV1_HIGH10_444},
        };

        for (QMap<int, int>::const_iterator it = mapping.cbegin(); it != mapping.cend(); ++it) {
            if (serverCodecModes & it.key()) {
                mask |= it.value();
                serverCodecModes &= ~it.key();
            }
        }

        // Make sure nobody forgets to update this for new SCM values
        SDL_assert(serverCodecModes == 0);

        int val = *this;
        return val & mask;
    }
};

class Session : public QObject
{
    Q_OBJECT

    friend class SdlInputHandler;
    friend class DeferredSessionCleanupTask;
    friend class AsyncConnectionStartThread;
    friend class ExecThread;

public:
    explicit Session(NvComputer* computer, NvApp& app, StreamingPreferences *preferences = nullptr);

    // NB: This may not get destroyed for a long time! Don't put any cleanup here.
    // Use Session::exec() or DeferredSessionCleanupTask instead.
    virtual ~Session() {
        if (m_QuickMenuManager) {
            delete m_QuickMenuManager;
            m_QuickMenuManager = nullptr;
        }
        if (m_ServerCommandManager) {
            delete m_ServerCommandManager;
            m_ServerCommandManager = nullptr;
        }
        if (m_ClipboardManager) {
            // m_ClipboardManager is the ClipboardManager::instance()
            // SINGLETON, also owned by the QML engine (main.cpp registers it via
            // ClipboardManager::create). Deleting it here left QML holding a dangling
            // pointer (crash on the next Settings open) and caused a double-delete at
            // shutdown. Just drop our connection state; never delete the singleton.
            m_ClipboardManager->disconnect();
            m_ClipboardManager = nullptr;
        }
    };

    Q_INVOKABLE void exec(QWindow* qtWindow);

    // True when the stream was cut unexpectedly (connection loss),
    // as opposed to a user-initiated quit — used by the auto-reconnect logic in QML.
    Q_INVOKABLE bool wasUnexpectedTermination() const { return m_UnexpectedTermination; }

    // BL-2265: true when THIS session ended because the catastrophic
    // bitrate-collapse rescue tore it down to reconnect at a lower bitrate.
    // The reconnect session picks the stepped-down bitrate up via the
    // one-shot s_PendingRescueBitrateKbps override in initialize().
    Q_INVOKABLE bool wasBitrateRescue() const { return m_RescueToKbps > 0; }
    Q_INVOKABLE int rescueFromKbps() const { return m_RescueFromKbps; }
    Q_INVOKABLE int rescueToKbps() const { return m_RescueToKbps; }

    // BL-2265 (test140 v2): the one-shot pending-rescue consume, factored to
    // a static seam so the selftest can prove the trigger->pending->consume
    // chain offscreen with no host or stream. Returns the bitrate the next
    // session must run at; clears the pending override (one-shot); never
    // raises above configuredKbps.
    static int consumePendingRescueKbps(int configuredKbps);

    // Test-only (selftest): stage a pending rescue as if a session had
    // triggered one. Never called from production flows.
    static void stagePendingRescueKbpsForTest(int kbps) { s_PendingRescueBitrateKbps.storeRelease(kbps); }

    // A fresh Session for the same host+app (per-game profiles and
    // preferences re-apply automatically). QML takes ownership of the returned object.
    Q_INVOKABLE Session* createResumeSession() { return new Session(m_Computer, m_App); }

    static
    void getDecoderInfo(SDL_Window* window,
                        bool& isHardwareAccelerated, bool& isFullScreenOnly,
                        bool& isHdrSupported, QSize& maxResolution);

    static Session* get()
    {
        return s_ActiveSession;
    }

    Overlay::OverlayManager& getOverlayManager()
    {
        return m_OverlayManager;
    }

    QuickMenuManager* getQuickMenuManager()
    {
        return m_QuickMenuManager;
    }

    void flushWindowEvents();

    void setShouldExitAfterQuit();

    // Vibemis: quit the RUNNING APP on the host when this session ends, but keep
    // Vibemis itself open (back to the grid) — a one-shot session-scoped quitAppAfter.
    void setShouldQuitAppAfter();

signals:
    void stageStarting(QString stage);

    void stageFailed(QString stage, int errorCode, QString failingPorts);

    void connectionStarted();

    void displayLaunchError(QString text);

    void displayLaunchWarning(QString text);

    void quitStarting();

    void sessionFinished(int portTestResult);

    // Emitted after sessionFinished() when the session is ready to be destroyed
    void readyForDeletion();

private:
    void execInternal();

    bool initialize();

    bool startConnectionAsync();

    bool validateLaunch(SDL_Window* testWindow);

    void emitLaunchWarning(QString text);

    bool populateDecoderProperties(SDL_Window* window);

    IAudioRenderer* createAudioRenderer(const POPUS_MULTISTREAM_CONFIGURATION opusConfig);

    bool initializeAudioRenderer();

    bool testAudio(int audioConfiguration);

    int getAudioRendererCapabilities(int audioConfiguration);

    void getWindowDimensions(int& x, int& y,
                             int& width, int& height);

    // Helper function to get actual fps for decoder tests
    // Converts Apollo's internal fps representation (fps * 1000) back to normal fps
    int getActualFpsForDecoderTest() const;

    void toggleFullscreen();

    void toggleQuickMenu();

    void notifyMouseEmulationMode(bool enabled);

    void updateOptimalWindowDisplayMode();

    enum class DecoderAvailability {
        None,
        Software,
        Hardware
    };

    static
    DecoderAvailability getDecoderAvailability(SDL_Window* window,
                                               StreamingPreferences::VideoDecoderSelection vds,
                                               int videoFormat, int width, int height, int frameRate);

    static
    bool chooseDecoder(StreamingPreferences::VideoDecoderSelection vds,
                       SDL_Window* window, int videoFormat, int width, int height,
                       int frameRate, bool enableVsync, bool enableFramePacing,
                       bool testOnly,
                       IVideoDecoder*& chosenDecoder,
                       bool enableVrr = false,
                       int vrrDisplayRefreshHz = 0);

    static
    void clStageStarting(int stage);

    static
    void clStageFailed(int stage, int errorCode);

    static
    void clConnectionTerminated(int errorCode);

    static
    void clLogMessage(const char* format, ...);

    static
    void clRumble(unsigned short controllerNumber, unsigned short lowFreqMotor, unsigned short highFreqMotor);

    static
    void clConnectionStatusUpdate(int connectionStatus);

    static
    void clSetHdrMode(bool enabled);

    static
    void clRumbleTriggers(uint16_t controllerNumber, uint16_t leftTrigger, uint16_t rightTrigger);

    static
    void clSetMotionEventState(uint16_t controllerNumber, uint8_t motionType, uint16_t reportRateHz);

    static
    void clSetControllerLED(uint16_t controllerNumber, uint8_t r, uint8_t g, uint8_t b);

    static
    void clSetAdaptiveTriggers(uint16_t controllerNumber, uint8_t eventFlags, uint8_t typeLeft, uint8_t typeRight, uint8_t *left, uint8_t *right);

    static
    int arInit(int audioConfiguration,
               const POPUS_MULTISTREAM_CONFIGURATION opusConfig,
               void* arContext, int arFlags);

    static
    void arCleanup();

    static
    void arDecodeAndPlaySample(char* sampleData, int sampleLength);

    static
    int drSetup(int videoFormat, int width, int height, int frameRate, void*, int);

    static
    void drCleanup();

    static
    int drSubmitDecodeUnit(PDECODE_UNIT du);

    // BL-2265 collapse detector, v2 (test140 device FAIL RCA). ACCOUNTING
    // and EVALUATION are deliberately split: v1 evaluated inside this
    // delivery callback, which starves in a real collapse (common-c only
    // calls submitDecodeUnit for COMPLETE frames), so the verdict never ran.
    // This method now ONLY counts (depacketizer thread) ...
    void onRescueFrameDelivery(uint32_t frameNumber);

    // ... and this wall-clock check — called from the streaming event loop
    // every iteration (>=1 Hz even with zero SDL events) — owns the window
    // and the verdict, using expected-vs-delivered accounting that needs no
    // delivery events at all. Also emits the rate-limited (5s) 3-condition
    // debug trace requested by test140 so the next device cycle can bisect.
    void checkBitrateRescue();

    void triggerBitrateRescue(uint32_t elapsedMs, uint32_t delivered, uint32_t dropped);

    StreamingPreferences* m_Preferences;
    bool m_IsFullScreen;
    SupportedVideoFormatList m_SupportedVideoFormats; // Sorted in order of descending priority
    STREAM_CONFIGURATION m_StreamConfig;
    DECODER_RENDERER_CALLBACKS m_VideoCallbacks;
    AUDIO_RENDERER_CALLBACKS m_AudioCallbacks;
    NvComputer* m_Computer;
    NvApp m_App;
    SDL_Window* m_Window;
    IVideoDecoder* m_VideoDecoder;
    SDL_SpinLock m_DecoderLock;
    bool m_AudioDisabled;
    bool m_AudioMuted;
    Uint32 m_FullScreenFlag;
    QWindow* m_QtWindow;
    bool m_ThreadedExec;
    bool m_UnexpectedTermination;
    SdlInputHandler* m_InputHandler;
    int m_MouseEmulationRefCount;
    int m_FlushingWindowEventsRef;
    // One-time "VRR unavailable" fallback notice latch (BL-2212)
    bool m_VrrFallbackNotified = false;
    // Refresh rate the current decoder's VRR session qualified at, 0 when the
    // last qualification pass rejected (or never requested) VRR. Lets the
    // window-event guard detect a same-display refresh-mode switch that
    // invalidates the qualified rate (BL-2296, Nonary v6.1.0-vrr9.1 parity).
    int m_ActiveVrrRefreshHz = 0;
    // BL-2265 bitrate-collapse rescue state (v2 threading contract):
    //  - m_RescueLastFrameNumber: depacketizer thread ONLY.
    //  - m_RescueDeliveredTotal / m_RescueGapDroppedTotal: written on the
    //    depacketizer thread, read on the streaming-loop thread (atomics).
    //  - m_RescueWnd* / m_RescueLastTraceMs: streaming-loop thread ONLY.
    //  - m_RescueTriggered: CAS latch, any thread.
    bool m_RescueArmed = false;
    SDL_atomic_t m_RescueTriggered {};
    SDL_atomic_t m_RescueDeliveredTotal {};
    SDL_atomic_t m_RescueGapDroppedTotal {};
    uint32_t m_RescueLastFrameNumber = 0;
    uint32_t m_RescueWndStartMs = 0;
    int m_RescueWndBaseDelivered = 0;
    int m_RescueWndBaseGapDropped = 0;
    uint32_t m_RescueLastTraceMs = 0;
    int m_RescueFromKbps = 0;
    int m_RescueToKbps = 0;
    // One-shot cross-session carry of the stepped-down bitrate: written when
    // a rescue triggers, consumed (and cleared) by the NEXT session's
    // initialize(). Never persisted to settings — the user's saved bitrate
    // preference is untouched.
    static QAtomicInt s_PendingRescueBitrateKbps;
    QList<QString> m_LaunchWarnings;
    bool m_ShouldExitAfterQuit;
    // Vibemis: see setShouldQuitAppAfter()
    bool m_ShouldQuitAppAfter;

    bool m_AsyncConnectionSuccess;
    int m_PortTestResults;

    int m_ActiveVideoFormat;
    int m_ActiveVideoWidth;
    int m_ActiveVideoHeight;
    int m_ActiveVideoFrameRate;

    OpusMSDecoder* m_OpusDecoder;
    IAudioRenderer* m_AudioRenderer;
    OPUS_MULTISTREAM_CONFIGURATION m_ActiveAudioConfig;
    OPUS_MULTISTREAM_CONFIGURATION m_OriginalAudioConfig;
    int m_AudioSampleCount;
    Uint32 m_DropAudioEndTime;

    Overlay::OverlayManager m_OverlayManager;
    QuickMenuManager* m_QuickMenuManager;
    ServerCommandManager* m_ServerCommandManager;
    ClipboardManager* m_ClipboardManager;

    static CONNECTION_LISTENER_CALLBACKS k_ConnCallbacks;
    static Session* s_ActiveSession;
    static QSemaphore s_ActiveSessionSemaphore;
};
