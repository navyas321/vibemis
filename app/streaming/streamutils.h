#pragma once

#include "SDL_compat.h"

class StreamUtils
{
public:
    static
    Uint32 getPlatformWindowFlags();

    // Fit the source rect into the destination rect. The 2-arg form applies the user's
    // configured video scale mode (StreamingPreferences::videoScaleMode); the 3-arg form
    // takes an explicit mode. Using the configured mode for BOTH video rendering and input
    // coordinate mapping keeps absolute mouse/touch aligned with what's on screen.
    static
    void scaleSourceToDestinationSurface(SDL_Rect* src, SDL_Rect* dst);

    static
    void scaleSourceToDestinationSurface(SDL_Rect* src, SDL_Rect* dst, int scaleMode);

    static
    void screenSpaceToNormalizedDeviceCoords(SDL_FRect* rect, int viewportWidth, int viewportHeight);

    static
    void screenSpaceToNormalizedDeviceCoords(SDL_Rect* src, SDL_FRect* dst, int viewportWidth, int viewportHeight);

    static
    bool getNativeDesktopMode(int displayIndex, SDL_DisplayMode* mode, SDL_Rect* safeArea);

    static
    int getDisplayRefreshRate(SDL_Window* window);

    // Strict variant for VRR qualification (BL-2212): returns false instead of
    // silently substituting a 60 Hz fallback when the display mode is unknown.
    static
    bool tryGetDisplayRefreshRate(SDL_Window* window, int& outHz);

    // Same-display refresh-mode-switch guard (BL-2296, from the Nonary
    // v6.1.0-vrr9.1 refreshMayHaveChanged guard in session.cpp): a mode switch
    // on the CURRENT display invalidates the qualified VRR rate just like a
    // move to another display does. Nonary permanently disables VRR for the
    // session there because its per-session PresentationSettings snapshot is
    // immutable; vibemis re-derives qualification on every decoder
    // (re)creation, so our guard only needs to force that recreation and let
    // the new qualification pass pick up the new rate or fall back to fixed
    // pacing. The decision logic is kept as pure header-inline predicates so
    // the standalone checker (app/test_vrrrefreshguard.cpp) can exercise it
    // without SDL linkage.
    //
    // Phase 1 - cheap gate before touching SDL display state: only probe the
    // refresh when a VRR session actually holds adaptive presentation and the
    // window event could have changed the display refresh.
    //
    // BL-2529: the second input is isAdaptivePresentationActive(), NOT
    // isVrrActive(). An unpaced VRR session (frame pacing off) runs no worker
    // but still presents on an adaptive swapchain qualified at a specific
    // refresh rate; gating on the worker made this guard inert for exactly
    // those sessions.
    static
    bool vrrRefreshSwitchNeedsProbe(int qualifiedRefreshHz,
                                    bool adaptivePresentationActive,
                                    bool refreshMayHaveChanged)
    {
        return qualifiedRefreshHz > 0 && adaptivePresentationActive &&
               refreshMayHaveChanged;
    }

    // Phase 2 - the requalification decision from the probe result: an
    // unreadable refresh or any deviation from the qualified rate means the
    // worker would otherwise keep pacing against a stale period.
    static
    bool vrrRefreshSwitchRequiresRequalification(int qualifiedRefreshHz,
                                                 bool refreshReadable,
                                                 int currentRefreshHz)
    {
        return qualifiedRefreshHz > 0 &&
               (!refreshReadable || currentRefreshHz != qualifiedRefreshHz);
    }

    static
    bool hasFastAes();

    static
    int getDrmFdForWindow(SDL_Window* window, bool* needsClose);

    static
    int getDrmFd(bool preferRenderNode);
};
