#!/usr/bin/env python3
"""Generate Vibemis's Steam library artwork from the brand tokens.

Steam shows a non-Steam shortcut as a flat coloured rectangle with the app's name in
plain text unless artwork exists in `userdata/<id>/config/grid/`. Every other app in the
library ships art, so Vibemis was the one entry in Game Mode that looked broken.

The four assets Steam actually looks for, and where each is used:

    <appid>p.png      600x900   PORTRAIT CAPSULE - the library grid tile. The one you see.
    <appid>.png       920x430   LANDSCAPE CAPSULE - "recent games" rows, some list views.
    <appid>_hero.png  1920x620  HERO - full-bleed banner behind the game's detail page.
    <appid>_logo.png  ~800x310  LOGO - transparent, drawn ON TOP of the hero by Steam.

The hero therefore carries NO text: Steam composites the logo over it, and a hero with
its own wordmark renders the name twice. The capsules do carry the wordmark, because
nothing is overlaid on them.

Tokens come from docs/design/redesign/logo/README.md: a cut-gem diamond cradling a play
triangle, teal accent #6ADDE7 -> #2FC6D0, on a dark tile #14181D -> #0A0C0F. The mark is
drawn programmatically rather than upscaled from mark-512.png so it stays crisp at
1920px wide.

Usage:  python3 scripts/gen-steam-artwork.py [--out app/res/steam]
Outputs are COMMITTED, so this only needs re-running when the brand changes.
"""
from __future__ import annotations

import argparse
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
except ImportError:
    sys.exit("Pillow is required: pip install Pillow")

ACCENT_HI = (0x6A, 0xDD, 0xE7)   # #6ADDE7
ACCENT_LO = (0x2F, 0xC6, 0xD0)   # #2FC6D0
TILE_HI = (0x14, 0x18, 0x1D)     # #14181D
TILE_LO = (0x0A, 0x0C, 0x0F)     # #0A0C0F

SS = 4  # supersampling factor -- draw big, downscale, get clean antialiased edges.

# Candidate wordmark faces, best first. A geometric/technical sans matches the mark's
# straight-edged geometry; the DejaVu fallback is what Linux CI has.
FONT_CANDIDATES = [
    "C:/Windows/Fonts/bahnschrift.ttf",
    "C:/Windows/Fonts/arialbd.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
]


def load_font(px: int) -> ImageFont.FreeTypeFont:
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, px)
            except OSError:
                continue
    raise SystemExit(
        "No usable TTF found. Install DejaVu (Linux) or run on Windows.\n"
        "Tried:\n  " + "\n  ".join(FONT_CANDIDATES)
    )


def linear_gradient(size, c0, c1, diagonal=True) -> Image.Image:
    """Solid image with a linear gradient, used as the paint behind a shape mask."""
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    denom = float((w - 1) + (h - 1)) if diagonal else float(h - 1)
    denom = denom or 1.0
    for y in range(h):
        for x in range(w):
            t = ((x + y) / denom) if diagonal else (y / denom)
            t = 0.0 if t < 0 else (1.0 if t > 1 else t)
            px[x, y] = (
                int(c0[0] + (c1[0] - c0[0]) * t),
                int(c0[1] + (c1[1] - c0[1]) * t),
                int(c0[2] + (c1[2] - c0[2]) * t),
            )
    return img


def mark_mask(box: int) -> Image.Image:
    """L-mode mask of the brand mark in a box x box square, per the design-kit ratios:
    diamond half-diagonal ~37% of the box, stroke ~7.8%, filled play triangle ~30% tall."""
    s = box * SS
    m = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(m)
    c = s / 2.0
    half = 0.37 * s
    stroke = 0.078 * s

    outer = [(c, c - half), (c + half, c), (c, c + half), (c - half, c)]
    inner_half = half - stroke
    inner = [(c, c - inner_half), (c + inner_half, c), (c, c + inner_half), (c - inner_half, c)]
    d.polygon(outer, fill=255)
    d.polygon(inner, fill=0)          # hollow it out -> a diamond ring

    tri_h = 0.30 * s
    tri_w = tri_h * 0.86
    d.polygon(
        [(c - tri_w / 2, c - tri_h / 2), (c - tri_w / 2, c + tri_h / 2), (c + tri_w / 1.55, c)],
        fill=255,
    )
    return m.resize((box, box), Image.LANCZOS)


def paint_mark(box: int, glow: bool = True) -> Image.Image:
    """RGBA brand mark: teal gradient through the shape mask, with an optional soft glow."""
    mask = mark_mask(box)
    grad = linear_gradient((box, box), ACCENT_HI, ACCENT_LO)
    out = Image.new("RGBA", (box, box), (0, 0, 0, 0))
    if glow:
        halo = mask.filter(ImageFilter.GaussianBlur(box * 0.045))
        halo = halo.point(lambda v: int(v * 0.55))
        glow_layer = Image.new("RGBA", (box, box), ACCENT_HI + (0,))
        glow_layer.putalpha(halo)
        out.alpha_composite(glow_layer)
    body = grad.convert("RGBA")
    body.putalpha(mask)
    out.alpha_composite(body)
    return out


def backdrop(size) -> Image.Image:
    """Dark tile gradient plus a teal radial bloom, so the capsules read as one family."""
    w, h = size
    bg = linear_gradient(size, TILE_HI, TILE_LO, diagonal=False).convert("RGBA")
    bloom_box = int(max(w, h) * 1.05)
    bloom = Image.new("L", (bloom_box, bloom_box), 0)
    ImageDraw.Draw(bloom).ellipse(
        (bloom_box * 0.22, bloom_box * 0.22, bloom_box * 0.78, bloom_box * 0.78), fill=70
    )
    bloom = bloom.filter(ImageFilter.GaussianBlur(bloom_box * 0.16))
    layer = Image.new("RGBA", (bloom_box, bloom_box), ACCENT_LO + (0,))
    layer.putalpha(bloom)
    bg.alpha_composite(layer, ((w - bloom_box) // 2, (h - bloom_box) // 2))
    return bg


def draw_wordmark(img: Image.Image, cx: int, top: int, px: int, tracking_ratio=0.14) -> int:
    """Letter-spaced 'VIBEMIS' centred on cx. Returns the bottom y."""
    font = load_font(px)
    text = "VIBEMIS"
    tracking = px * tracking_ratio
    d = ImageDraw.Draw(img)
    widths = [d.textlength(ch, font=font) for ch in text]
    total = sum(widths) + tracking * (len(text) - 1)
    x = cx - total / 2.0
    for ch, w in zip(text, widths):
        d.text((x, top), ch, font=font, fill=(0xF2, 0xF6, 0xF8, 255))
        x += w + tracking
    return top + px


def portrait(path: str) -> None:
    w, h = 600, 900
    img = backdrop((w, h))
    box = 340
    img.alpha_composite(paint_mark(box), ((w - box) // 2, 196))
    bottom = draw_wordmark(img, w // 2, 606, 76)
    d = ImageDraw.Draw(img)
    sub = load_font(27)
    label = "GAME STREAMING"
    d.text(((w - d.textlength(label, font=sub)) / 2, bottom + 34), label,
           font=sub, fill=(0x7F, 0x93, 0x9C, 255))
    img.convert("RGB").save(path)


def landscape(path: str) -> None:
    w, h = 920, 430
    img = backdrop((w, h))
    box = 250
    img.alpha_composite(paint_mark(box), (96, (h - box) // 2))
    d = ImageDraw.Draw(img)
    font = load_font(84)
    tracking = 84 * 0.13
    x, text = 392, "VIBEMIS"
    for ch in text:
        d.text((x, 150), ch, font=font, fill=(0xF2, 0xF6, 0xF8, 255))
        x += d.textlength(ch, font=font) + tracking
    sub = load_font(25)
    d.text((396, 254), "GAME STREAMING", font=sub, fill=(0x7F, 0x93, 0x9C, 255))
    img.convert("RGB").save(path)


def hero(path: str) -> None:
    # NO text and nothing solid in the lower-left: Steam composites _logo.png on top of
    # this, anchored bottom-left. A mark placed there collides with the logo, and a
    # wordmark here renders the name twice. So the hero is pure atmosphere, with the
    # ghosted mark pushed to the right third to leave the logo clean space.
    w, h = 1920, 620
    img = backdrop((w, h))
    box = 1000
    ghost = paint_mark(box, glow=False)
    ghost.putalpha(ghost.getchannel("A").point(lambda v: int(v * 0.18)))
    img.alpha_composite(ghost, (int(w * 0.63), (h - box) // 2))
    img.convert("RGB").save(path)


def logo(path: str) -> None:
    w, h = 840, 320
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    box = 250
    img.alpha_composite(paint_mark(box), (18, (h - box) // 2))
    d = ImageDraw.Draw(img)
    font = load_font(96)
    tracking = 96 * 0.12
    x = 300
    for ch in "VIBEMIS":
        d.text((x, 90), ch, font=font, fill=(0xFF, 0xFF, 0xFF, 255))
        x += d.textlength(ch, font=font) + tracking
    img.save(path)


def icon(path: str) -> None:
    box = 256
    img = backdrop((box, box))
    inner = 232
    img.alpha_composite(paint_mark(inner), ((box - inner) // 2, (box - inner) // 2))
    img.save(path)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default="app/res/steam", help="output directory")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)

    targets = [
        ("vibemis_p.png", portrait, "600x900 portrait capsule (the library grid tile)"),
        ("vibemis.png", landscape, "920x430 landscape capsule"),
        ("vibemis_hero.png", hero, "1920x620 hero banner (no text - logo overlays it)"),
        ("vibemis_logo.png", logo, "transparent logo drawn over the hero"),
        ("vibemis_icon.png", icon, "256x256 icon"),
    ]
    for name, fn, desc in targets:
        dest = os.path.join(args.out, name)
        fn(dest)
        print(f"  {name:20s} {os.path.getsize(dest):>7,d} B  {desc}")
    print(f"\nWrote {len(targets)} assets to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
