import QtQuick 2.9
import Vibemis.Redesign 1.0

// Small all-caps outline badge (host-type: VIBEPOLLO / APOLLO accent outline, SUNSHINE neutral).
// docs/design/redesign status.badge. `neutral` = use text.dim outline instead of accent.
Rectangle {
    id: badge
    property alias text: label.text
    property bool neutral: false
    implicitWidth: label.implicitWidth + 20
    implicitHeight: 24
    radius: VbTokens.radiusBadge
    color: "transparent"
    border.width: 1
    border.color: neutral ? VbTokens.textDim : VbTokens.accent

    Text {
        id: label
        anchors.centerIn: parent
        font.family: VbTokens.fontBody
        font.pixelSize: VbTokens.sizeBadge
        font.bold: true
        font.letterSpacing: VbTokens.badgeSpacing
        color: badge.neutral ? VbTokens.textDim : VbTokens.accent
    }
}
