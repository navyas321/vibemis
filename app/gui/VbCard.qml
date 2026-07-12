import QtQuick 2.9
import Vibemis.Redesign 1.0

// Elevated card surface with the redesign focus-ring recipe built in. Bind `focused` to the
// owning delegate's focus/selection state — the fill switches to VbTokens.focusedFill and the
// focus ring appears. Put content inside as children (they layer above the surface).
// docs/design/redesign — used by host cards (1a), app tiles (1b), sidebar rows, action rows.
Item {
    id: card
    property bool focused: false
    property int radius: VbTokens.radiusCard
    property color baseColor: VbTokens.bgElev
    property real contentOpacity: 1.0
    default property alias content: holder.data

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: card.radius
        color: card.focused ? VbTokens.focusedFill : card.baseColor
        border.width: 1
        border.color: VbTokens.stroke
        opacity: card.contentOpacity
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Item {
        id: holder
        anchors.fill: parent
        opacity: card.contentOpacity
    }

    VbFocusRing {
        active: card.focused
        radius: card.radius
    }
}
