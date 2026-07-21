#pragma once

#include <cstdint>

// BL-2265: catastrophic bitrate-collapse rescue policy.
//
// When the configured stream bitrate exceeds the network path's effective
// throughput ceiling, Sunshine-class hosts emit each frame as a line-rate
// burst and the slowest segment tail-drops every burst. FEC parity is sent
// LAST in each frame, so it is the first casualty: no frame is recoverable,
// the client's IDR requests storm (each IDR is itself oversized and also
// truncated), and delivery pins below 1 fps at ANY frame rate (host-side RCA:
// 90/100/116 fps all collapse identically at 32 Mbps; 116 fps is pristine at
// 10 Mbps). The protocol has no runtime bitrate renegotiation
// (STREAM_CONFIGURATION.bitrate is write-once at LiStartConnection), so the
// rescue is a fast client-side reconnect at an aggressively stepped-down
// bitrate.
//
// This object is the PURE decision logic (no Qt/SDL/session dependency) so
// the signature thresholds and the step schedule can be unit tested, in the
// style of VrrRatePolicy.
class BitrateRescuePolicy
{
public:
    struct Config {
        // Minimum sustained observation before a collapse verdict. The
        // collapse signature is extreme (>90% of offered frames lost), so a
        // short window is safe and keeps the rescue inside "a few seconds".
        uint32_t windowMs;
        // Minimum offered frames (delivered + dropped) in the window before
        // any verdict — never fire on a tiny sample.
        uint32_t minOfferedFrames;
        // Collapse requires at least this share of offered frames dropped by
        // the network (client-side mirror of the unrecoverable-frame streak /
        // IDR-request storm: frames that FEC could not recover never reach
        // the decoder and appear as frame-number gaps).
        double minDroppedShare;
        // ...AND the delivered frame rate must be under this share of the
        // negotiated stream fps. A healthy stream at mild loss stays far
        // above this; a death-spiral (0.36 fps of 116) is far below it.
        double maxDeliveredFpsShare;
        // Step schedule: halve toward this floor; never step below it and
        // never step at all once at/below it.
        int floorKbps;
        // Round each step down to a multiple of this (display sanity).
        int roundKbps;
    };

    static Config defaultConfig();

    // Pure verdict for one observation window of delivered/dropped frames.
    // targetFps is the negotiated stream frame rate (normalized, NOT the
    // Apollo fps*1000 representation).
    static bool isCollapse(uint32_t elapsedMs,
                           uint32_t deliveredFrames,
                           uint32_t droppedFrames,
                           int targetFps,
                           const Config& cfg = defaultConfig());

    // The step schedule: aggressive halving toward the floor, rounded down
    // to cfg.roundKbps. Returns 0 when no further step is possible (current
    // bitrate already at/below the floor) — the caller must NOT rescue then.
    // e.g. 32000 -> 16000 -> 8000 -> 4000 -> 2000 -> 0(stop).
    static int nextBitrateKbps(int currentKbps, const Config& cfg = defaultConfig());

    // BL-2265 guard for the BL-2235 VRR fps auto-derive: deriving a HIGHER
    // fps must never inflate the session bitrate — auto-derive changes fps,
    // not bandwidth appetite. If the configured bitrate is exactly the
    // auto-computed default for the DERIVED fps and that exceeds the default
    // for the fps the user actually had, fall back to the user-fps default.
    // An explicit user bitrate (any value not equal to the derived-fps
    // default) is always respected exactly.
    static int bitrateForAutoDerivedFps(int configuredKbps,
                                        int defaultAtUserFpsKbps,
                                        int defaultAtDerivedFpsKbps);
};
