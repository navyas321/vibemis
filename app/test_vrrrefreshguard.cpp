// Vibemis (BL-2296): standalone unit tests for the same-display
// refresh-mode-switch guard predicates (StreamUtils::vrrRefreshSwitchNeedsProbe
// and StreamUtils::vrrRefreshSwitchRequiresRequalification), ported from the
// Nonary moonlight-qt v6.1.0-vrr9.1 refreshMayHaveChanged guard and adapted to
// vibemis's requalify-per-decoder-creation architecture.
//
// The predicates are pure header-inline members of StreamUtils, so this
// harness needs SDL2 *headers* (streamutils.h includes SDL_compat.h) but no
// SDL, Qt, or renderer linkage. Like the repo's other standalone tests
// (test_vrrratepolicy.cpp, test_otp_pairing.cpp) it lives in app/ with its
// own main() and is NOT part of the app build.
//
// Build & run (WSL2 / any Linux with g++ and libsdl2-dev; one line):
//   g++ -std=c++17 -Wall -Wextra -Werror $(sdl2-config --cflags) -Iapp
//       app/test_vrrrefreshguard.cpp -o /tmp/test_vrrrefreshguard
//   /tmp/test_vrrrefreshguard
//
// Exits 0 when every check passes, 1 otherwise (one "FAIL ..." line each).

#include "streaming/streamutils.h"

#include <cstdio>

static int g_Failures = 0;
static int g_Checks = 0;

#define CHECK(cond) \
    do { \
        g_Checks++; \
        if (!(cond)) { \
            g_Failures++; \
            fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond); \
        } \
    } while (0)

// Phase 1: only probe SDL display state when a VRR session actually holds
// adaptive presentation (paced or unpaced -- BL-2529) AND the window event
// could have changed the display refresh.
static void testNeedsProbe()
{
    // Qualified, presenting adaptively, and the event may have changed the
    // refresh: probe.
    CHECK(StreamUtils::vrrRefreshSwitchNeedsProbe(120, true, true));
    CHECK(StreamUtils::vrrRefreshSwitchNeedsProbe(144, true, true));

    // The last qualification pass rejected (or never requested) VRR: the
    // worker is on fixed pacing with no qualified rate to go stale.
    CHECK(!StreamUtils::vrrRefreshSwitchNeedsProbe(0, true, true));

    // Qualified at session level but the renderer fell back to fixed
    // presentation (non-Vulkan renderer, presenter rejection, worker startup
    // failure): retain upstream's window-event behavior untouched.
    CHECK(!StreamUtils::vrrRefreshSwitchNeedsProbe(120, false, true));

    // Window event that cannot have changed the display refresh.
    CHECK(!StreamUtils::vrrRefreshSwitchNeedsProbe(120, true, false));

    // Fully inert combination.
    CHECK(!StreamUtils::vrrRefreshSwitchNeedsProbe(0, false, false));
}

// Phase 2: the requalification decision from the strict refresh probe.
static void testRequiresRequalification()
{
    // Same rate as qualified: nothing changed, no recreation churn.
    CHECK(!StreamUtils::vrrRefreshSwitchRequiresRequalification(120, true, 120));
    CHECK(!StreamUtils::vrrRefreshSwitchRequiresRequalification(144, true, 144));

    // Same-display mode switch to a lower rate: the qualified rate is stale.
    CHECK(StreamUtils::vrrRefreshSwitchRequiresRequalification(120, true, 90));

    // Mode switch to a higher rate is just as stale (the worker would pace
    // slower than the panel allows, and headroom must be re-derived).
    CHECK(StreamUtils::vrrRefreshSwitchRequiresRequalification(120, true, 144));

    // Refresh became unreadable: never keep pacing against a rate that can no
    // longer be verified (matches the strict-probe qualification rule).
    CHECK(StreamUtils::vrrRefreshSwitchRequiresRequalification(120, false, 0));

    // Unreadable wins even when the stale out-value happens to match.
    CHECK(StreamUtils::vrrRefreshSwitchRequiresRequalification(120, false, 120));

    // Defensive: no qualified rate means nothing to requalify (phase 1
    // already gates this, but the predicate must not misfire on its own).
    CHECK(!StreamUtils::vrrRefreshSwitchRequiresRequalification(0, true, 120));
    CHECK(!StreamUtils::vrrRefreshSwitchRequiresRequalification(0, false, 0));
}

// End-to-end walk of the guard's decision table as session.cpp composes it.
static void testGuardScenarios()
{
    struct Scenario {
        const char* name;
        int qualifiedHz;        // m_ActiveVrrRefreshHz
        bool adaptiveActive;    // m_VideoDecoder->isAdaptivePresentationActive()
        bool mayHaveChanged;    // refreshMayHaveChanged from the window event
        bool refreshReadable;   // StreamUtils::tryGetDisplayRefreshRate result
        int currentHz;          // probed rate
        bool expectRecreation;
    };

    const Scenario scenarios[] = {
        { "borderless resize event, rate unchanged",
          120, true, true, true, 120, false },
        { "same-display mode switch 120 -> 90 via SIZE_CHANGED",
          120, true, true, true, 90, true },
        // BL-2529: an unpaced VRR session (frame pacing off) reports
        // adaptiveActive=true with no worker running, and its qualified rate
        // goes stale exactly like the paced mode's. This row pins the session
        // wiring: feed the guard isAdaptivePresentationActive(), never
        // isVrrActive(), or this scenario's input cannot be produced.
        { "adaptive UNPACED session, mode switch 120 -> 90",
          120, true, true, true, 90, true },
        { "same-display mode switch 120 -> 144 via DISPLAY_CHANGED",
          120, true, true, true, 144, true },
        { "refresh became unreadable mid-session",
          120, true, true, false, 0, true },
        { "fixed-pacing fallback session ignores mode switch",
          0, false, true, true, 90, false },
        { "VRR qualified but renderer inactive: upstream path untouched",
          120, false, true, true, 90, false },
        { "unrelated window event while VRR pacing",
          120, true, false, true, 120, false },
    };

    for (const Scenario& s : scenarios) {
        bool recreation = false;
        if (StreamUtils::vrrRefreshSwitchNeedsProbe(s.qualifiedHz,
                                                    s.adaptiveActive,
                                                    s.mayHaveChanged)) {
            recreation = StreamUtils::vrrRefreshSwitchRequiresRequalification(
                s.qualifiedHz, s.refreshReadable, s.currentHz);
        }
        g_Checks++;
        if (recreation != s.expectRecreation) {
            g_Failures++;
            fprintf(stderr, "FAIL %s:%d: scenario '%s' expected %d got %d\n",
                    __FILE__, __LINE__, s.name, s.expectRecreation, recreation);
        }
    }
}

int main()
{
    testNeedsProbe();
    testRequiresRequalification();
    testGuardScenarios();

    if (g_Failures != 0) {
        fprintf(stderr, "%d of %d checks FAILED\n", g_Failures, g_Checks);
        return 1;
    }

    printf("all %d checks passed\n", g_Checks);
    return 0;
}
