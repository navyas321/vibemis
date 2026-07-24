// Standalone regression coverage for the Vulkan VRR swapchain-depth policy.
// Gamescope's FIFO WSI path must retain a second in-flight image: depth 1
// serializes acquisition behind the previous present completion and cannot
// sustain a 116 FPS stream on a 120 Hz display.

#include "streaming/video/ffmpeg-renderers/vrrswapchainpolicy.h"

#include <cstdio>

static int g_Failures = 0;
static int g_Checks = 0;

#define CHECK(condition) \
    do { \
        ++g_Checks; \
        if (!(condition)) { \
            ++g_Failures; \
            std::fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #condition); \
        } \
    } while (false)

int main()
{
    CHECK(VrrSwapchainPolicy::depthForSession(false, false) == 1);
    CHECK(VrrSwapchainPolicy::depthForSession(false, true) == 1);
    CHECK(VrrSwapchainPolicy::depthForSession(true, false) == 1);
    CHECK(VrrSwapchainPolicy::depthForSession(true, true) == 2);

    std::printf("test_vrrswapchainpolicy: %d checks, %d failure(s)\n",
                g_Checks, g_Failures);
    return g_Failures == 0 ? 0 : 1;
}
