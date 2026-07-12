import QtQuick 2.9
import QtQuick.Layouts 1.3
import Vibemis.Redesign 1.0

// Redesign 1a — a rich host card (design_handoff previews/1a-computers.png). Pure-visual: the caller
// (PcView delegate) binds the model roles to these properties and handles input/activation. A 430px-
// wide card: rounded monitor thumbnail top-left, ONLINE/OFFLINE pulse pill top-right, host name
// (Sora 27), an access line ("Paired · Full access"), and a badge row (VIBEPOLLO/APOLLO/SUNSHINE +
// "4 ms · LAN"). Offline cards grey down (opacity .75) and show "Last seen …". Focus = accent ring +
// elev-2 fill (VbFocusRing).
Item {
    id: card

    property string hostName: ""
    property bool online: false
    property bool paired: false
    property bool statusUnknown: false
    property string accessText: ""          // e.g. "Paired · Full access" / "Paired · Tailscale"
    property string hostBadge: "SUNSHINE"   // VIBEPOLLO / APOLLO / SUNSHINE
    property bool badgeAccent: false         // accent outline for Apollo-lineage; neutral for Sunshine
    property string metaText: ""            // "4 ms · LAN" when online, "Last seen 2 h ago" when offline
    property bool focused: false

    implicitWidth: 430
    implicitHeight: 150

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: VbTokens.radiusCard
        color: card.focused ? VbTokens.bgElev2 : VbTokens.bgElev
        border.width: 1
        border.color: card.focused ? VbTokens.accent : VbTokens.stroke
        opacity: card.online ? 1.0 : 0.75

        VbFocusRing {
            active: card.focused
            radius: VbTokens.radiusCard
        }

        // ---- Monitor thumbnail (top-left) ----
        Rectangle {
            id: thumb
            x: 20; y: 20
            width: 54; height: 54
            radius: VbTokens.radiusControl
            color: VbTokens.bgElev2
            border.width: 1
            border.color: VbTokens.stroke
            VbSheetIcon {
                anchors.centerIn: parent
                width: 30; height: 30
                kind: "monitor"
                color: card.online ? VbTokens.text : VbTokens.statusOffline
            }
        }

        // ---- Status pill (top-right) ----
        VbStatusPill {
            visible: !card.statusUnknown
            online: card.online
            anchors.top: parent.top
            anchors.topMargin: 22
            anchors.right: parent.right
            anchors.rightMargin: 20
        }

        // ---- Name ----
        Text {
            id: nameText
            text: card.hostName
            anchors.left: thumb.right
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.top: parent.top
            anchors.topMargin: 22
            font.family: VbTokens.fontDisplay
            font.weight: Font.Bold
            font.pixelSize: VbTokens.sizeCardName
            color: VbTokens.text
            elide: Text.ElideRight
        }

        // ---- Access line ----
        Text {
            id: accessLine
            text: card.accessText
            visible: card.accessText !== ""
            anchors.left: thumb.right
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.top: nameText.bottom
            anchors.topMargin: 4
            font.family: VbTokens.fontBody
            font.pixelSize: VbTokens.sizeLabel
            color: VbTokens.textDim
            elide: Text.ElideRight
        }

        // ---- Badge + meta row (bottom) ----
        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            spacing: 12

            VbBadge {
                text: card.hostBadge
                neutral: !card.badgeAccent
            }
            Text {
                text: card.metaText
                visible: card.metaText !== ""
                Layout.fillWidth: true
                font.family: VbTokens.fontBody
                font.pixelSize: VbTokens.sizeLabel
                color: VbTokens.textDim
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
