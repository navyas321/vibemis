#include <QtTest>

#include "../../app/streaming/bitraterescuepolicy.h"

// BL-2265: pure decision-logic tests for the catastrophic bitrate-collapse
// rescue — the FEC-tail-drop collapse signature detection thresholds and the
// halving step schedule. Numbers are anchored to the host-side RCA evidence
// (1920x1200@116, 32000 kbps requested / 24588 kbps video: <1 fps delivered,
// 95-99% of offered frames unrecoverable, IDR storm; pristine at 10000 kbps).
class BitrateRescuePolicyTest : public QObject
{
    Q_OBJECT

private slots:
    void collapseSignatureDetected();
    void healthyStreamsNeverCollapse();
    void degradedButUsableStreamsHold();
    void smallOrShortSamplesHold();
    void stepScheduleHalvesTowardFloor();
    void stepScheduleStopsAtFloor();
    void vrrAutoDeriveNeverInflatesBitrate();
};

void BitrateRescuePolicyTest::collapseSignatureDetected()
{
    // RCA S1 shape: ~0.4 fps delivered of a 116 fps stream, ~99% dropped.
    QVERIFY(BitrateRescuePolicy::isCollapse(2500, 1, 289, 116));
    QVERIFY(BitrateRescuePolicy::isCollapse(3000, 2, 300, 116));
    // Growing window (evaluated continuously past the minimum).
    QVERIFY(BitrateRescuePolicy::isCollapse(10000, 4, 1157, 116));
    // The collapse is fps-agnostic (90 and 100 fps collapsed identically).
    QVERIFY(BitrateRescuePolicy::isCollapse(2500, 1, 220, 90));
    QVERIFY(BitrateRescuePolicy::isCollapse(2500, 1, 245, 100));
    // Even a less-total collapse (60% dropped, 20% of target delivered) fires.
    QVERIFY(BitrateRescuePolicy::isCollapse(2500, 55, 235, 116));
}

void BitrateRescuePolicyTest::healthyStreamsNeverCollapse()
{
    // Perfect delivery.
    QVERIFY(!BitrateRescuePolicy::isCollapse(2500, 290, 0, 116));
    // RCA S4 shape: 116 fps clean at 10 Mbps.
    QVERIFY(!BitrateRescuePolicy::isCollapse(10000, 1160, 0, 116));
    // A static 60 fps desktop stream.
    QVERIFY(!BitrateRescuePolicy::isCollapse(5000, 300, 0, 60));
}

void BitrateRescuePolicyTest::degradedButUsableStreamsHold()
{
    // Rough Wi-Fi: 10% of frames dropped but delivery keeps pace — no rescue.
    QVERIFY(!BitrateRescuePolicy::isCollapse(2500, 261, 29, 116));
    // Heavy loss burst (40% dropped) that stays under the 50% share gate.
    QVERIFY(!BitrateRescuePolicy::isCollapse(2500, 174, 116, 116));
    // Majority dropped but delivered fps still above 25% of target
    // (e.g. a transient hiccup mid-window): both gates must agree.
    QVERIFY(!BitrateRescuePolicy::isCollapse(2500, 100, 190, 116));
}

void BitrateRescuePolicyTest::smallOrShortSamplesHold()
{
    // Under the minimum observation window.
    QVERIFY(!BitrateRescuePolicy::isCollapse(2499, 1, 289, 116));
    QVERIFY(!BitrateRescuePolicy::isCollapse(1000, 1, 500, 116));
    // Under the minimum offered-frames sample.
    QVERIFY(!BitrateRescuePolicy::isCollapse(2500, 1, 28, 116));
    // Degenerate inputs.
    QVERIFY(!BitrateRescuePolicy::isCollapse(2500, 0, 0, 116));
    QVERIFY(!BitrateRescuePolicy::isCollapse(2500, 1, 289, 0));
    QVERIFY(!BitrateRescuePolicy::isCollapse(2500, 1, 289, -1));
}

void BitrateRescuePolicyTest::stepScheduleHalvesTowardFloor()
{
    // The default-bitrate ladder for 1920x1200@116 (32000 kbps).
    QCOMPARE(BitrateRescuePolicy::nextBitrateKbps(32000), 16000);
    QCOMPARE(BitrateRescuePolicy::nextBitrateKbps(16000), 8000);
    QCOMPARE(BitrateRescuePolicy::nextBitrateKbps(8000), 4000);
    QCOMPARE(BitrateRescuePolicy::nextBitrateKbps(4000), 2000);
    // Odd rates round down to 500 kbps.
    QCOMPARE(BitrateRescuePolicy::nextBitrateKbps(30000), 15000);
    QCOMPARE(BitrateRescuePolicy::nextBitrateKbps(7500), 3500);
    QCOMPARE(BitrateRescuePolicy::nextBitrateKbps(24588), 12000);
    // Halving below the floor clamps to the floor.
    QCOMPARE(BitrateRescuePolicy::nextBitrateKbps(3000), 2000);
}

void BitrateRescuePolicyTest::stepScheduleStopsAtFloor()
{
    // At (or under) the floor there is NO further step — the caller must
    // not tear the stream down for a rescue that cannot help.
    QCOMPARE(BitrateRescuePolicy::nextBitrateKbps(2000), 0);
    QCOMPARE(BitrateRescuePolicy::nextBitrateKbps(1500), 0);
    QCOMPARE(BitrateRescuePolicy::nextBitrateKbps(0), 0);
}

void BitrateRescuePolicyTest::vrrAutoDeriveNeverInflatesBitrate()
{
    // 1920x1200: default 23000 kbps at 60 fps, 32000 kbps at 116 fps.
    // A bitrate auto-tracked to the DERIVED fps falls back to the user-fps default.
    QCOMPARE(BitrateRescuePolicy::bitrateForAutoDerivedFps(32000, 23000, 32000), 23000);
    // An explicit user bitrate (not the derived-fps default) is untouched.
    QCOMPARE(BitrateRescuePolicy::bitrateForAutoDerivedFps(15000, 23000, 32000), 15000);
    QCOMPARE(BitrateRescuePolicy::bitrateForAutoDerivedFps(40000, 23000, 32000), 40000);
    // No inflation (derived default not higher) - untouched.
    QCOMPARE(BitrateRescuePolicy::bitrateForAutoDerivedFps(23000, 23000, 23000), 23000);
    // Degenerate defaults never rewrite the configured bitrate.
    QCOMPARE(BitrateRescuePolicy::bitrateForAutoDerivedFps(32000, 0, 32000), 32000);
}

QTEST_APPLESS_MAIN(BitrateRescuePolicyTest)

#include "tst_bitraterescuepolicy.moc"
