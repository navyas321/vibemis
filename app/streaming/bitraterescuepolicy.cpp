#include "bitraterescuepolicy.h"

// Threshold rationale (BL-2265 host-side RCA, sessions S1/S3/S5/S6/S7):
// a collapsed session delivers <1 fps of a 116 fps stream with 95-99% of
// offered frames network-dropped, within the FIRST seconds. A healthy
// stream at the same settings shows 0 dropped frames. Even a rough Wi-Fi
// patch (a few % loss with FEC recovering most frames) stays nowhere near
// 50% dropped + <25% delivered fps SUSTAINED for a full window, so the
// signature cleanly separates "catastrophic and unusable" from "imperfect".
BitrateRescuePolicy::Config BitrateRescuePolicy::defaultConfig()
{
    Config cfg;
    cfg.windowMs = 2500;
    cfg.minOfferedFrames = 30;
    cfg.minDroppedShare = 0.50;
    cfg.maxDeliveredFpsShare = 0.25;
    cfg.floorKbps = 2000;
    cfg.roundKbps = 500;
    return cfg;
}

bool BitrateRescuePolicy::isCollapse(uint32_t elapsedMs,
                                     uint32_t deliveredFrames,
                                     uint32_t droppedFrames,
                                     int targetFps,
                                     const Config& cfg)
{
    if (elapsedMs < cfg.windowMs || targetFps <= 0) {
        return false;
    }

    const uint32_t offered = deliveredFrames + droppedFrames;
    if (offered < cfg.minOfferedFrames) {
        return false;
    }

    const double droppedShare = (double)droppedFrames / (double)offered;
    if (droppedShare < cfg.minDroppedShare) {
        return false;
    }

    const double deliveredFps = (double)deliveredFrames * 1000.0 / (double)elapsedMs;
    return deliveredFps <= cfg.maxDeliveredFpsShare * (double)targetFps;
}

uint32_t BitrateRescuePolicy::expectedFrames(uint32_t elapsedMs, int targetFps)
{
    if (targetFps <= 0) {
        return 0;
    }
    return (uint32_t)(((uint64_t)targetFps * elapsedMs) / 1000);
}

bool BitrateRescuePolicy::isCollapseWallClock(uint32_t elapsedMs,
                                             uint32_t deliveredFrames,
                                             uint32_t gapDroppedFrames,
                                             int targetFps,
                                             const Config& cfg)
{
    const uint32_t expected = expectedFrames(elapsedMs, targetFps);

    // Effective dropped count is inferred from what the host should have
    // offered, so it keeps counting even when delivery (and therefore
    // gap-based accounting) starves completely.
    const uint32_t effDropped = (expected > deliveredFrames) ? (expected - deliveredFrames) : 0;

    if (!isCollapse(elapsedMs, deliveredFrames, effDropped, targetFps, cfg)) {
        return false;
    }

    // Network-loss evidence gate (idle-throttle false-positive guard): a
    // host that intentionally sends few frames produces no frame-number
    // gaps; genuine collapse either shows gaps at the trickle deliveries or
    // delivers nothing at all.
    return gapDroppedFrames > 0 || deliveredFrames == 0;
}

int BitrateRescuePolicy::nextBitrateKbps(int currentKbps, const Config& cfg)
{
    if (currentKbps <= cfg.floorKbps) {
        // Already at (or below) the floor — no rescue step remains.
        return 0;
    }

    int next = currentKbps / 2;
    if (cfg.roundKbps > 0) {
        next = (next / cfg.roundKbps) * cfg.roundKbps;
    }
    if (next < cfg.floorKbps) {
        next = cfg.floorKbps;
    }
    return next;
}

int BitrateRescuePolicy::bitrateForAutoDerivedFps(int configuredKbps,
                                                  int defaultAtUserFpsKbps,
                                                  int defaultAtDerivedFpsKbps)
{
    // Only intervene when the configured bitrate is exactly the auto-tracked
    // default for the DERIVED fps (i.e. it was inflated by the derived rate,
    // not chosen by the user) AND the inflation is real (derived default
    // higher than the user-fps default).
    if (configuredKbps == defaultAtDerivedFpsKbps &&
        defaultAtDerivedFpsKbps > defaultAtUserFpsKbps &&
        defaultAtUserFpsKbps > 0) {
        return defaultAtUserFpsKbps;
    }
    return configuredKbps;
}
