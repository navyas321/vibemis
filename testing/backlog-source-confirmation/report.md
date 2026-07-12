# Backlog cycles — SOURCE-CONFIRMED (runtime deferred: Settings-view mouse / in-stream host)

Non-disruptive source verification of the remaining queued feature cycles (their branches), done while
the maintainer is live on the real host. Each feature's wiring is present and correct; **runtime** needs
either the Settings **view** (mouse-only in gamescope — uinput is systemwide) or a **live stream** (host
currently in use) — deferred to a free host / the Sunshine mock-host.

| Cycle | Feature | Source location | Status |
|---|---|---|---|
| test23 | Vibepollo quality presets | `SettingsView.qml:135` `StreamingPreferences.applyPreset()` + "Applied: …next stream" | ✅ source |
| test24 | Compact performance overlay | `SettingsView.qml:2233-2240` `compactPerformanceOverlay` checkbox + persisted setting | ✅ source |
| test25 | Video scale mode (Fit/Fill/Stretch) | `SettingsView.qml:987-989` ListElements Fit(0)/Fill(1)/Stretch | ✅ source |
| test26 | Configurable Quick Menu shortcut | `SettingsView.qml:1803-1810` "Quick Menu shortcut" `quickMenuComboBox` | ✅ source |
| test31 | In-stream video zoom | `keyboard.cpp:175-185` `prefs->videoZoomFactor` (key-combo adjust) | ✅ source |
| test32 | In-stream video pan | `keyboard.cpp:188-204` `prefs->videoPanX/Y`, `KeyComboPanLeft/Right/Up/Down` | ✅ source |
| test40 | Battery-saver bitrate | `SettingsView.qml:1583` `reduceBitrateOnBatteryCheck` | ✅ source |

(Also source-confirmed this session: test29 Paste, test33 Stream Info, test47 Special Keys → PR #163; test82 motion forwarding → PR #162.)

## Runtime plan
- **Settings-bound** (test23/24/25/26/40): open Settings, toggle/select, confirm the value persists in
  `~/.config/Vibemis Project/Vibemis.conf`. Needs the Settings view (gear = mouse; uinput mouse is
  systemwide/headless-CI-only). Best done via a keyboard path if one is added, or on-device.
- **In-stream** (test31/32 zoom/pan): during a live stream, use the key combos and confirm the video
  transform. Needs a free host (deferred — maintainer live) or the mock-host.

**No code concerns from source review** — all features are wired and default-safe. This documents
coverage so nothing is silently untested; ticks pending the runtime pass.
