TEMPLATE = app
TARGET = tst_bitraterescuepolicy

QT += testlib
QT -= gui
CONFIG += console testcase c++17
CONFIG -= app_bundle

SOURCES += \
    $$PWD/tst_bitraterescuepolicy.cpp \
    $$PWD/../../app/streaming/bitraterescuepolicy.cpp
