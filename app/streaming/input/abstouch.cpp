#include "input.h"

// session.h (Qt-heavy) must precede SDL_syswm.h: the latter drags in Xlib.h, whose
// KeyPress/None/Expose macros poison QEvent's enum if Qt headers come after it.
#include "streaming/session.h"

#include <Limelight.h>
#include "SDL_compat.h"
#include <SDL_syswm.h>
#include "streaming/streamutils.h"

#include <QtMath>
#include <QDebug>

// How long the fingers must be stationary to start a right click
#define LONG_PRESS_ACTIVATION_DELAY 650

// How far the finger can move before it cancels a right click
#define LONG_PRESS_ACTIVATION_DELTA 0.01f

// How long the double tap deadzone stays in effect between touch up and touch down
#define DOUBLE_TAP_DEAD_ZONE_DELAY 250

// How far the finger can move before it can override the double tap deadzone
#define DOUBLE_TAP_DEAD_ZONE_DELTA 0.025f

Uint32 SdlInputHandler::longPressTimerCallback(Uint32, void*)
{
    // Raise the left click and start a right click
    LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
    LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_RIGHT);

    return 0;
}

void SdlInputHandler::disableTouchFeedback()
{
    SDL_SysWMinfo info;

    SDL_VERSION(&info.version);
    SDL_GetWindowWMInfo(m_Window, &info);

#ifdef Q_OS_WIN32
    if (info.subsystem == SDL_SYSWM_WINDOWS) {
        auto fnSetWindowFeedbackSetting = (decltype(SetWindowFeedbackSetting)*)GetProcAddress(GetModuleHandleW(L"user32.dll"), "SetWindowFeedbackSetting");
        if (fnSetWindowFeedbackSetting) {
            constexpr FEEDBACK_TYPE feedbackTypes[] = {
                FEEDBACK_TOUCH_CONTACTVISUALIZATION,
                FEEDBACK_PEN_BARRELVISUALIZATION,
                FEEDBACK_PEN_TAP,
                FEEDBACK_PEN_DOUBLETAP,
                FEEDBACK_PEN_PRESSANDHOLD,
                FEEDBACK_PEN_RIGHTTAP,
                FEEDBACK_TOUCH_TAP,
                FEEDBACK_TOUCH_DOUBLETAP,
                FEEDBACK_TOUCH_PRESSANDHOLD,
                FEEDBACK_TOUCH_RIGHTTAP,
                FEEDBACK_GESTURE_PRESSANDTAP,
            };

            for (FEEDBACK_TYPE ft : feedbackTypes) {
                BOOL val = FALSE;
                fnSetWindowFeedbackSetting(info.info.win.window, ft, 0, sizeof(val), &val);
            }
        }
    }
#endif
}

// Vibemis BL-1748: mode-agnostic on-screen touch-overlay hit-test. The MENU
// (top-left) / KBD (top-right) buttons are drawn in BOTH absolute and relative
// touch modes, but the interception used to live only in handleAbsoluteFingerEvent.
// In relative / virtual-trackpad mode the tap fell through to handleRelativeFingerEvent
// and was forwarded to the host as a click, so the buttons were inert. This method is
// now called from handleTouchFingerEvent BEFORE the absolute/relative split, so a tap
// on a button is consumed in either mode: MENU toggles the Quick Menu, KBD opens its
// text-send view. The rest of the captured finger's gesture (motion/up) is swallowed
// too so neither host path ever sees an unbalanced touch sequence. Returns true when
// the event was consumed (caller must stop processing it), false otherwise.
bool SdlInputHandler::handleTouchOverlayFingerEvent(SDL_TouchFingerEvent* event)
{
    if (m_TouchOverlayFingerActive) {
        if (event->fingerId == m_TouchOverlayFinger) {
            if (event->type == SDL_FINGERUP) {
                m_TouchOverlayFingerActive = false;
            }
            // Eat the rest of the captured finger's gesture.
            return true;
        }
        // A different finger while one is captured — let it be processed normally.
        return false;
    }

    if (event->type == SDL_FINGERDOWN &&
        Session::get() != nullptr &&
        Session::get()->getOverlayManager().isOverlayEnabled(Overlay::OverlayTouchButtonMenu)) {
        int windowWidth, windowHeight;
        SDL_GetWindowSize(m_Window, &windowWidth, &windowHeight);

        // Maintainer-caught (2026-07-13): the buttons are COMPOSITED INTO THE VIDEO
        // FRAME in STREAM pixels, but this hit-test measured raw WINDOW pixels from
        // the window origin. Under gamescope scaling / letterboxing the two spaces
        // diverge, so taps on the visible button fell outside the hit rect and were
        // forwarded to the host (Windows touch gestures fired). Map the button rects
        // through the same source->destination video transform the forwarding path
        // uses, then test in window coordinates.
        SDL_Rect hitSrc, hitDst;
        hitSrc.x = hitSrc.y = 0;
        hitSrc.w = m_StreamWidth;
        hitSrc.h = m_StreamHeight;
        hitDst.x = hitDst.y = 0;
        hitDst.w = windowWidth;
        hitDst.h = windowHeight;
        StreamUtils::scaleSourceToDestinationSurface(&hitSrc, &hitDst);
        float scaleX = (float)hitDst.w / m_StreamWidth;
        float scaleY = (float)hitDst.h / m_StreamHeight;
        int insetPxX = (int)(Overlay::TouchButtonInset * scaleX);
        int insetPxY = (int)(Overlay::TouchButtonInset * scaleY);
        int sizePxX = (int)(Overlay::TouchButtonSize * scaleX);
        int sizePxY = (int)(Overlay::TouchButtonSize * scaleY);

        int fingerX = (int)(event->x * windowWidth);
        int fingerY = (int)(event->y * windowHeight);

        if (fingerY >= hitDst.y + insetPxY &&
                fingerY <= hitDst.y + insetPxY + sizePxY) {
            bool onMenuButton = fingerX >= hitDst.x + insetPxX &&
                    fingerX <= hitDst.x + insetPxX + sizePxX;
            bool onKbdButton = fingerX >= hitDst.x + hitDst.w - insetPxX - sizePxX &&
                    fingerX <= hitDst.x + hitDst.w - insetPxX;
            if (onMenuButton || onKbdButton) {
                m_TouchOverlayFingerActive = true;
                m_TouchOverlayFinger = event->fingerId;

                // The Quick Menu lives on the Qt main thread — hop threads via a
                // queued invocation like the gamepad/keyboard intercepts do.
                QuickMenuManager* qmm = Session::get()->getQuickMenuManager();
                if (qmm != nullptr) {
                    QMetaObject::invokeMethod(qmm, onMenuButton ? "toggle" : "openTextSend",
                                              Qt::QueuedConnection);
                }
                return true;
            }
        }
    }

    return false;
}

void SdlInputHandler::handleAbsoluteFingerEvent(SDL_TouchFingerEvent* event)
{
    SDL_Rect src, dst;
    int windowWidth, windowHeight;

    SDL_GetWindowSize(m_Window, &windowWidth, &windowHeight);

    src.x = src.y = 0;
    src.w = m_StreamWidth;
    src.h = m_StreamHeight;

    dst.x = dst.y = 0;
    dst.w = windowWidth;
    dst.h = windowHeight;

    // Scale window-relative events to be video-relative and clamp to video region
    StreamUtils::scaleSourceToDestinationSurface(&src, &dst);
    float vidrelx = qMin(qMax((int)(event->x * windowWidth), dst.x), dst.x + dst.w) - dst.x;
    float vidrely = qMin(qMax((int)(event->y * windowHeight), dst.y), dst.y + dst.h) - dst.y;

    uint8_t eventType;
    switch (event->type) {
    case SDL_FINGERDOWN:
        eventType = LI_TOUCH_EVENT_DOWN;
        break;
    case SDL_FINGERMOTION:
        eventType = LI_TOUCH_EVENT_MOVE;
        break;
    case SDL_FINGERUP:
        eventType = LI_TOUCH_EVENT_UP;
        break;
    default:
        return;
    }

    uint32_t pointerId;

    // If the pointer ID is larger than we can fit, just CRC it and use that as the ID.
    if ((uint64_t)event->fingerId > UINT32_MAX) {
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
        QByteArrayView bav((char*)&event->fingerId, sizeof(event->fingerId));
        pointerId = qChecksum(bav);
#else
        pointerId = qChecksum((char*)&event->fingerId, sizeof(event->fingerId));
#endif
    }
    else {
        pointerId = (uint32_t)event->fingerId;
    }

    // Try to send it as a native pen/touch event, otherwise fall back to our touch emulation
    if (LiGetHostFeatureFlags() & LI_FF_PEN_TOUCH_EVENTS) {
#if SDL_VERSION_ATLEAST(2, 0, 22)
        bool isPen = false;

        int numTouchDevices = SDL_GetNumTouchDevices();
        for (int i = 0; i < numTouchDevices; i++) {
            if (event->touchId == SDL_GetTouchDevice(i)) {
                const char* touchName = SDL_GetTouchName(i);

                // SDL will report "pen" as the name of pen input devices on Windows.
                // https://github.com/libsdl-org/SDL/pull/5926
                isPen = touchName && SDL_strcmp(touchName, "pen") == 0;
                break;
            }
        }

        if (isPen) {
            // Pens keep the reported pressure as-is: 0.0 while in range is a REAL state
            // (hovering nib) that the host must see to distinguish hover from contact.
            LiSendPenEvent(eventType, LI_TOOL_TYPE_PEN, 0, vidrelx / dst.w, vidrely / dst.h, event->pressure,
                           0.0f, 0.0f, LI_ROT_UNKNOWN, LI_TILT_UNKNOWN);
        }
        else
#endif
        {
            // BL-2015: many touchscreens (the Legion Go panel included) report SDL finger
            // pressure as 0.0, and Apollo-lineage hosts inject pressure<=0 DOWN/MOVE as
            // hover — the pointer relocates but never makes contact, so taps don't click
            // and drags don't draw. A capacitive finger can't hover: treat missing
            // pressure as full contact. UP keeps 0.0 (contact release).
            float pressure = event->pressure;
            if (eventType != LI_TOUCH_EVENT_UP && pressure <= 0.0f) {
                pressure = 1.0f;
            }

            int err = LiSendTouchEvent(eventType, pointerId, vidrelx / dst.w, vidrely / dst.h, pressure,
                                       0.0f, 0.0f, LI_ROT_UNKNOWN);

            // BL-2015 observability (test-agent ask): the send path was previously
            // unloggable. DOWN/UP only — never per-MOVE (input-path logging caused the
            // BL-1619 lag storm); moves are counted and summarized on UP. Single shared
            // counter: diagnostic-grade for the dominant single-finger case.
            static uint32_t s_MovesSinceDown = 0;
            if (eventType == LI_TOUCH_EVENT_DOWN) {
                s_MovesSinceDown = 0;
                qDebug() << "Touch DOWN id" << pointerId
                         << "norm" << vidrelx / dst.w << vidrely / dst.h
                         << "pressure" << pressure << "err" << err;
            }
            else if (eventType == LI_TOUCH_EVENT_MOVE) {
                s_MovesSinceDown++;
            }
            else {
                qDebug() << "Touch UP id" << pointerId << "after" << s_MovesSinceDown
                         << "moves, err" << err;
            }
        }

        if (!m_DisabledTouchFeedback) {
            // Disable touch feedback when passing touch natively
            disableTouchFeedback();
            m_DisabledTouchFeedback = true;
        }
    }
    else {
        emulateAbsoluteFingerEvent(event);
    }
}

void SdlInputHandler::emulateAbsoluteFingerEvent(SDL_TouchFingerEvent* event)
{
    // Observations on Windows 10: x and y appear to be relative to 0,0 of the window client area.
    // Although SDL documentation states they are 0.0 - 1.0 float values, they can actually be higher
    // or lower than those values as touch events continue for touches started within the client area that
    // leave the client area during a drag motion.
    // dx and dy are deltas from the last touch event, not the first touch down.

    // Ignore touch down events with more than one finger
    if (event->type == SDL_FINGERDOWN && SDL_GetNumTouchFingers(event->touchId) > 1) {
        return;
    }

    // Ignore touch move and touch up events from the non-primary finger
    if (event->type != SDL_FINGERDOWN && event->fingerId != m_LastTouchDownEvent.fingerId) {
        return;
    }

    SDL_Rect src, dst;
    int windowWidth, windowHeight;

    SDL_GetWindowSize(m_Window, &windowWidth, &windowHeight);

    src.x = src.y = 0;
    src.w = m_StreamWidth;
    src.h = m_StreamHeight;

    dst.x = dst.y = 0;
    dst.w = windowWidth;
    dst.h = windowHeight;

    // Use the stream and window sizes to determine the video region
    StreamUtils::scaleSourceToDestinationSurface(&src, &dst);

    if (qSqrt(qPow(event->x - m_LastTouchDownEvent.x, 2) + qPow(event->y - m_LastTouchDownEvent.y, 2)) > LONG_PRESS_ACTIVATION_DELTA) {
        // Moved too far since touch down. Cancel the long press timer.
        SDL_RemoveTimer(m_LongPressTimer);
        m_LongPressTimer = 0;
    }

    // Don't reposition for finger down events within the deadzone. This makes double-clicking easier.
    if (event->type != SDL_FINGERDOWN ||
            event->timestamp - m_LastTouchUpEvent.timestamp > DOUBLE_TAP_DEAD_ZONE_DELAY ||
            qSqrt(qPow(event->x - m_LastTouchUpEvent.x, 2) + qPow(event->y - m_LastTouchUpEvent.y, 2)) > DOUBLE_TAP_DEAD_ZONE_DELTA) {
        // Scale window-relative events to be video-relative and clamp to video region
        short x = qMin(qMax((int)(event->x * windowWidth), dst.x), dst.x + dst.w);
        short y = qMin(qMax((int)(event->y * windowHeight), dst.y), dst.y + dst.h);

        // Update the cursor position relative to the video region
        LiSendMousePositionEvent(x - dst.x, y - dst.y, dst.w, dst.h);
    }

    if (event->type == SDL_FINGERDOWN) {
        m_LastTouchDownEvent = *event;

        // Start/restart the long press timer
        SDL_RemoveTimer(m_LongPressTimer);
        m_LongPressTimer = SDL_AddTimer(LONG_PRESS_ACTIVATION_DELAY,
                                        longPressTimerCallback,
                                        nullptr);

        // Left button down on finger down
        LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_LEFT);
    }
    else if (event->type == SDL_FINGERUP) {
        m_LastTouchUpEvent = *event;

        // Cancel the long press timer
        SDL_RemoveTimer(m_LongPressTimer);
        m_LongPressTimer = 0;

        // Left button up on finger up
        LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);

        // Raise right button too in case we triggered a long press gesture
        LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_RIGHT);
    }
}
