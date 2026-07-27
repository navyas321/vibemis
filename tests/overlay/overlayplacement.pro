TEMPLATE = app
TARGET = tst_overlayplacement

QT += testlib
QT -= gui
CONFIG += console testcase c++17
CONFIG -= app_bundle

SOURCES += \
    $$PWD/tst_overlayplacement.cpp
