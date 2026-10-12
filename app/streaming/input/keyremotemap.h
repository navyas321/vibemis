#pragma once

// ---------------------------------------------------------------------------
// Keyboard mapping: local key press -> remote keyboard event.
//
// Extracted from SdlInputHandler::handleKeyEvent() so the table can be unit
// tested (tests/keyboard) without a Session, an SDL window or a host. The
// function below is pure: it takes what SDL reports for one key and returns
// what must go on the wire.
//
// What goes on the wire (see LiSendKeyboardEvent2()) is
//
//      0x8000 | <Windows virtual-key code>   +  optional SS_KBE_FLAG_NON_NORMALIZED
//
// and the flag decides how the host reads that VK code:
//
//   * normalised (flag clear): the VK names a key by its POSITION on a US/ANSI
//     board. Apollo/Sunshine look it up in a hardcoded US table
//     (src/platform/windows/keylayout.h, VK_TO_SCANCODE_MAP) and inject the
//     matching scancode, so the host's own keyboard layout decides which
//     character comes out. This is what makes an AZERTY client against an AZERTY
//     host work, and it is why handleKeyEvent() deliberately derives the VK from
//     the SDL *scancode* (physical position) instead of the keysym (character).
//
//   * non-normalised (flag set): the VK is meant to be read in the HOST's active
//     layout, which the client cannot see. Clients use it only for keys that
//     have no US position at all, and it therefore assumes host layout ==
//     client layout -- the same assumption every remote-play client makes for a
//     keyboard-specific key.
//
// Vibemis never sends a raw scancode: the protocol carries VK codes, and the
// tables above are what turns them into scancodes on the host.
// ---------------------------------------------------------------------------

#include <SDL_keycode.h>
#include <SDL_scancode.h>

// Windows virtual-key codes (winuser.h) that this table needs. Defined locally
// because the SDL headers do not ship them and the app builds without the
// Windows SDK on Linux.
#ifndef VK_0
#define VK_0 0x30
#endif
#ifndef VK_A
#define VK_A 0x41
#endif
#ifndef VK_F1
#define VK_F1 0x70
#endif
#ifndef VK_F13
#define VK_F13 0x7C
#endif
#ifndef VK_NUMPAD0
#define VK_NUMPAD0 0x60
#endif
#ifndef VK_OEM_5
#define VK_OEM_5 0xDC
#endif
#ifndef VK_OEM_102
#define VK_OEM_102 0xE2
#endif
// The two keys the Brazilian ABNT/ABNT2 keyboards add to the 104-key US set.
// VK_ABNT_C1 is the extra bottom-right key: `/` unshifted, `?` with Shift, `°`
// with AltGr (ReactOS dll/keyboard/kbdbr and Wine include/kbd.h both agree).
#ifndef VK_ABNT_C1
#define VK_ABNT_C1 0xC1
#endif

namespace KeyRemoteMap {

enum Action : unsigned char {
    // Put vkCode on the wire.
    ActionSend,
    // A key we know but must not forward (the Windows key while the host is not
    // capturing system keys). Silent, as it has always been.
    ActionDrop,
    // Not in the table at all. The caller logs it, because it means a real key
    // died on the client.
    ActionUnhandled,
};

struct RemoteKey {
    Action action;
    short vkCode;
    // true -> send SS_KBE_FLAG_NON_NORMALIZED (vkCode is a host-layout VK).
    bool nonNormalized;
};

inline RemoteKey drop()
{
    return RemoteKey{ActionDrop, 0, false};
}

inline RemoteKey unhandled()
{
    return RemoteKey{ActionUnhandled, 0, false};
}

inline RemoteKey send(short vkCode, bool nonNormalized = false)
{
    return RemoteKey{ActionSend, vkCode, nonNormalized};
}

// SDL reports SDL_SCANCODE_INTERNATIONAL1 for X11 keycode 97 (XKB <AB11>), the
// extra key Brazilian and Japanese keyboards put between `/` and Right Shift.
// It is a positional placeholder, not a key: SDL's X11 backend fills its
// keycode -> scancode table from a fixed layout (xfree86_scancode_table2 in
// src/events/scancodes_xfree86.h) and only replaces an entry from the keysym
// when the keysym maps to a NON-character scancode, so the placeholder survives
// on any layout that types a normal character there. What the key actually is
// depends on the layout:
//
//   br / abnt2      -> `/` `?`            (XKB <AB11>: slash, question, degree, questiondown)
//   br / abnt       -> `\` `|`            (same key position, backslash, bar)
//   jp              -> the RO key         (`\` / yen)
//   anything else   -> usually nothing
//
// Resolve it from the keysym -- the one signal that says what the local layout
// really puts on that key -- and keep the legacy answer for every other keysym.
inline RemoteKey mapInternationalKey(SDL_Keycode keysym)
{
    switch (keysym) {
    // The ABNT/ABNT2 `/` key. No US board has a key at this position, so there
    // is no US-position VK that can describe it: VK_OEM_2 (`/?` on US) would
    // make an ABNT2 host type `;`, because that is what an ABNT2 keyboard has
    // where the US layout has `/`. Send the VK the Windows Brazilian layout
    // assigns to this physical key instead and tell the host not to normalise
    // it, exactly as the ISO extra key below does.
    //
    // SDLK_QUESTION is for the SDL builds/backends that report the shifted
    // keysym on a Shift-modified press (SDL 2 X11 reports the base SDLK_SLASH
    // and puts Shift in the modifier mask; the Wayland backend and SDL 3 do not
    // always). Both name the same physical key, so both must land on the same
    // VK.
    //
    // AltGr levels are listed too. They are unreachable on SDL 2's X11 backend
    // (measured with XTEST on a real ABNT2 board: with RALT held, XFilterEvent
    // swallows the KeyPress and only a SDL_TEXTINPUT of the degree sign arrives),
    // but the Wayland backend and SDL 3 can report them, and they must not matter:
    // every level of one physical key has to resolve to one remote key, because
    // handleKeyEvent() tracks the press and the release by the remote VK. A table
    // that answered 0xC1 for `/` and 0xE2 for the AltGr level would leave the host
    // holding a key whose release went to a different key.
    //
    // This assumes host layout == client layout, the same bet the ISO extra key
    // and the JIS keys below already make: a client whose layout types `/` on that
    // key is a Brazilian keyboard, and its owner will have set the host to ABNT2
    // too. On a host with another layout the key does nothing, which still beats
    // today's `\`. Two host facts bound that trade-off:
    //   * VK_ABNT_C1 is scancode 0x73 of the Windows Brazilian layout (ReactOS
    //     dll/keyboard/kbdbr scan-code -> VK table), and it is NOT E0-extended,
    //     so a host that resolves it with MapVirtualKey() injects the right key
    //     without needing an extended-key flag.
    //   * The flag only travels to a Sunshine-family host: moonlight-common-c
    //     InputStream.c sets `keyboard.flags = IS_SUNSHINE() ? flags : 0`, so
    //     against GFE this key falls back to the old normalized 0xE2 behaviour.
    //     Apollo and Vibepollo advertise as Sunshine, which is who this is for.
    case SDLK_SLASH:
    case SDLK_QUESTION:
    case 0x00b0: // XK_degree       - AltGr level of this key (SDL 2 names no keysym above U+007E)
    case 0x00bf: // XK_questiondown - AltGr + Shift level
        return send(VK_ABNT_C1, true);

    // Everything else, including the JIS RO key that this scancode was written
    // for (fabb4fda "Fix INTERNATIONAL keys wouldn't work properly") and the
    // br/abnt variant where the key is `\` `|`: the ISO extra-key VK, unchanged.
    default:
        return send(VK_OEM_102, true);
    }
}

// Resolve one key press.
//
//   keysym            - event->keysym.sym  (character after local layout)
//   scancode          - event->keysym.scancode (physical position per SDL)
//   systemKeysCaptured - whether the host is allowed to receive Win/Super
inline RemoteKey mapKeyPress(SDL_Keycode keysym, SDL_Scancode scancode, bool systemKeysCaptured)
{
    // We explicitly use the scancode here because the host tries to correct for
    // AZERTY layouts, and that depends on receiving VK_ values matching a
    // QWERTY layout.
    if (scancode >= SDL_SCANCODE_1 && scancode <= SDL_SCANCODE_9) {
        // SDL defines SDL_SCANCODE_0 > SDL_SCANCODE_9, so we need to handle that manually
        return send((short)((scancode - SDL_SCANCODE_1) + VK_0 + 1));
    }

    if (scancode >= SDL_SCANCODE_A && scancode <= SDL_SCANCODE_Z) {
        return send((short)((scancode - SDL_SCANCODE_A) + VK_A));
    }

    if (scancode >= SDL_SCANCODE_F1 && scancode <= SDL_SCANCODE_F12) {
        return send((short)((scancode - SDL_SCANCODE_F1) + VK_F1));
    }

    if (scancode >= SDL_SCANCODE_F13 && scancode <= SDL_SCANCODE_F24) {
        return send((short)((scancode - SDL_SCANCODE_F13) + VK_F13));
    }

    if (scancode >= SDL_SCANCODE_KP_1 && scancode <= SDL_SCANCODE_KP_9) {
        // SDL defines SDL_SCANCODE_KP_0 > SDL_SCANCODE_KP_9, so we need to handle that manually
        return send((short)((scancode - SDL_SCANCODE_KP_1) + VK_NUMPAD0 + 1));
    }

    switch (scancode) {
    case SDL_SCANCODE_BACKSPACE:
        return send(0x08);
    case SDL_SCANCODE_TAB:
        return send(0x09);
    case SDL_SCANCODE_CLEAR:
        return send(0x0C);
    case SDL_SCANCODE_KP_ENTER: // FIXME: Is this correct?
    case SDL_SCANCODE_RETURN:
        return send(0x0D);
    case SDL_SCANCODE_PAUSE:
        return send(0x13);
    case SDL_SCANCODE_CAPSLOCK:
        return send(0x14);
    case SDL_SCANCODE_ESCAPE:
        return send(0x1B);
    case SDL_SCANCODE_SPACE:
        return send(0x20);
    case SDL_SCANCODE_PAGEUP:
        return send(0x21);
    case SDL_SCANCODE_PAGEDOWN:
        return send(0x22);
    case SDL_SCANCODE_END:
        return send(0x23);
    case SDL_SCANCODE_HOME:
        return send(0x24);
    case SDL_SCANCODE_LEFT:
        return send(0x25);
    case SDL_SCANCODE_UP:
        return send(0x26);
    case SDL_SCANCODE_RIGHT:
        return send(0x27);
    case SDL_SCANCODE_DOWN:
        return send(0x28);
    case SDL_SCANCODE_SELECT:
        return send(0x29);
    case SDL_SCANCODE_EXECUTE:
        return send(0x2B);
    case SDL_SCANCODE_PRINTSCREEN:
        return send(0x2C);
    case SDL_SCANCODE_INSERT:
        return send(0x2D);
    case SDL_SCANCODE_DELETE:
        return send(0x2E);
    case SDL_SCANCODE_HELP:
        return send(0x2F);
    case SDL_SCANCODE_KP_0:
        // See comment above about why we only handle SDL_SCANCODE_KP_0 here
        return send(VK_NUMPAD0);
    case SDL_SCANCODE_0:
        // See comment above about why we only handle SDL_SCANCODE_0 here
        return send(VK_0);
    case SDL_SCANCODE_KP_MULTIPLY:
        return send(0x6A);
    case SDL_SCANCODE_KP_PLUS:
        return send(0x6B);
    case SDL_SCANCODE_KP_COMMA:
        return send(0x6C);
    case SDL_SCANCODE_KP_MINUS:
        return send(0x6D);
    case SDL_SCANCODE_KP_PERIOD:
        return send(0x6E);
    case SDL_SCANCODE_KP_DIVIDE:
        return send(0x6F);
    case SDL_SCANCODE_NUMLOCKCLEAR:
        return send(0x90);
    case SDL_SCANCODE_SCROLLLOCK:
        return send(0x91);
    case SDL_SCANCODE_LSHIFT:
        return send(0xA0);
    case SDL_SCANCODE_RSHIFT:
        return send(0xA1);
    case SDL_SCANCODE_LCTRL:
        return send(0xA2);
    case SDL_SCANCODE_RCTRL:
        return send(0xA3);
    case SDL_SCANCODE_LALT:
        return send(0xA4);
    case SDL_SCANCODE_RALT:
        return send(0xA5);
    case SDL_SCANCODE_LGUI:
        if (!systemKeysCaptured) {
            return drop();
        }
        return send(0x5B);
    case SDL_SCANCODE_RGUI:
        if (!systemKeysCaptured) {
            return drop();
        }
        return send(0x5C);
    case SDL_SCANCODE_APPLICATION:
        return send(0x5D);
    case SDL_SCANCODE_AC_BACK:
        return send(0xA6);
    case SDL_SCANCODE_AC_FORWARD:
        return send(0xA7);
    case SDL_SCANCODE_AC_REFRESH:
        return send(0xA8);
    case SDL_SCANCODE_AC_STOP:
        return send(0xA9);
    case SDL_SCANCODE_AC_SEARCH:
        return send(0xAA);
    case SDL_SCANCODE_AC_BOOKMARKS:
        return send(0xAB);
    case SDL_SCANCODE_AC_HOME:
        return send(0xAC);
    case SDL_SCANCODE_SEMICOLON:
        return send(0xBA);
    case SDL_SCANCODE_EQUALS:
        return send(0xBB);
    case SDL_SCANCODE_COMMA:
        return send(0xBC);
    case SDL_SCANCODE_MINUS:
        return send(0xBD);
    case SDL_SCANCODE_PERIOD:
        return send(0xBE);
    case SDL_SCANCODE_SLASH:
        return send(0xBF);
    case SDL_SCANCODE_GRAVE:
        return send(0xC0);
    case SDL_SCANCODE_LEFTBRACKET:
        return send(0xDB);
    case SDL_SCANCODE_INTERNATIONAL3:
        return send(VK_OEM_5, true);
    case SDL_SCANCODE_BACKSLASH:
        return send(VK_OEM_5);
    case SDL_SCANCODE_RIGHTBRACKET:
        return send(0xDD);
    case SDL_SCANCODE_APOSTROPHE:
        return send(0xDE);
    case SDL_SCANCODE_INTERNATIONAL1:
        // Positional placeholder: only the keysym says which key this is. See
        // mapInternationalKey() for why this cannot be a plain scancode lookup.
        return mapInternationalKey(keysym);
    case SDL_SCANCODE_NONUSBACKSLASH:
        return send(VK_OEM_102, false);
    case SDL_SCANCODE_LANG1:
        return send(0x1C);
    case SDL_SCANCODE_LANG2:
        return send(0x1D);
    default:
        return unhandled();
    }
}

} // namespace KeyRemoteMap
