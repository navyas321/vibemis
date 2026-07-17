import QtQuick 2.0
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import Vibemis.Redesign 1.0

import UiSoundManager 1.0

// Used only by the global toolbar (main.qml), which is the redesign header bar. Styled to the design's
// 52px header icon buttons: a rounded-square token surface (bgElev, 1px stroke, radius 14)
// with an accent focus ring and a ~22px centered icon.
ToolButton {
    id: btn
    property string iconSource

    // Activation blip — Connections so the instances' own onClicked
    // declarations (every toolbar button has one) can't override it.
    Connections {
        target: btn
        function onClicked() {
            UiSoundManager.activated()
        }
    }

    activeFocusOnTab: true
    implicitWidth: VbTokens.iconButton
    implicitHeight: VbTokens.iconButton
    padding: 0
    Layout.alignment: Qt.AlignVCenter

    background: Rectangle {
        radius: VbTokens.radiusIconButton
        color: btn.activeFocus ? VbTokens.focusedFill : (btn.hovered ? VbTokens.bgElev2 : VbTokens.bgElev)
        border.width: 1
        border.color: btn.activeFocus ? VbTokens.accent : VbTokens.stroke
    }

    contentItem: Item {
        Image {
            anchors.centerIn: parent
            source: btn.iconSource
            sourceSize.width: 22
            sourceSize.height: 22
            fillMode: Image.PreserveAspectFit
        }
    }

    Keys.onReturnPressed: {
        clicked()
    }

    Keys.onEnterPressed: {
        clicked()
    }

    Keys.onRightPressed: {
        nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocus)
    }

    Keys.onLeftPressed: {
        nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocus)
    }
}
