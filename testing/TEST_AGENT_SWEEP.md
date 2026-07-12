# Test-agent sweep — CORRECT redesign (beta 0.26.0+)

**(Bus truncates ~300 chars — full instructions here. `git pull` vibemis-main + read this.)**

## What changed (important)
The previously-shipped redesign DIVERGED from the design handoff. The **authoritative** source is
`Downloads/critical pick this UP/design_handoff_vibemis_redesign/previews/` (screens `1a`–`1f`,
1920×1200). Compare the app against **those PNGs**, not the older build.

0.26.0 rebuilds **1a Computers** to match `previews/1a-computers.png`:
- **VIBEMIS wordmark** top-left; 52px **Add / Refresh / Help / Settings** buttons top-right.
- **"Computers · N hosts · M online"** section title.
- **Rich 430px host cards**: monitor thumbnail, **● ONLINE / ● OFFLINE** pulse pill, name (Sora),
  access line ("Paired · Full access"), **VIBEPOLLO / APOLLO / SUNSHINE** badge + **"<transport>"**
  (LAN / Tailscale). *(Latency "4 ms" is deferred — BL-1598 — so cards show transport only for now.)*
- The **Material-blue global toolbar is gone** — every launcher screen owns its per-screen header.

## CRITICAL GATE — do this FIRST
The global toolbar collapse changed (`main.qml` redesignScreen is now DEFAULT-TRUE, so the toolbar is
height 0 from the first frame — no 60→0 startup transition). This is the exact area that caused the
0.25.0 gamescope black screen. **Verify 1a is NOT BLACK under gamescope / Game Mode before anything
else.** If black: capture the log (`Made gamescope surface` / `Destroying swapchain`) and report
immediately — I'll rework the header architecture. glxgears in the same gamescope = compositor OK.

## Then, against the previews
1. **1a Computers** — wordmark header renders; **host cards match** `1a-computers.png` (pill, name,
   access, badge = VIBEPOLLO for the mock/Navid-PC, transport). Pair the mock (100.127.67.80:48900) so
   real cards show.
2. **1b App grid** — header un-hidden (back + host + Settings); tiles (Desktop/Steam/Virtual Desktop).
   *(Full 1b tile polish still in progress — flag gaps vs `1b-app-grid.png`.)*
3. **1c/1d/1e/1f** — compare to previews; note any divergence (these are being re-checked).
4. Both viewports **1920×1200 + 1280×800**.

## Reporting
Incremental SHORT (<250 char) bus messages, or append to `testing/TEST_AGENT_FINDINGS.md` + commit.
The black-screen check is the release-blocking gate; everything else feeds the next hot-fix wave.
