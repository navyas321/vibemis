TEMPLATE = app
TARGET = tst_updaterswap

QT += testlib
QT -= gui
CONFIG += console testcase c++17
CONFIG -= app_bundle

SOURCES += \
    $$PWD/tst_updaterswap.cpp \
    $$PWD/../../app/backend/appimageswap.cpp

HEADERS += \
    $$PWD/../../app/backend/appimageswap.h
