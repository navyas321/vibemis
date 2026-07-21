// Vibemis (BL-2212): standalone unit tests for VrrRatePolicy (vendored from
// Nonary moonlight-qt v6.1.0-vrr9.1).
//
// VrrRatePolicy is deliberately dependency-free (no SDL, no Qt, no renderer),
// so this harness needs nothing but a C++17 compiler. Like the repo's other
// standalone test (test_otp_pairing.cpp) it lives in app/ with its own main()
// and is NOT part of the app build.
//
// Build & run (WSL2 / any Linux with g++; one line):
//   g++ -std=c++17 -Wall -Wextra -Werror app/test_vrrratepolicy.cpp
//       app/streaming/vrrratepolicy.cpp -o /tmp/test_vrrratepolicy
//   /tmp/test_vrrratepolicy
//
// Exits 0 when every check passes, 1 otherwise (one "FAIL ..." line each).

#include "streaming/vrrratepolicy.h"

#include <cstdio>
#include <vector>

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

static bool hasChoice(const std::vector<VrrFpsChoice>& choices,
                      int fps, VrrFpsChoiceKind kind)
{
    for (const VrrFpsChoice& choice : choices) {
        if (choice.fps == fps && choice.kind == kind) {
            return true;
        }
    }
    return false;
}

static bool hasFps(const std::vector<VrrFpsChoice>& choices, int fps)
{
    for (const VrrFpsChoice& choice : choices) {
        if (choice.fps == fps) {
            return true;
        }
    }
    return false;
}

int main()
{
    // ---- vrrRateForRefresh: floor(r - r^2/3600) ----
    // The documented reference points from the epic: 116 @ 120 Hz, 138 @ 144 Hz.
    CHECK(VrrRatePolicy::vrrRateForRefresh(120) == 116);
    CHECK(VrrRatePolicy::vrrRateForRefresh(144) == 138);
    CHECK(VrrRatePolicy::vrrRateForRefresh(60) == 59);
    CHECK(VrrRatePolicy::vrrRateForRefresh(165) == 157);  // floor(165*3435/3600)
    CHECK(VrrRatePolicy::vrrRateForRefresh(240) == 224);
    // Integer-only floor semantics: floor(r - r^2/3600) != r - floor(r^2/3600)
    // for 144 Hz (144 - floor(5.76) = 139, but the true floor is 138).
    CHECK(VrrRatePolicy::vrrRateForRefresh(144) != 144 - (144 * 144) / 3600);
    // Unusable refresh rates
    CHECK(VrrRatePolicy::vrrRateForRefresh(0) == 0);
    CHECK(VrrRatePolicy::vrrRateForRefresh(1) == 0);
    CHECK(VrrRatePolicy::vrrRateForRefresh(-60) == 0);
    // Degenerate huge rates never go negative
    CHECK(VrrRatePolicy::vrrRateForRefresh(3600) == 0);
    CHECK(VrrRatePolicy::vrrRateForRefresh(4000) == 0);

    // ---- lowLatencyRateForRefresh: floor((r*5/6)/5)*5 ----
    CHECK(VrrRatePolicy::lowLatencyRateForRefresh(120) == 100);
    CHECK(VrrRatePolicy::lowLatencyRateForRefresh(144) == 120);
    CHECK(VrrRatePolicy::lowLatencyRateForRefresh(60) == 50);
    CHECK(VrrRatePolicy::lowLatencyRateForRefresh(165) == 135);  // 137 -> 135
    CHECK(VrrRatePolicy::lowLatencyRateForRefresh(240) == 200);
    CHECK(VrrRatePolicy::lowLatencyRateForRefresh(0) == 0);
    CHECK(VrrRatePolicy::lowLatencyRateForRefresh(1) == 0);

    // ---- isNativeRefreshRate ----
    CHECK(VrrRatePolicy::isNativeRefreshRate(120, {60, 120}));
    CHECK(!VrrRatePolicy::isNativeRefreshRate(116, {60, 120}));
    CHECK(!VrrRatePolicy::isNativeRefreshRate(120, {}));

    // ---- hasAdaptiveHeadroom: session qualification ----
    // The stream period must exceed one display period plus the guard.
    CHECK(VrrRatePolicy::hasAdaptiveHeadroom(116, 120));
    CHECK(VrrRatePolicy::hasAdaptiveHeadroom(138, 144));
    CHECK(VrrRatePolicy::hasAdaptiveHeadroom(60, 120));
    CHECK(VrrRatePolicy::hasAdaptiveHeadroom(30, 60));
    // Streaming at (or above) the native refresh leaves no adaptive headroom.
    CHECK(!VrrRatePolicy::hasAdaptiveHeadroom(120, 120));
    CHECK(!VrrRatePolicy::hasAdaptiveHeadroom(144, 144));
    CHECK(!VrrRatePolicy::hasAdaptiveHeadroom(144, 120));
    // A rate just inside the guard band must be rejected too:
    // 119 @ 120 Hz -> stream 8403 us vs display 8333 us + 130 us guard.
    CHECK(!VrrRatePolicy::hasAdaptiveHeadroom(119, 120));
    // Invalid inputs
    CHECK(!VrrRatePolicy::hasAdaptiveHeadroom(0, 120));
    CHECK(!VrrRatePolicy::hasAdaptiveHeadroom(120, 0));
    CHECK(!VrrRatePolicy::hasAdaptiveHeadroom(-1, -1));

    // ---- sessionFpsForStart: the BL-2235 one-toggle FPS decision ----
    // VRR on + no explicit fps -> the display's calculated VRR rate.
    CHECK(VrrRatePolicy::sessionFpsForStart(true, false, 60, 120) == 116);
    CHECK(VrrRatePolicy::sessionFpsForStart(true, false, 60, 144) == 138);
    CHECK(VrrRatePolicy::sessionFpsForStart(true, false, 60, 60) == 59);
    // An explicit fps choice always wins, whatever the display says.
    CHECK(VrrRatePolicy::sessionFpsForStart(true, true, 60, 120) == 60);
    CHECK(VrrRatePolicy::sessionFpsForStart(true, true, 120, 120) == 120);
    // VRR off never rewrites the configured fps.
    CHECK(VrrRatePolicy::sessionFpsForStart(false, false, 60, 120) == 60);
    CHECK(VrrRatePolicy::sessionFpsForStart(false, true, 90, 120) == 90);
    // An unusable refresh reading keeps the configured fps (no silent 60
    // fallback and no zero fps).
    CHECK(VrrRatePolicy::sessionFpsForStart(true, false, 60, 0) == 60);
    CHECK(VrrRatePolicy::sessionFpsForStart(true, false, 60, -120) == 60);
    CHECK(VrrRatePolicy::sessionFpsForStart(true, false, 60, 4000) == 60);
    // Degenerate corner: a 62 Hz panel derives 60 -- identical to the
    // default, which is a no-op by value, not an error.
    CHECK(VrrRatePolicy::sessionFpsForStart(true, false, 60, 62) == 60);

    // ---- buildChoices: the settings FPS list ----
    {
        // VRR enabled on a 120 Hz panel with a saved native 120 FPS:
        // baselines stay, the calculated rates appear, and the exact native
        // refresh is intentionally omitted (saved value included).
        const auto choices = VrrRatePolicy::buildChoices({120}, 120, true);
        CHECK(hasChoice(choices, 30, VrrFpsChoiceKind::Baseline));
        CHECK(hasChoice(choices, 60, VrrFpsChoiceKind::Baseline));
        CHECK(hasChoice(choices, 116, VrrFpsChoiceKind::Vrr));
        CHECK(hasChoice(choices, 100, VrrFpsChoiceKind::LowLatencyVrr));
        CHECK(!hasFps(choices, 120));
    }
    {
        // A non-native saved value survives as Custom even in VRR mode.
        const auto choices = VrrRatePolicy::buildChoices({120}, 90, true);
        CHECK(hasChoice(choices, 90, VrrFpsChoiceKind::Custom));
    }
    {
        // VRR disabled: native refresh choices are back, no calculated rates.
        const auto choices = VrrRatePolicy::buildChoices({120}, 60, false);
        CHECK(hasChoice(choices, 120, VrrFpsChoiceKind::Native));
        CHECK(!hasFps(choices, 116));
        CHECK(!hasFps(choices, 100));
        // Saved 60 collides with the baseline 60; the baseline role wins.
        CHECK(hasChoice(choices, 60, VrrFpsChoiceKind::Baseline));
    }
    {
        // Multi-display: rates for every usable panel; unusable ones skipped.
        const auto choices = VrrRatePolicy::buildChoices({120, 144, 0, 1}, 0, true);
        CHECK(hasChoice(choices, 116, VrrFpsChoiceKind::Vrr));
        CHECK(hasChoice(choices, 138, VrrFpsChoiceKind::Vrr));
        CHECK(hasChoice(choices, 100, VrrFpsChoiceKind::LowLatencyVrr));
        CHECK(hasChoice(choices, 120, VrrFpsChoiceKind::LowLatencyVrr));
    }
    {
        // The list is sorted ascending and duplicate-free (std::map contract).
        const auto choices = VrrRatePolicy::buildChoices({120, 144}, 45, true);
        for (size_t i = 1; i < choices.size(); i++) {
            CHECK(choices[i - 1].fps < choices[i].fps);
        }
    }
    {
        // 60 Hz panel with VRR: 59 VRR + 50 low-latency; 60 stays (baseline).
        const auto choices = VrrRatePolicy::buildChoices({60}, 60, true);
        CHECK(hasChoice(choices, 59, VrrFpsChoiceKind::Vrr));
        CHECK(hasChoice(choices, 50, VrrFpsChoiceKind::LowLatencyVrr));
        CHECK(hasChoice(choices, 60, VrrFpsChoiceKind::Baseline));
    }

    printf("test_vrrratepolicy: %d checks, %d failure(s)\n", g_Checks, g_Failures);
    return g_Failures == 0 ? 0 : 1;
}
