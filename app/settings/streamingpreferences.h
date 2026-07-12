#pragma once

#include <QObject>
#include <QRect>
#include <QQmlEngine>

class StreamingPreferences : public QObject
{
    Q_OBJECT

public:
    static StreamingPreferences* get(QQmlEngine *qmlEngine = nullptr);

    Q_INVOKABLE static int
    getDefaultBitrate(int width, int height, int fps, bool yuv444);

    Q_INVOKABLE void save();

    // Vibemis: export all settings to a portable .ini and import them back (config backup /
    // sharing across devices). exportSettings() returns the written path ("" on failure);
    // importSettings() returns true and reloads on success.
    Q_INVOKABLE QString exportSettings();
    Q_INVOKABLE bool importSettings();

    void reload();

    // Vibemis: one-click quality presets tuned for the Lenovo Legion Go S Z2
    // (1920x1200 native, 120 Hz, AMD VAAPI hardware decode, HEVC). applyPreset()
    // batch-sets the relevant streaming preferences and persists them.
    enum VibepolloPreset
    {
        PRESET_QUALITY,      // 1920x1200 @ 120 — best image, native res/refresh
        PRESET_BALANCED,     // 1920x1200 @ 90  — native res, lighter refresh
        PRESET_PERFORMANCE,  // 1280x800  @ 120 — lower res for high fps / low latency
        PRESET_BATTERY       // 1280x800  @ 60  — easiest on battery and network
    };
    Q_ENUM(VibepolloPreset)

    Q_INVOKABLE void applyPreset(int preset);

    enum AudioConfig
    {
        AC_STEREO,
        AC_51_SURROUND,
        AC_71_SURROUND
    };
    Q_ENUM(AudioConfig)

    enum VideoCodecConfig
    {
        VCC_AUTO,
        VCC_FORCE_H264,
        VCC_FORCE_HEVC,
        VCC_FORCE_HEVC_HDR_DEPRECATED, // Kept for backwards compatibility
        VCC_FORCE_AV1
    };
    Q_ENUM(VideoCodecConfig)

    enum VideoDecoderSelection
    {
        VDS_AUTO,
        VDS_FORCE_HARDWARE,
        VDS_FORCE_SOFTWARE
    };
    Q_ENUM(VideoDecoderSelection)

    enum WindowMode
    {
        WM_FULLSCREEN,
        WM_FULLSCREEN_DESKTOP,
        WM_WINDOWED
    };
    Q_ENUM(WindowMode)

    enum UIDisplayMode
    {
        UI_WINDOWED,
        UI_MAXIMIZED,
        UI_FULLSCREEN
    };
    Q_ENUM(UIDisplayMode)

    // Renderer backend preference
    enum RendererBackend
    {
        RB_AUTO,
        RB_VULKAN,
        RB_OPENGL,
    };
    Q_ENUM(RendererBackend)

    // Vibemis: which gamepad button combo opens the in-stream Quick Menu.
    enum QuickMenuGamepadCombo
    {
        QMGC_SELECT_LB_RB_Y,  // default — Select + L1 + R1 + Y
        QMGC_SELECT_LB_RB_B,  // Select + L1 + R1 + B
        QMGC_L3_R3,           // click both analog sticks (L3 + R3)
        QMGC_SELECT_START,    // Select + Start
    };
    Q_ENUM(QuickMenuGamepadCombo)
    // Vibemis: how the video frame is fit to the window.
    enum VideoScaleMode
    {
        SCALE_FIT,      // letterbox / pillarbox, preserve aspect (default — original behaviour)
        SCALE_FILL,     // cover: fill the window and crop overflow, preserve aspect
        SCALE_STRETCH,  // stretch to fill, ignore aspect ratio
    };
    Q_ENUM(VideoScaleMode)

    // New entries must go at the end of the enum
    // to avoid renumbering existing entries (which
    // would affect existing user preferences).
    enum Language
    {
        LANG_AUTO,
        LANG_EN,
        LANG_FR,
        LANG_ZH_CN,
        LANG_DE,
        LANG_NB_NO,
        LANG_RU,
        LANG_ES,
        LANG_JA,
        LANG_VI,
        LANG_TH,
        LANG_KO,
        LANG_HU,
        LANG_NL,
        LANG_SV,
        LANG_TR,
        LANG_UK,
        LANG_ZH_TW,
        LANG_PT,
        LANG_PT_BR,
        LANG_EL,
        LANG_IT,
        LANG_HI,
        LANG_PL,
        LANG_CS,
        LANG_HE,
        LANG_CKB,
        LANG_LT,
        LANG_ET,
        LANG_BG,
        LANG_EO,
        LANG_TA,
    };
    Q_ENUM(Language);

    enum CaptureSysKeysMode
    {
        CSK_OFF,
        CSK_FULLSCREEN,
        CSK_ALWAYS,
    };
    Q_ENUM(CaptureSysKeysMode);

    // Vibemis: font size of the in-stream performance overlay.
    // PERF_TEXT_NORMAL preserves the historical 20pt default.
    enum PerfOverlayTextSize
    {
        PERF_TEXT_SMALL,
        PERF_TEXT_NORMAL,
        PERF_TEXT_LARGE,
    };
    Q_ENUM(PerfOverlayTextSize);

    // Vibemis: which screen corner the in-stream performance overlay anchors to.
    // POS_TOP_LEFT preserves the historical Moonlight position (default).
    enum PerfOverlayPosition
    {
        POS_TOP_LEFT,
        POS_TOP_RIGHT,
        POS_BOTTOM_LEFT,
        POS_BOTTOM_RIGHT,
    };
    Q_ENUM(PerfOverlayPosition);

    Q_PROPERTY(int width MEMBER width NOTIFY displayModeChanged)
    Q_PROPERTY(int height MEMBER height NOTIFY displayModeChanged)
    Q_PROPERTY(int fps MEMBER fps NOTIFY displayModeChanged)
    Q_PROPERTY(int bitrateKbps MEMBER bitrateKbps NOTIFY bitrateChanged)
    Q_PROPERTY(bool unlockBitrate MEMBER unlockBitrate NOTIFY unlockBitrateChanged)
    Q_PROPERTY(bool autoAdjustBitrate MEMBER autoAdjustBitrate NOTIFY autoAdjustBitrateChanged)
    Q_PROPERTY(bool enableVsync MEMBER enableVsync NOTIFY enableVsyncChanged)
    Q_PROPERTY(bool gameOptimizations MEMBER gameOptimizations NOTIFY gameOptimizationsChanged)
    Q_PROPERTY(bool playAudioOnHost MEMBER playAudioOnHost NOTIFY playAudioOnHostChanged)
    Q_PROPERTY(bool multiController MEMBER multiController NOTIFY multiControllerChanged)
    Q_PROPERTY(bool enableMdns MEMBER enableMdns NOTIFY enableMdnsChanged)
    Q_PROPERTY(bool quitAppAfter MEMBER quitAppAfter NOTIFY quitAppAfterChanged)
    Q_PROPERTY(bool absoluteMouseMode MEMBER absoluteMouseMode NOTIFY absoluteMouseModeChanged)
    Q_PROPERTY(bool absoluteTouchMode MEMBER absoluteTouchMode NOTIFY absoluteTouchModeChanged)
    Q_PROPERTY(bool framePacing MEMBER framePacing NOTIFY framePacingChanged)
    Q_PROPERTY(bool connectionWarnings MEMBER connectionWarnings NOTIFY connectionWarningsChanged)
    Q_PROPERTY(bool configurationWarnings MEMBER configurationWarnings NOTIFY configurationWarningsChanged)
    Q_PROPERTY(bool richPresence MEMBER richPresence NOTIFY richPresenceChanged)
    Q_PROPERTY(bool gamepadMouse MEMBER gamepadMouse NOTIFY gamepadMouseChanged)
    Q_PROPERTY(bool detectNetworkBlocking MEMBER detectNetworkBlocking NOTIFY detectNetworkBlockingChanged)
    Q_PROPERTY(bool showPerformanceOverlay MEMBER showPerformanceOverlay NOTIFY showPerformanceOverlayChanged)
    // Vibemis: when true, the performance overlay shows a single compact line
    // (fps · resolution/codec · latency · drops) instead of the full multi-line block —
    // far more legible on a small handheld screen during a stream.
    Q_PROPERTY(bool compactPerformanceOverlay MEMBER compactPerformanceOverlay NOTIFY compactPerformanceOverlayChanged)
    Q_PROPERTY(bool preferTailscale MEMBER preferTailscale NOTIFY preferTailscaleChanged)
    Q_PROPERTY(bool forwardMotionControls MEMBER forwardMotionControls NOTIFY forwardMotionControlsChanged)
    // Vibemis (test72): optional wall-clock line at the top of the performance
    // overlay. Off by default so the overlay is unchanged for existing users.
    Q_PROPERTY(bool perfOverlayShowClock MEMBER perfOverlayShowClock NOTIFY perfOverlayShowClockChanged)
    Q_PROPERTY(bool suppressControllerRumble MEMBER suppressControllerRumble NOTIFY suppressControllerRumbleChanged)
    Q_PROPERTY(PerfOverlayTextSize perfOverlayTextSize MEMBER perfOverlayTextSize NOTIFY perfOverlayTextSizeChanged)
    Q_PROPERTY(PerfOverlayPosition perfOverlayPosition MEMBER perfOverlayPosition NOTIFY perfOverlayPositionChanged)
    Q_PROPERTY(bool adaptiveBitrate MEMBER adaptiveBitrate NOTIFY adaptiveBitrateChanged)
    Q_PROPERTY(AudioConfig audioConfig MEMBER audioConfig NOTIFY audioConfigChanged)
    Q_PROPERTY(VideoCodecConfig videoCodecConfig MEMBER videoCodecConfig NOTIFY videoCodecConfigChanged)
    Q_PROPERTY(bool enableHdr MEMBER enableHdr NOTIFY enableHdrChanged)
    // Vibemis: companion gate to enableHdr. When the user enables HDR but their
    // display can't actually show HDR (e.g. Legion Go S Z2 LCD), the host
    // streams HDR PQ-encoded content that looks washed out on the SDR panel.
    // Defaults to true so existing HDR users aren't regressed; users who hit
    // the wash-out can uncheck it in Settings without disabling HDR entirely.
    Q_PROPERTY(bool displayHdrCapability MEMBER displayHdrCapability NOTIFY displayHdrCapabilityChanged)
    Q_PROPERTY(bool enableYUV444 MEMBER enableYUV444 NOTIFY enableYUV444Changed)
    Q_PROPERTY(VideoDecoderSelection videoDecoderSelection MEMBER videoDecoderSelection NOTIFY videoDecoderSelectionChanged)
    Q_PROPERTY(WindowMode windowMode MEMBER windowMode NOTIFY windowModeChanged)
    Q_PROPERTY(WindowMode recommendedFullScreenMode MEMBER recommendedFullScreenMode CONSTANT)
    Q_PROPERTY(UIDisplayMode uiDisplayMode MEMBER uiDisplayMode NOTIFY uiDisplayModeChanged)
    Q_PROPERTY(bool swapMouseButtons MEMBER swapMouseButtons NOTIFY mouseButtonsChanged)
    Q_PROPERTY(bool muteOnFocusLoss MEMBER muteOnFocusLoss NOTIFY muteOnFocusLossChanged)
    Q_PROPERTY(bool backgroundGamepad MEMBER backgroundGamepad NOTIFY backgroundGamepadChanged)
    Q_PROPERTY(bool reverseScrollDirection MEMBER reverseScrollDirection NOTIFY reverseScrollDirectionChanged)
    Q_PROPERTY(bool swapFaceButtons MEMBER swapFaceButtons NOTIFY swapFaceButtonsChanged)
    Q_PROPERTY(bool keepAwake MEMBER keepAwake NOTIFY keepAwakeChanged)
    // Vibemis P3.21 (test80): bounded auto-reconnect after an unexpected mid-stream drop.
    Q_PROPERTY(bool autoReconnect MEMBER autoReconnect NOTIFY autoReconnectChanged)
    Q_PROPERTY(bool seenWelcomeHint MEMBER seenWelcomeHint NOTIFY seenWelcomeHintChanged)
    Q_PROPERTY(CaptureSysKeysMode captureSysKeysMode MEMBER captureSysKeysMode NOTIFY captureSysKeysModeChanged)
    Q_PROPERTY(Language language MEMBER language NOTIFY languageChanged)
    Q_PROPERTY(RendererBackend rendererBackend MEMBER rendererBackend NOTIFY rendererBackendChanged)
    Q_PROPERTY(QuickMenuGamepadCombo quickMenuGamepadCombo MEMBER quickMenuGamepadCombo NOTIFY quickMenuGamepadComboChanged)

    Q_PROPERTY(VideoScaleMode videoScaleMode MEMBER videoScaleMode NOTIFY videoScaleModeChanged)
    
    // Vibemis client-side streaming enhancements
    Q_PROPERTY(bool useVirtualDisplay MEMBER useVirtualDisplay NOTIFY useVirtualDisplayChanged)
    Q_PROPERTY(bool enableFractionalRefreshRate MEMBER enableFractionalRefreshRate NOTIFY enableFractionalRefreshRateChanged)
    Q_PROPERTY(double customRefreshRate MEMBER customRefreshRate NOTIFY customRefreshRateChanged)
    Q_PROPERTY(bool enableResolutionScaling MEMBER enableResolutionScaling NOTIFY enableResolutionScalingChanged)
    Q_PROPERTY(int resolutionScaleFactor MEMBER resolutionScaleFactor NOTIFY resolutionScaleFactorChanged);

    Q_INVOKABLE bool retranslate();

    // Directly accessible members for preferences
    int width;
    int height;
    int fps;
    int bitrateKbps;
    bool unlockBitrate;
    bool autoAdjustBitrate;
    bool enableVsync;
    bool gameOptimizations;
    bool playAudioOnHost;
    bool multiController;
    bool enableMdns;
    bool quitAppAfter;
    bool absoluteMouseMode;
    bool absoluteTouchMode;
    bool framePacing;
    bool connectionWarnings;
    bool configurationWarnings;
    bool richPresence;
    bool gamepadMouse;
    bool detectNetworkBlocking;
    bool showPerformanceOverlay;
    bool compactPerformanceOverlay;
    bool preferTailscale;
    bool forwardMotionControls;
    bool perfOverlayShowClock;
    bool suppressControllerRumble;
    PerfOverlayTextSize perfOverlayTextSize;
    PerfOverlayPosition perfOverlayPosition;
    bool adaptiveBitrate;
    bool swapMouseButtons;
    bool muteOnFocusLoss;
    bool backgroundGamepad;
    bool reverseScrollDirection;
    bool swapFaceButtons;
    bool keepAwake;
    bool autoReconnect;
    bool seenWelcomeHint;
    int packetSize;
    AudioConfig audioConfig;
    VideoCodecConfig videoCodecConfig;
    bool enableHdr;
    // Vibemis: see Q_PROPERTY comment above; gates HDR request on display capability.
    bool displayHdrCapability;
    bool enableYUV444;
    VideoDecoderSelection videoDecoderSelection;
    WindowMode windowMode;
    WindowMode recommendedFullScreenMode;
    UIDisplayMode uiDisplayMode;
    Language language;
    CaptureSysKeysMode captureSysKeysMode;
    RendererBackend rendererBackend;
    QuickMenuGamepadCombo quickMenuGamepadCombo;
    VideoScaleMode videoScaleMode;

    // Vibemis client-side streaming enhancements
    bool useVirtualDisplay;
    bool enableFractionalRefreshRate;
    double customRefreshRate;
    bool enableResolutionScaling;
    int resolutionScaleFactor;

signals:
    void displayModeChanged();
    void bitrateChanged();
    void unlockBitrateChanged();
    void autoAdjustBitrateChanged();
    void enableVsyncChanged();
    void gameOptimizationsChanged();
    void playAudioOnHostChanged();
    void multiControllerChanged();
    void unsupportedFpsChanged();
    void enableMdnsChanged();
    void quitAppAfterChanged();
    void absoluteMouseModeChanged();
    void absoluteTouchModeChanged();
    void audioConfigChanged();
    void videoCodecConfigChanged();
    void enableHdrChanged();
    void displayHdrCapabilityChanged();
    void enableYUV444Changed();
    void videoDecoderSelectionChanged();
    void uiDisplayModeChanged();
    void windowModeChanged();
    void framePacingChanged();
    void connectionWarningsChanged();
    void configurationWarningsChanged();
    void richPresenceChanged();
    void gamepadMouseChanged();
    void detectNetworkBlockingChanged();
    void showPerformanceOverlayChanged();
    void compactPerformanceOverlayChanged();
    void preferTailscaleChanged();
    void forwardMotionControlsChanged();
    void perfOverlayShowClockChanged();
    void suppressControllerRumbleChanged();
    void perfOverlayTextSizeChanged();
    void perfOverlayPositionChanged();
    void adaptiveBitrateChanged();
    void mouseButtonsChanged();
    void muteOnFocusLossChanged();
    void backgroundGamepadChanged();
    void reverseScrollDirectionChanged();
    void swapFaceButtonsChanged();
    void captureSysKeysModeChanged();
    void keepAwakeChanged();
    void autoReconnectChanged();
    void seenWelcomeHintChanged();
    void languageChanged();
    void rendererBackendChanged();
    void quickMenuGamepadComboChanged();

    void videoScaleModeChanged();
    
    // Vibemis client-side streaming enhancement signals
    void useVirtualDisplayChanged();
    void enableFractionalRefreshRateChanged();
    void customRefreshRateChanged();
    void enableResolutionScalingChanged();
    void resolutionScaleFactorChanged();

public:
    // Create a standalone preferences instance loaded fresh from QSettings, NOT the
    // shared singleton. Used for session-scoped overrides (e.g. per-game stream
    // profiles) so the global object the Settings UI binds to is never mutated.
    // Caller owns the returned object (parent it or delete it).
    static StreamingPreferences* createDetached() { return new StreamingPreferences(nullptr); }

private:
    explicit StreamingPreferences(QQmlEngine *qmlEngine);

    QString getSuffixFromLanguage(Language lang);

    QQmlEngine* m_QmlEngine;
};

