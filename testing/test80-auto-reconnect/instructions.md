# test80 — Auto-reconnect on unexpected stream drop (P3.21)

**Branch:** `test80-auto-reconnect` (auto-merges on green CI) · **Report:** `diagnostic/test80-auto-reconnect-report`
**Artifact:** merged beta (0.10.0) or this branch's alpha via `run-cycle.sh test80-auto-reconnect`.
**Setting:** `autoreconnect` — **default OFF** this slice. Enable via conf:
`printf '\nautoreconnect=true\n' >> ~/.config/Vibemis\ Project/Vibemis.conf` (no UI toggle yet — deferred to avoid SettingsView conflicts with pending test23/24/40).

## Tier 1 — reconnect behavior (gamescope emulation, streaming)
1. Enable the setting, stream Desktop. Simulate an unexpected drop — easiest headless options:
   (a) on the HOST side ask the build agent on the bus to briefly firewall/restart the stream, or
   (b) `iptables`-less client-side: drop Wi-Fi for ~5 s (`rfkill block wifi; sleep 5; rfkill unblock wifi`) if permitted, or
   (c) kill the host's session pipe if you have a lever. If none is feasible, mark Tier 1
   **N/A (no drop lever)** and do Tier 2 only — say so explicitly.
2. EXPECT: segue shows "Connection lost — reconnecting to Desktop (attempt 1 of 3)..." and the
   stream comes back without returning to the grid. Log shows a fresh connection sequence.
3. With the host fully DOWN: EXPECT exactly 3 attempts (backoff 1.5s/3s/4.5s), then the normal
   error dialog + return to the grid. No infinite loop, no crash.

## Tier 2 — regression with the setting OFF (default)
1. Unset/false `autoreconnect`. Stream, then quit normally (combo) → EXPECT the old behavior
   exactly (back to grid, no reconnect attempt, no new dialog).
2. User-initiated disconnect with the setting ON → EXPECT NO reconnect (only unexpected drops arm it).
3. `selftest` PASS; settings roundtrip includes `autoreconnect`.

## Report
`testing/test80-auto-reconnect/report.md` on `diagnostic/test80-auto-reconnect-report`; tick the row; bus announce.
