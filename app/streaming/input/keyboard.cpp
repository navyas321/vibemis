#include "streaming/session.h"
#include "settings/streamingpreferences.h"
#include "backend/quickmenumanager.h"

#include <Limelight.h>
#include "SDL_compat.h"

#include "keyremotemap.h"

// VIBEMIS_DEBUG_KEYBOARD=1 logs each local key next to the remote event it turns
// into. Read once per run, so it costs nothing when unset.
static bool
debugKeyboardEvents()
{
    static const bool enabled = qgetenv("VIBEMIS_DEBUG_KEYBOARD") == "1";
    return enabled;
}

void SdlInputHandler::performSpecialKeyCombo(KeyCombo combo)
{
    switch (combo) {
    case KeyComboQuit:
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                    "Detected quit key combo");

        // Push a quit event to the main loop
        SDL_Event event;
        event.type = SDL_QUIT;
        event.quit.timestamp = SDL_GetTicks();
        SDL_PushEvent(&event);
        break;

    case KeyComboUngrabInput:
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                    "Detected mouse capture toggle combo");

        // Stop handling future input
        setCaptureActive(!isCaptureActive());

        // Force raise all keys to ensure they aren't stuck,
        // since we won't get their key up events.
        raiseAllKeys();
        break;

    case KeyComboToggleFullScreen:
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                    "Detected full-screen toggle combo");
        Session::s_ActiveSession->toggleFullscreen();

        // Force raise all keys just be safe across this full-screen/windowed
        // transition just in case key events get lost.
        raiseAllKeys();
        break;

    case KeyComboToggleStatsOverlay:
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                    "Detected stats toggle combo");

        // Toggle the stats overlay
        Session::get()->getOverlayManager().setOverlayState(Overlay::OverlayDebug,
                                                            !Session::get()->getOverlayManager().isOverlayEnabled(Overlay::OverlayDebug));
        break;

    case KeyComboToggleMouseMode:
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                    "Detected mouse mode toggle combo");

        // Uncapture input
        setCaptureActive(false);

        // Toggle mouse mode
        m_AbsoluteMouseMode = !m_AbsoluteMouseMode;

        // Recapture input
        setCaptureActive(true);
        break;

    case KeyComboToggleCursorHide:
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                    "Detected show mouse combo");

        if (!SDL_GetRelativeMouseMode()) {
            m_MouseCursorCapturedVisibilityState = !m_MouseCursorCapturedVisibilityState;
            SDL_ShowCursor(m_MouseCursorCapturedVisibilityState);
        }
        else {
            SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                        "Cursor can only be shown in remote desktop mouse mode");
        }
        break;

    case KeyComboToggleMinimize:
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                    "Detected minimize combo");
        SDL_MinimizeWindow(m_Window);
        break;

    case KeyComboPasteText:
    {
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                    "Detected type clipboard text combo");

        // Force raise all keys to ensure that none of them interfere
        // with the text we're going to type.
        raiseAllKeys();

        char* text;
        if (SDL_HasClipboardText() && (text = SDL_GetClipboardText()) != nullptr) {
            // Sending both CR and LF will lead to two newlines in the destination for
            // each newline in the source, so we fix up any CRLFs into just a single LF.
            for (char* c = text; *c != 0; c++) {
                if (*c == '\r' && *(c + 1) == '\n') {
                    // We're using strlen() rather than strlen() - 1 since we need to add 1
                    // to copy the null terminator which is not included in strlen()'s count.
                    memmove(c, c + 1, strlen(c));
                }
            }

            // Send this text to the PC
            LiSendUtf8TextEvent(text, (unsigned int)strlen(text));

            // SDL_GetClipboardText() allocates, so we must free
            SDL_free((void*)text);
        }
        else {
            SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                        "No text in clipboard to paste!");
        }
        break;
    }

    case KeyComboTogglePointerRegionLock:
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                    "Detected pointer region lock toggle combo");
        m_PointerRegionLockActive = !m_PointerRegionLockActive;

        // Remember that the user changed this manually, so we don't mess with it anymore
        // during windowed <-> full-screen transitions.
        m_PointerRegionLockToggledByUser = true;

        // Apply the new region lock
        updatePointerRegionLock();
        break;

    case KeyComboQuitAndExit:
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                    "Detected quitAndExit key combo");

        // Indicate that we want to exit afterwards
        // Vibemis (BL-2226): keep the fork's session-exit API; upstream's
        // setShouldExit(true) belongs to the un-adopted QML lifecycle refactor.
        Session::get()->setShouldExitAfterQuit();

        // Push a quit event to the main loop
        SDL_Event quitExitEvent;
        quitExitEvent.type = SDL_QUIT;
        quitExitEvent.quit.timestamp = SDL_GetTicks();
        SDL_PushEvent(&quitExitEvent);
        break;

    // KeyComboToggleServerCommands removed - now handled through QuickMenu

    case KeyComboToggleQuickMenu:
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "Detected quick menu toggle combo");

        // Access the QuickMenuManager through the Session
        if (Session::get()) {
            Session::get()->toggleQuickMenu();
        }
        break;

    case KeyComboZoomIn:
    case KeyComboZoomOut:
    case KeyComboZoomReset: {
        // Vibemis in-stream video zoom (centered). Read by StreamUtils each frame.
        auto prefs = StreamingPreferences::get();
        if (prefs) {
            double z = prefs->videoZoomFactor;
            if (combo == KeyComboZoomReset) {
                z = 1.0;
            } else if (combo == KeyComboZoomIn) {
                z += 0.25;
            } else {
                z -= 0.25;
            }
            if (z < 1.0) z = 1.0;
            if (z > 4.0) z = 4.0;
            prefs->videoZoomFactor = z;
            if (combo == KeyComboZoomReset || z <= 1.0) {
                // Re-center the pan when zoom is reset / back to 1x.
                prefs->videoPanX = 0.0;
                prefs->videoPanY = 0.0;
            }
            SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "Video zoom set to %.2fx", z);
        }
        break;
    }

    case KeyComboPanLeft:
    case KeyComboPanRight:
    case KeyComboPanUp:
    case KeyComboPanDown: {
        // Vibemis in-stream pan (only visibly effective while zoomed). Read by StreamUtils.
        auto prefs = StreamingPreferences::get();
        if (prefs) {
            const double step = 0.2;
            if (combo == KeyComboPanLeft)  prefs->videoPanX -= step;
            if (combo == KeyComboPanRight) prefs->videoPanX += step;
            if (combo == KeyComboPanUp)    prefs->videoPanY -= step;
            if (combo == KeyComboPanDown)  prefs->videoPanY += step;
            if (prefs->videoPanX < -1.0) prefs->videoPanX = -1.0;
            if (prefs->videoPanX >  1.0) prefs->videoPanX =  1.0;
            if (prefs->videoPanY < -1.0) prefs->videoPanY = -1.0;
            if (prefs->videoPanY >  1.0) prefs->videoPanY =  1.0;
            SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "Video pan set to (%.2f, %.2f)",
                        prefs->videoPanX, prefs->videoPanY);
        }
        break;
    }

    case KeyComboToggleKeyboardGrab:
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                    "Detected keyboard grab toggle combo");

        // Toggle the system key capture mode
        if (isSystemKeyCaptureActive()) {
            m_CaptureSystemKeysMode = StreamingPreferences::CSK_OFF;
        }
        else {
            m_CaptureSystemKeysMode = StreamingPreferences::CSK_ALWAYS;
        }

        updateKeyboardGrabState();
        break;

    default:
        Q_UNREACHABLE();
    }
}

void SdlInputHandler::handleKeyEvent(SDL_KeyboardEvent* event)
{
    short keyCode;
    char modifiers;
    bool nonNormalized = false;

    if (event->repeat) {
        // Ignore repeat key down events
        SDL_assert(event->state == SDL_PRESSED);
        return;
    }

    // When the Quick Menu is open, route unmodified navigation keys into it instead of
    // sending them to the host. The toggle combo (Ctrl+Alt+Shift+\) still reaches the
    // special-combo handler below because we only intercept keys with no combo modifiers.
    {
        Session* sess = Session::get();
        bool menuOpen = sess && sess->getQuickMenuManager() && sess->getQuickMenuManager()->isVisible();
        bool noComboMods = !(event->keysym.mod & (KMOD_CTRL | KMOD_ALT | KMOD_GUI));
        if (!menuOpen && !m_MenuConsumedKeys.isEmpty()) {
            // Menu closed with entries pending — drop them so a stale entry can't
            // swallow an unrelated future release.
            m_MenuConsumedKeys.clear();
        }
        if (menuOpen && sess->getQuickMenuManager()->isTextInputActive() && noComboMods) {
            // The menu's text field is focused. Make sure SDL emits
            // SDL_TEXTINPUT (idempotent; we're on the SDL thread) so typed characters flow
            // to handleTextInputEvent -> injectText. Handle editing keys here; swallow the
            // rest so the host never sees them while the user is typing into the menu.
            if (event->state == SDL_PRESSED) {
                SDL_StartTextInput();
                int editKey = 0;
                switch (event->keysym.sym) {
                case SDLK_BACKSPACE: editKey = Qt::Key_Backspace; break;
                case SDLK_DELETE:    editKey = Qt::Key_Delete;    break;
                case SDLK_LEFT:      editKey = Qt::Key_Left;      break;
                case SDLK_RIGHT:     editKey = Qt::Key_Right;     break;
                case SDLK_RETURN:
                case SDLK_KP_ENTER:  editKey = Qt::Key_Return;    break;  // submit (Send)
                case SDLK_ESCAPE:    editKey = Qt::Key_Escape;    break;  // leave text mode
                default: break;
                }
                if (editKey) {
                    QMetaObject::invokeMethod(sess->getQuickMenuManager(), "injectKey",
                                              Qt::QueuedConnection, Q_ARG(int, editKey));
                }
            }
            return; // consume; printable chars arrive via SDL_TEXTINPUT
        }
        if (menuOpen && noComboMods) {
            bool navKey = false;
            int qtKey = 0;
            switch (event->keysym.sym) {
            case SDLK_UP:       qtKey = Qt::Key_Up;     navKey = true; break;
            case SDLK_DOWN:     qtKey = Qt::Key_Down;   navKey = true; break;
            case SDLK_LEFT:     qtKey = Qt::Key_Left;   navKey = true; break;
            case SDLK_RIGHT:    qtKey = Qt::Key_Right;  navKey = true; break;
            case SDLK_RETURN:   qtKey = Qt::Key_Return; navKey = true; break;
            case SDLK_KP_ENTER: qtKey = Qt::Key_Enter;  navKey = true; break;
            case SDLK_ESCAPE:   qtKey = Qt::Key_Escape; navKey = true; break;
            default: break;
            }
            if (navKey) {
                if (event->state == SDL_PRESSED) {
                    QMetaObject::invokeMethod(sess->getQuickMenuManager(), "injectKey",
                                              Qt::QueuedConnection, Q_ARG(int, qtKey));
                    m_MenuConsumedKeys.insert(event->keysym.scancode);
                    return;
                }
                // Only swallow a RELEASE whose press we consumed.
                // A nav key held since before the menu opened was sent DOWN to the host —
                // eating its release left the key stuck down host-side.
                if (m_MenuConsumedKeys.remove(event->keysym.scancode)) {
                    return;
                }
                // fall through: deliver the release to the host as usual
            }
        }
    }

    // Check for our special key combos
    if ((event->state == SDL_PRESSED) &&
            (event->keysym.mod & KMOD_CTRL) &&
            (event->keysym.mod & KMOD_ALT) &&
            (event->keysym.mod & KMOD_SHIFT)) {
        // First we test the SDLK combos for matches,
        // that way we ensure that latin keyboard users
        // can match to the key they see on their keyboards.
        // If nothing matches that, we'll then go on to
        // checking scancodes so non-latin keyboard users
        // can have working hotkeys (though possibly in
        // odd positions). We must do all SDLK tests before
        // any scancode tests to avoid issues in cases
        // where the SDLK for one shortcut collides with
        // the scancode of another.

        for (int i = 0; i < KeyComboMax; i++) {
            if (m_SpecialKeyCombos[i].enabled && event->keysym.sym == m_SpecialKeyCombos[i].keyCode) {
                performSpecialKeyCombo(m_SpecialKeyCombos[i].keyCombo);
                return;
            }
        }

        for (int i = 0; i < KeyComboMax; i++) {
            if (m_SpecialKeyCombos[i].enabled && event->keysym.scancode == m_SpecialKeyCombos[i].scanCode) {
                performSpecialKeyCombo(m_SpecialKeyCombos[i].keyCombo);
                return;
            }
        }
    }

    // Set modifier flags
    modifiers = 0;
    if (event->keysym.mod & KMOD_CTRL) {
        modifiers |= MODIFIER_CTRL;
    }
    if (event->keysym.mod & KMOD_ALT) {
        modifiers |= MODIFIER_ALT;
    }
    if (event->keysym.mod & KMOD_SHIFT) {
        modifiers |= MODIFIER_SHIFT;
    }
    if (event->keysym.mod & KMOD_GUI) {
        if (isSystemKeyCaptureActive()) {
            modifiers |= MODIFIER_META;
        }
    }

    // Resolve the remote key from the physical position SDL reports. The table
    // lives in keyremotemap.h so it can be unit tested without a Session (see
    // tests/keyboard); that header explains what the returned VK means and when
    // it must be sent un-normalised.
    KeyRemoteMap::RemoteKey remoteKey = KeyRemoteMap::mapKeyPress(event->keysym.sym,
                                                                  event->keysym.scancode,
                                                                  isSystemKeyCaptureActive());

    // VIBEMIS_DEBUG_KEYBOARD=1 prints the whole translation for every key, which
    // is what you need to tell "SDL handed us the wrong scancode" apart from
    // "our table is wrong" apart from "the host mapped it wrong". Vibemis is an
    // SDL app, so this layer has no Qt key / nativeScanCode and SDL does not
    // expose the native X11 keycode: the scancode is the physical position SDL
    // resolved, the keysym is the character the local layout puts on that key.
    if (debugKeyboardEvents()) {
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                    "Keyboard: %s scancode=%d(%s) keysym=0x%04X(%s) mod=0x%X -> action=%d vk=0x%02X flags=%s",
                    event->state == SDL_PRESSED ? "down" : "up",
                    (int)event->keysym.scancode,
                    SDL_GetScancodeName(event->keysym.scancode),
                    (unsigned int)event->keysym.sym,
                    SDL_GetKeyName(event->keysym.sym),
                    (unsigned int)event->keysym.mod,
                    (int)remoteKey.action,
                    (int)remoteKey.vkCode,
                    remoteKey.nonNormalized ? "SS_KBE_FLAG_NON_NORMALIZED" : "0");
    }

    if (remoteKey.action != KeyRemoteMap::ActionSend) {
        if (remoteKey.action == KeyRemoteMap::ActionUnhandled) {
            SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                        "Unhandled button event: %d",
                         event->keysym.scancode);
        }
        return;
    }

    keyCode = remoteKey.vkCode;
    nonNormalized = remoteKey.nonNormalized;
    // Track the key state so we always know which keys are down
    if (event->state == SDL_PRESSED) {
        m_KeysDown.insert(keyCode, nonNormalized);
    }
    else {
        m_KeysDown.remove(keyCode);
    }

    LiSendKeyboardEvent2(0x8000 | keyCode,
                        event->state == SDL_PRESSED ?
                            KEY_ACTION_DOWN : KEY_ACTION_UP,
                        modifiers,
                        nonNormalized ? SS_KBE_FLAG_NON_NORMALIZED : 0);
}


void SdlInputHandler::handleTextInputEvent(SDL_TextInputEvent* event)
{
    // Forward typed text to the Quick Menu's focused text field. When the
    // field isn't active the host still receives keystrokes via SDL_KEYDOWN scancodes, so
    // we only consume text input while the menu field has focus.
    Session* sess = Session::get();
    if (sess && sess->getQuickMenuManager() &&
        sess->getQuickMenuManager()->isVisible() &&
        sess->getQuickMenuManager()->isTextInputActive()) {
        QMetaObject::invokeMethod(sess->getQuickMenuManager(), "injectText",
                                  Qt::QueuedConnection,
                                  Q_ARG(QString, QString::fromUtf8(event->text)));
    }
}
