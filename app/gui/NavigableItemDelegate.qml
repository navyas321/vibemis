import QtQuick 2.0
import QtQuick.Controls 2.2

import UiSoundManager 1.0

ItemDelegate {
    id: navDelegate

    property GridView grid

    highlighted: grid.activeFocus && grid.currentItem === this

    // Activation blip. Wired via Connections rather than an onClicked
    // handler because instance-level onClicked declarations override base
    // handlers (the text-clip lesson). clicked() is the single funnel for
    // A/Enter (the load-bearing Keys handlers below) and mouse/touch alike.
    Connections {
        target: navDelegate
        function onClicked() {
            UiSoundManager.activated()
        }
    }

    Keys.onLeftPressed: {
        grid.moveCurrentIndexLeft()
    }
    Keys.onRightPressed: {
        grid.moveCurrentIndexRight()
    }
    Keys.onDownPressed: {
        grid.moveCurrentIndexDown()
    }
    Keys.onUpPressed: {
        grid.moveCurrentIndexUp()

        // If we've reached the top of the grid, move focus to the toolbar
        if (grid.currentItem === this) {
            nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocus)
        }
    }
    // These manual handlers are LOAD-BEARING — removing them on the
    // "Qt 6 AbstractButton activates on Return natively" theory bricked every A/Enter
    // activation on-device (0.2.0-alpha.001 critical regression): ItemDelegate only
    // accepts Space natively. The original double-push bug is fixed at the PUSH SITES
    // instead (stackView.busy guards) so a duplicate clicked() is a harmless no-op.
    Keys.onReturnPressed: {
        clicked()
    }
    Keys.onEnterPressed: {
        clicked()
    }
}
