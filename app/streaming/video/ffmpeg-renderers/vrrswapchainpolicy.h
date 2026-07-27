#pragma once

// libplacebo's swapchain depth is the number of additional in-flight images.
// Upstream moonlight-qt deliberately ships depth 1 ("No queued frames") on
// every path, and that stays the default here: it is the lowest-latency
// choice and the paced worker owns presentation timing on its own.
//
// The one exception is an application-facing FIFO swapchain, which today means
// the Gamescope WSI path. There libplacebo's swap_buffers() waits for the
// queued present, so depth 1 serializes each preparation behind the previous
// display completion -- measured at 10-13 ms per frame, capping a 116 FPS
// stream near 83 FPS on a 120 Hz panel. One extra in-flight image restores the
// pipelining without giving the application a standing queue.
//
// Mailbox (Wayland) and Immediate (X11/KMSDRM) do NOT block in swap_buffers,
// so they were never throughput-limited at depth 1 and must stay there: an
// extra in-flight image would only add up to one present of latency to a path
// that had no problem to fix.
// BL-2528: depth 2 is NOT enough on Gamescope, and the reason is image count,
// not the swap wait. The FROG WSI layer pins minImageCount to 3 regardless of
// what we request, so depth 1 and depth 2 are indistinguishable there -- which
// is why raising 1 -> 2 changed nothing on the Legion Go S. Three images cannot
// sustain 113 FPS when the compositor holds each buffer for roughly two display
// periods (composite rather than direct scanout): the tokens simply do not
// recycle fast enough, and the client starves regardless of when it asks.
//
// A simulation driving the byte-exact rc.001 timing controller against that
// compositor model reproduced the device almost exactly at three images
// (80.0 vs 84.5 FPS rendered, 30.6% vs 25.0% pacer drops, 23.06 vs 23.03 ms
// queue delay, render lead pinned at 6.50 ms in both) and was completely cured
// by a fourth (115.2 FPS, 0 drops, acquire p95 0.06 ms). Acquiring earlier --
// the intuitive fix -- changed nothing at all, because the limit is token-bound
// rather than phase-bound.
//
// Upstream corroborates the direction: Nonary carries
// PLVK_USE_DYNAMIC_SWAPCHAIN_DEPTH for exactly this reason on macOS, where
// direct-to-display scanout "block[s] us from getting a new drawable while the
// current one is getting scanned out".
constexpr int kVrrFifoSwapchainDepth = 3;

class VrrSwapchainPolicy
{
public:
    static constexpr int depthForSession(bool vrrRequested,
                                         bool adaptivePresentationAvailable,
                                         bool applicationFacingFifo)
    {
        return vrrRequested && adaptivePresentationAvailable &&
                       applicationFacingFifo ?
            kVrrFifoSwapchainDepth : 1;
    }
};
