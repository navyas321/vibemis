// Standalone regression coverage for the Vulkan VRR swapchain-depth policy.
// Gamescope's application-facing FIFO WSI path needs a second in-flight image:
// depth 1 serializes acquisition behind the previous present completion and
// cannot sustain a 116 FPS stream on a 120 Hz display.
//
// Every other path must stay at upstream moonlight-qt's depth 1. Mailbox
// (Wayland) and Immediate (X11/KMSDRM) do not block in swap_buffers, so an
// extra in-flight image there buys no throughput and costs up to one present
// of latency.

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
    // VRR off: always the lowest-latency depth, whatever the present mode.
    CHECK(VrrSwapchainPolicy::depthForSession(false, false, false) == 1);
    CHECK(VrrSwapchainPolicy::depthForSession(false, false, true) == 1);
    CHECK(VrrSwapchainPolicy::depthForSession(false, true, false) == 1);
    CHECK(VrrSwapchainPolicy::depthForSession(false, true, true) == 1);

    // VRR requested but adaptive presentation unavailable: fixed-vsync
    // fallback, still depth 1.
    CHECK(VrrSwapchainPolicy::depthForSession(true, false, false) == 1);
    CHECK(VrrSwapchainPolicy::depthForSession(true, false, true) == 1);

    // Qualified adaptive session on a non-blocking present mode (Wayland
    // Mailbox, X11/KMSDRM Immediate): must NOT be pipelined to depth 2.
    CHECK(VrrSwapchainPolicy::depthForSession(true, true, false) == 1);

    // The one case that earns the extra in-flight image: a qualified adaptive
    // session presenting through an application-facing FIFO swapchain.
    // BL-2528: three, not two. The Gamescope WSI layer pins minImageCount to 3,
    // so depth 1 and 2 both yield three images there and are indistinguishable;
    // three images cannot sustain 113 FPS against ~2-display-period compositor
    // holds. Depth 3 asks for the fourth image that the simulation showed is
    // the difference between 80 FPS with 30% drops and 115 FPS with none.
    CHECK(VrrSwapchainPolicy::depthForSession(true, true, true) ==
          kVrrFifoSwapchainDepth);
    CHECK(kVrrFifoSwapchainDepth == 3);
    // Every non-FIFO path keeps upstream's lowest-latency depth.
    CHECK(VrrSwapchainPolicy::depthForSession(true, true, false) == 1);

    std::printf("test_vrrswapchainpolicy: %d checks, %d failure(s)\n",
                g_Checks, g_Failures);
    return g_Failures == 0 ? 0 : 1;
}
