import QtQuick 2.9
import Vibemis.Redesign 1.0

// Focus drop-shadow — the 3rd layer of the redesign focus-ring recipe
// ("2px accent border + 5px accent@22% glow + drop shadow"). Qt 6.4 on the Legion Go
// ships NO effects modules (neither QtQuick.Effects/MultiEffect nor Qt5Compat DropShadow),
// so we cast the shadow with a Canvas — portable across every Qt 6.x the CI/device use.
//
// Design handoff: focused card shadow = 0 18px 48px rgba(0,0,0,0.45). Place as the FIRST
// child of a focusable card's root Item (so it paints BEHIND the opaque surface), bind
// `active` to focus and `radius` to the surface radius. Purely visual; no input.
Item {
    id: shadow
    property bool active: false
    property int radius: VbTokens.radiusCard
    property real blur: 48
    property real offsetY: 18
    property color shadowColor: Qt.rgba(0, 0, 0, 0.45)
    anchors.fill: parent
    visible: active

    Canvas {
        id: cv
        // Extend beyond the parent so the blurred shadow isn't clipped at the card edge.
        anchors.fill: parent
        anchors.margins: -(shadow.blur + shadow.offsetY)
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var m = shadow.blur + shadow.offsetY;   // inset back to the card's own rect
            var x = m, y = m;
            var w = width - 2 * m, h = height - 2 * m;
            if (w <= 0 || h <= 0) {
                return;
            }
            var r = Math.min(shadow.radius, w / 2, h / 2);
            ctx.save();
            ctx.shadowColor = shadow.shadowColor;
            ctx.shadowBlur = shadow.blur;
            ctx.shadowOffsetX = 0;
            ctx.shadowOffsetY = shadow.offsetY;
            ctx.fillStyle = "#000000";
            ctx.beginPath();
            ctx.moveTo(x + r, y);
            ctx.arcTo(x + w, y, x + w, y + h, r);
            ctx.arcTo(x + w, y + h, x, y + h, r);
            ctx.arcTo(x, y + h, x, y, r);
            ctx.arcTo(x, y, x + w, y, r);
            ctx.closePath();
            ctx.fill();
            ctx.restore();
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    onActiveChanged: if (active) { cv.requestPaint(); }
}
