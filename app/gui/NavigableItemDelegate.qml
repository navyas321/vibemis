import QtQuick 2.0
import QtQuick.Controls 2.2

ItemDelegate {
    property GridView grid

    highlighted: grid.activeFocus && grid.currentItem === this

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
    // BL-1745: NO manual Return/Enter -> clicked() here. On Qt 6, AbstractButton natively
    // emits clicked() for Return/Enter on the focused control, so the old Qt 5-era manual
    // handler made every gamepad-A / Enter activation fire clicked() TWICE (two AppViews
    // pushed from the host card => Back had to be pressed twice to reach home).
}
