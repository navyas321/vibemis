#pragma once

// Pure placement math for composited overlays, shared by the libplacebo Vulkan
// frontend (plvk.cpp) and the regression tests (tests/overlay). Deliberately
// free of Qt/SDL/libplacebo includes so the test target builds with bare
// qmake + testlib (same constraint as tests/bitrate).

namespace OverlayPlacement {

struct Point {
    float x;
    float y;
};

// Centered placement (Quick Menu, server-commands toast): center the overlay
// surface inside the output frame, clamped so an oversized overlay pins to the
// visible top-left corner instead of going negative. The SDL renderers
// (sdlvid/eglvid/vaapi) compute the same "(frame - overlay) / 2" placement;
// keep them in agreement (BL-2370).
inline Point centered(float frameW, float frameH, float overlayW, float overlayH)
{
    Point p;
    p.x = (frameW - overlayW) / 2.0f;
    p.y = (frameH - overlayH) / 2.0f;
    if (p.x < 0.0f) {
        p.x = 0.0f;
    }
    if (p.y < 0.0f) {
        p.y = 0.0f;
    }
    return p;
}

}
