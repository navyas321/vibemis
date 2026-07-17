import QtQuick 2.9
import QtQuick.Controls 2.2
import "../../app/gui"

// Minimal PcView-shaped nav repro — mock toolbar (chain-before-grid), a 1-item
// GridView using the REAL NavigableItemDelegate with PcView's exact instance overrides
// (ghost-selection branches included). Drive with keys: Up must land focus on "toolbtn2".
Rectangle {
    width: 900
    height: 600
    color: "#0E1013"

    Row {
        id: toolbarMock
        spacing: 8
        Button { objectName: "toolbtn1"; text: "gear"; width: 90; height: 40 }
        Button { objectName: "toolbtn2"; text: "help"; width: 90; height: 40 }
    }

    GridView {
        id: pcGrid
        objectName: "pcGrid"
        anchors.top: toolbarMock.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        focus: true
        activeFocusOnTab: true
        cellWidth: 462; cellHeight: 274
        property real itemsPerRow: Math.max(1, Math.floor(width / cellWidth))
        property bool ghostSelected: false
        function selectGhost() { ghostSelected = true }
        onCurrentIndexChanged: ghostSelected = false
        onActiveFocusChanged: {
            if (activeFocus && currentIndex === -1 && count > 0) {
                currentIndex = 0
            }
            if (!activeFocus) {
                ghostSelected = false
            }
        }

        model: ListModel {
            ListElement { name: "Gaming-PC" }
        }

        delegate: NavigableItemDelegate {
            objectName: "delegate-" + model.name
            width: 430; height: 242
            grid: pcGrid
            background: null

            Keys.onRightPressed: {
                if (index === pcGrid.count - 1 && !pcGrid.ghostSelected) {
                    pcGrid.selectGhost()
                }
                else if (!pcGrid.ghostSelected) {
                    grid.moveCurrentIndexRight()
                }
            }
            Keys.onDownPressed: {
                var cols = Math.max(1, Math.floor(pcGrid.itemsPerRow))
                if (!pcGrid.ghostSelected &&
                        Math.floor(index / cols) === Math.floor((pcGrid.count - 1) / cols)) {
                    pcGrid.selectGhost()
                }
                else if (!pcGrid.ghostSelected) {
                    grid.moveCurrentIndexDown()
                }
            }
            Keys.onLeftPressed: {
                if (pcGrid.ghostSelected) {
                    pcGrid.ghostSelected = false
                }
                else {
                    grid.moveCurrentIndexLeft()
                }
            }
            Keys.onUpPressed: {
                if (pcGrid.ghostSelected) {
                    pcGrid.ghostSelected = false
                }
                else {
                    grid.moveCurrentIndexUp()
                    if (grid.currentItem === this) {
                        nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocus)
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: "#15181D"
                border.color: parent.highlighted ? "#2FC6D0" : "#333"
                border.width: 2
                Text { anchors.centerIn: parent; text: model.name; color: "white" }
            }
        }

        Component.onCompleted: {
            currentIndex = 0
            forceActiveFocus()
        }
    }
}
