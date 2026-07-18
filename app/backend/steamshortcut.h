#pragma once

// Vibemis self-registration: on Linux, silently ensure Vibemis has a proper
// Steam non-Steam-game shortcut with a working icon, without requiring the
// user to run any script or manually "Add a Non-Steam Game" in Steam.
//
// Safe by construction: if an existing shortcuts.vdf can't be parsed
// confidently, this backs off and writes nothing rather than risk
// corrupting the user's real Steam library data. Idempotent - a no-op on
// every launch after the first successful fix.
class SteamShortcut
{
public:
    // Call once, early, from a background thread (this does blocking file
    // I/O). No-op on non-Linux platforms and when no Steam installation is
    // found.
    static void ensureRegistered();
};
