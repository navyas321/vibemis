import QtQuick 2.0
import QtQuick.Controls 2.2

import UiSoundManager 1.0

MenuItem {
    id: navMenuItem

    // Ensure focus can't be given to an invisible item
    enabled: visible
    height: visible ? implicitHeight : 0
    focusPolicy: visible ? Qt.TabFocus : Qt.NoFocus

    // Activation blip — Connections so the instances' own onTriggered
    // declarations (every menu item has one) can't override it.
    Connections {
        target: navMenuItem
        function onTriggered() {
            UiSoundManager.activated()
        }
    }

    onTriggered: {
        // We must close the context menu first or
        // it can steal focus from any dialogs that
        // onTriggered may spawn.
        menu.close()
    }

    Keys.onReturnPressed: {
        triggered()
    }

    Keys.onEnterPressed: {
        triggered()
    }

    Keys.onEscapePressed: {
        menu.close()
    }
}
