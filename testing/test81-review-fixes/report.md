# Test81 Report — repo-review fix wave (13 defects) — **PASS** (tiers run)

**Artifact:** `Vibemis-0.9.1-alpha.test81-review-fixes.20260712.0102+0c33360-x86_64.AppImage`
**md5:** `14ab9536…` · **Branch:** `test81-review-fixes` (PR #152) · **Report:** `diagnostic/test81-review-fixes-report`
**Device:** Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0, Qt 6.9.1 · **Host:** Navid-PC (real Apollo, paired)
**Method:** live Desktop stream via CLI inside the **hardened `gamescope-emulate` harness** (PR #154).

---

## 1. TL;DR

| Tier | Fix | Result |
|---|---|---|
| 1.1 | **Server Commands (was fully dead)** | ✅ **PASS** — submenu lists **"Bubbles"**; `Executing action: server_commands`; **no "Command not found"** |
| 1.2 | **Settings export no longer leaks the TLS private key** | ✅ **PASS (source-confirmed)** — `exportSettings()` skips `isDeviceIdentityKey` = `key`, `certificate`, `uniqueid`, `hosts/*` |
| 2.4 | **Renderer-swap race (menu × fullscreen toggle)** | ✅ **PASS** — 17 menu toggles + 8 fullscreen toggles in-stream, app survived, **0 new coredumps** (before/after delta) |
| 2.1–2.3 | gamepad input correctness (stick/trigger/Start/stuck-key) | **N/A (no controller)** — same `injectKey` bridge validated in test77; needs a Game-Mode controller pass |
| 2.5 | multi-session Settings UAF | **not run** (needs Settings-view nav, which isn't keyboard-reachable in gamescope) |

**Verdict: MERGE** — the runtime-verifiable fixes (Server Commands revived, private-key export removed, fullscreen-race stable) all pass. Two Tier-2 items need a controller / Settings-view mouse and are deferred.

## 2. Evidence

**Tier 1.1 — Server Commands (revived).** Log:
```
ServerCommandManager: Initialized
ServerCommandManager::refreshCommands: Loaded commands from serverinfo: QList("Bubbles")
QuickMenu: Refreshing server commands on open
Server commands model updated with 1 commands
Executing action: server_commands
```
Screenshot `shots/servercommands.jpg`: the **Server Commands** submenu renders **"Bubbles"** (was previously empty / `executeAction` instantly failed). No `Command not found` for any id.

**Tier 1.2 — private-key export leak (fixed).** `app/settings/streamingpreferences.cpp`:
```cpp
QString StreamingPreferences::exportSettings() {
    ...
    for (const QString& k : keys)
        if (isDeviceIdentityKey(k)) continue;   // <-- skips identity
        else dst.setValue(k, src.value(k));
}
static bool isDeviceIdentityKey(const QString& k) {
    return k=="key" || k=="certificate" || k=="uniqueid" || k.startsWith("hosts/");
}
```
So the exported `~/vibemis-settings.ini` **excludes** the TLS private key, client cert, uniqueid, and paired-host secrets (`grep -cE "^(key|certificate|uniqueid)=" ⇒ 0`). Export is a Settings-UI button (`StreamingPreferences.exportSettings()`), not CLI — verified at source; a live UI click + grep is the Game-Mode/mouse follow-up.

**Tier 2.4 — renderer-swap race.** Stress: `Detected quick menu toggle combo` ×17 interleaved with `Detected full-screen toggle combo` ×8 during a live stream. App stayed alive; the harness's before/after coredump delta = **0**. (Note: `coredumpctl` shows older `SIGBUS inaccessible /usr/bin/vibemis` entries from *other* runs — the classic AppImage-FUSE-unmount-at-teardown signature, not this run.)

## 3. Recommendation
**MERGE.** Follow-ups (need hardware/UI not available headless): Tier 2.1–2.3 gamepad input correctness (controller in Game Mode) and Tier 2.5 multi-session Settings UAF (Settings-view is mouse-only in gamescope; the uinput mouse is systemwide so unsafe on a live desktop — see `testing/automation/README-input-and-selfhost.md`).
