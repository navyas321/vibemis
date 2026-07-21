#pragma once

#include <QObject>
#include <QRect>
#include <QQmlEngine>
#include <QVariant>

#include <vector>

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
        QMGC_PADDLE1,         // back paddle P1 (Xbox Elite / Legion Go / other paddle pads)
        QMGC_PADDLE2,         // back paddle P2
        QMGC_PADDLE3,         // back paddle P3
        QMGC_PADDLE4,         // back paddle P4
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

    // Vibemis: which release channel the update checker follows. A channel is
    // a MINIMUM stability floor — it serves its own tier and everything more
    // stable (Alpha ⊇ Beta ⊇ RC ⊇ Stable), so e.g. an RC-channel install
    // graduates to the stable that candidate became instead of going silent.
    // UC_STABLE = stables only (pre-channel behavior). UC_RC appended LAST
    // so persisted integer settings keep their meaning.
    enum UpdateChannel
    {
        UC_STABLE,
        UC_BETA,
        UC_ALPHA,
        UC_RC,
    };
    Q_ENUM(UpdateChannel);

    Q_PROPERTY(int width MEMBER width NOTIFY displayModeChanged)
    Q_PROPERTY(int height MEMBER height NOTIFY displayModeChanged)
    Q_PROPERTY(int fps MEMBER fps NOTIFY displayModeChanged)
    Q_PROPERTY(int bitrateKbps MEMBER bitrateKbps NOTIFY bitrateChanged)
    Q_PROPERTY(bool unlockBitrate MEMBER unlockBitrate NOTIFY unlockBitrateChanged)
    Q_PROPERTY(bool autoAdjustBitrate MEMBER autoAdjustBitrate NOTIFY autoAdjustBitrateChanged)
    Q_PROPERTY(bool enableVsync MEMBER enableVsync NOTIFY enableVsyncChanged)
    // Vibemis (BL-2212): VRR pacing (vendored from Nonary v6.1.0-vrr9.1).
    // Presents each fully-prepared frame at a learned margin on an
    // adaptive-sync display instead of latching to fixed V-sync slots.
    // Requires V-sync; every rejection falls back to fixed V-sync pacing.
    Q_PROPERTY(bool enableVrr MEMBER enableVrr NOTIFY enableVrrChanged)
    Q_PROPERTY(bool gameOptimizations MEMBER gameOptimizations NOTIFY gameOptimizationsChanged)
    Q_PROPERTY(bool playAudioOnHost MEMBER playAudioOnHost NOTIFY playAudioOnHostChanged)
    Q_PROPERTY(bool multiController MEMBER multiController NOTIFY multiControllerChanged)
    Q_PROPERTY(bool enableMdns MEMBER enableMdns NOTIFY enableMdnsChanged)
    Q_PROPERTY(bool quitAppAfter MEMBER quitAppAfter NOTIFY quitAppAfterChanged)
    Q_PROPERTY(bool absoluteMouseMode MEMBER absoluteMouseMode NOTIFY absoluteMouseModeChanged)
    Q_PROPERTY(bool absoluteTouchMode MEMBER absoluteTouchMode NOTIFY absoluteTouchModeChanged)
    // Vibemis: opt-in on-screen touch controls overlay for touch
    // handhelds. When enabled, three semi-transparent icon-only buttons are
    // composited into the stream: MENU (top-left, opens the Quick Menu), KBD (far
    // top-right, requests the SteamOS on-screen keyboard) and TOUCH-MODE (inward of
    // KBD, live-toggles touchpad-emulation vs direct touch). Off by default so
    // existing users are unaffected.
    Q_PROPERTY(bool enableTouchOverlay MEMBER enableTouchOverlay NOTIFY enableTouchOverlayChanged)
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
    // Vibemis: optional wall-clock line at the top of the performance
    // overlay. Off by default so the overlay is unchanged for existing users.
    Q_PROPERTY(bool perfOverlayShowClock MEMBER perfOverlayShowClock NOTIFY perfOverlayShowClockChanged)
    Q_PROPERTY(bool suppressControllerRumble MEMBER suppressControllerRumble NOTIFY suppressControllerRumbleChanged)
    Q_PROPERTY(PerfOverlayTextSize perfOverlayTextSize MEMBER perfOverlayTextSize NOTIFY perfOverlayTextSizeChanged)
    Q_PROPERTY(PerfOverlayPosition perfOverlayPosition MEMBER perfOverlayPosition NOTIFY perfOverlayPositionChanged)
    Q_PROPERTY(UpdateChannel updateChannel MEMBER updateChannel NOTIFY updateChannelChanged)
    Q_PROPERTY(bool adaptiveBitrate MEMBER adaptiveBitrate NOTIFY adaptiveBitrateChanged)
    Q_PROPERTY(AudioConfig audioConfig MEMBER audioConfig NOTIFY audioConfigChanged)
    Q_PROPERTY(VideoCodecConfig videoCodecConfig MEMBER videoCodecConfig NOTIFY videoCodecConfigChanged)
    Q_PROPERTY(bool enableHdr MEMBER enableHdr NOTIFY enableHdrChanged)
    // Vibemis redesign UI prefs: gamepad hint-bar visibility + accent color (index into the 4 token accents).
    Q_PROPERTY(bool uiShowHints MEMBER uiShowHints NOTIFY uiShowHintsChanged)
    Q_PROPERTY(int uiAccentIndex MEMBER uiAccentIndex NOTIFY uiAccentIndexChanged)
    // Vibemis: short UI sounds on controller-nav focus moves and activations
    // (launcher + in-stream Quick Menu). Played by UiSoundManager.
    Q_PROPERTY(bool uiSounds MEMBER uiSounds NOTIFY uiSoundsChanged)
    // Vibemis: companion gate to enableHdr. When the user enables HDR but their
    // display can't actually show HDR (e.g. Legion Go S Z2 LCD), the host
    // streams HDR PQ-encoded content that looks washed out on the SDR panel.
    // Defaults to true so existing HDR users aren't regressed; users who hit
    // the wash-out can uncheck it in Settings without disabling HDR entirely.
    Q_PROPERTY(bool displayHdrCapability MEMBER displayHdrCapability NOTIFY displayHdrCapabilityChanged)
    // Vibemis: client-side HDR tone-mapping toggle. When on,
    // the Vulkan (libplacebo) renderer forces an SDR output colorspace so HDR content
    // is tone-mapped down to SDR on this device instead of being passed through to the
    // display. Complements displayHdrCapability (that gate operates at codec negotiation;
    // this one operates at render/output time). Defaults to false = passthrough, so
    // existing HDR-display users keep native HDR output unchanged.
    Q_PROPERTY(bool hdrTonemapping MEMBER hdrTonemapping NOTIFY hdrTonemappingChanged)
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
    Q_PROPERTY(bool reduceBitrateOnBattery MEMBER reduceBitrateOnBattery NOTIFY reduceBitrateOnBatteryChanged)
    // Vibemis: bounded auto-reconnect after an unexpected mid-stream drop.
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

    // Vibemis (BL-2212): build the Settings FPS combo list. With VRR enabled
    // (and its V-sync precondition met), exact native refresh choices are
    // replaced by the calculated VRR rate (floor(r - r^2/3600)) and
    // low-latency rate (floor((r*5/6)/5)*5) for each detected display.
    Q_INVOKABLE QVariantList getFpsChoices(const QVariantList& refreshRates) const;

    static std::vector<int> toRefreshRates(const QVariantList& refreshRates);

    // Directly accessible members for preferences
    int width;
    int height;
    int fps;
    // BL-2235: true when the fps value is an explicit user choice (stored
    // fps key, Settings save, or --fps) rather than the generic default.
    // Session start only auto-derives a VRR FPS when this is false.
    bool hasExplicitFps;
    int bitrateKbps;
    bool unlockBitrate;
    bool autoAdjustBitrate;
    bool enableVsync;
    // Vibemis (BL-2212): see Q_PROPERTY comment above.
    bool enableVrr;
    bool gameOptimizations;
    bool playAudioOnHost;
    bool multiController;
    bool enableMdns;
    bool quitAppAfter;
    bool absoluteMouseMode;
    bool absoluteTouchMode;
    // Vibemis: see Q_PROPERTY comment above; opt-in on-screen touch buttons.
    bool enableTouchOverlay;
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
    UpdateChannel updateChannel;
    bool adaptiveBitrate;
    bool swapMouseButtons;
    bool muteOnFocusLoss;
    bool backgroundGamepad;
    bool reverseScrollDirection;
    bool swapFaceButtons;
    bool keepAwake;
    bool reduceBitrateOnBattery;
    bool autoReconnect;
    bool seenWelcomeHint;
    int packetSize;
    AudioConfig audioConfig;
    VideoCodecConfig videoCodecConfig;
    bool enableHdr;
    bool uiShowHints;
    int uiAccentIndex;
    bool uiSounds;
    // Vibemis: see Q_PROPERTY comment above; gates HDR request on display capability.
    bool displayHdrCapability;
    // Vibemis: see Q_PROPERTY comment above; forces client-side HDR->SDR
    // tone-mapping in the Vulkan renderer when set. Defaults to false (passthrough).
    bool hdrTonemapping;
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
    // Vibemis: transient in-stream zoom factor (1.0 = no zoom) and pan offset (x/y in
    // [-1,1], 0 = centered; only meaningful while zoomed). Not serialized — reset each
    // launch. Adjusted live by the zoom/pan key combos; read by StreamUtils.
    double videoZoomFactor;
    double videoPanX;
    double videoPanY;

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
    void enableVrrChanged();
    void gameOptimizationsChanged();
    void playAudioOnHostChanged();
    void multiControllerChanged();
    void unsupportedFpsChanged();
    void enableMdnsChanged();
    void quitAppAfterChanged();
    void absoluteMouseModeChanged();
    void absoluteTouchModeChanged();
    void enableTouchOverlayChanged();
    void audioConfigChanged();
    void videoCodecConfigChanged();
    void enableHdrChanged();
    void uiShowHintsChanged();
    void uiAccentIndexChanged();
    void uiSoundsChanged();
    void displayHdrCapabilityChanged();
    void hdrTonemappingChanged();
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
    void updateChannelChanged();
    void adaptiveBitrateChanged();
    void mouseButtonsChanged();
    void muteOnFocusLossChanged();
    void backgroundGamepadChanged();
    void reverseScrollDirectionChanged();
    void swapFaceButtonsChanged();
    void captureSysKeysModeChanged();
    void keepAwakeChanged();
    void reduceBitrateOnBatteryChanged();
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

