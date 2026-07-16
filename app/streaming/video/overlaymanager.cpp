#include "overlaymanager.h"
#include "path.h"
#include "settings/streamingpreferences.h"

using namespace Overlay;

int OverlayManager::getDebugOverlayAnchor()
{
    return static_cast<int>(StreamingPreferences::get()->perfOverlayPosition);
}

OverlayManager::OverlayManager() :
    m_Renderer(nullptr),
    m_FontData(Path::readDataFile("ModeSeven.ttf"))
{
    memset(m_Overlays, 0, sizeof(m_Overlays));

    // Vibemis: the debug/performance overlay font size is user-configurable so the
    // stats HUD is legible on small handheld panels. Map the preference onto point
    // sizes; PERF_TEXT_NORMAL (20) preserves the historical default.
    int debugFontSize;
    switch (StreamingPreferences::get()->perfOverlayTextSize) {
    case StreamingPreferences::PERF_TEXT_SMALL:
        debugFontSize = 16;
        break;
    case StreamingPreferences::PERF_TEXT_LARGE:
        debugFontSize = 28;
        break;
    case StreamingPreferences::PERF_TEXT_NORMAL:
    default:
        debugFontSize = 20;
        break;
    }

    m_Overlays[OverlayType::OverlayDebug].color = {0xD0, 0xD0, 0x00, 0xFF};
    m_Overlays[OverlayType::OverlayDebug].fontSize = debugFontSize;

    m_Overlays[OverlayType::OverlayStatusUpdate].color = {0xCC, 0x00, 0x00, 0xFF};
    m_Overlays[OverlayType::OverlayStatusUpdate].fontSize = 36;

    m_Overlays[OverlayType::OverlayServerCommands].color = {0x00, 0xCC, 0xCC, 0xFF};
    m_Overlays[OverlayType::OverlayServerCommands].fontSize = 24;

    // The Quick Menu is not a text overlay — its surface is rendered offscreen from QML
    // and published via updateOverlaySurface(). No font/colour is used here.
    m_Overlays[OverlayType::OverlayQuickMenu].fontSize = 0;

    // Vibemis BL-1562/BL-2007: on-screen touch buttons. Icon-only — the glyph is
    // drawn from primitive shapes onto a semi-transparent button background in
    // renderTouchButtonSurface(); no TTF is involved, so fontSize stays 0. The
    // color is the glyph paint color.
    m_Overlays[OverlayType::OverlayTouchButtonMenu].color = {0xFF, 0xFF, 0xFF, 0xFF};
    m_Overlays[OverlayType::OverlayTouchButtonMenu].fontSize = 0;
    m_Overlays[OverlayType::OverlayTouchButtonKbd].color = {0xFF, 0xFF, 0xFF, 0xFF};
    m_Overlays[OverlayType::OverlayTouchButtonKbd].fontSize = 0;
    m_Overlays[OverlayType::OverlayTouchButtonTouchMode].color = {0xFF, 0xFF, 0xFF, 0xFF};
    m_Overlays[OverlayType::OverlayTouchButtonTouchMode].fontSize = 0;

    // While TTF will usually not be initialized here, it is valid for that not to
    // be the case, since Session destruction is deferred and could overlap with
    // the lifetime of a new Session object.
    //SDL_assert(TTF_WasInit() == 0);

    if (TTF_Init() != 0) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "TTF_Init() failed: %s",
                    TTF_GetError());
        return;
    }
}

OverlayManager::~OverlayManager()
{
    for (int i = 0; i < OverlayType::OverlayMax; i++) {
        if (m_Overlays[i].surface != nullptr) {
            SDL_FreeSurface(m_Overlays[i].surface);
        }
        if (m_Overlays[i].font != nullptr) {
            TTF_CloseFont(m_Overlays[i].font);
        }
    }

    TTF_Quit();

    // For similar reasons to the comment in the constructor, this will usually,
    // but not always, deinitialize TTF. In the cases where Session objects overlap
    // in lifetime, there may be an additional reference on TTF for the new Session
    // that means it will not be cleaned up here.
    //SDL_assert(TTF_WasInit() == 0);
}

bool OverlayManager::isOverlayEnabled(OverlayType type)
{
    return m_Overlays[type].enabled;
}

char* OverlayManager::getOverlayText(OverlayType type)
{
    return m_Overlays[type].text;
}

void OverlayManager::updateOverlayText(OverlayType type, const char* text)
{
    strncpy(m_Overlays[type].text, text, sizeof(m_Overlays[0].text));
    m_Overlays[type].text[getOverlayMaxTextLength() - 1] = '\0';

    setOverlayTextUpdated(type);
}

int OverlayManager::getOverlayMaxTextLength()
{
    return sizeof(m_Overlays[0].text);
}

int OverlayManager::getOverlayFontSize(OverlayType type)
{
    return m_Overlays[type].fontSize;
}

SDL_Surface* OverlayManager::getUpdatedOverlaySurface(OverlayType type)
{
    // If a new surface is available, return it. If not, return nullptr.
    // Caller must free the surface on success.
    return (SDL_Surface*)SDL_AtomicSetPtr((void**)&m_Overlays[type].surface, nullptr);
}

void OverlayManager::setOverlayTextUpdated(OverlayType type)
{
    // Only update the overlay state if it's enabled. If it's not enabled,
    // the renderer has already been notified by setOverlayState().
    if (m_Overlays[type].enabled) {
        notifyOverlayUpdated(type);
    }
}

void OverlayManager::setOverlayState(OverlayType type, bool enabled)
{
    bool stateChanged = m_Overlays[type].enabled != enabled;

    m_Overlays[type].enabled = enabled;

    if (stateChanged) {
        if (!enabled) {
            // Set the text to empty string on disable
            m_Overlays[type].text[0] = 0;
        }

        notifyOverlayUpdated(type);
    }
}

SDL_Color OverlayManager::getOverlayColor(OverlayType type)
{
    return m_Overlays[type].color;
}

void OverlayManager::setOverlayRenderer(IOverlayRenderer* renderer)
{
    {
        // test81 (review fix): the renderer is swapped on the exec/render thread during
        // decoder recreation while the Quick Menu's main-thread render timer may be inside
        // notifyOverlayUpdated() — serialize access so we never call into a freed renderer.
        QMutexLocker locker(&m_RendererLock);
        m_Renderer = renderer;
    }

    // Vibemis BL-1562: the touch buttons render their surface once when toggled on
    // (their glyphs never refresh, unlike the perf overlay), so a renderer created or
    // recreated after that point would never receive their surface and the buttons
    // would silently vanish. Regenerate them whenever a new renderer registers.
    // NB: must be outside the lock scope above — notifyOverlayUpdated() re-acquires it.
    if (renderer != nullptr) {
        if (m_Overlays[OverlayTouchButtonMenu].enabled) {
            notifyOverlayUpdated(OverlayTouchButtonMenu);
        }
        if (m_Overlays[OverlayTouchButtonKbd].enabled) {
            notifyOverlayUpdated(OverlayTouchButtonKbd);
        }
        if (m_Overlays[OverlayTouchButtonTouchMode].enabled) {
            notifyOverlayUpdated(OverlayTouchButtonTouchMode);
        }
    }
}

void OverlayManager::updateOverlaySurface(OverlayType type, SDL_Surface* surface)
{
    // Atomically swap in the externally-rendered surface, freeing any previous
    // surface that the renderer hasn't consumed yet. Mirrors the swap discipline
    // used for text overlays so getUpdatedOverlaySurface() stays race-free.
    SDL_Surface* oldSurface = (SDL_Surface*)SDL_AtomicSetPtr((void**)&m_Overlays[type].surface, surface);
    if (oldSurface != nullptr) {
        SDL_FreeSurface(oldSurface);
    }

    QMutexLocker locker(&m_RendererLock);
    if (m_Renderer != nullptr) {
        m_Renderer->notifyOverlayUpdated(type);
    }
}

// Vibemis BL-2007 — primitive-shape glyph painters for the icon-only touch buttons.
// SDL_Surface has no circle/line primitives and the buttons must not pull in new
// font or image assets, so the glyphs are built from filled rects (SDL_FillRect)
// plus a scanline-rasterized ring for the touch glyph's dot and arcs.

static void fillGlyphRect(SDL_Surface* surface, int x, int y, int w, int h, Uint32 color)
{
    SDL_Rect rect = { x, y, w, h };
    SDL_FillRect(surface, &rect, color);
}

// Paint the annulus innerR <= dist <= outerR around (cx, cy); innerR = 0 degenerates
// to a filled circle. With upperHalfOnly, rows below the center are skipped so the
// ring reads as an arc radiating upward.
static void fillGlyphRing(SDL_Surface* surface, int cx, int cy, int innerR, int outerR,
                          Uint32 color, bool upperHalfOnly)
{
    if (SDL_MUSTLOCK(surface)) {
        if (SDL_LockSurface(surface) != 0) {
            return;
        }
    }

    Uint32* pixels = (Uint32*)surface->pixels;
    int pitchPx = surface->pitch / (int)sizeof(Uint32);
    for (int y = SDL_max(cy - outerR, 0); y <= SDL_min(cy + outerR, surface->h - 1); y++) {
        if (upperHalfOnly && y > cy) {
            break;
        }
        for (int x = SDL_max(cx - outerR, 0); x <= SDL_min(cx + outerR, surface->w - 1); x++) {
            int dx = x - cx;
            int dy = y - cy;
            int distSq = dx * dx + dy * dy;
            if (distSq <= outerR * outerR && distSq >= innerR * innerR) {
                pixels[y * pitchPx + x] = color;
            }
        }
    }

    if (SDL_MUSTLOCK(surface)) {
        SDL_UnlockSurface(surface);
    }
}

SDL_Surface* OverlayManager::renderTouchButtonSurface(OverlayType type)
{
    SDL_Surface* button = SDL_CreateRGBSurfaceWithFormat(0, TouchButtonSize, TouchButtonSize,
                                                         32, SDL_PIXELFORMAT_ARGB8888);
    if (button == nullptr) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "SDL_CreateRGBSurfaceWithFormat() failed: %s",
                    SDL_GetError());
        return nullptr;
    }

    // Same semi-transparent box style the labeled BL-1562 buttons used.
    Uint32 background = SDL_MapRGBA(button->format, 0x20, 0x20, 0x20, 0x90);
    SDL_Color glyphColor = m_Overlays[type].color;
    Uint32 glyph = SDL_MapRGBA(button->format, glyphColor.r, glyphColor.g, glyphColor.b, glyphColor.a);
    SDL_FillRect(button, nullptr, background);

    switch (type) {
    case OverlayTouchButtonMenu:
        // Hamburger: three horizontal bars.
        fillGlyphRect(button, 17, 22, 30, 4, glyph);
        fillGlyphRect(button, 17, 30, 30, 4, glyph);
        fillGlyphRect(button, 17, 38, 30, 4, glyph);
        break;

    case OverlayTouchButtonKbd:
        // Keyboard: rect outline (1px corners knocked out so it reads as rounded),
        // two rows of key dots, and a space bar.
        fillGlyphRect(button, 14, 21, 36, 2, glyph);        // top edge
        fillGlyphRect(button, 14, 41, 36, 2, glyph);        // bottom edge
        fillGlyphRect(button, 14, 21, 2, 22, glyph);        // left edge
        fillGlyphRect(button, 48, 21, 2, 22, glyph);        // right edge
        fillGlyphRect(button, 14, 21, 1, 1, background);
        fillGlyphRect(button, 49, 21, 1, 1, background);
        fillGlyphRect(button, 14, 42, 1, 1, background);
        fillGlyphRect(button, 49, 42, 1, 1, background);
        for (int keyX = 19; keyX <= 43; keyX += 6) {        // 5 columns of 2x2 keys
            fillGlyphRect(button, keyX, 26, 2, 2, glyph);
            fillGlyphRect(button, keyX, 31, 2, 2, glyph);
        }
        fillGlyphRect(button, 24, 36, 16, 2, glyph);        // space bar
        break;

    case OverlayTouchButtonTouchMode:
        // Touch: fingertip dot with two arcs radiating upward (tap gesture).
        fillGlyphRing(button, 32, 40, 0, 7, glyph, false);
        fillGlyphRing(button, 32, 40, 13, 16, glyph, true);
        fillGlyphRing(button, 32, 40, 20, 23, glyph, true);
        break;

    default:
        SDL_assert(false);
        break;
    }

    return button;
}

void OverlayManager::notifyOverlayUpdated(OverlayType type)
{
    if (m_Renderer == nullptr) {
        return;
    }

    // The Quick Menu's pixels come from updateOverlaySurface(), not TTF. Just notify
    // the renderer of the enable/disable state change — don't run the text path which
    // would clobber the externally-rendered surface.
    if (type == OverlayQuickMenu) {
        QMutexLocker locker(&m_RendererLock);
        if (m_Renderer != nullptr) {
            m_Renderer->notifyOverlayUpdated(type);
        }
        return;
    }

    // Vibemis BL-2007: the touch buttons are icon-only — their glyph surfaces are
    // drawn from primitive shapes, bypassing the TTF text path entirely (they have
    // no text, and TTF would render an empty string to nullptr anyway).
    if (type == OverlayTouchButtonMenu || type == OverlayTouchButtonKbd ||
            type == OverlayTouchButtonTouchMode) {
        SDL_Surface* oldSurface = (SDL_Surface*)SDL_AtomicSetPtr((void**)&m_Overlays[type].surface, nullptr);
        if (oldSurface != nullptr) {
            SDL_FreeSurface(oldSurface);
        }

        if (m_Overlays[type].enabled) {
            SDL_AtomicSetPtr((void**)&m_Overlays[type].surface, renderTouchButtonSurface(type));
        }

        QMutexLocker locker(&m_RendererLock);
        if (m_Renderer != nullptr) {
            m_Renderer->notifyOverlayUpdated(type);
        }
        return;
    }

    // Construct the required font to render the overlay
    if (m_Overlays[type].font == nullptr) {
        if (m_FontData.isEmpty()) {
            SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                         "SDL overlay font failed to load");
            return;
        }

        // m_FontData must stay around until the font is closed
        m_Overlays[type].font = TTF_OpenFontRW(SDL_RWFromConstMem(m_FontData.constData(), m_FontData.size()),
                                               1,
                                               m_Overlays[type].fontSize);
        if (m_Overlays[type].font == nullptr) {
            SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                        "TTF_OpenFont() failed: %s",
                        TTF_GetError());

            // Can't proceed without a font
            return;
        }
    }

    SDL_Surface* oldSurface = (SDL_Surface*)SDL_AtomicSetPtr((void**)&m_Overlays[type].surface, nullptr);

    // Free the old surface
    if (oldSurface != nullptr) {
        SDL_FreeSurface(oldSurface);
    }

    if (m_Overlays[type].enabled) {
        // The _Wrapped variant is required for line breaks to work
        SDL_Surface* surface = TTF_RenderText_Blended_Wrapped(m_Overlays[type].font,
                                                              m_Overlays[type].text,
                                                              m_Overlays[type].color,
                                                              1024);

        SDL_AtomicSetPtr((void**)&m_Overlays[type].surface, surface);
    }

    // Notify the renderer
    QMutexLocker locker(&m_RendererLock);
    if (m_Renderer != nullptr) {
        m_Renderer->notifyOverlayUpdated(type);
    }
}
