# Regression coverage for the local key -> remote keyboard event table
# (app/streaming/input/keyremotemap.h), the code behind the ABNT2 `/` `?` key
# reporting the same remote key as `\` `|`.
#
# The table is a pure header over SDL's scancode/keycode enums: the test
# references no SDL symbol, so nothing here opens a window, reads a keyboard or
# reaches a host. The pkg-config arms below are for the headers; the -lSDL2 they
# add is unused (and with Ubuntu's --as-needed it is not even recorded as a
# dependency).
TEMPLATE = app
TARGET = tst_keyremotemap

QT += testlib
QT -= gui
CONFIG += console testcase c++17
CONFIG -= app_bundle

INCLUDEPATH += $$PWD/../../app/streaming/input

win32 {
    contains(QT_ARCH, x86_64) {
        INCLUDEPATH += $$PWD/../../libs/windows/include/x64 \
                       $$PWD/../../libs/windows/include/x64/SDL2
    }
    contains(QT_ARCH, arm64) {
        INCLUDEPATH += $$PWD/../../libs/windows/include/arm64 \
                       $$PWD/../../libs/windows/include/arm64/SDL2
    }
}

macx {
    !disable-prebuilts {
        # SDL_keycode.h / SDL_scancode.h are unprefixed includes, so the SDL2
        # sibling directory is needed as well (same pair app.pro:60 uses).
        INCLUDEPATH += $$PWD/../../libs/mac/include \
                       $$PWD/../../libs/mac/include/SDL2
    } else {
        CONFIG += link_pkgconfig
        PKGCONFIG += sdl2
    }
}

unix:!macx {
    CONFIG += link_pkgconfig
    PKGCONFIG += sdl2
}

SOURCES += \
    $$PWD/tst_keyremotemap.cpp
