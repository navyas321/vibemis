TEMPLATE = app
TARGET = test_vrrswapchainpolicy

QT -= core gui
CONFIG += console c++17
CONFIG -= app_bundle qt

INCLUDEPATH += $$PWD/../../app

SOURCES += $$PWD/tst_vrrswapchainpolicy.cpp
