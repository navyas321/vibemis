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
    // Vibemis BL-1562: opt-in on-screen touch controls. Two small semi-transparent
    // buttons composited into the stream: MENU (top-left, opens the Quick Menu) and
    // KBD (top-right, opens the Quick Menu's text-send view). Hit-testing lives in
    // the absolute touch handler (abstouch.cpp) using the constants below.
    OverlayTouchButtonMenu,
    OverlayTouchButtonKbd,
    OverlayMax
};

// Vibemis BL-1562: geometry of the on-screen touch buttons — square side length and
// inset from the top corners, in pixels. Shared by the renderers (drawing) and the
// touch input handler (hit-testing) so the visuals and the hit rects stay in sync.
const int TouchButtonSize = 64;
const int TouchButtonInset = 24;

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

    struct {
        bool enabled;
        int fontSize;
        SDL_Color color;
        char text[512];

        TTF_Font* font;
        SDL_Surface* surface;
    } m_Overlays[OverlayMax];
    IOverlayRenderer* m_Renderer;
    QMutex m_RendererLock;   // test81: guards m_Renderer swap vs cross-thread notify
    QByteArray m_FontData;
};

}
