pragma Singleton
import QtQuick 2.9

// Harness shim for the app's C++ StreamingPreferences singleton — just the two
// properties VbTokens.qml reads (defaults: teal accent, hints on).
QtObject {
    property int uiAccentIndex: 0
    property bool uiShowHints: true
}
