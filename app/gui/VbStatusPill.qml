import QtQuick 2.9
import Vibemis.Redesign 1.0

// Online/offline status pill: a dot (online pulses 2.4s) + label. docs/design/redesign.
Rectangle {
    id: pill
    property bool online: true
    implicitWidth: row.implicitWidth + 24
    implicitHeight: 28
    radius: VbTokens.radiusPill
    color: VbTokens.bgElev2
    border.width: 1
    border.color: VbTokens.stroke

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Rectangle {
            id: dot
            width: 9; height: 9; radius: 999
            anchors.verticalCenter: parent.verticalCenter
            color: pill.online ? VbTokens.statusOnline : VbTokens.statusOffline
            // Pulse only when online.
            SequentialAnimation on opacity {
                running: pill.online
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.45; duration: VbTokens.onlinePulseMs / 2; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.45; to: 1.0; duration: VbTokens.onlinePulseMs / 2; easing.type: Easing.InOutSine }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: pill.online ? qsTr("ONLINE") : qsTr("OFFLINE")
            font.family: VbTokens.fontBody
            font.pixelSize: VbTokens.sizeBadge
            font.bold: true
            font.letterSpacing: 0.7   // handoff pill spacing (badge uses 1.2)
            color: pill.online ? VbTokens.statusOnline : VbTokens.textDim
        }
    }
}
