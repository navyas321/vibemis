// Standalone deterministic coverage for the platform-neutral VRR core.
// This file is intentionally not wired into the application build; tests/vrr
// owns the optional qmake harness.

#include "../../app/streaming/video/ffmpeg-renderers/pacer/vrr/vrrtargetwaiter.h"
#include "../../app/streaming/video/ffmpeg-renderers/pacer/vrr/vrrtimingcontroller.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <limits>

namespace {

int failures = 0;

void expect(bool condition, const char* message)
{
    if (!condition) {
        std::fprintf(stderr, "FAIL: %s\n", message);
        ++failures;
    }
}

VrrSessionConfig config(int streamRateHz = 60, int displayRefreshHz = 120)
{
    VrrSessionConfig value;
    value.streamRateHz = streamRateHz;
    value.displayRefreshHz = displayRefreshHz;
    return value;
}

PacedFrame frame(int number, uint32_t timestamp, bool timestampValid,
                  uint64_t decodedUs)
{
    return PacedFrame(nullptr, number, timestamp, timestampValid, decodedUs);
}

uint32_t quantizedRtpTimestamp(int frameNumber, int sourceRateHz,
                               int captureRateHz = 120)
{
    const uint64_t captureFrame =
        (static_cast<uint64_t>(frameNumber) * captureRateHz +
         static_cast<uint64_t>(sourceRateHz) / 2) /
        static_cast<uint64_t>(sourceRateHz);
    return static_cast<uint32_t>(
        (captureFrame * 90000ULL +
         static_cast<uint64_t>(captureRateHz) / 2) /
        static_cast<uint64_t>(captureRateHz));
}

uint64_t decodedTimeForRtp(uint64_t epochUs, uint32_t timestamp)
{
    return epochUs + static_cast<uint64_t>(timestamp) * 1000000ULL / 90000ULL;
}

uint64_t idealDecodedTime(uint64_t epochUs, int frameNumber, int rateHz)
{
    return epochUs + (static_cast<uint64_t>(frameNumber) * 1000000ULL +
                      static_cast<uint64_t>(rateHz) / 2) /
        static_cast<uint64_t>(rateHz);
}

void testRtpWrapResetAndFallback()
{
    VrrTimingController controller(config());
    const uint32_t wrappedStart = 0xfffffe00U;
    controller.schedule(frame(1, wrappedStart, true, 100000), 100000);
    VrrTimingDecision wrapped = controller.schedule(
        frame(2, wrappedStart + 1500U, true, 116666), 116666);
    expect(!wrapped.rebased && wrapped.usedRtpTimestamp,
           "RTP wrap must be a normal valid interval");
    expect(wrapped.sourceIntervalUs == 16666,
           "wrapped RTP delta must convert at 90 kHz");

    VrrTimingDecision reset = controller.schedule(
        frame(3, 100U, true, 130000), 130000);
    expect(reset.rebased,
           "backward RTP movement must rebase rather than unwrap forward");

    VrrTimingController largeForwardController(config());
    largeForwardController.schedule(frame(1, 0, true, 100000), 100000);
    VrrTimingDecision largeForward = largeForwardController.schedule(
        frame(2, 90001, true, 1100011), 1100011);
    expect(largeForward.rebased,
           "valid RTP movement over one second must rebase");

    VrrTimingController fallbackController(config());
    fallbackController.schedule(frame(10, 0, false, 500000), 500000);
    VrrTimingDecision fallback = fallbackController.schedule(
        frame(12, 0, false, 533334), 533334);
    expect(!fallback.usedRtpTimestamp && fallback.sourceIntervalUs == 33333,
           "invalid timestamps must use rational frame-number cadence");

    VrrTimingDecision forwardReset = fallbackController.schedule(
        frame(1000, 0, false, 2000000), 2000000);
    expect(forwardReset.rebased,
           "fallback movement beyond one second must rebase");
}

// BL-2415: DECODE_UNIT carries the raw 90 kHz RTP timestamp alongside an
// explicit validity flag, and the ffmpeg.cpp decoder->pacer handoff forwards
// both verbatim. Two properties are locked in here:
//
//   1. An RTP timestamp of 0 is a legitimate 90 kHz value. Validity must come
//      from the flag, never be inferred from `rtpTimestamp != 0`.
//   2. When the host sends no PTS the flag is false and the controller takes
//      its rational frame-number cadence. The client must not substitute a
//      fabricated `presentationTimeMs * 90` clock: that value is
//      millisecond-quantized, so it feeds the cadence learner alternating
//      17/17/16 ms atoms and makes the model chase a phantom rate.
void testZeroTimestampIsValidAndAbsentTimestampFallsBack()
{
    // A valid timestamp that happens to be 0 must seed the RTP timeline. Were
    // it mistaken for "absent", the next frame would have no valid predecessor
    // and would report the frame-number fallback instead.
    VrrTimingController zeroSeeded(config(60, 120));
    zeroSeeded.schedule(frame(1, 0, true, 100000), 100000);
    VrrTimingDecision afterZero = zeroSeeded.schedule(
        frame(2, 1500, true, 116666), 116666);
    expect(afterZero.usedRtpTimestamp,
           "a valid RTP timestamp of 0 must seed the RTP timeline");
    expect(afterZero.sourceIntervalUs == 16666,
           "the interval after a valid zero timestamp must convert at 90 kHz");

    // Treating 0 as valid must not weaken the backward-movement reset: a valid
    // 0 arriving after a larger timestamp is still a wrap/reset, not an
    // interval.
    VrrTimingController backward(config(60, 120));
    backward.schedule(frame(1, 4500, true, 100000), 100000);
    expect(backward.schedule(frame(2, 0, true, 116666), 116666).rebased,
           "a valid zero timestamp arriving backward must still rebase");

    // Host omits PTS. `honest` receives what the fixed client forwards (the
    // carried timestamp plus validity == false); `fabricated` receives what the
    // pre-fix client synthesized (presentationTimeMs * 90, asserted valid).
    VrrTimingController honest(config(60, 120));
    VrrTimingController fabricated(config(60, 120));
    constexpr uint64_t nominalIntervalUs = 16666;
    uint64_t worstHonestErrorUs = 0;
    uint64_t worstFabricatedErrorUs = 0;
    bool fabricatedClaimedRtpCadence = false;
    bool honestClaimedRtpCadence = false;
    for (int number = 1; number <= 60; ++number) {
        const uint64_t decodedUs = idealDecodedTime(100000, number, 60);
        // presentationTimeMs as the synthetic-PTS path produces it: the source
        // clock truncated to whole milliseconds.
        const uint32_t presentationTimeMs = static_cast<uint32_t>(
            (static_cast<uint64_t>(number) * 1000ULL) / 60ULL);

        VrrTimingDecision honestDecision =
            honest.schedule(frame(number, 0, false, decodedUs), decodedUs);
        VrrTimingDecision fabricatedDecision = fabricated.schedule(
            frame(number, presentationTimeMs * 90u, true, decodedUs),
            decodedUs);

        if (number == 1) {
            continue;
        }

        honestClaimedRtpCadence =
            honestClaimedRtpCadence || honestDecision.usedRtpTimestamp;
        fabricatedClaimedRtpCadence =
            fabricatedClaimedRtpCadence || fabricatedDecision.usedRtpTimestamp;

        const uint64_t honestErrorUs =
            honestDecision.sourceIntervalUs > nominalIntervalUs ?
                honestDecision.sourceIntervalUs - nominalIntervalUs :
                nominalIntervalUs - honestDecision.sourceIntervalUs;
        const uint64_t fabricatedErrorUs =
            fabricatedDecision.sourceIntervalUs > nominalIntervalUs ?
                fabricatedDecision.sourceIntervalUs - nominalIntervalUs :
                nominalIntervalUs - fabricatedDecision.sourceIntervalUs;
        worstHonestErrorUs = std::max(worstHonestErrorUs, honestErrorUs);
        worstFabricatedErrorUs = std::max(worstFabricatedErrorUs,
                                          fabricatedErrorUs);
    }

    expect(!honestClaimedRtpCadence,
           "an absent timestamp must never be reported as an RTP interval");
    expect(worstHonestErrorUs <= 1,
           "the documented fallback must produce exact rational 60 FPS atoms");
    expect(fabricatedClaimedRtpCadence,
           "the pre-fix fabricated clock was indistinguishable from a real one");
    expect(worstFabricatedErrorUs >= 300,
           "a ms-quantized fabricated clock misreports the source cadence, "
           "which is why the fallback must be taken instead");
}

void testTimingFormulaeAndReserveCap()
{
    VrrTimingController controller(config(60, 120));
    VrrTimingDecision first = controller.schedule(
        frame(1, 0, true, 100000), 100000);
    const VrrTimingParameters& parameters = controller.parameters();
    const uint64_t expectedGuardUs = std::clamp(
        controller.displayPeriodUs() / parameters.baseGuardDivisor,
        parameters.minimumGuardUs, parameters.maximumBaseGuardUs);
    expect(first.guardUs == expectedGuardUs,
           "display guard must honor the configured divisor and bounds");
    expect(first.headroomUs ==
               controller.sourcePeriodUs() - controller.displayPeriodUs() -
                   expectedGuardUs,
           "headroom must subtract one display period and the guard");
    expect(first.targetUs ==
               100000 + first.renderLeadUs + parameters.presentationSafetyUs &&
               first.renderStartUs ==
                   first.targetUs - first.renderLeadUs - first.renderWakeLeadUs,
           "target must include render lead and presentation safety");

    controller.noteSubmission(true, false, first.targetUs);
    VrrTimingDecision second = controller.schedule(
        frame(2, 1500, true, 116666), 116666);
    expect(second.targetUs >=
               first.targetUs + controller.displayPeriodUs() + expectedGuardUs,
           "target must honor the prior presentation floor and guard");

    VrrTimingController capped(config(360, 120));
    VrrTimingDecision cappedDecision = capped.schedule(
        frame(1, 0, true, 100000), 100000);
    capped.notePreparationDuration(10000);
    capped.noteSubmission(true, false, cappedDecision.targetUs);
    expect(capped.renderLeadUs() <= capped.sourcePeriodUs(),
           "render lead must never exceed the source period");
}

void testLongRunNearRefreshRtpCadence()
{
    constexpr int streamRateHz = 116;
    constexpr uint64_t rtpClockHz = 90000;
    constexpr uint64_t microsecondsPerSecond = 1000000;
    constexpr uint64_t initialUs = 1000000;
    VrrTimingController controller(config(streamRateHz, 120));
    controller.schedule(frame(0, 0, true, initialUs), initialUs);

    uint64_t maximumSourceErrorUs = 0;
    bool sawRebase = false;
    for (int i = 1; i <= 2000; ++i) {
        const uint32_t timestamp = static_cast<uint32_t>(
            (static_cast<uint64_t>(i) * rtpClockHz) / streamRateHz);
        const uint64_t expectedSourceUs = initialUs +
            (static_cast<uint64_t>(i) * microsecondsPerSecond) / streamRateHz;
        VrrTimingDecision decision = controller.schedule(
            frame(i, timestamp, true, expectedSourceUs), expectedSourceUs);
        sawRebase = sawRebase || decision.rebased;
        const uint64_t sourceErrorUs = decision.sourceTimeUs > expectedSourceUs ?
            decision.sourceTimeUs - expectedSourceUs :
            expectedSourceUs - decision.sourceTimeUs;
        maximumSourceErrorUs = std::max(maximumSourceErrorUs, sourceErrorUs);
    }

    expect(!sawRebase,
           "steady near-refresh RTP cadence must not rebase");
    expect(maximumSourceErrorUs <= 12,
           "90 kHz timestamp quantization must not accumulate source-clock drift");
}

void testQuantizedCadenceDoesNotOscillate()
{
    constexpr uint64_t epochUs = 1000000;
    struct CadenceCase {
        int streamRateHz;
        int captureRateHz;
        int displayRefreshHz;
    };
    const CadenceCase cases[] = {
        {59, 60, 60},
        {116, 120, 120},
        {138, 144, 144},
        {480, 480, 960},
    };

    for (const CadenceCase& cadence : cases) {
        VrrTimingController controller(config(cadence.streamRateHz,
                                              cadence.displayRefreshHz));
        VrrTimingDecision decision = controller.schedule(
            frame(0, 0, true, epochUs), epochUs);
        controller.noteSubmission(true, false, decision.targetUs);

        const uint64_t expectedPeriodUs =
            (1000000ULL + static_cast<uint64_t>(cadence.streamRateHz) / 2) /
            static_cast<uint64_t>(cadence.streamRateHz);
        uint64_t minimumPeriodUs = std::numeric_limits<uint64_t>::max();
        uint64_t maximumPeriodUs = 0;
        int64_t minimumReadyOffsetUs = std::numeric_limits<int64_t>::max();
        int64_t maximumReadyOffsetUs = std::numeric_limits<int64_t>::min();
        uint64_t maximumTimingBudgetUs = 0;
        bool sawRebase = false;
        const int warmupFrames = cadence.streamRateHz * 4;
        const int frameCount = cadence.streamRateHz * 12;

        for (int i = 1; i <= frameCount; ++i) {
            const uint32_t timestamp = quantizedRtpTimestamp(
                i, cadence.streamRateHz, cadence.captureRateHz);
            const uint64_t decodedUs = idealDecodedTime(
                epochUs, i, cadence.streamRateHz);
            decision = controller.schedule(
                frame(i, timestamp, true, decodedUs), decodedUs);
            controller.noteSubmission(true, false, decision.targetUs);
            sawRebase = sawRebase || decision.rebased;

            if (i > warmupFrames) {
                minimumPeriodUs = std::min(minimumPeriodUs,
                                            decision.sourcePeriodUs);
                maximumPeriodUs = std::max(maximumPeriodUs,
                                            decision.sourcePeriodUs);
                minimumReadyOffsetUs = std::min(minimumReadyOffsetUs,
                                                decision.readyOffsetUs);
                maximumReadyOffsetUs = std::max(maximumReadyOffsetUs,
                                                decision.readyOffsetUs);
                maximumTimingBudgetUs = std::max(
                    maximumTimingBudgetUs, controller.timingBudgetUs());
            }
        }

        const uint64_t readyOffsetSpanUs =
            maximumReadyOffsetUs > minimumReadyOffsetUs ?
                static_cast<uint64_t>(maximumReadyOffsetUs -
                                      minimumReadyOffsetUs) : 0;
        if (minimumPeriodUs != expectedPeriodUs ||
                maximumPeriodUs != expectedPeriodUs ||
                readyOffsetSpanUs > 2 ||
                maximumTimingBudgetUs > 2000) {
            std::fprintf(stderr,
                         "quantized cadence %d/%d: period=%llu..%llu "
                         "expected=%llu phase-span=%llu budget=%llu\n",
                         cadence.streamRateHz, cadence.captureRateHz,
                         static_cast<unsigned long long>(minimumPeriodUs),
                         static_cast<unsigned long long>(maximumPeriodUs),
                         static_cast<unsigned long long>(expectedPeriodUs),
                         static_cast<unsigned long long>(readyOffsetSpanUs),
                         static_cast<unsigned long long>(maximumTimingBudgetUs));
        }
        expect(!sawRebase,
               "steady host-quantized cadence must not rebase");
        expect(minimumPeriodUs == expectedPeriodUs &&
                   maximumPeriodUs == expectedPeriodUs,
               "host-quantized cadence must retain one exact learned period");
        expect(readyOffsetSpanUs <= 2,
               "host-quantized cadence must not create millisecond source phase motion");
        expect(maximumTimingBudgetUs <= 2000,
               "host-quantized cadence must not create a multi-millisecond readiness reserve");
    }
}

void testNegotiatedRateCeiling()
{
    constexpr uint64_t epochUs = 1000000;

    VrrTimingController candidateController(config(60, 120));
    candidateController.schedule(frame(0, 0, true, epochUs), epochUs);
    candidateController.schedule(
        frame(1, 1500, true, idealDecodedTime(epochUs, 1, 60)),
        idealDecodedTime(epochUs, 1, 60));
    VrrTimingDecision provisional = candidateController.schedule(
        frame(2, 1875, true, idealDecodedTime(epochUs, 2, 240)),
        idealDecodedTime(epochUs, 2, 240));
    VrrTimingDecision boundedCandidate = candidateController.schedule(
        frame(3, 2250, true, idealDecodedTime(epochUs, 3, 240)),
        idealDecodedTime(epochUs, 3, 240));
    const uint64_t sixtyFpsPeriodUs = (1000000ULL + 30) / 60;
    expect(provisional.phaseDiscontinuity &&
               !boundedCandidate.sourceRateChanged &&
               candidateController.sourcePeriodUs() == sixtyFpsPeriodUs,
           "a faster provisional candidate must remain at the negotiated rate");

    VrrTimingController fittedController(config(116, 120));
    fittedController.schedule(frame(0, 0, true, epochUs), epochUs);
    uint64_t minimumPeriodUs = std::numeric_limits<uint64_t>::max();
    for (int i = 1; i <= 128; ++i) {
        const uint32_t timestamp = static_cast<uint32_t>(i * 750);
        const uint64_t decodedUs = idealDecodedTime(epochUs, i, 120);
        const VrrTimingDecision decision = fittedController.schedule(
            frame(i, timestamp, true, decodedUs), decodedUs);
        if (i >= 16) {
            minimumPeriodUs = std::min(minimumPeriodUs,
                                        decision.sourcePeriodUs);
        }
    }
    const uint64_t negotiatedPeriodUs = (1000000ULL + 58) / 116;
    expect(minimumPeriodUs == negotiatedPeriodUs,
           "a fitted cadence must never imply a rate above the negotiated stream FPS");
}

void testSpacingGuardFeedback()
{
    VrrTimingController controller(config(60, 120));
    VrrTimingDecision first = controller.schedule(
        frame(1, 0, true, 100000), 100000);
    controller.noteSubmission(true, false, first.targetUs);
    controller.noteSpacingDeficit(300);
    expect(controller.guardUs() == 400,
           "a spacing deficit must raise the bounded guard directly");

    VrrTimingDecision second = controller.schedule(
        frame(2, 1500, true, 116666), 116666);
    expect(second.targetUs >= first.targetUs + 8333 + 400,
           "the raised guard must affect the next display-spacing floor");

    for (int i = 0; i < 120; ++i) {
        controller.noteSpacingDeficit(0);
    }
    expect(controller.guardUs() == 350,
           "a clean run must decay the guard by one small step");
}

void testNearRefreshRequestsLatchedPresentation()
{
    VrrTimingController nearRefresh(config(116, 120));
    VrrTimingDecision decision = nearRefresh.schedule(
        frame(1, 0, true, 100000), 100000);
    expect(decision.latchedPresentation,
           "a near-refresh cadence must request latched presentation");

    VrrTimingController withHeadroom(config(20, 120));
    decision = withHeadroom.schedule(frame(1, 0, true, 100000), 100000);
    expect(!decision.latchedPresentation,
           "a cadence beyond the display-scaled protection window must keep immediate flips");

    VrrTimingController immutableMailbox(config(116, 120), false);
    decision = immutableMailbox.schedule(
        frame(1, 0, true, 100000), 100000);
    expect(!decision.latchedPresentation,
           "an immutable cadence-following backend must not be classified as fixed-vsync latched");
}

void testLatchedPresentationRecoversAfterGuardDecay()
{
    VrrTimingController controller(config(35, 144));
    VrrTimingDecision decision = controller.schedule(
        frame(1, 0, true, 100000), 100000);
    expect(!decision.latchedPresentation,
           "a cadence beyond the scaled entry window must begin in immediate mode");

    const uint64_t baseGuardUs = decision.guardUs;
    const VrrTimingParameters& parameters = controller.parameters();
    const uint64_t scaledLatchHeadroomUs =
        controller.displayPeriodUs() *
            parameters.latchedPresentationHeadroomPeriodNumerator /
            parameters.latchedPresentationHeadroomPeriodDenominator;
    const uint64_t latchHeadroomUs = std::max(
        parameters.latchedPresentationHeadroomUs,
        scaledLatchHeadroomUs);
    const uint64_t latchDeficitUs =
        decision.headroomUs - latchHeadroomUs + 1;
    controller.noteSpacingDeficit(latchDeficitUs);
    decision = controller.schedule(
        frame(2, 2571, true, 128571), 128571);
    expect(decision.latchedPresentation,
           "a transient guard increase must select the safe latched path");

    const size_t decayCycles = static_cast<size_t>(
        (controller.guardUs() - baseGuardUs +
         parameters.guardStepUs - 1) /
        parameters.guardStepUs);
    for (size_t i = 0;
         i < decayCycles * parameters.guardDecayFrames; ++i) {
        controller.noteSpacingDeficit(0);
    }
    decision = controller.schedule(
        frame(3, 5143, true, 157144), 157144);
    expect(!decision.latchedPresentation,
           "a fully recovered guard must restore immediate presentation outside the scaled window");
}

void testDisplayScaledLatchedPresentationBoundary()
{
    const struct {
        int displayHz;
        int protectedRateHz;
        int adaptiveRateHz;
    } cases[] = {
        {60, 15, 14},
        {120, 30, 29},
        {144, 36, 35},
        {165, 42, 41},
    };
    for (const auto& value : cases) {
        VrrTimingController protectedController(
            config(value.protectedRateHz, value.displayHz));
        const VrrTimingDecision protectedDecision =
            protectedController.schedule(
                frame(1, 0, true, 100000), 100000);
        expect(protectedDecision.latchedPresentation,
               "three-period latch protection must scale with display refresh");

        VrrTimingController adaptiveController(
            config(value.adaptiveRateHz, value.displayHz));
        const VrrTimingDecision adaptiveDecision =
            adaptiveController.schedule(
                frame(1, 0, true, 100000), 100000);
        expect(!adaptiveDecision.latchedPresentation,
               "cadence beyond the three-period window must stay adaptive at every display rate");
    }
}

void testHeadroomAwareReadinessReserve()
{
    constexpr uint64_t epochUs = 1000000;
    VrrTimingController wideHeadroom(config(60, 120), false);
    VrrTimingController nearCeiling(config(116, 120), false);

    const auto train = [](VrrTimingController& controller, int rateHz) {
        constexpr uint64_t startUs = epochUs;
        VrrTimingDecision decision = controller.schedule(
            frame(0, 0, true, startUs), startUs);
        controller.noteSubmission(true, false, decision.targetUs);
        for (int i = 1; i <= 96; ++i) {
            const uint32_t timestamp = static_cast<uint32_t>(
                static_cast<uint64_t>(i) * 90000ULL /
                static_cast<uint64_t>(rateHz));
            const uint64_t sourceUs = decodedTimeForRtp(startUs, timestamp);
            const uint64_t tailUs = i % 4 == 0 ? 3000 : 0;
            decision = controller.schedule(
                frame(i, timestamp, true, sourceUs + tailUs),
                sourceUs + tailUs);
            controller.noteSubmission(true, false, decision.targetUs);
        }
    };

    train(wideHeadroom, 60);
    train(nearCeiling, 116);

    if (wideHeadroom.timingBudgetUs() + 500 >=
            nearCeiling.timingBudgetUs()) {
        std::fprintf(stderr,
                     "headroom budgets: wide=%llu us near=%llu us\n",
                     static_cast<unsigned long long>(wideHeadroom.timingBudgetUs()),
                     static_cast<unsigned long long>(nearCeiling.timingBudgetUs()));
    }
    expect(wideHeadroom.timingBudgetUs() + 500 <
               nearCeiling.timingBudgetUs(),
           "cadence headroom must absorb arrival spread without carrying the near-ceiling reserve at lower rates");
    expect(nearCeiling.timingBudgetUs() >= 3000,
           "near-ceiling cadence-following presentation must retain a real burst cushion");
}

void testNearCeilingBufferFitsOneSourceInterval()
{
    constexpr int streamRateHz = 116;
    constexpr uint64_t epochUs = 1000000;
    VrrTimingController controller(config(streamRateHz, 120), false);

    VrrTimingDecision decision = controller.schedule(
        frame(0, 0, true, epochUs), epochUs);
    controller.noteSubmission(true, false, decision.targetUs);

    // Train the readiness model with a severe but valid gap-then-burst arrival
    // pattern. Before the near-ceiling cap, the learned reserve could consume
    // a full source interval and render lead was added on top, creating a
    // standing queue deeper than one frame and feeding present backpressure.
    for (int i = 1; i <= 128; ++i) {
        const uint32_t timestamp = static_cast<uint32_t>(
            static_cast<uint64_t>(i) * 90000ULL / streamRateHz);
        const uint64_t sourceUs = decodedTimeForRtp(epochUs, timestamp);
        // Keep decoded time monotonic while still creating enough spread to
        // reproduce the pre-fix reserve overflow.
        const uint64_t arrivalTailUs = i % 4 == 0 ? 8000 : 0;
        decision = controller.schedule(
            frame(i, timestamp, true, sourceUs + arrivalTailUs),
            sourceUs + arrivalTailUs);
        const uint64_t scheduledReadinessUs =
            decision.readinessBudgetUs > 0 ?
                static_cast<uint64_t>(decision.readinessBudgetUs) : 0;
        expect(scheduledReadinessUs + decision.renderLeadUs <=
                   decision.sourcePeriodUs + 2000,
               "burst-driven timing budget must remain bounded");
        controller.notePreparationDuration(1000);
        controller.noteSubmission(true, false, decision.targetUs);
    }

    if (controller.timingBudgetUs() > controller.sourcePeriodUs()) {
        std::fprintf(stderr,
                     "near-ceiling buffer: budget=%llu us source=%llu us\n",
                     static_cast<unsigned long long>(controller.timingBudgetUs()),
                     static_cast<unsigned long long>(controller.sourcePeriodUs()));
    }
    expect(controller.timingBudgetUs() <= controller.sourcePeriodUs() + 2000,
           "near-ceiling timing budget must remain bounded");

    // The scheduling target, not just telemetry, must obey the same bound.
    const uint32_t cleanTimestamp = static_cast<uint32_t>(
        129ULL * 90000ULL / streamRateHz);
    const uint64_t cleanSourceUs = decodedTimeForRtp(epochUs, cleanTimestamp);
    decision = controller.schedule(
        frame(129, cleanTimestamp, true, cleanSourceUs), cleanSourceUs);
    const uint64_t positiveReadinessUs = decision.readinessBudgetUs > 0 ?
        static_cast<uint64_t>(decision.readinessBudgetUs) : 0;
    expect(positiveReadinessUs + decision.renderLeadUs <=
               decision.sourcePeriodUs + 2000,
           "the near-ceiling scheduling budget must remain bounded");
}

void testRenderLeadGrowthIsStable()
{
    constexpr int streamRateHz = 116;
    constexpr uint64_t epochUs = 1000000;
    VrrTimingController controller(config(streamRateHz, 120), false);

    for (int i = 0; i <= 96; ++i) {
        const uint32_t timestamp = static_cast<uint32_t>(
            static_cast<uint64_t>(i) * 90000ULL / streamRateHz);
        const uint64_t sourceUs = decodedTimeForRtp(epochUs, timestamp);
        const uint64_t arrivalTailUs =
            i < 48 && i % 4 == 0 ? 8000 : 0;
        VrrTimingDecision decision = controller.schedule(
            frame(i, timestamp, true, sourceUs + arrivalTailUs),
            sourceUs + arrivalTailUs);
        controller.notePreparationDuration(i < 48 ? 1000 : 6000);
        controller.noteSubmission(true, false, decision.targetUs);
    }

    expect(controller.renderLeadUs() >= 1000 && controller.renderLeadUs() <= 6500,
           "render lead must converge within the configured floor/ceiling");
}

void testHighRateRenderLeadLeavesPresentationSafety()
{
    constexpr int streamRateHz = 480;
    constexpr uint64_t epochUs = 1000000;
    VrrTimingController controller(config(streamRateHz, 960), false);

    for (int i = 0; i <= 64; ++i) {
        const uint32_t timestamp = static_cast<uint32_t>(
            static_cast<uint64_t>(i) * 90000ULL / streamRateHz);
        const uint64_t sourceUs = decodedTimeForRtp(epochUs, timestamp);
        VrrTimingDecision decision = controller.schedule(
            frame(i, timestamp, true, sourceUs), sourceUs);
        controller.notePreparationDuration(10000);
        controller.noteSubmission(true, false, decision.targetUs);
    }

    expect(controller.renderLeadUs() <= controller.sourcePeriodUs(),
           "high-rate render lead must not exceed the source period");
    expect(controller.timingBudgetUs() <= controller.sourcePeriodUs() + 2000,
           "high-rate timing budget must remain bounded");
}

void testColdStartBudgetIsReasonable()
{
    // The cold-start readiness reserve is a fixed constant. On very high
    // rate streams it can temporarily exceed one source interval; the
    // readiness model corrects this during scheduling. Verify the budget
    // is at least plausible (not wildly out of range).
    const struct { int streamRateHz; int displayRefreshHz; } cases[] = {
        { 480, 960 }, { 360, 360 }, { 240, 240 }, { 144, 144 },
        { 120, 120 }, { 116, 120 }, { 60, 120 }, { 30, 60 },
    };

    for (const auto& c : cases) {
        VrrTimingController controller(config(c.streamRateHz,
                                              c.displayRefreshHz), false);
        expect(controller.timingBudgetUs() <= controller.sourcePeriodUs() * 2,
               "a freshly constructed controller must have a bounded timing budget");
    }
}

void testLateArrivalPhaseKeepsBudgetInsideSourceInterval()
{
    constexpr int streamRateHz = 116;
    constexpr uint64_t epochUs = 1000000;
    VrrTimingController controller(config(streamRateHz, 120), false);

    // Anchor on an on-time frame, then hold every later frame consistently
    // behind the projected source clock but under the re-anchor ceiling. The
    // learned readiness phase is then strongly positive, which is the only
    // regime where the desired-budget clamp - rather than the reserve clamp
    // that the other near-ceiling tests exercise - is what keeps readiness
    // plus render lead inside one source interval.
    VrrTimingDecision decision = controller.schedule(
        frame(0, 0, true, epochUs), epochUs);
    controller.notePreparationDuration(1000);
    controller.noteSubmission(true, false, decision.targetUs);

    for (int i = 1; i <= 160; ++i) {
        const uint32_t timestamp = static_cast<uint32_t>(
            static_cast<uint64_t>(i) * 90000ULL / streamRateHz);
        // Sustained late phase plus a real arrival spread, so the learned
        // reserve is non-trivial on top of the positive phase.
        const uint64_t latenessUs = 5000 + (i % 4 == 0 ? 3000 : 0);
        const uint64_t arrivalUs =
            decodedTimeForRtp(epochUs, timestamp) + latenessUs;
        decision = controller.schedule(
            frame(i, timestamp, true, arrivalUs), arrivalUs);
        controller.notePreparationDuration(1000);
        controller.noteSubmission(true, false, decision.targetUs);

        // Check after the submission: this is where the reserve-acquire ramp
        // runs, and where an unclamped desired budget overshoots the cap by a
        // ramp step before the next schedule clamps it back.
        const uint64_t positiveReadinessUs =
            controller.readinessBudgetUs() > 0 ?
                static_cast<uint64_t>(controller.readinessBudgetUs()) : 0;
        expect(positiveReadinessUs + controller.renderLeadUs() <=
                   controller.sourcePeriodUs() + 2000,
               "a positive readiness phase must keep the budget bounded");
    }

    if (controller.timingBudgetUs() > controller.sourcePeriodUs()) {
        std::fprintf(stderr,
                     "late-arrival phase: budget=%llu us source=%llu us\n",
                     static_cast<unsigned long long>(controller.timingBudgetUs()),
                     static_cast<unsigned long long>(controller.sourcePeriodUs()));
    }
    expect(controller.timingBudgetUs() <= controller.sourcePeriodUs(),
           "a positive readiness phase must keep the timing budget inside one "
           "source interval");
}

void testCadenceGapAndRateChange()
{
    VrrTimingController controller(config(120, 120));
    uint32_t timestamp = 0;
    uint64_t decodedUs = 100000;
    controller.schedule(frame(0, timestamp, true, decodedUs), decodedUs);
    for (int i = 1; i <= 8; ++i) {
        timestamp += 1500;
        decodedUs += 16666;
        controller.schedule(frame(i, timestamp, true, decodedUs), decodedUs);
    }
    expect(controller.sourcePeriodUs() == 16667,
           "stable raw cadence must retain rational RTP conversion carry");

    timestamp += 6000;
    decodedUs += 66666;
    VrrTimingDecision gap = controller.schedule(
        frame(9, timestamp, true, decodedUs), decodedUs);
    expect(!gap.cadenceEligible,
           "one large interval must be isolated from cadence adaptation");
    expect(controller.sourcePeriodUs() == 16667,
           "an isolated gap must not retune the source period");

    timestamp += 1500;
    decodedUs += 16666;
    controller.schedule(frame(10, timestamp, true, decodedUs), decodedUs);

    VrrTimingDecision accepted;
    for (int i = 0; i < 16; ++i) {
        timestamp += 1000;
        decodedUs += 11111;
        accepted = controller.schedule(
            frame(11 + i, timestamp, true, decodedUs), decodedUs);
    }
    const double learnedRateHz = 1000000.0 /
        static_cast<double>(controller.sourcePeriodUs());
    expect(std::abs(learnedRateHz - 90.0) < 1.0,
           "a cumulative segment must converge on a non-atomic new rate");
}

void testFutureSourceProjectionReseedsPhase()
{
    VrrTimingController controller(config(116, 120));
    constexpr uint64_t initialUs = 1000000;
    controller.schedule(frame(0, 0, true, initialUs), initialUs);

    constexpr uint64_t nowUs = initialUs + 8621;
    VrrTimingDecision recovered = controller.schedule(
        frame(50, 38024, true, nowUs), nowUs);

    expect(!recovered.rebased && recovered.sourceIntervalUs != 0 &&
               recovered.targetUs < nowUs + 2 * 8621,
           "a source projection ahead of decoded local time must reseed phase without discarding cadence");
}

void testDecodeTailAdaptation()
{
    VrrTimingController controller(config());
    uint32_t timestamp = 0;
    uint64_t sourceUs = 1000000;
    controller.schedule(frame(0, timestamp, true, sourceUs), sourceUs);

    for (int i = 1; i <= 16; ++i) {
        timestamp += 1500;
        sourceUs += 16666;
        const uint64_t tailUs = i % 4 == 0 ? 5000 : 0;
        VrrTimingDecision decision = controller.schedule(
            frame(i, timestamp, true, sourceUs + tailUs), sourceUs + tailUs);
        controller.notePreparationDuration(1000);
        controller.noteSubmission(true, false, decision.targetUs);
    }

    // Upstream's retuned model replaced the fixed 500 us render slack with a
    // p99 preparation percentile over a longer learning window; with every
    // observed preparation at 1000 us the learned lead is exactly that.
    expect(controller.renderLeadUs() == 1000,
           "render lead must follow the learned preparation percentile");
    // The 5000 us decode tail must be LEARNED (demand includes spread plus
    // the arrival guard), while 60-on-120's wide cadence headroom absorbs it
    // without a standing reserve: budget stays at the floor of minimum
    // reserve + render lead.
    expect(controller.diagnostics().readinessDemandUs >= 5000,
           "a decode tail must be learned into readiness demand");
    expect(controller.timingBudgetUs() == 1500,
           "wide cadence headroom must absorb the tail without standing latency");
}

void testRateChangeReseedsReadinessBudget()
{
    VrrTimingController controller(config(116, 120));
    controller.schedule(frame(0, 0, true, 100000), 100000);
    VrrTimingDecision provisional = controller.schedule(
        frame(1, 3000, true, 133333), 133333);
    VrrTimingDecision accepted = controller.schedule(
        frame(2, 6000, true, 166666), 166666);

    expect(provisional.phaseDiscontinuity &&
               accepted.sourceRateChanged &&
               accepted.readinessBudgetUs == accepted.readyOffsetUs &&
               std::abs(1000000.0 /
                   static_cast<double>(accepted.sourcePeriodUs) - 30.0) < 0.1,
            "a confirmed major slowdown must reseed phase and readiness after two intervals");
}

void testFractionalQuantizedCadenceLearning()
{
    constexpr uint64_t epochUs = 1000000;

    for (int rateHz = 30; rateHz <= 116; ++rateHz) {
        VrrTimingController controller(config(116, 120));
        controller.schedule(frame(0, 0, true, epochUs), epochUs);

        const int sampleCount = std::max(160, rateHz * 2);
        bool rebased = false;
        for (int i = 1; i <= sampleCount; ++i) {
            const uint32_t timestamp = quantizedRtpTimestamp(i, rateHz);
            const uint64_t decodedUs = decodedTimeForRtp(epochUs, timestamp);
            const VrrTimingDecision decision = controller.schedule(
                frame(i, timestamp, true, decodedUs), decodedUs);
            rebased = rebased || decision.rebased;
        }

        const double learnedRateHz = 1000000.0 /
            static_cast<double>(controller.sourcePeriodUs());
        expect(!rebased,
               "fractional capture-clock cadence must not rebase");
        if (std::abs(learnedRateHz - rateHz) >= 0.75) {
            std::fprintf(stderr,
                         "cadence mismatch: requested=%d learned=%.3f\n",
                         rateHz, learnedRateHz);
        }
        expect(std::abs(learnedRateHz - rateHz) < 0.75,
               "cumulative cadence learning must represent arbitrary rates continuously");
    }
}

void testCutsceneRecoveryAndHitchIsolation()
{
    constexpr uint64_t epochUs = 1000000;
    VrrTimingController controller(config(116, 120));
    controller.schedule(frame(0, 0, true, epochUs), epochUs);

    int frameNumber = 0;
    uint32_t timestamp = 0;
    for (int i = 1; i <= 140; ++i) {
        frameNumber = i;
        timestamp = quantizedRtpTimestamp(i, 116);
        const uint64_t decodedUs = decodedTimeForRtp(epochUs, timestamp);
        controller.schedule(frame(frameNumber, timestamp, true, decodedUs),
                            decodedUs);
    }
    const uint64_t stablePeriodUs = controller.sourcePeriodUs();

    timestamp += 3750;
    ++frameNumber;
    uint64_t decodedUs = decodedTimeForRtp(epochUs, timestamp);
    VrrTimingDecision hitch = controller.schedule(
        frame(frameNumber, timestamp, true, decodedUs), decodedUs);
    expect(hitch.phaseDiscontinuity && !hitch.sourceRateChanged,
           "one large hitch must start only a provisional cadence segment");

    timestamp += 750;
    ++frameNumber;
    decodedUs = decodedTimeForRtp(epochUs, timestamp);
    VrrTimingDecision recovered = controller.schedule(
        frame(frameNumber, timestamp, true, decodedUs), decodedUs);
    expect(recovered.phaseDiscontinuity && !recovered.sourceRateChanged &&
               std::abs(static_cast<int64_t>(controller.sourcePeriodUs()) -
                        static_cast<int64_t>(stablePeriodUs)) < 100,
           "a normal successor must abandon a hitch without poisoning the stable rate");

    VrrTimingDecision cutscene;
    for (int i = 0; i < 2; ++i) {
        timestamp += 3000;
        ++frameNumber;
        decodedUs = decodedTimeForRtp(epochUs, timestamp);
        cutscene = controller.schedule(
            frame(frameNumber, timestamp, true, decodedUs), decodedUs);
    }
    expect(cutscene.sourceRateChanged &&
               std::abs(1000000.0 /
                   static_cast<double>(controller.sourcePeriodUs()) - 30.0) < 0.1,
           "a 30 FPS cutscene must be accepted after two confirming intervals");

    VrrTimingDecision acceleration;
    for (int i = 0; i < 2; ++i) {
        timestamp += 750;
        ++frameNumber;
        decodedUs = decodedTimeForRtp(epochUs, timestamp);
        acceleration = controller.schedule(
            frame(frameNumber, timestamp, true, decodedUs), decodedUs);
    }
    expect(acceleration.sourceRateChanged && acceleration.latchedPresentation,
           "returning to the tight high-rate range must recover provisionally in latched mode");
}

void testModerateSlowdownSelfHealsPhase()
{
    constexpr uint64_t epochUs = 1000000;
    VrrTimingController controller(config(60, 120));
    controller.schedule(frame(0, 0, true, epochUs), epochUs);

    int frameNumber = 0;
    uint32_t timestamp = 0;
    for (int i = 1; i <= 80; ++i) {
        frameNumber = i;
        timestamp += 1500;
        const uint64_t decodedUs = decodedTimeForRtp(epochUs, timestamp);
        controller.schedule(frame(frameNumber, timestamp, true, decodedUs),
                            decodedUs);
    }

    bool healedPhase = false;
    for (int i = 0; i < 40; ++i) {
        ++frameNumber;
        timestamp += 3000;
        const uint64_t decodedUs = decodedTimeForRtp(epochUs, timestamp);
        const VrrTimingDecision decision = controller.schedule(
            frame(frameNumber, timestamp, true, decodedUs), decodedUs);
        healedPhase = healedPhase || decision.phaseDiscontinuity;
        if (i == 3) {
            expect(healedPhase,
                   "a moderate slowdown must heal phase within four frames even without a major-rate candidate");
        }
    }

    const double learnedRateHz = 1000000.0 /
        static_cast<double>(controller.sourcePeriodUs());
    expect(std::abs(learnedRateHz - 30.0) < 0.75,
           "a moderate slowdown must converge to its cumulative cadence after phase recovery");

    ++frameNumber;
    timestamp += 1500;
    const uint64_t acceleratedDecodeUs = decodedTimeForRtp(epochUs,
                                                            timestamp);
    const VrrTimingDecision accelerated = controller.schedule(
        frame(frameNumber, timestamp, true, acceleratedDecodeUs),
        acceleratedDecodeUs);
    expect(accelerated.phaseDiscontinuity &&
               accelerated.targetUs < acceleratedDecodeUs + 5000,
           "a frame arriving ahead of a slower cutscene clock must bypass stale latency immediately");
}

void testContinuousCadenceSweep()
{
    constexpr uint64_t epochUs = 1000000;
    VrrTimingController controller(config(116, 120));
    controller.schedule(frame(0, 0, true, epochUs), epochUs);

    int frameNumber = 0;
    long double idealRtpTicks = 0.0L;
    uint32_t timestamp = 0;
    double maximumRateErrorHz = 0.0;
    bool rebased = false;

    const auto runRate = [&](int rateHz) {
        const uint32_t startTimestamp = timestamp;
        const int startFrame = frameNumber;
        for (int i = 0; i < rateHz; ++i) {
            idealRtpTicks += 90000.0L /
                static_cast<long double>(rateHz);
            const uint64_t captureTick = static_cast<uint64_t>(
                std::llround(idealRtpTicks / 750.0L));
            timestamp = static_cast<uint32_t>(captureTick * 750ULL);
            ++frameNumber;
            const uint64_t decodedUs = decodedTimeForRtp(epochUs, timestamp);
            const VrrTimingDecision decision = controller.schedule(
                frame(frameNumber, timestamp, true, decodedUs), decodedUs);
            rebased = rebased || decision.rebased;
        }

        const uint32_t elapsedTicks = timestamp - startTimestamp;
        const int elapsedFrames = frameNumber - startFrame;
        const double measuredRateHz = elapsedTicks == 0 ? 0.0 :
            static_cast<double>(elapsedFrames) * 90000.0 /
                static_cast<double>(elapsedTicks);
        const double learnedRateHz = 1000000.0 /
            static_cast<double>(controller.sourcePeriodUs());
        maximumRateErrorHz = std::max(
            maximumRateErrorHz,
            std::abs(learnedRateHz - measuredRateHz));
    };

    for (int rateHz = 116; rateHz >= 30; --rateHz) {
        runRate(rateHz);
    }
    for (int rateHz = 31; rateHz <= 116; ++rateHz) {
        runRate(rateHz);
    }

    if (maximumRateErrorHz >= 2.0) {
        std::fprintf(stderr, "sweep maximum rate error: %.3f Hz\n",
                     maximumRateErrorHz);
    }
    expect(!rebased,
           "a continuous cadence sweep must not reset the source epoch");
    expect(maximumRateErrorHz < 2.0,
           "a one FPS-per-second sweep must remain within two FPS of measured cadence");
}

void testQuantizedCadenceProjectsSmoothTargets()
{
    constexpr uint64_t epochUs = 1000000;
    constexpr uint64_t expectedPeriodUs = 10000;
    VrrTimingController controller(config(116, 120));
    VrrTimingDecision decision = controller.schedule(
        frame(0, 0, true, epochUs), epochUs);
    controller.noteSubmission(true, false, decision.targetUs);

    uint64_t previousTargetUs = decision.targetUs;
    unsigned int measuredSpacings = 0;
    unsigned int largeErrors = 0;
    for (int i = 1; i <= 300; ++i) {
        const uint32_t timestamp = quantizedRtpTimestamp(i, 100);
        const uint64_t decodedUs = decodedTimeForRtp(epochUs, timestamp);
        decision = controller.schedule(
            frame(i, timestamp, true, decodedUs), decodedUs);
        controller.noteSubmission(true, false, decision.targetUs);

        if (i > 180) {
            const uint64_t spacingUs = decision.targetUs - previousTargetUs;
            const uint64_t errorUs = spacingUs > expectedPeriodUs ?
                spacingUs - expectedPeriodUs : expectedPeriodUs - spacingUs;
            ++measuredSpacings;
            if (errorUs > 500) {
                ++largeErrors;
            }
        }
        previousTargetUs = decision.targetUs;
    }

    if (largeErrors * 20 > measuredSpacings) {
        std::fprintf(stderr,
                     "quantized target errors: %u/%u, readiness=%lld us, budget=%llu us\n",
                     largeErrors, measuredSpacings,
                     static_cast<long long>(controller.readinessBudgetUs()),
                     static_cast<unsigned long long>(controller.timingBudgetUs()));
    }
    expect(largeErrors * 20 <= measuredSpacings,
           "a learned quantized cadence must project at least 95 percent of targets within 500 us");
}

void testSkippedLocalFramePreservesCadence()
{
    constexpr uint64_t epochUs = 1000000;
    VrrTimingController controller(config(100, 120));
    VrrTimingDecision decision = controller.schedule(
        frame(0, 0, true, epochUs), epochUs);

    for (int i = 1; i <= 180; ++i) {
        const uint32_t timestamp = quantizedRtpTimestamp(i, 100);
        const uint64_t decodedUs = decodedTimeForRtp(epochUs, timestamp);
        decision = controller.schedule(
            frame(i, timestamp, true, decodedUs), decodedUs);
    }
    const uint64_t stablePeriodUs = controller.sourcePeriodUs();

    const int successor = 183;
    const uint32_t timestamp = quantizedRtpTimestamp(successor, 100);
    const uint64_t decodedUs = decodedTimeForRtp(epochUs, timestamp);
    decision = controller.schedule(
        frame(successor, timestamp, true, decodedUs), decodedUs);

    expect(!decision.rebased && decision.cadenceEligible &&
               std::abs(static_cast<int64_t>(controller.sourcePeriodUs()) -
                        static_cast<int64_t>(stablePeriodUs)) < 100,
           "a latest-frame queue replacement must advance by frame delta without resetting cadence");
}

void testSchedulerDelayFeedback()
{
    VrrTimingController controller(config());
    VrrTimingDecision first = controller.schedule(
        frame(1, 0, true, 100000), 100000);
    controller.noteSchedulerDelays(600, 300, true);
    controller.noteSubmission(true, false, first.targetUs);

    VrrTimingDecision second = controller.schedule(
        frame(2, 1500, true, 116666), 116666);
    expect(second.renderWakeLeadUs == 600 &&
               second.targetWakeLeadUs == 300 &&
               second.renderStartUs + second.renderLeadUs +
                   second.renderWakeLeadUs == second.targetUs,
           "render and final-target wake delays must learn independently");

    for (int i = 0; i < 40; ++i) {
        controller.noteSchedulerDelays(0, 0, false);
    }
    expect(controller.targetWakeLeadUs() == 300,
           "frames without a coarse target sleep must retain learned delay");
}

void testTargetWaiterBoundaries()
{
    uint64_t nowUs = 0;
    uint64_t requestedCoarseSleepUs = 0;
    VrrTargetWaiterHooks hooks;
    hooks.nowUs = [&nowUs]() { return nowUs; };
    hooks.sleepForUs = [&nowUs, &requestedCoarseSleepUs](uint64_t durationUs) {
        requestedCoarseSleepUs += durationUs;
        nowUs += durationUs;
    };
    hooks.yield = [&nowUs]() { nowUs += 25; };
    VrrTargetWaiter waiter(hooks);

    VrrTargetWaitResult result = waiter.waitUntil(1000);
    expect(requestedCoarseSleepUs == 500 && result.finalNowUs >= 1000,
           "waiter must sleep to the active-wait boundary");

    nowUs = 0;
    requestedCoarseSleepUs = 0;
    result = waiter.waitUntil(1000, 400);
    expect(requestedCoarseSleepUs == 100 && result.finalNowUs >= 1000,
           "learned scheduler delay must wake the final wait earlier");

    uint64_t delayedNowUs = 0;
    VrrTargetWaiterHooks delayedHooks;
    delayedHooks.nowUs = [&delayedNowUs]() { return delayedNowUs; };
    delayedHooks.sleepForUs = [&delayedNowUs](uint64_t durationUs) {
        delayedNowUs += durationUs + 900;
    };
    delayedHooks.yield = [&delayedNowUs]() { delayedNowUs += 25; };
    VrrTargetWaiter delayedWaiter(delayedHooks);
    result = delayedWaiter.waitUntil(5000);
    expect(result.schedulerDelayValid && result.schedulerDelayUs == 400 &&
               result.finalNowUs == 5400,
           "coarse wake feedback must measure overshoot beyond the active margin");

    delayedNowUs = 0;
    result = delayedWaiter.waitUntil(5000, 400);
    expect(result.schedulerDelayValid && result.schedulerDelayUs == 400 &&
               result.finalNowUs == 5000,
           "learned wake delay must correct final-target overshoot");

    nowUs = 100;
    result = waiter.waitUntil(100);
    expect(result.deadlineAlreadyElapsed && result.finalNowUs == 100,
           "an elapsed deadline must return without waiting");

    unsigned int stalledSleepCalls = 0;
    unsigned int stalledYieldCalls = 0;
    VrrTargetWaiterHooks stalledHooks;
    stalledHooks.nowUs = []() { return 0ULL; };
    stalledHooks.sleepForUs = [&stalledSleepCalls](uint64_t) {
        ++stalledSleepCalls;
    };
    stalledHooks.yield = [&stalledYieldCalls]() { ++stalledYieldCalls; };
    VrrTargetWaiter stalled(stalledHooks);
    result = stalled.waitUntil(1000);
    expect(result.finalNowUs == 0 && stalledSleepCalls == 2 &&
               stalledYieldCalls == 64,
           "a non-advancing clock must not create unbounded active spinning");
}

} // namespace

int main()
{
    testRtpWrapResetAndFallback();
    testZeroTimestampIsValidAndAbsentTimestampFallsBack();
    testTimingFormulaeAndReserveCap();
    testLongRunNearRefreshRtpCadence();
    testQuantizedCadenceDoesNotOscillate();
    testNegotiatedRateCeiling();
    testSpacingGuardFeedback();
    testNearRefreshRequestsLatchedPresentation();
    testLatchedPresentationRecoversAfterGuardDecay();
    testDisplayScaledLatchedPresentationBoundary();
    testHeadroomAwareReadinessReserve();
    testNearCeilingBufferFitsOneSourceInterval();
    testRenderLeadGrowthIsStable();
    testHighRateRenderLeadLeavesPresentationSafety();
    testColdStartBudgetIsReasonable();
    testLateArrivalPhaseKeepsBudgetInsideSourceInterval();
    testCadenceGapAndRateChange();
    testFutureSourceProjectionReseedsPhase();
    testDecodeTailAdaptation();
    testRateChangeReseedsReadinessBudget();
    testFractionalQuantizedCadenceLearning();
    testCutsceneRecoveryAndHitchIsolation();
    testModerateSlowdownSelfHealsPhase();
    testContinuousCadenceSweep();
    testQuantizedCadenceProjectsSmoothTargets();
    testSkippedLocalFramePreservesCadence();
    testSchedulerDelayFeedback();
    testTargetWaiterBoundaries();
    return failures == 0 ? 0 : 1;
}
