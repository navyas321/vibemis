import QtQuick 2.9
import Vibemis.Redesign 1.0

// The Vibemis focus-ring recipe: 2px accent border + a 5px accent@22%
// glow + a drop shadow. Place as a sibling/overlay of a focusable surface and bind `active` to
// its activeFocus. The parent surface should switch its own fill to VbTokens.focusedFill when
// active. Non-interactive; purely visual.
Item {
    id: ring
    property bool active: false
    property int radius: VbTokens.radiusCard
    anchors.fill: parent
    visible: active
    z: 10

    // Outer glow (accent @ 22%), sits just outside the border.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -VbTokens.focusGlow
        // radius -1 thickens the band by ~1px at the CORNERS only, overlapping the
        // surface corner instead of meeting it edge-to-edge. Geometrically the exact value
        // (ring.radius + focusGlow) is concentric, but on-device rasterization (gamescope,
        // Qt hi-DPI scaling disabled) let the card's corner poke a hair past the halo curve.
        radius: ring.radius + VbTokens.focusGlow - 1
        color: "transparent"
        border.width: VbTokens.focusGlow
        border.color: VbTokens.focusGlowColor
        antialiasing: true
    }
    // Accent border.
    Rectangle {
        anchors.fill: parent
        radius: ring.radius
        color: "transparent"
        border.width: VbTokens.focusBorder
        border.color: VbTokens.accent
        antialiasing: true
    }
}
