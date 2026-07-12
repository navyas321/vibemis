import QtQuick 2.9
import Vibemis.Redesign 1.0

// Focus drop-shadow — the 3rd layer of the redesign focus-ring recipe
// ("2px accent border + 5px accent@22% glow + drop shadow").
//
// PERF (BL-1619): the first implementation cast this with a Canvas + 48px shadowBlur.
// On the Legion Go that software-Gaussian repainted on every focus move and STALLED the
// launcher (home-page-only input lag — Settings, which uses no drop-shadow, stayed smooth).
// This version fakes the depth with two stacked translucent rounded rects offset downward:
// pure GPU compositing, zero per-move repaint cost. Softer-looking than a real blur but
// effectively free, which matters far more on a handheld GPU.
//
// Place as the FIRST child of a focusable card's root Item (so it sits BEHIND the opaque
// surface), bind `active` to focus and `radius` to the surface radius. Purely visual.
Item {
    id: shadow
    property bool active: false
    property int radius: VbTokens.radiusCard
    property int offsetY: 14
    anchors.fill: parent
    visible: active

    // Outer, wider + lower + fainter.
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: shadow.offsetY + 8
        anchors.bottomMargin: -(shadow.offsetY + 8)
        anchors.leftMargin: -7
        anchors.rightMargin: -7
        radius: shadow.radius + 8
        color: Qt.rgba(0, 0, 0, 0.24)
    }
    // Inner, tighter + darker — reads as the shadow's core.
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: shadow.offsetY
        anchors.bottomMargin: -shadow.offsetY
        anchors.leftMargin: -2
        anchors.rightMargin: -2
        radius: shadow.radius + 2
        color: Qt.rgba(0, 0, 0, 0.36)
    }
}
