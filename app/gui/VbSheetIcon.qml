import QtQuick 2.9
import Vibemis.Redesign 1.0

// Monochrome 2px line icons for the Host-options side-sheet (1d). A square Canvas that
// recolors via `color` (danger rows pass statusDanger, focused rows pass accent, otherwise
// textMute). Drawn in-app so no icon font is needed. docs/design/redesign preview 1d.
Canvas {
    id: g
    property string kind: "apps"
    property color color: VbTokens.textMute
    property real stroke: 2
    width: 26
    height: 26
    antialiasing: true
    onColorChanged: requestPaint()
    onKindChanged: requestPaint()

    // Rounded-rect path helper (Qt Canvas has no roundedRect()).
    function rr(ctx, x, y, w, h, r) {
        ctx.beginPath()
        ctx.moveTo(x + r, y)
        ctx.arcTo(x + w, y, x + w, y + h, r)
        ctx.arcTo(x + w, y + h, x, y + h, r)
        ctx.arcTo(x, y + h, x, y, r)
        ctx.arcTo(x, y, x + w, y, r)
        ctx.closePath()
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.strokeStyle = g.color
        ctx.fillStyle = g.color
        ctx.lineWidth = g.stroke
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        var w = width, h = height
        var cx = w / 2, cy = h / 2

        if (kind === "monitor") {
            rr(ctx, 3, 3, w - 6, h - 12, 3); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(cx, h - 9); ctx.lineTo(cx, h - 4); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(cx - 5, h - 4); ctx.lineTo(cx + 5, h - 4); ctx.stroke()
        } else if (kind === "apps") {
            var s = 8, gap = 3, o = 4
            rr(ctx, o, o, s, s, 2); ctx.stroke()
            rr(ctx, o + s + gap, o, s, s, 2); ctx.stroke()
            rr(ctx, o, o + s + gap, s, s, 2); ctx.stroke()
            rr(ctx, o + s + gap, o + s + gap, s, s, 2); ctx.stroke()
        } else if (kind === "network") {
            var r = (w - 8) / 2
            ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(cx - r, cy); ctx.lineTo(cx + r, cy); ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(cx, cy - r)
            ctx.bezierCurveTo(cx - r * 0.75, cy - r * 0.5, cx - r * 0.75, cy + r * 0.5, cx, cy + r)
            ctx.bezierCurveTo(cx + r * 0.75, cy + r * 0.5, cx + r * 0.75, cy - r * 0.5, cx, cy - r)
            ctx.stroke()
        } else if (kind === "rename") {
            ctx.beginPath()
            ctx.moveTo(5, h - 5); ctx.lineTo(5, h - 9)
            ctx.lineTo(w - 9, 5); ctx.lineTo(w - 5, 9)
            ctx.lineTo(9, h - 5); ctx.closePath(); ctx.stroke()
        } else if (kind === "details") {
            var r2 = (w - 8) / 2
            ctx.beginPath(); ctx.arc(cx, cy, r2, 0, 2 * Math.PI); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(cx, cy + r2 * 0.55); ctx.stroke()
            ctx.beginPath(); ctx.arc(cx, cy - r2 * 0.45, 1.0, 0, 2 * Math.PI); ctx.fill()
        } else if (kind === "delete") {
            ctx.beginPath(); ctx.moveTo(4, 7); ctx.lineTo(w - 4, 7); ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(cx - 3, 7); ctx.lineTo(cx - 3, 4); ctx.lineTo(cx + 3, 4); ctx.lineTo(cx + 3, 7); ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(6, 7); ctx.lineTo(7.5, h - 4); ctx.lineTo(w - 7.5, h - 4); ctx.lineTo(w - 6, 7); ctx.stroke()
        } else if (kind === "wake") {
            var rp = (w - 8) / 2
            ctx.beginPath(); ctx.arc(cx, cy + 1, rp, -Math.PI / 2 + 0.45, -Math.PI / 2 - 0.45 + 2 * Math.PI); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(cx, 3); ctx.lineTo(cx, cy - 1); ctx.stroke()
        } else if (kind === "pair") {
            rr(ctx, 3, cy - 4, w * 0.55, 8, 4); ctx.stroke()
            rr(ctx, w * 0.45 - 3, cy - 4, w * 0.55, 8, 4); ctx.stroke()
        } else if (kind === "video") {
            // film frame + play triangle
            rr(ctx, 3, 4, w - 6, h - 8, 3); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(cx - 3, cy - 5); ctx.lineTo(cx + 5, cy); ctx.lineTo(cx - 3, cy + 5); ctx.closePath(); ctx.stroke()
        } else if (kind === "audio") {
            // speaker cone + two sound arcs
            ctx.beginPath(); ctx.moveTo(5, cy - 3); ctx.lineTo(9, cy - 3); ctx.lineTo(13, cy - 6); ctx.lineTo(13, cy + 6); ctx.lineTo(9, cy + 3); ctx.lineTo(5, cy + 3); ctx.closePath(); ctx.stroke()
            ctx.beginPath(); ctx.arc(13, cy, 4, -Math.PI / 3, Math.PI / 3); ctx.stroke()
            ctx.beginPath(); ctx.arc(13, cy, 7, -Math.PI / 3, Math.PI / 3); ctx.stroke()
        } else if (kind === "gamepad") {
            // rounded controller body + two button dots
            rr(ctx, 3, cy - 5, w - 6, 12, 6); ctx.stroke()
            ctx.beginPath(); ctx.arc(cx - 5, cy + 1, 1.4, 0, 2 * Math.PI); ctx.fill()
            ctx.beginPath(); ctx.arc(cx + 5, cy - 1, 1.4, 0, 2 * Math.PI); ctx.fill()
        } else if (kind === "streaming") {
            // broadcast: center dot + concentric side arcs
            ctx.beginPath(); ctx.arc(cx, cy, 1.6, 0, 2 * Math.PI); ctx.fill()
            ctx.beginPath(); ctx.arc(cx, cy, 5, -Math.PI / 4, Math.PI / 4); ctx.stroke()
            ctx.beginPath(); ctx.arc(cx, cy, 5, Math.PI - Math.PI / 4, Math.PI + Math.PI / 4); ctx.stroke()
            ctx.beginPath(); ctx.arc(cx, cy, 8, -Math.PI / 4, Math.PI / 4); ctx.stroke()
            ctx.beginPath(); ctx.arc(cx, cy, 8, Math.PI - Math.PI / 4, Math.PI + Math.PI / 4); ctx.stroke()
        } else if (kind === "advanced") {
            // three sliders with offset knobs
            var ys = [cy - 5, cy, cy + 5], kx = [w - 8, 8, cx + 3]
            for (var vi = 0; vi < 3; vi++) {
                ctx.beginPath(); ctx.moveTo(4, ys[vi]); ctx.lineTo(w - 4, ys[vi]); ctx.stroke()
                ctx.beginPath(); ctx.arc(kx[vi], ys[vi], 2, 0, 2 * Math.PI); ctx.stroke()
            }
        }
    }
}
