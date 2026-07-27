// BL-2417: coverage for the debug overlay's decoder-capability line.
//
// Why this test exists: BL-2408 disabled reference frame invalidation on every
// AMD/Gallium device for months, and nobody noticed because no screen and no
// log ever stated the RFI state. The overlay line these tests cover is the
// countermeasure. Its single most important property is that it must not lie —
// "RFI: on" when RFI is off is worse than printing nothing, because it converts
// a silent regression into a confidently-wrong one.
//
// Build (see tests/tests.pro, opt-in):
//   qmake6 tests/tests.pro CONFIG+=tests && make && ./overlay/tst_decoderstatus

#include <QtTest/QtTest>

#include "../../app/streaming/video/decoderstatus.h"

class TstDecoderStatus : public QObject
{
    Q_OBJECT

private:
    // Convenience wrapper: format into a generous buffer and hand back the
    // rendered text. Mirrors how stringifyVideoStats() calls formatLine().
    static QByteArray render(const char* decoder,
                             const char* hwType,
                             const char* renderer,
                             const char* vendor,
                             int rfiState)
    {
        char buf[512];
        int ret = DecoderStatus::formatLine(buf, sizeof(buf), decoder, hwType,
                                            renderer, vendor, rfiState);
        // A truncated line would mean the caps in decoderstatus.h disagree with
        // the buffer, which is the failure mode this whole file guards.
        Q_ASSERT(ret > 0 && ret < (int)sizeof(buf));
        Q_UNUSED(ret);
        return QByteArray(buf);
    }

private slots:
    // ---- The reason the line exists ------------------------------------

    // The exact BL-2408 shape: a Gallium VAAPI backend whose RFI capability was
    // zeroed, so the negotiated state is off. The line must say so.
    void reportsRfiOffForTheBl2408Shape()
    {
        QByteArray line = render("hevc", "vaapi", "VAAPI",
                                 "Mesa Gallium driver 24.2.8 for AMD Radeon Graphics",
                                 DecoderStatus::RfiOff);
        QVERIFY(line.contains("RFI: off"));
        QVERIFY(!line.contains("RFI: on"));
    }

    // The healthy counterpart. If this and the test above ever agree, the line
    // has stopped carrying information.
    void reportsRfiOnWhenNegotiated()
    {
        QByteArray line = render("hevc", "vaapi", "VAAPI", "Mesa Gallium driver",
                                 DecoderStatus::RfiOn);
        QVERIFY(line.contains("RFI: on"));
        QVERIFY(!line.contains("RFI: off"));
    }

    // Before the RTSP/SDP handshake there is no negotiated value. The line must
    // admit that rather than defaulting to a plausible-looking "off" (or, far
    // worse, "on").
    void reportsRfiUnknownBeforeNegotiation()
    {
        QByteArray line = render("hevc", "vaapi", "VAAPI", "Mesa Gallium driver",
                                 DecoderStatus::RfiUnknown);
        QVERIFY(line.contains("RFI: unknown"));
        QVERIFY(!line.contains("RFI: on"));
        QVERIFY(!line.contains("RFI: off"));
    }

    // The three states must be mutually distinguishable as rendered text. This
    // is what a screenshot triage actually depends on.
    void rfiStatesRenderDistinctly()
    {
        QCOMPARE(DecoderStatus::rfiStateText(DecoderStatus::RfiOn), "on");
        QCOMPARE(DecoderStatus::rfiStateText(DecoderStatus::RfiOff), "off");
        QCOMPARE(DecoderStatus::rfiStateText(DecoderStatus::RfiUnknown), "unknown");
        QVERIFY(strcmp(DecoderStatus::rfiStateText(DecoderStatus::RfiOn),
                       DecoderStatus::rfiStateText(DecoderStatus::RfiOff)) != 0);
    }

    // An out-of-range value must degrade to "unknown", never to "on". If the
    // shim ever returns something unexpected, the overlay must not claim RFI is
    // working.
    void unexpectedStateValuesDegradeToUnknown()
    {
        QCOMPARE(DecoderStatus::rfiStateText(42), "unknown");
        QCOMPARE(DecoderStatus::rfiStateText(-99), "unknown");
    }

    // ---- Line composition ----------------------------------------------

    void rendersAllFieldsInOrder()
    {
        QByteArray line = render("hevc", "vaapi", "VAAPI", "Mesa Gallium driver",
                                 DecoderStatus::RfiOn);
        QCOMPARE(line, QByteArray("Decoder: hevc (vaapi) via VAAPI; "
                                  "driver: Mesa Gallium driver; RFI: on\n"));
    }

    // Matches the "Label: value\n" convention of every other overlay section.
    void isASingleNewlineTerminatedLine()
    {
        QByteArray line = render("h264", "d3d11va", "D3D11VA", "NVIDIA GeForce RTX 4070",
                                 DecoderStatus::RfiOn);
        QVERIFY(line.startsWith("Decoder: "));
        QVERIFY(line.endsWith('\n'));
        QCOMPARE(line.count('\n'), 1);
    }

    // Software decoding has no hwaccel type; the parenthetical must vanish
    // rather than render as an empty "()".
    void omitsHwTypeWhenAbsent()
    {
        QByteArray line = render("hevc", nullptr, "SDL", nullptr,
                                 DecoderStatus::RfiOn);
        QCOMPARE(line, QByteArray("Decoder: hevc via SDL; RFI: on\n"));
        QVERIFY(!line.contains("()"));
    }

    // A non-hwaccel hardware decoder already names its hardware in codec->name,
    // so it arrives with an empty hwType. Same treatment as null.
    void treatsEmptyStringsAsAbsent()
    {
        QByteArray line = render("h264_rkmpp", "", "DRM", "",
                                 DecoderStatus::RfiOff);
        QCOMPARE(line, QByteArray("Decoder: h264_rkmpp via DRM; RFI: off\n"));
    }

    // Most renderers cannot identify their driver. Dropping the clause is
    // honest; printing "driver: unknown" would imply we asked and got nothing.
    void omitsDriverClauseWhenVendorUnavailable()
    {
        QByteArray line = render("av1", "vulkan", "Vulkan (libplacebo)", nullptr,
                                 DecoderStatus::RfiOn);
        QVERIFY(!line.contains("driver:"));
        QCOMPARE(line, QByteArray("Decoder: av1 (vulkan) via Vulkan (libplacebo); RFI: on\n"));
    }

    // Null identity fields must degrade visibly, not produce a malformed line
    // or dereference null. reset() frees the codec context and renderers before
    // the teardown stats log, so this path is reachable in production.
    void nullIdentityFieldsDegradeToUnknown()
    {
        QByteArray line = render(nullptr, nullptr, nullptr, nullptr,
                                 DecoderStatus::RfiUnknown);
        QCOMPARE(line, QByteArray("Decoder: unknown via unknown; RFI: unknown\n"));
    }

    // ---- Bounding, which is what protects the overlay buffer -------------

    // Mesa's real driver string is over 100 characters. It must be truncated,
    // must be marked as truncated, and must still carry the "Gallium" token —
    // that substring is what gates the BL-2408 workaround, so it is precisely
    // what a triager needs to see next to "RFI: off".
    void truncatesLongVendorButKeepsTheDiagnosticToken()
    {
        const char* mesa = "Mesa Gallium driver 24.2.8 for AMD Radeon Graphics "
                           "(radeonsi, gfx1103_r1, LLVM 18.1.8, DRM 3.57, 6.11.11)";
        QVERIFY((int)strlen(mesa) > DecoderStatus::MaxVendorChars);

        QByteArray line = render("hevc", "vaapi", "VAAPI", mesa,
                                 DecoderStatus::RfiOff);
        QVERIFY(line.contains("Gallium"));
        QVERIFY(line.contains("..."));
        QVERIFY(!line.contains("6.11.11"));
        // Truncation must never cost the RFI verdict at the end of the line.
        QVERIFY(line.endsWith("; RFI: off\n"));
    }

    // Every field is capped with a %.*s precision, so the line has a hard
    // upper bound no runtime value can exceed. This is the property that
    // distinguishes it from the VRR lines, whose widths grow with their
    // counters.
    void isWidthBoundedRegardlessOfInput()
    {
        QByteArray huge(400, 'X');
        QByteArray line = render(huge.constData(), huge.constData(),
                                 huge.constData(), huge.constData(),
                                 DecoderStatus::RfiUnknown);
        QVERIFY(line.size() <= DecoderStatus::MaxLineChars);
    }

    // The stated bound must be reachable, or it is not a bound of anything —
    // a stale MaxLineChars that over-estimates would hide a real overflow.
    void statedBoundIsTight()
    {
        QByteArray huge(400, 'X');
        QByteArray line = render(huge.constData(), huge.constData(),
                                 huge.constData(), huge.constData(),
                                 DecoderStatus::RfiUnknown);
        QCOMPARE(line.size(), DecoderStatus::MaxLineChars);
    }

    // The overlay buffer budget (overlaymanager.h). The existing sections were
    // measured at 1083 bytes worst case by rendering their verbatim format
    // strings with pessimistic-but-reachable values (7680x4320, 9999.99 rates,
    // saturated VRR counters and a 20-digit sequence number). This test fails
    // if the decoder line ever grows enough to threaten that headroom.
    void fitsTheOverlayTextBufferWithHeadroom()
    {
        const int overlayBufferBytes = 1536;
        const int measuredExistingWorstCase = 1083;
        const int nulTerminator = 1;

        QVERIFY(measuredExistingWorstCase + DecoderStatus::MaxLineChars + nulTerminator
                    < overlayBufferBytes);

        // Keep a real margin rather than merely "fits" — the VRR fields are not
        // width-bounded and will keep creeping.
        int remaining = overlayBufferBytes - measuredExistingWorstCase
                            - DecoderStatus::MaxLineChars - nulTerminator;
        QVERIFY2(remaining >= 128,
                 qPrintable(QStringLiteral("overlay slack fell to %1 bytes").arg(remaining)));
    }

    // formatLine() must report truncation the way snprintf() does, because
    // stringifyVideoStats() relies on the `ret >= length - offset` idiom to
    // detect a full buffer.
    void reportsTruncationLikeSnprintf()
    {
        // Heap-allocated so the compiler cannot statically prove the overflow
        // and warn about this deliberately-undersized buffer.
        QByteArray small(16, '\xFF');
        int ret = DecoderStatus::formatLine(small.data(), small.size(), "hevc",
                                            "vaapi", "VAAPI", nullptr,
                                            DecoderStatus::RfiOn);
        QVERIFY(ret >= small.size());
        // And it must still NUL-terminate what it did write.
        QCOMPARE(small.at(small.size() - 1), '\0');
    }
};

QTEST_APPLESS_MAIN(TstDecoderStatus)
#include "tst_decoderstatus.moc"
