#pragma once

#include "settings/streamingpreferences.h"
#include "backend/computermanager.h"

#include "SDL_compat.h"

struct GamepadState {
    SDL_GameController* controller;
    SDL_JoystickID jsId;
    short index;

#if !SDL_VERSION_ATLEAST(2, 0, 9)
    SDL_Haptic* haptic;
    int hapticMethod;
    int hapticEffectId;
#endif

    SDL_TimerID mouseEmulationTimer;
    uint32_t lastStartDownTime;

    // Buttons whose PRESS was consumed by the Quick Menu intercept.
    // Their RELEASE must be swallowed too, or it leaks into the normal handlers with
    // stale state (e.g. Start release toggling mouse emulation, stray mouse-button
    // releases in emulation mode).
    int buttonsConsumedByMenu;

    // BL-2538: buttons that were already PHYSICALLY HELD when this controller
    // attached to the stream's input handler. That press belongs to whatever
    // launched the stream (the app-grid A press), not to the game -- forwarding
    // it nearly confirmed a save-overwrite prompt on the host (default = Yes).
    // Each bit is swallowed (press and release) until SDL reports the first
    // RELEASE, after which the button behaves normally.
    int buttonsHeldAtAttach;

    // While the Quick Menu is open, the left stick drives navigation like the d-pad.
    // Axis events fire continuously, so we remember the last stick-derived direction (a Qt::Key
    // value, or 0 for centered) and only emit on CHANGE (edges) — the menu handles auto-repeat.
    int menuStickDir;

    bool clickpadButtonEmulationEnabled;
    bool emulatedClickpadButtonDown;

#if SDL_VERSION_ATLEAST(2, 0, 14)
    uint8_t gyroReportPeriodMs;
    float lastGyroEventData[SDL_arraysize(SDL_ControllerSensorEvent::data)];
    uint32_t lastGyroEventTime;

    uint8_t accelReportPeriodMs;
    float lastAccelEventData[SDL_arraysize(SDL_ControllerSensorEvent::data)];
    uint32_t lastAccelEventTime;
#endif

    int buttons;
    short lsX, lsY;
    short rsX, rsY;
    unsigned char lt, rt;
};


struct DualSenseOutputReport{
    uint8_t validFlag0;
    uint8_t validFlag1;

    /* For DualShock 4 compatibility mode. */
    uint8_t motorRight;
    uint8_t motorLeft;

    /* Audio controls */
    uint8_t reserved[4];
    uint8_t muteButtonLed;

    uint8_t powerSaveControl;
    uint8_t rightTriggerEffectType;
    uint8_t rightTriggerEffect[DS_EFFECT_PAYLOAD_SIZE];
    uint8_t leftTriggerEffectType;
    uint8_t leftTriggerEffect[DS_EFFECT_PAYLOAD_SIZE];
    uint8_t reserved2[6];

    /* LEDs and lightbar */
    uint8_t validFlag2;
    uint8_t reserved3[2];
    uint8_t lightbarSetup;
    uint8_t ledBrightness;
    uint8_t playerLeds;
    uint8_t lightbarRed;
    uint8_t lightbarGreen;
    uint8_t lightbarBlue;
};

// activeGamepadMask is a short, so we're bounded by the number of mask bits
#define MAX_GAMEPADS 16

#define MAX_FINGERS 2

#define GAMEPAD_HAPTIC_METHOD_NONE 0
#define GAMEPAD_HAPTIC_METHOD_LEFTRIGHT 1
#define GAMEPAD_HAPTIC_METHOD_SIMPLERUMBLE 2

#define GAMEPAD_HAPTIC_SIMPLE_HIFREQ_MOTOR_WEIGHT 0.33
#define GAMEPAD_HAPTIC_SIMPLE_LOWFREQ_MOTOR_WEIGHT 0.8

class SdlInputHandler
{
public:
    explicit SdlInputHandler(StreamingPreferences& prefs, int streamWidth, int streamHeight);

    ~SdlInputHandler();

    void setWindow(SDL_Window* window);

    void handleKeyEvent(SDL_KeyboardEvent* event);
    void handleTextInputEvent(SDL_TextInputEvent* event);

    // Thread-safe bridge so the Quick Menu (Qt main thread) can trigger
    // input ops that MUST run on the SDL thread (fullscreen / mouse-mode / input-capture
    // toggles). QuickMenuManager pushes this SDL user event; the SDL event loop dispatches
    // it here. Returns the registered SDL user-event type (stable for the process).
    static Uint32 quickMenuComboEventType();
    void dispatchQuickMenuCombo(int comboCode);

    void handleMouseButtonEvent(SDL_MouseButtonEvent* event);

    void handleMouseMotionEvent(SDL_MouseMotionEvent* event);

    void handleMouseWheelEvent(SDL_MouseWheelEvent* event);

    void handleControllerAxisEvent(SDL_ControllerAxisEvent* event);

    void handleControllerButtonEvent(SDL_ControllerButtonEvent* event);

    void handleControllerDeviceEvent(SDL_ControllerDeviceEvent* event);

#if SDL_VERSION_ATLEAST(2, 0, 14)
    void handleControllerSensorEvent(SDL_ControllerSensorEvent* event);

    void handleControllerTouchpadEvent(SDL_ControllerTouchpadEvent* event);
#endif

#if SDL_VERSION_ATLEAST(2, 24, 0)
    void handleJoystickBatteryEvent(SDL_JoyBatteryEvent* event);
#endif

    void handleJoystickArrivalEvent(SDL_JoyDeviceEvent* event);

    void sendText(QString& string);

    void rumble(uint16_t controllerNumber, uint16_t lowFreqMotor, uint16_t highFreqMotor);

    void rumbleTriggers(uint16_t controllerNumber, uint16_t leftTrigger, uint16_t rightTrigger);

    void setMotionEventState(uint16_t controllerNumber, uint8_t motionType, uint16_t reportRateHz);

    void setControllerLED(uint16_t controllerNumber, uint8_t r, uint8_t g, uint8_t b);

    void setAdaptiveTriggers(uint16_t controllerNumber, DualSenseOutputReport *report);

    void handleTouchFingerEvent(SDL_TouchFingerEvent* event);

    int getAttachedGamepadMask();

    void raiseAllKeys();

    void notifyMouseLeave();

    void notifyFocusLost();

    void notifyFocusGained();

    bool isCaptureActive();

    bool isSystemKeyCaptureActive();

    void setCaptureActive(bool active);

    bool isMouseInVideoRegion(int mouseX, int mouseY, int windowWidth = -1, int windowHeight = -1);

    void updateKeyboardGrabState();

    void updatePointerRegionLock();

    static
    QString getUnmappedGamepads();

private:
    enum KeyCombo {
        KeyComboQuit,
        KeyComboUngrabInput,
        KeyComboToggleFullScreen,
        KeyComboToggleStatsOverlay,
        KeyComboToggleMouseMode,
        KeyComboToggleCursorHide,
        KeyComboToggleMinimize,
        KeyComboPasteText,
        KeyComboTogglePointerRegionLock,
        KeyComboQuitAndExit,
        KeyComboToggleQuickMenu,
        KeyComboZoomIn,
        KeyComboZoomOut,
        KeyComboZoomReset,
        KeyComboPanLeft,
        KeyComboPanRight,
        KeyComboPanUp,
        KeyComboPanDown,
        KeyComboToggleKeyboardGrab,
        KeyComboMax
    };

    GamepadState*
    findStateForGamepad(SDL_JoystickID id);

    void sendGamepadState(GamepadState* state);

    void sendGamepadBatteryState(GamepadState* state, SDL_JoystickPowerLevel level);

    void handleAbsoluteFingerEvent(SDL_TouchFingerEvent* event);

    // Mode-agnostic overlay hit-test; called before the absolute/relative
    // split so the MENU/KBD/TOUCH-MODE buttons work in both touch modes. Returns
    // true if consumed.
    bool handleTouchOverlayFingerEvent(SDL_TouchFingerEvent* event);

    void emulateAbsoluteFingerEvent(SDL_TouchFingerEvent* event);

    void disableTouchFeedback();

    void handleRelativeFingerEvent(SDL_TouchFingerEvent* event);

    void performSpecialKeyCombo(KeyCombo combo);

    static
    Uint32 longPressTimerCallback(Uint32 interval, void* param);

    static
    Uint32 mouseEmulationTimerCallback(Uint32 interval, void* param);

    static
    Uint32 releaseLeftButtonTimerCallback(Uint32 interval, void* param);

    static
    Uint32 releaseRightButtonTimerCallback(Uint32 interval, void* param);

    static
    Uint32 dragTimerCallback(Uint32 interval, void* param);

    SDL_Window* m_Window;
    bool m_MultiController;
    bool m_GamepadMouse;
    bool m_SwapMouseButtons;
    bool m_ReverseScrollDirection;
    bool m_SwapFaceButtons;

    bool m_MouseWasInVideoRegion;
    bool m_PendingMouseButtonsAllUpOnVideoRegionLeave;
    bool m_PointerRegionLockActive;
    bool m_PointerRegionLockToggledByUser;

    int m_GamepadMask;
    GamepadState m_GamepadState[MAX_GAMEPADS];
    QSet<short> m_KeysDown;
    // Scancodes whose key-DOWN the Quick Menu consumed; their key-UP
    // must be swallowed too — but a key held since BEFORE the menu opened must still get
    // its release sent to the host (stuck-key fix).
    QSet<int> m_MenuConsumedKeys;
    bool m_FakeMouseCaptureActive;
    bool m_KeyboardCaptureActive;
    QString m_OldIgnoreDevices;
    QString m_OldIgnoreDevicesExcept;
    QStringList m_IgnoreDeviceGuids;
    StreamingPreferences::CaptureSysKeysMode m_CaptureSystemKeysMode;
    int m_MouseCursorCapturedVisibilityState;

    struct {
        KeyCombo keyCombo;
        SDL_Keycode keyCode;
        SDL_Scancode scanCode;
        bool enabled;
    } m_SpecialKeyCombos[KeyComboMax];

    SDL_TouchFingerEvent m_LastTouchDownEvent;
    SDL_TouchFingerEvent m_LastTouchUpEvent;
    SDL_TimerID m_LongPressTimer;
    int m_StreamWidth;
    int m_StreamHeight;
    bool m_AbsoluteMouseMode;
    bool m_AbsoluteTouchMode;
    bool m_DisabledTouchFeedback;

    // Vibemis: finger currently captured by the on-screen touch overlay
    // buttons; its motion/up events are swallowed so the host never sees an
    // unbalanced touch sequence (see abstouch.cpp).
    SDL_FingerID m_TouchOverlayFinger;
    // Dense pointer-id slots for native touch passthrough (abstouch.cpp) —
    // hosts reject injection ids >= their max contact count, so raw finger ids can't
    // be forwarded. 10 matches typical InitializeTouchInjection limits.
    SDL_FingerID m_TouchSlotFinger[10] = {};
    bool m_TouchSlotActive[10] = {};
    bool m_TouchOverlayFingerActive;

    SDL_TouchFingerEvent m_TouchDownEvent[MAX_FINGERS];
    SDL_TimerID m_LeftButtonReleaseTimer;
    SDL_TimerID m_RightButtonReleaseTimer;
    SDL_TimerID m_DragTimer;
    char m_DragButton;
    int m_NumFingersDown;

    static const int k_ButtonMap[];
};
