# Vibemis (BL-2296): build target for the standalone same-display
# refresh-mode-switch guard checker (app/test_vrrrefreshguard.cpp). The guard
# predicates are pure header-inline members of StreamUtils, so this target
# compiles only the test file; SDL2 is needed for headers alone
# (streamutils.h includes SDL_compat.h) and no Qt is used at all.
TEMPLATE = app
TARGET = test_vrrrefreshguard

QT -= core gui
CONFIG += console c++17
CONFIG -= app_bundle qt

SOURCES += \
    $$PWD/../../app/test_vrrrefreshguard.cpp

INCLUDEPATH += \
    $$PWD/../../app

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
