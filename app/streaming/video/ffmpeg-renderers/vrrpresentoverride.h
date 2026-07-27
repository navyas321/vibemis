#pragma once

// BL-2531 diagnostic instrument: VIBEMIS_PRESENT_MODE_OVERRIDE.
//
// The on-device A/B (test146) needs to vary the Vulkan present mode
// INDEPENDENTLY of the Enable VRR flag: the toggle is confounded -- flipping
// it swaps Mailbox <-> FIFO presentation along with the pacing path, and the
// measured ~21.5% rendered-FPS cost (and the user-visible ghosting) may live
// in either half. This env var lets the test agent pin the present mode per
// session while every other effect of the VRR flag stays untouched.
//
// It is a TESTING INSTRUMENT, not user configuration (BL-2235 forbids
// env-var UX): flag-gated exactly like MOONLIGHT_VRR_TRACE, never read from
// settings, never required for any feature, and loudly logged when active.
// The consumer (PlVkRenderer::applyPresentModeOverride) must keep two
// properties CI-guarded by check-vrr-invariants.sh:
//   1. support-checked -- an unsupported mode is ignored with a warning, so a
//      typo can never create an invalid swapchain;
//   2. VRR-state-neutral -- it must never touch m_VrrFallbackReason, so the
//      pacing path selected for the session is exactly what the experiment
//      holds constant.
//
// Parsing lives here, Vulkan-free, so the standalone VRR test binaries can
// pin the contract without linking plvk.

enum class PresentModeOverride {
    Unset,      // env var absent/empty: no override, normal selection
    Unknown,    // env var present but not a recognized mode: warn + ignore
    Mailbox,
    Fifo,
    FifoRelaxed,
    Immediate,
};

inline bool presentOverrideTokenEquals(const char* value, const char* token)
{
    // Case-insensitive ASCII compare; no Qt so the standalone tests stay
    // dependency-free.
    while (*value != '\0' && *token != '\0') {
        char a = *value >= 'A' && *value <= 'Z' ? *value + ('a' - 'A') : *value;
        char b = *token >= 'A' && *token <= 'Z' ? *token + ('a' - 'A') : *token;
        if (a != b) {
            return false;
        }
        ++value;
        ++token;
    }
    return *value == '\0' && *token == '\0';
}

inline PresentModeOverride parsePresentModeOverride(const char* value)
{
    if (value == nullptr || value[0] == '\0') {
        return PresentModeOverride::Unset;
    }

    if (presentOverrideTokenEquals(value, "mailbox")) {
        return PresentModeOverride::Mailbox;
    }
    if (presentOverrideTokenEquals(value, "fifo")) {
        return PresentModeOverride::Fifo;
    }
    if (presentOverrideTokenEquals(value, "fifo_relaxed") ||
        presentOverrideTokenEquals(value, "fiforelaxed")) {
        return PresentModeOverride::FifoRelaxed;
    }
    if (presentOverrideTokenEquals(value, "immediate")) {
        return PresentModeOverride::Immediate;
    }

    return PresentModeOverride::Unknown;
}

inline const char* presentModeOverrideName(PresentModeOverride mode)
{
    switch (mode) {
    case PresentModeOverride::Unset:
        return "unset";
    case PresentModeOverride::Unknown:
        return "unknown";
    case PresentModeOverride::Mailbox:
        return "mailbox";
    case PresentModeOverride::Fifo:
        return "fifo";
    case PresentModeOverride::FifoRelaxed:
        return "fifo_relaxed";
    case PresentModeOverride::Immediate:
        return "immediate";
    }

    return "unknown";
}
