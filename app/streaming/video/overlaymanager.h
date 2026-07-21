#pragma once

#include <QString>
#include <QMutex>

#include "SDL_compat.h"
#include <SDL_ttf.h>

namespace Overlay {

enum OverlayType {
    OverlayDebug,
    OverlayStatusUpdate,
    OverlayServerCommands,
    OverlayQuickMenu,
    // Vibemis opt-in on-screen touch controls. Three small
    // semi-transparent icon-only buttons composited into the stream: MENU
    // (top-left, opens the Quick Menu), KBD (far top-right, requests the SteamOS
    // on-screen keyboard) and TOUCH-MODE (immediately inward of KBD,
    // live-toggles touchpad-emulation vs direct touch). Their glyphs are drawn
    // with primitive shapes in notifyOverlayUpdated() — no text, no assets.
    // Hit-testing lives in the touch handler (abstouch.cpp) using the constants
    // below.
    OverlayTouchButtonMenu,
    OverlayTouchButtonKbd,
    OverlayTouchButtonTouchMode,
    OverlayMax
};

// Vibemis geometry of the on-screen touch buttons — square side length and
// inset from the top corners, in pixels. Shared by the renderers (drawing) and the
// touch input handler (hit-testing) so the visuals and the hit rects stay in sync.
// TouchButtonSpacing is the gap between the two buttons of the top-right
// cluster (KBD at the corner, TOUCH-MODE inward of it).
const int TouchButtonSize = 64;
const int TouchButtonInset = 24;
const int TouchButtonSpacing = 12;

class IOverlayRenderer
{
public:
    virtual ~IOverlayRenderer() = default;

    virtual void notifyOverlayUpdated(OverlayType type) = 0;
};

class OverlayManager
{
public:
    OverlayManager();
    ~OverlayManager();

    bool isOverlayEnabled(OverlayType type);
    char* getOverlayText(OverlayType type);
    void updateOverlayText(OverlayType type, const char* text);
    int getOverlayMaxTextLength();
    void setOverlayTextUpdated(OverlayType type);
    void setOverlayState(OverlayType type, bool enabled);
    SDL_Color getOverlayColor(OverlayType type);
    int getOverlayFontSize(OverlayType type);
    SDL_Surface* getUpdatedOverlaySurface(OverlayType type);

    // Publish an externally-rendered RGBA surface for an overlay (e.g. the Quick Menu
    // rendered offscreen from QML). Unlike the text overlays, the pixels are produced
    // by the caller rather than by TTF. Takes ownership of 'surface'; the renderer
    // consuming it via getUpdatedOverlaySurface() will free it. Thread-safe.
    void updateOverlaySurface(OverlayType type, SDL_Surface* surface);

    // Vibemis: anchor corner for the debug/performance overlay, read from user
    // preference. Returns StreamingPreferences::PerfOverlayPosition as an int
    // (0=TL, 1=TR, 2=BL, 3=BR). Renderers map this to their own coordinate space.
    int getDebugOverlayAnchor();

    void setOverlayRenderer(IOverlayRenderer* renderer);

private:
    void notifyOverlayUpdated(OverlayType type);

    // Build the icon-only surface for one of the on-screen touch
    // buttons (TouchButtonSize square, semi-transparent background, glyph drawn
    // from primitive shapes). Returns nullptr on allocation failure.
    SDL_Surface* renderTouchButtonSurface(OverlayType type);

    struct {
        bool enabled;
        int fontSize;
        SDL_Color color;
        // 1024 matches Nonary v6.1.0-vrr9.1 (BL-2229): the debug overlay's
        // base video stats (~500 chars) plus the five VRR pacing telemetry
        // lines (~375 chars) exceed the historical 512-byte buffer, and
        // stringifyVideoStats() drops any section that would overflow.
        char text[1024];

        TTF_Font* font;
        SDL_Surface* surface;
    } m_Overlays[OverlayMax];
    IOverlayRenderer* m_Renderer;
    QMutex m_RendererLock;   // guards m_Renderer swap vs cross-thread notify
    QByteArray m_FontData;
};

}
