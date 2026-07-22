// Regression test for BL-2370: the Quick Menu (and server-commands toast)
// rendered anchored to the top-left on the libplacebo Vulkan frontend because
// plvk.cpp's overlay placement switch had no case for those types — the
// zero-initialized pl_overlay_part left dst at (0,0). plvk now routes them
// through OverlayPlacement::centered(); these tests pin the centering math.
//
// Build (see tests/tests.pro, opt-in):
//   qmake6 tests/tests.pro CONFIG+=tests && make && ./overlay/tst_overlayplacement

#include <QtTest/QtTest>

#include "../../app/streaming/video/overlayplacement.h"

class TstOverlayPlacement : public QObject
{
    Q_OBJECT

private slots:
    // The deck case that regressed: 1280x800 Game Mode surface, Quick Menu FBO
    // sized to 80% of the window by QuickMenuManager::setWindowGeometry().
    void quickMenuCentersOnDeckSurface()
    {
        OverlayPlacement::Point p = OverlayPlacement::centered(1280, 800, 1024, 640);
        QCOMPARE(p.x, 128.0f);
        QCOMPARE(p.y, 80.0f);
        // The regression put the menu at the origin; centered placement of a
        // smaller-than-frame overlay must never sit at the top-left corner.
        QVERIFY(p.x > 0.0f && p.y > 0.0f);
    }

    void centersOn1080pSurface()
    {
        // 720x600 is the pre-setWindowGeometry default FBO size.
        OverlayPlacement::Point p = OverlayPlacement::centered(1920, 1080, 720, 600);
        QCOMPARE(p.x, 600.0f);
        QCOMPARE(p.y, 240.0f);
    }

    void exactFitLandsAtOrigin()
    {
        OverlayPlacement::Point p = OverlayPlacement::centered(1280, 800, 1280, 800);
        QCOMPARE(p.x, 0.0f);
        QCOMPARE(p.y, 0.0f);
    }

    void oversizedOverlayClampsToOrigin()
    {
        // An overlay larger than the frame must pin to the visible top-left
        // rather than centering off-screen with negative coordinates.
        OverlayPlacement::Point p = OverlayPlacement::centered(1280, 800, 1400, 900);
        QCOMPARE(p.x, 0.0f);
        QCOMPARE(p.y, 0.0f);
    }

    void oddSizesCenterFractionally()
    {
        OverlayPlacement::Point p = OverlayPlacement::centered(1281, 801, 640, 480);
        QCOMPARE(p.x, 320.5f);
        QCOMPARE(p.y, 160.5f);
    }
};

QTEST_APPLESS_MAIN(TstOverlayPlacement)
#include "tst_overlayplacement.moc"
