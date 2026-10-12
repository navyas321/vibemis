// Regression coverage for KeyRemoteMap::mapKeyPress(), the table that turns one
// SDL key press into the keyboard event Vibemis puts on the wire.
//
// Motivating bug (ABNT2): on a Brazilian keyboard the `\` `|` key is X11 keycode
// 94 and the `/` `?` key is X11 keycode 97. SDL's X11 backend resolves those to
// SDL_SCANCODE_NONUSBACKSLASH and SDL_SCANCODE_INTERNATIONAL1 respectively --
// measured on a real ABNT2 keyboard against SDL 2.30.0 -- and the table used to
// route both to VK_OEM_102, so the host pressed the same physical key twice
// over and `/` could never be typed. The tests below pin both keys and assert
// the general property that broke: two physical keys must not collapse onto one
// remote key.

#include <QtTest>

#include "keyremotemap.h"

using KeyRemoteMap::mapKeyPress;
using KeyRemoteMap::RemoteKey;
using KeyRemoteMap::Action;
using KeyRemoteMap::ActionSend;
using KeyRemoteMap::ActionDrop;
using KeyRemoteMap::ActionUnhandled;

class TestKeyRemoteMap : public QObject
{
    Q_OBJECT

private slots:
    void abnt2KeysMapToDifferentRemoteKeys();
    void abnt2SlashKeySendsAbntVirtualKey();
    void abnt2SlashKeyResolvesEveryLevelToTheSameRemoteKey();
    void otherInternationalOneKeysKeepTheLegacyVirtualKey();
    void abnt2KeysDoNotCollideWithEachOther();
    void usPositionedKeysAreUnchanged();
    void systemKeysHonourTheCaptureMode();
    void unknownScancodesAreReported();
};

// The two physical keys, described exactly as SDL describes them on X11.
static const SDL_Scancode ABNT2_BACKSLASH_SCANCODE = SDL_SCANCODE_NONUSBACKSLASH; // X11 keycode 94
static const SDL_Scancode ABNT2_SLASH_SCANCODE = SDL_SCANCODE_INTERNATIONAL1;      // X11 keycode 97

void TestKeyRemoteMap::abnt2KeysMapToDifferentRemoteKeys()
{
    RemoteKey pipe = mapKeyPress(SDLK_BACKSLASH, ABNT2_BACKSLASH_SCANCODE, false);
    RemoteKey slash = mapKeyPress(SDLK_SLASH, ABNT2_SLASH_SCANCODE, false);

    QVERIFY2(pipe.action == ActionSend, "the \\ | key must still reach the host");
    QVERIFY2(slash.action == ActionSend, "the / ? key must reach the host at all");
    QVERIFY2(slash.vkCode != pipe.vkCode,
             "two physical keys collapsed onto one remote virtual-key code");

    // The `\` | key is the ISO extra key: unchanged, and still normalised, which
    // is how it has always worked (the host injects US scancode 0x56 and the
    // ABNT2 layout reads it as `\`).
    QCOMPARE(pipe.vkCode, (short)VK_OEM_102);
    QCOMPARE(pipe.nonNormalized, false);
}

void TestKeyRemoteMap::abnt2SlashKeySendsAbntVirtualKey()
{
    RemoteKey slash = mapKeyPress(SDLK_SLASH, ABNT2_SLASH_SCANCODE, false);

    // VK_ABNT_C1 is the virtual key the Windows Brazilian layout assigns to this
    // physical key (ReactOS dll/keyboard/kbdbr: VK_ABNT_C1 -> '/', '?', 0xB0).
    // It has to go out un-normalised: no US-position VK can name this key,
    // because no US board has a key there.
    QCOMPARE(slash.vkCode, (short)VK_ABNT_C1);
    QCOMPARE(slash.nonNormalized, true);
}

void TestKeyRemoteMap::abnt2SlashKeyResolvesEveryLevelToTheSameRemoteKey()
{
    // This key carries four characters (`  /`, Shift `?`, AltGr degree, AltGr+Shift
    // inverted question mark). handleKeyEvent() tracks the press and the release by
    // the remote VK, so every level must resolve to the SAME remote key: if the
    // press said 0xC1 and the release said 0xE2, the host would be left holding a
    // key whose release went somewhere else.
    //
    // Measured on SDL 2's X11 backend with a Shift held across the press, the
    // keysym stays the base SDLK_SLASH and Shift travels in the modifier mask, so
    // SDLK_SLASH alone would do today; the other three levels are what the Wayland
    // backend and SDL 3 can report, and each is asserted against the absolute
    // value (not merely against each other) so a table that regressed to the
    // legacy 0xE2 would fail here.
    const SDL_Keycode levels[] = {
        SDLK_SLASH,       // `/`
        SDLK_QUESTION,    // `?`
        0x00b0,           // XK_degree, AltGr
        0x00bf,           // XK_questiondown, AltGr + Shift
    };

    for (SDL_Keycode level : levels) {
        RemoteKey result = mapKeyPress(level, ABNT2_SLASH_SCANCODE, false);
        QVERIFY2(result.action == ActionSend,
                 QByteArray("level 0x").append(QByteArray::number(level, 16)).append(" dropped"));
        QCOMPARE(result.vkCode, (short)VK_ABNT_C1);
        QCOMPARE(result.nonNormalized, true);
    }
}

void TestKeyRemoteMap::otherInternationalOneKeysKeepTheLegacyVirtualKey()
{
    // SDL 2 only names the ASCII keysyms; above U+007E an SDL_Keycode is just
    // the Unicode code point, so the JIS and Latin-1 keys are written as values.
    const SDL_Keycode yen = 0x00a5;  // XK_yen, what the JIS RO key types

    // The scancode was introduced for the Japanese RO key, and the br/abnt
    // (ABNT1) variant puts `\` | on it too. Those layouts must keep the
    // behaviour fabb4fda added; only a key that really types `/` moves.
    QVERIFY(mapKeyPress(yen, ABNT2_SLASH_SCANCODE, false).vkCode != VK_ABNT_C1);
    QCOMPARE(mapKeyPress(yen, ABNT2_SLASH_SCANCODE, false).vkCode, (short)VK_OEM_102);
    QCOMPARE(mapKeyPress(yen, ABNT2_SLASH_SCANCODE, false).nonNormalized, true);

    QCOMPARE(mapKeyPress(SDLK_BACKSLASH, ABNT2_SLASH_SCANCODE, false).vkCode, (short)VK_OEM_102);
    QCOMPARE(mapKeyPress(SDLK_BACKSLASH, ABNT2_SLASH_SCANCODE, false).nonNormalized, true);

    // A layout that binds nothing readable there also keeps the old answer
    // rather than silently changing.
    QCOMPARE(mapKeyPress(SDLK_UNKNOWN, ABNT2_SLASH_SCANCODE, false).vkCode, (short)VK_OEM_102);
}

void TestKeyRemoteMap::abnt2KeysDoNotCollideWithEachOther()
{
    // Measured on the ABNT2 keyboard: SDL gives each of these a different
    // scancode, so the table must give each a different remote key. This is the
    // invariant the bug violated.
    const struct {
        SDL_Keycode keysym;
        SDL_Scancode scancode;
        const char *name;
    } abnt2Keys[] = {
        {SDLK_BACKSLASH, SDL_SCANCODE_NONUSBACKSLASH, "\\ |  (X11 94)"},
        {SDLK_SLASH, SDL_SCANCODE_INTERNATIONAL1, "/ ?  (X11 97)"},
        {SDLK_RIGHTBRACKET, SDL_SCANCODE_BACKSLASH, "] }  (X11 51)"},
        {SDLK_SEMICOLON, SDL_SCANCODE_SLASH, "; :  (X11 61)"},
        {SDLK_a, SDL_SCANCODE_A, "a    (X11 38)"},
        {0x00e7, SDL_SCANCODE_SEMICOLON, "\303\247  (X11 47)"},
    };

    QList<short> seen;
    for (const auto &key : abnt2Keys) {
        RemoteKey result = mapKeyPress(key.keysym, key.scancode, false);
        QVERIFY2(result.action == ActionSend, key.name);
        QVERIFY2(!seen.contains(result.vkCode),
                 QByteArray("remote VK collision between ABNT2 keys at ") + key.name);
        seen.append(result.vkCode);
    }
}

void TestKeyRemoteMap::usPositionedKeysAreUnchanged()
{
    // Golden values: the scancode-driven table must keep naming keys by their
    // US position, which is what lets the host correct for its own layout.
    struct {
        SDL_Scancode scancode;
        short vk;
        bool nonNormalized;
    } expected[] = {
        {SDL_SCANCODE_A, VK_A, false},
        {SDL_SCANCODE_Z, 0x5A, false},
        {SDL_SCANCODE_1, 0x31, false},
        {SDL_SCANCODE_9, 0x39, false},
        {SDL_SCANCODE_0, VK_0, false},                    // SDL orders 0 after 9
        {SDL_SCANCODE_F1, VK_F1, false},
        {SDL_SCANCODE_F12, 0x7B, false},
        {SDL_SCANCODE_F13, VK_F13, false},
        {SDL_SCANCODE_KP_1, VK_NUMPAD0 + 1, false},
        {SDL_SCANCODE_KP_0, VK_NUMPAD0, false},           // SDL orders KP_0 after KP_9
        {SDL_SCANCODE_SPACE, 0x20, false},
        {SDL_SCANCODE_RETURN, 0x0D, false},
        {SDL_SCANCODE_SEMICOLON, 0xBA, false},
        {SDL_SCANCODE_SLASH, 0xBF, false},
        {SDL_SCANCODE_BACKSLASH, VK_OEM_5, false},
        {SDL_SCANCODE_NONUSBACKSLASH, VK_OEM_102, false},
        {SDL_SCANCODE_INTERNATIONAL3, VK_OEM_5, true},    // the JIS `\` key
    };

    for (const auto &test : expected) {
        RemoteKey result = mapKeyPress(SDLK_UNKNOWN, test.scancode, true);
        QVERIFY2(result.action == ActionSend, QByteArray("dropped scancode ") +
                 QByteArray::number(test.scancode));
        QCOMPARE(result.vkCode, test.vk);
        QCOMPARE(result.nonNormalized, test.nonNormalized);
    }
}

void TestKeyRemoteMap::systemKeysHonourTheCaptureMode()
{
    QCOMPARE((int)mapKeyPress(SDLK_UNKNOWN, SDL_SCANCODE_LGUI, false).action, (int)ActionDrop);
    QCOMPARE((int)mapKeyPress(SDLK_UNKNOWN, SDL_SCANCODE_RGUI, false).action, (int)ActionDrop);

    RemoteKey win = mapKeyPress(SDLK_UNKNOWN, SDL_SCANCODE_LGUI, true);
    QVERIFY(win.action == ActionSend);
    QCOMPARE(win.vkCode, (short)0x5B);
}

void TestKeyRemoteMap::unknownScancodesAreReported()
{
    // A key that is not in the table must be distinguishable from one we
    // deliberately swallow, so the caller can log it.
    QCOMPARE((int)mapKeyPress(SDLK_UNKNOWN, SDL_SCANCODE_UNKNOWN, true).action, (int)ActionUnhandled);
}

QTEST_GUILESS_MAIN(TestKeyRemoteMap)
#include "tst_keyremotemap.moc"
