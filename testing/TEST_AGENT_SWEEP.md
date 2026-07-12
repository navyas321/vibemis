# Test-agent sweep — beta 0.26.2 (black-screen fix + exact-match redesign)

**(Bus truncation is FIXED now — you get full messages. Still, the full list lives here.
`git pull` vibemis-main + read this.)**

## The black-screen fix (THE gate)
Root cause (from your data): a **collapsed / 0-height ApplicationWindow header black-screens under
the gamescope WSI path** (0.25.1 with the toolbar PRESENT rendered clean; 0.25.0 + 0.26.0 with it
collapsed went black). 0.26.2's fix: the **global toolbar is ALWAYS PRESENT at 84px and IS the
header** — VIBEMIS wordmark on Computers, Back + title elsewhere, Add/Refresh/Help/Settings + version
chip. Each screen's own header bar is removed (only its body section title remains), so there is no
double header. This reproduces your known-good render condition.

**DO THIS FIRST on 0.26.2:** confirm **1a RENDERS (not black) under gamescope / Game Mode.**
- If it renders → we are at the stable-1.0 gate. Proceed to the sweep below.
- If still black → the header isn't the whole cause; capture the log (`Made gamescope surface` /
  `Destroying swapchain: (nil)`) + report immediately. glxgears in the same gamescope = compositor OK.

## Exact-match sweep (against the previews)
The 6 screens were rebuilt to match `Downloads/critical pick this UP/design_handoff_vibemis_redesign`
(`previews/1a..1f` + the `.dc.html`). Compare the app to **those PNGs** at **1920×1200 AND 1280×800**:
1. **1a Computers** — VIBEMIS wordmark + Add/Refresh/Help/Settings; "Computers · N hosts · M online";
   rich 430px cards (82×58 monitor outline, ONLINE/OFFLINE pulse pill, name, "Paired · Full access",
   VIBEPOLLO/APOLLO/SUNSHINE badge + transport); circled hint-bar glyph badges. Pair the mock
   (100.127.67.80:48900) so real cards show.
2. **1b App grid** — Back + host + Refresh/Settings in the toolbar; "Apps · N available"; 320×430
   tiles (Desktop / Steam focused w/ RESUME + Ⓐ Launch / Virtual Desktop dashed).
3. **1c Add-PC** — 720px modal, 72px accent field, Tailscale note.
4. **1d Host options** — 560px right sheet (Ⓧ / Menu opens it), 66px rows, red Delete.
5. **1e Settings** — sidebar categories + Video panel (summary line, dropdown/bitrate/toggle cards),
   version chip, LB/RB switch hint.
6. **1f Help** — hero Quick Menu card + gamepad/keyboard/remote-play sections.

Report the gamescope render verdict FIRST (release-blocking), then per-screen findings — short bus
messages (full-length now) or append to `testing/TEST_AGENT_FINDINGS.md` + commit.
