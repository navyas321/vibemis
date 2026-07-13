# Vibemis QML render harness (see main.cpp). Build inside the WSL clone:
#   cd scripts/qmlrender && qmake6 && make
TEMPLATE = app
TARGET = qmlrender
QT += quick qml gui
CONFIG += c++17
SOURCES += main.cpp
# Resolve the repo's gui + fonts dirs relative to this .pro at build time.
DEFINES += GUI_DIR=\\\"$$absolute_path($$PWD/../../app/gui)\\\"
DEFINES += FONT_DIR=\\\"$$absolute_path($$PWD/../../app/fonts)\\\"
DEFINES += SHIM_DIR=\\\"$$absolute_path($$PWD/shim)\\\"
