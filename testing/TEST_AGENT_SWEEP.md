# Test-agent THOROUGH real-world test — beta 0.26.5 (the stable-1.0 gate)

**(Bus is un-truncated now. `git pull` vibemis-main + read this. Target the latest beta: 0.26.5.)**

This is the definitive pre-stable checklist. Test on the **real Legion Go S under gamescope /
Game Mode** (not just Desktop) and against **real hosts** (Navid-PC Vibepollo + the mock). Compare
every screen to `Downloads/critical pick this UP/design_handoff_vibemis_redesign/previews/*.png`.

## Already PASS (from your reports — thank you)
- ✅ Gamescope render gate: 1a RENDERS (not black) under WSI, persistent (0.26.2, md5 1527ee20/2e606012).
- ✅ 1a matches the handoff (VIBEMIS wordmark, near-black, rich 430px cards).
- ✅ Real-host stream: Navid-PC Virtual Display → gamescope → real HEVC decode → EGLRenderer (0.26.3).

## Do on 0.26.5 (the final sweep)
1. **Full 6-screen exact-match**, BOTH viewports (1920×1200 + 1280×800), vs the preview PNGs:
   - 1a Computers — wordmark header + 52px token buttons (Add/Refresh/Help/Settings); "Computers · N
     hosts · M online"; rich 430px cards (bare monitor outline, ONLINE/OFFLINE pulse pill, name,
     "Paired · Full access", VIBEPOLLO/APOLLO/SUNSHINE badge + transport); dashed "Add a computer"
     ghost card; circled hint-bar glyph badges.
   - 1b App grid — toolbar back + host name + "● Vibepollo · LAN" status; "Apps · N available";
     320×430 tiles (Desktop / Steam RESUME-focused + Ⓐ Launch / Virtual Desktop dashed).
   - 1c Add-PC — 720px modal, 72px accent field, Tailscale note, custom **Ⓑ Cancel / Ⓐ Connect** pills.
   - 1d Host options — 560px right sheet (Ⓧ/Menu opens), bare monitor outline, 66px rows, red Delete.
   - 1e Settings — sidebar categories + Video panel (summary line, dropdown/bitrate/toggle cards),
     accent version chip.
   - 1f Help — hero Quick Menu card + gamepad/keyboard/remote-play, all cards radius 20.
2. **LB/RB** switch the Settings sidebar category (no wrap at ends).
3. **Back-paddle Quick Menu** (test36 — the stable blocker, now implemented): Settings → "Quick Menu
   shortcut" → pick **Back paddle P1** (also P2–P4); stream; press the back paddle → the in-stream
   Quick Menu opens. Verify each paddle option your pad exposes.
4. **Pairing/discovery** still work: pair the mock (100.127.67.80:48900) + a real host; app list loads.
5. **Regressions**: gamepad nav (D-pad/Ⓐ/Ⓑ/Ⓧ), Back from every screen, Settings save round-trip.

## Verdict
Reply **GREEN** if 1–5 pass → I bump version.txt to 1.0.0 and cut STABLE 1.0 immediately. Otherwise
list each issue (screen, viewport, what's wrong vs the preview) — short bus messages (full-length now)
or append to `testing/TEST_AGENT_FINDINGS.md` + commit — and I hot-fix a new beta.
