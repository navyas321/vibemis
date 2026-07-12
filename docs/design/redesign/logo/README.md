# Vibemis — logo & app icons

A **cut-gem diamond cradling a play triangle** — reads as "stream & launch a game," and echoes
the diamond bug in the in-app wordmark. Teal accent (`#2FC6D0` → `#6ADDE7`) with a soft glow on a
dark tile (`#14181D` → `#0A0C0F`).

## Files
```
logo/app/
├─ tile-16 / 20 / 24 / 32 / 40 / 48 / 64 / 128 / 256 / 512.png   rounded app-icon tile (full bleed)
└─ mark-128 / 256 / 512.png                                       transparent mark only (diamond + play)
```

## Use it
- **Linux / SteamOS desktop icon** — install the `tile-*` PNGs into the hicolor theme
  (`share/icons/hicolor/<size>/apps/vibemis.png`) and point your `.desktop` file at `vibemis`.
  Ship at least 32/48/64/128/256.
- **Steam library / Game Mode grid** — use `tile-256.png` (or `512`) as the app tile.
- **In-app header bug** — use `mark-256.png` (transparent) at ~18–22 px next to the "VIBEMIS"
  wordmark; the current prototype draws a plain rotated square there — swap in this mark.
- **Windows host build (if any)** — pack `tile-16,24,32,48,256` into a multi-res `.ico`
  (`magick tile-16.png tile-24.png tile-32.png tile-48.png tile-256.png vibemis.ico`).

## Regenerating / new sizes
Marks are drawn programmatically from the tokens. To add a size: draw a diamond (half-diagonal
≈ 37% of the box), stroke ≈ 7.8% of box (bolder ≈ 9.8% below 40 px), with a filled play triangle
(≈ 30% tall) centered inside; accent gradient `#6ADDE7 → #2FC6D0`; drop the glow at sizes ≤ 40 px so
it stays crisp.
