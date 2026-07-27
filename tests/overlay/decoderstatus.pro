TEMPLATE = app
TARGET = tst_decoderstatus

QT += testlib
QT -= gui
CONFIG += console testcase c++17
CONFIG -= app_bundle

SOURCES += \
    $$PWD/tst_decoderstatus.cpp
