import QtQuick 2.9
import Vibemis.Redesign 1.0

// Monochrome 2px line icons for the Host-options side-sheet (1d). A square Canvas that
// recolors via `color` (danger rows pass statusDanger, focused rows pass accent, otherwise
// textMute). Drawn in-app so no icon font is needed.
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
        } else if (kind === "power") {
            // power symbol — arc + vertical stem
            var rq = (w - 10) / 2
            ctx.beginPath(); ctx.arc(cx, cy + 1, rq, -Math.PI / 2 + 0.5, -Math.PI / 2 - 0.5 + 2 * Math.PI); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(cx, 3); ctx.lineTo(cx, cy); ctx.stroke()
        } else if (kind === "terminal") {
            // terminal window — frame + '>' prompt + cursor line
            rr(ctx, 3, 4, w - 6, h - 8, 3); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(7, cy - 3); ctx.lineTo(11, cy); ctx.lineTo(7, cy + 3); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(13, cy + 3); ctx.lineTo(18, cy + 3); ctx.stroke()
        } else if (kind === "clipboard" || kind === "clipboard-up" || kind === "clipboard-down") {
            // clipboard board + clip; up/down variants add an arrow on the board
            rr(ctx, 5, 5, w - 10, h - 8, 3); ctx.stroke()
            rr(ctx, cx - 4, 2, 8, 5, 2); ctx.stroke()
            if (kind === "clipboard-up") {
                ctx.beginPath(); ctx.moveTo(cx, h - 7); ctx.lineTo(cx, 11); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(cx - 3, 14); ctx.lineTo(cx, 11); ctx.lineTo(cx + 3, 14); ctx.stroke()
            } else if (kind === "clipboard-down") {
                ctx.beginPath(); ctx.moveTo(cx, 11); ctx.lineTo(cx, h - 7); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(cx - 3, h - 10); ctx.lineTo(cx, h - 7); ctx.lineTo(cx + 3, h - 10); ctx.stroke()
            } else {
                ctx.beginPath(); ctx.moveTo(9, 12); ctx.lineTo(w - 9, 12); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(9, 16); ctx.lineTo(w - 11, 16); ctx.stroke()
            }
        } else if (kind === "keyboard") {
            // keyboard — frame + key dots + space bar
            rr(ctx, 3, 7, w - 6, h - 14, 3); ctx.stroke()
            var kxs = [7, 11, 15, 19]
            for (var ki = 0; ki < kxs.length; ki++) {
                ctx.beginPath(); ctx.arc(kxs[ki], 11, 0.8, 0, 2 * Math.PI); ctx.fill()
            }
            ctx.beginPath(); ctx.moveTo(9, h - 11); ctx.lineTo(w - 9, h - 11); ctx.stroke()
        } else if (kind === "stats") {
            // three rising bars on a baseline
            ctx.beginPath(); ctx.moveTo(4, h - 5); ctx.lineTo(w - 4, h - 5); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(8, h - 8); ctx.lineTo(8, h - 12); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(cx, h - 8); ctx.lineTo(cx, h - 16); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(w - 8, h - 8); ctx.lineTo(w - 8, h - 20); ctx.stroke()
        } else if (kind === "mouse") {
            // mouse body + center scroll line
            rr(ctx, cx - 6, 4, 12, h - 8, 6); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(cx, 7); ctx.lineTo(cx, 11); ctx.stroke()
        } else if (kind === "fullscreen") {
            // four outward corners
            ctx.beginPath(); ctx.moveTo(4, 9); ctx.lineTo(4, 4); ctx.lineTo(9, 4); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(w - 9, 4); ctx.lineTo(w - 4, 4); ctx.lineTo(w - 4, 9); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(w - 4, h - 9); ctx.lineTo(w - 4, h - 4); ctx.lineTo(w - 9, h - 4); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(9, h - 4); ctx.lineTo(4, h - 4); ctx.lineTo(4, h - 9); ctx.stroke()
        } else if (kind === "touch") {
            // pointing finger dot + two tap arcs
            ctx.beginPath(); ctx.arc(cx, cy + 2, 2, 0, 2 * Math.PI); ctx.fill()
            ctx.beginPath(); ctx.arc(cx, cy + 2, 6, -Math.PI * 0.8, -Math.PI * 0.2); ctx.stroke()
            ctx.beginPath(); ctx.arc(cx, cy + 2, 9, -Math.PI * 0.75, -Math.PI * 0.25); ctx.stroke()
        } else if (kind === "key") {
            // single keycap with a centered dash (for send-key actions)
            rr(ctx, 5, 6, w - 10, h - 12, 4); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(cx - 3, cy); ctx.lineTo(cx + 3, cy); ctx.stroke()
        } else if (kind === "restart") {
            // circular arrow with head
            var rr2 = (w - 10) / 2
            ctx.beginPath(); ctx.arc(cx, cy, rr2, -Math.PI * 0.35, Math.PI * 1.25); ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(cx + rr2 * Math.cos(-Math.PI * 0.35) - 4, cy + rr2 * Math.sin(-Math.PI * 0.35) - 1)
            ctx.lineTo(cx + rr2 * Math.cos(-Math.PI * 0.35), cy + rr2 * Math.sin(-Math.PI * 0.35))
            ctx.lineTo(cx + rr2 * Math.cos(-Math.PI * 0.35) - 1, cy + rr2 * Math.sin(-Math.PI * 0.35) + 4)
            ctx.stroke()
        } else if (kind === "disconnect") {
            // broken link — two offset chain halves
            rr(ctx, 3, cy - 4, 9, 8, 4); ctx.stroke()
            rr(ctx, w - 12, cy - 4, 9, 8, 4); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(cx - 1, cy - 6); ctx.lineTo(cx + 1, cy - 9); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(cx - 1, cy + 6); ctx.lineTo(cx + 1, cy + 9); ctx.stroke()
        }
    }
}
