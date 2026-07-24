#pragma once

// libplacebo's swapchain depth is the number of additional in-flight images.
// Fixed presentation keeps the lowest-latency depth of one. The paced Vulkan
// path needs one more image so acquisition can overlap completion of the prior
// present instead of serializing the entire worker behind FIFO feedback.
class VrrSwapchainPolicy
{
public:
    static constexpr int depthForSession(bool vrrRequested,
                                         bool adaptivePresentationAvailable)
    {
        return vrrRequested && adaptivePresentationAvailable ? 2 : 1;
    }
};
