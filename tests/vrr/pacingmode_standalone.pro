# Vibemis (BL-2529): standalone checker for the frame-pacing gate on the VRR
# path (app/streaming/video/ffmpeg-renderers/pacer/vrr/vrrpacingmode.h).
#
# The policy is a pure function of the preferences plus the IVrrFramePresenter
# boundary, so this target needs no Qt, no window, and no renderer. It compiles
# VrrRatePolicy (the headroom arithmetic the policy defers to) and reuses
# tests/vrr/vrrtestfakes.h for the presenter, which is why libavutil is linked:
# the fake's frame helpers reference it even when a test does not build frames.

TEMPLATE = app
TARGET = test_vrrpacingmode

QT -= core gui
CONFIG += console c++17
CONFIG -= app_bundle qt

SOURCES += \
    $$PWD/tst_vrrpacingmode.cpp \
    $$PWD/../../app/streaming/vrrratepolicy.cpp

INCLUDEPATH += \
    $$PWD/../../app \
    $$PWD/../../moonlight-common-c/moonlight-common-c/src

win32 {
    contains(QT_ARCH, x86_64) {
        INCLUDEPATH += $$PWD/../../libs/windows/include/x64 \
                       $$PWD/../../libs/windows/include/x64/SDL2
        LIBS += -L$$PWD/../../libs/windows/lib/x64 -lavutil
    }
    contains(QT_ARCH, arm64) {
        INCLUDEPATH += $$PWD/../../libs/windows/include/arm64 \
                       $$PWD/../../libs/windows/include/arm64/SDL2
        LIBS += -L$$PWD/../../libs/windows/lib/arm64 -lavutil
    }
}

macx {
    !disable-prebuilts {
        INCLUDEPATH += $$PWD/../../libs/mac/include
        LIBS += -L$$PWD/../../libs/mac/lib -lavutil.60
    } else {
        CONFIG += link_pkgconfig
        PKGCONFIG += libavutil
    }
}

unix:!macx {
    CONFIG += link_pkgconfig
    PKGCONFIG += libavutil
}
