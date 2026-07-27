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
class VrrSwapchainPolicy
{
public:
    static constexpr int depthForSession(bool vrrRequested,
                                         bool adaptivePresentationAvailable,
                                         bool applicationFacingFifo)
    {
        return vrrRequested && adaptivePresentationAvailable &&
                       applicationFacingFifo ?
            2 : 1;
    }
};
