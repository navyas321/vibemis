import QtQuick 2.9
import Vibemis.Redesign 1.0

// Small all-caps outline badge (host-type: VIBEPOLLO / APOLLO accent outline, SUNSHINE neutral).
// Status badge component. `neutral` = use text.dim outline instead of accent.
Rectangle {
    id: badge
    property alias text: label.text
    property bool neutral: false
    implicitWidth: label.implicitWidth + 20
    implicitHeight: 24
    radius: VbTokens.radiusBadge
    color: "transparent"
    border.width: 1
    // Match the design exactly: Apollo-lineage = accent@55% outline, Sunshine = white@14%.
    border.color: neutral ? Qt.rgba(1, 1, 1, 0.14)
                          : Qt.rgba(VbTokens.accent.r, VbTokens.accent.g, VbTokens.accent.b, 0.55)

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
