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

    static
    bool hasFastAes();

    static
    int getDrmFdForWindow(SDL_Window* window, bool* needsClose);

    static
    int getDrmFd(bool preferRenderNode);
};
