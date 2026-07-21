# Vibemis (BL-2230): build target for the repo's pre-existing standalone
# VrrRatePolicy checker (app/test_vrrratepolicy.cpp, added in the BL-2212
# wave / PR #240). It has its own main() and needs no Qt at all; this target
# just gives it a home in the opt-in test tree so `qmake tests.pro
# CONFIG+=tests && make` builds and runs everything in one place.
TEMPLATE = app
TARGET = test_vrrratepolicy

QT -= core gui
CONFIG += console c++17
CONFIG -= app_bundle qt

SOURCES += \
    $$PWD/../../app/test_vrrratepolicy.cpp \
    $$PWD/../../app/streaming/vrrratepolicy.cpp
