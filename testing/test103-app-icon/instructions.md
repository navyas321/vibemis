# test103 — Branded app icon in the Linux desktop / hicolor icon set (BL-1566)

Wires the redesign **brand mark** into the Linux icon set so the AppImage, the
`.desktop` entry, and **Add to Steam** show the Vibemis mark instead of a generic
(old Moonlight) icon.

What changed:
- New branded hicolor PNGs shipped in the repo and installed by `make install`
  (`app/app.pro` → `INSTALLS icon128 icon256 icon512`):
  `usr/share/icons/hicolor/{128x128,256x256,512x512}/apps/vibemis.png`
  (sourced from `app/res/vibemis-mark-{128,256,512}.png`, the same art `main.cpp`
  already uses for the window `QIcon`).
- The `.desktop` `Icon=` key is **`vibemis`** (unchanged) — now resolves to the
  branded PNGs.
- CI (`.github/workflows/dev-build.yml`): the old "Render icon PNG from SVG" step
  (which rasterised the **stale** `res/vibemis.svg`) is gone; linuxdeploy's
  `--icon-file …/256x256/apps/vibemis.png` now uses the branded PNG for `.DirIcon`.
- `scripts/build-appimage.sh`: linuxdeploy gets an explicit `--icon-file` (branded
  256 PNG), and the AppRun desktop-integration hook installs the branded PNG into
  the user's `~/.local/share/icons/hicolor/256x256/apps/vibemis.png`.
- There is no vector master for the raster brand mark, so **no** `scalable/apps/vibemis.svg`
  is shipped anymore (PNG-only theme, 128/256/512).

## Scorecard

**Build** — CI alpha `0.23.1-alpha.test103-*` must be green (this branch). Download
that AppImage. Set `APP=./Vibemis-0.23.1-*-x86_64.AppImage` for the commands below.

**Tier 1 — icon files in the AppImage (deterministic, no GUI):**
1. Extract: `"$APP" --appimage-extract >/dev/null && cd squashfs-root`
2. All three branded PNGs present at the right sizes:
   `file usr/share/icons/hicolor/128x128/apps/vibemis.png` → `PNG image data, 128 x 128 … RGBA`
   `file usr/share/icons/hicolor/256x256/apps/vibemis.png` → `PNG image data, 256 x 256 … RGBA`
   `file usr/share/icons/hicolor/512x512/apps/vibemis.png` → `PNG image data, 512 x 512 … RGBA`
3. The AppImage top-level icon is the branded mark (not generic):
   `file .DirIcon` → resolves to a `PNG image data, 256 x 256` (the brand mark).
   Optional proof it matches the source: `cmp .DirIcon usr/share/icons/hicolor/256x256/apps/vibemis.png` → no output (identical), or compare against `usr/share/icons/hicolor/256x256/apps/vibemis.png`.
4. `.desktop` icon name matches: `grep '^Icon=' usr/share/applications/com.vibemis.Vibemis.desktop`
   → `Icon=vibemis`
5. The stale old-logo SVG is gone: `test ! -e usr/share/icons/hicolor/scalable/apps/vibemis.svg && echo OK-absent`
   → prints `OK-absent`.
   (Then `cd ..` and `rm -rf squashfs-root`.)

**Tier 2 — window / taskbar icon at runtime (Desktop Mode):**
6. Launch `"$APP"` in Desktop Mode. The window titlebar **and** the taskbar/dock
   entry show the **Vibemis brand mark** (rounded dark tile with the mark), NOT the
   old black/white Moonlight circle. Screenshot the window + taskbar.

**Tier 3 — desktop entry + Add to Steam:**
7. Install the clean desktop entry: `bash scripts/install-vibemis-desktop.sh "$APP"`
   Then verify the branded icon was extracted and referenced:
   `file ~/.local/share/icons/hicolor/256x256/apps/vibemis.png` → `PNG image data, 256 x 256`
   `grep -E '^(Icon|Name)=' ~/.local/share/applications/vibemis.desktop`
   → `Name=Vibemis` and `Icon=` points at the branded PNG (…/vibemis.png) or the name `vibemis`.
8. In the application launcher / menu, the **Vibemis** entry shows the brand mark.
   (Alternatively, launching the AppImage once triggers the AppRun hook which writes
   `~/.local/share/applications/Vibemis.desktop` + `~/.local/share/icons/hicolor/256x256/apps/vibemis.png`.)
9. **Add to Steam** (Desktop Mode → Games → Add a Non-Steam Game → tick "Vibemis"),
   switch to Game Mode: the "Vibemis" shortcut shows the brand-mark icon (not a
   generic/placeholder tile). Screenshot the Game-Mode library tile.

**Negative / artifacts:**
10. No generic old-Moonlight logo appears anywhere (window, taskbar, launcher, Steam).
11. The icon renders crisp with a transparent background — no tofu/□ box, no white
    square halo, no stretched/blurry scaling at any of the three surfaces above.

Report PASS/FAIL per numbered step. Attach: the Tier-1 `file` outputs (steps 2-5),
a Desktop-Mode window/taskbar screenshot (step 6), and a Game-Mode Steam tile
screenshot (step 9).
