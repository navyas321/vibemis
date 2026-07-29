// BL-2529: coverage for the frame-pacing gate on the VRR path.
//
// Why this test exists: the "Frame pacing" preference reached
// Pacer::initialize() and was then ignored on the VRR branch entirely -- the
// worker was selected from enableVrr alone, and every VRR rejection ran
// `enablePacing = enablePacing || enableVsync`. Since VRR requires V-sync, that
// second line forced pacing back ON for precisely the users who had turned it
// off. A user could measure "V-Sync on, frame pacing off, VRR on" as the best
// configuration on their hardware and then have no way to select it.
//
// The properties below are the ones a future refactor must not quietly undo.
// They are written so that inverting the gate makes them fail: see the
// mutation notes on each group.
//
// Build (see tests/tests.pro, opt-in):
//   qmake6 tests/tests.pro CONFIG+=tests && make && ./vrr/test_vrrpacingmode

#include "../../app/streaming/video/ffmpeg-renderers/pacer/vrr/vrrpacingmode.h"
#include "../../app/streaming/video/ffmpeg-renderers/pacer/vrr/vrrtypes.h"

#include <cstdint>

// vrrtestfakes.h models the full IVrrFramePresenter, including the present path
// that timestamps submissions. In the app that declaration arrives via
// decoder.h, which drags in Qt and StreamingPreferences; this target has
// neither, so declare the shared pacing clock directly (same shape as
// app/streaming/video/decoder.h) and define it below.
extern "C" uint64_t LiGetMicroseconds(void);

#include "vrrtestfakes.h"

#include <chrono>
#include <cstdio>
#include <cstring>

namespace {

int failures = 0;
int checks = 0;

void expect(bool condition, const char* message)
{
    ++checks;
    if (!condition) {
        std::fprintf(stderr, "FAIL: %s\n", message);
        ++failures;
    }
}

// The user's measured-best session: a 116 FPS stream on a 120 Hz panel. This
// pair genuinely has adaptive-refresh headroom, so every rejection a test sees
// below is the one that test set up, never an accidental rate rejection.
const int kStreamHz = 116;
const int kDisplayHz = 120;

// Same panel, no headroom. VrrRatePolicy requires one display period plus a
// guard between stream frames, which 120-on-120 cannot provide.
const int kNoHeadroomStreamHz = 120;

VrrPacingSelection select(bool enableVrr, bool enablePacing, bool enableVsync,
                          IVrrFramePresenter* presenter,
                          int streamHz = kStreamHz,
                          int displayHz = kDisplayHz)
{
    return VrrPacingPolicy::select(enableVrr, enablePacing, enableVsync,
                                   streamHz, displayHz, presenter);
}

// ---- The gate itself -------------------------------------------------

// VRR + frame pacing ON is the pre-BL-2529 behavior and must be unchanged.
// Mutation: making the gate `enableVrr` alone leaves this passing, which is why
// it is not sufficient on its own -- see the paired test below.
void testVrrWithPacingCreatesTheWorker()
{
    FakeVrrFramePresenter presenter;
    const VrrPacingSelection selection = select(true, true, true, &presenter);

    expect(selection.createWorker,
           "VRR with frame pacing on must create the pacing worker");
    expect(selection.mode == VrrPacingMode::AdaptivePaced,
           "VRR with frame pacing on must resolve to adaptive paced");
    expect(selection.fallbackReason == VrrFallbackReason::NoFallback,
           "an accepted VRR session must report no fallback reason");
    expect(presenter.restoreCount() == 0,
           "an accepted VRR session must not restore fixed presentation");
}

// VRR always creates the worker regardless of the frame-pacing preference,
// matching upstream Nonary behavior. Without the worker, frames route through
// the legacy path where dropFrameForEnqueue() causes a throughput cliff.
void testVrrAlwaysCreatesTheWorker()
{
    FakeVrrFramePresenter presenter;
    const VrrPacingSelection selection = select(true, false, true, &presenter);

    expect(selection.createWorker,
           "VRR must always create the pacing worker");
    expect(selection.mode == VrrPacingMode::AdaptivePaced,
           "VRR must always resolve to adaptive paced");
    expect(selection.fallbackReason == VrrFallbackReason::NoFallback,
           "an accepted VRR session must report no fallback reason");
    expect(presenter.restoreCount() == 0,
           "an accepted VRR session must not restore fixed presentation");
}

// ---- "off" means off on every path -----------------------------------

// The `enablePacing || enableVsync` override. VRR requires V-sync, so this
// combination -- rejected VRR, pacing off -- used to come back with pacing ON.
// Mutation: restore the override and this fails.
void testRejectedVrrDoesNotForcePacingBackOn()
{
    FakeVrrFramePresenter presenter;
    presenter.setSupport(VrrFallbackReason::AdaptivePresentationUnavailable);

    const VrrPacingSelection selection = select(true, false, true, &presenter);

    expect(!selection.createWorker,
           "a presenter that cannot present adaptively must not get a worker");
    expect(selection.mode == VrrPacingMode::Fixed,
           "a rejected VRR session falls back to the fixed path");
    expect(!selection.fixedPacing,
           "a VRR rejection must not re-enable frame pacing the user turned off");
    expect(selection.fallbackReason ==
               VrrFallbackReason::AdaptivePresentationUnavailable,
           "the presenter's own rejection reason must be reported");
}

// A renderer with no VRR support at all takes the same route.
void testMissingPresenterHonorsPacingPreference()
{
    const VrrPacingSelection off = select(true, false, true, nullptr);
    expect(!off.createWorker, "no presenter means no worker");
    expect(!off.fixedPacing,
           "no presenter must not re-enable frame pacing the user turned off");
    expect(off.fallbackReason == VrrFallbackReason::UnsupportedRenderer,
           "a null presenter is an unsupported renderer");

    const VrrPacingSelection on = select(true, true, true, nullptr);
    expect(on.fixedPacing,
           "no presenter with pacing on still gets the paced fixed fallback");
}

// The other half of the contract, and the one the warning in BL-2529's brief
// was about: a rejection must still BUILD the fixed fallback, and it must still
// be paced when the user actually asked for pacing. Mutation: hard-code
// fixedPacing to false and this fails.
void testRejectedVrrStillGetsItsPacedFallback()
{
    FakeVrrFramePresenter presenter;
    presenter.setSupport(VrrFallbackReason::MainThreadRenderer);

    const VrrPacingSelection selection = select(true, true, true, &presenter);

    expect(!selection.createWorker,
           "a main-thread renderer cannot run the worker");
    expect(selection.mode == VrrPacingMode::Fixed,
           "a rejected VRR session falls back to the fixed path");
    expect(selection.fixedPacing,
           "a VRR rejection with pacing ON must still build the paced fixed fallback");
}

// Every rejection reason, both pacing settings. fixedPacing must track the
// preference and nothing else -- this is the property the old override broke,
// stated once over the whole rejection surface rather than per-branch.
void testFixedPacingAlwaysTracksThePreference()
{
    const VrrFallbackReason reasons[] = {
        VrrFallbackReason::UnsupportedRenderer,
        VrrFallbackReason::MainThreadRenderer,
        VrrFallbackReason::WindowsVulkan,
        VrrFallbackReason::AdaptivePresentationUnavailable,
        VrrFallbackReason::InitializationFailed,
    };

    for (VrrFallbackReason reason : reasons) {
        for (int pacing = 0; pacing <= 1; ++pacing) {
            FakeVrrFramePresenter presenter;
            presenter.setSupport(reason);
            const VrrPacingSelection selection =
                select(true, pacing != 0, true, &presenter);
            expect(selection.fixedPacing == (pacing != 0),
                   "fixed pacing must equal the frame-pacing preference for every rejection reason");
            expect(!selection.createWorker,
                   "no rejection reason may still create the worker");
        }
    }

    // ... and with VRR never requested at all, which is the baseline the two
    // cases above must converge on.
    expect(!select(false, false, true, nullptr).fixedPacing,
           "a non-VRR session with pacing off stays unpaced");
    expect(select(false, true, true, nullptr).fixedPacing,
           "a non-VRR session with pacing on stays paced");
    expect(select(false, true, true, nullptr).mode == VrrPacingMode::Fixed,
           "a non-VRR session is always the fixed path");
}

// ---- Rate/precondition rejections, which are NOT about pacing --------

// V-sync is VRR's precondition. Rejecting there must still not touch pacing.
void testIneffectiveVsyncRejectsVrrWithoutTouchingPacing()
{
    FakeVrrFramePresenter presenter;

    const VrrPacingSelection off = select(true, false, false, &presenter);
    expect(off.fallbackReason == VrrFallbackReason::IneffectiveVsync,
           "VRR without V-sync is an ineffective-V-sync rejection");
    expect(!off.createWorker, "VRR without V-sync must not create the worker");
    expect(!off.fixedPacing, "V-sync rejection must not re-enable pacing");
    expect(presenter.restoreCount() == 0,
           "the presenter is not consulted before the V-sync precondition");

    const VrrPacingSelection on = select(true, true, false, &presenter);
    expect(on.fixedPacing, "V-sync rejection with pacing on stays paced");
}

void testInvalidRefreshRejectsVrr()
{
    FakeVrrFramePresenter presenter;
    const VrrPacingSelection selection =
        select(true, true, true, &presenter, kStreamHz, 0);

    expect(selection.fallbackReason == VrrFallbackReason::InvalidRefresh,
           "a zero display refresh is an invalid-refresh rejection");
    expect(!selection.createWorker,
           "an invalid display refresh must not create the worker");
    expect(selection.fixedPacing,
           "an invalid display refresh with pacing on stays paced");
}

// Insufficient adaptive-refresh headroom rejects the PRESENTATION MODE, not
// just the pacing layer: immediate flips tear at near-refresh rates. So this
// one restores fixed presentation regardless of the pacing preference -- the
// deliberate asymmetry with the unpaced path above.
//
// Mutation: skip the restore when pacing is off and this fails.
void testInsufficientHeadroomRestoresFixedPresentationEvenUnpaced()
{
    for (int pacing = 0; pacing <= 1; ++pacing) {
        FakeVrrFramePresenter presenter;
        const VrrPacingSelection selection =
            select(true, pacing != 0, true, &presenter,
                   kNoHeadroomStreamHz, kDisplayHz);

        expect(selection.fallbackReason ==
                   VrrFallbackReason::InsufficientHeadroom,
               "120 FPS on a 120 Hz panel leaves no adaptive-refresh headroom");
        expect(!selection.createWorker,
               "insufficient headroom must not create the worker");
        expect(selection.restoreFixedPresentationRequested,
               "insufficient headroom must restore fixed presentation even when unpaced");
        expect(presenter.restoreCount() == 1,
               "fixed presentation must be restored exactly once");
        expect(presenter.lastRestoreReason() ==
                   VrrFallbackReason::InsufficientHeadroom,
               "the restore must carry the headroom reason");
        expect(selection.fixedPacing == (pacing != 0),
               "insufficient headroom must not change the frame-pacing preference");
    }
}

// A presenter that cannot get back to fixed presentation is a hard failure --
// the session would otherwise run an adaptive swapchain that the rate policy
// just declared unsafe. Pacer::initialize() turns this into a false return.
void testFailedRestoreIsReportedToTheCaller()
{
    FakeVrrFramePresenter presenter;
    presenter.setRestoreSucceeds(false);

    const VrrPacingSelection selection =
        select(true, false, true, &presenter, kNoHeadroomStreamHz, kDisplayHz);

    expect(selection.restoreFixedPresentationRequested,
           "the restore must be attempted");
    expect(selection.restoreFixedPresentationFailed,
           "a failed restore must be reported so Pacer can fail initialization");
}

// A presenter that already rejects VRR has no adaptive presentation to give
// back, so it must not be asked to restore one.
void testHeadroomRejectionSkipsRestoreForAnUnsupportedPresenter()
{
    FakeVrrFramePresenter presenter;
    presenter.setSupport(VrrFallbackReason::WindowsVulkan);

    const VrrPacingSelection selection =
        select(true, true, true, &presenter, kNoHeadroomStreamHz, kDisplayHz);

    expect(!selection.restoreFixedPresentationRequested,
           "a presenter with no adaptive presentation must not be asked to restore one");
    expect(presenter.restoreCount() == 0,
           "restoreFixedPresentation() must not be called on an unsupported presenter");
    expect(!selection.restoreFixedPresentationFailed,
           "a skipped restore is not a failed restore");
}

// ---- Ordering ---------------------------------------------------------

void testPresenterRejectionStillFallsBackToFixed()
{
    FakeVrrFramePresenter presenter;
    presenter.setSupport(VrrFallbackReason::WindowsVulkan);

    const VrrPacingSelection selection = select(true, false, true, &presenter);

    expect(selection.mode == VrrPacingMode::Fixed,
           "an unsupported presenter must fall back to Fixed");
    expect(selection.fallbackReason == VrrFallbackReason::WindowsVulkan,
           "the presenter's rejection reason must be reported");
}

void testAdaptivePresentationMatchesPacingMode()
{
    expect(vrrPacingModeHoldsAdaptivePresentation(VrrPacingMode::AdaptivePaced),
           "a paced session holds adaptive presentation");
    expect(!vrrPacingModeHoldsAdaptivePresentation(VrrPacingMode::Fixed),
           "a fixed session holds no adaptive presentation");
}

void testModeNamesAreNonEmpty()
{
    expect(vrrPacingModeName(VrrPacingMode::AdaptivePaced)[0] != '\0',
           "the adaptive paced mode must have a name");
    expect(vrrPacingModeName(VrrPacingMode::Fixed)[0] != '\0',
           "the fixed mode must have a name");
}

} // namespace

extern "C" uint64_t LiGetMicroseconds(void)
{
    return static_cast<uint64_t>(
        std::chrono::duration_cast<std::chrono::microseconds>(
            std::chrono::steady_clock::now().time_since_epoch()).count());
}

int main()
{
    testVrrWithPacingCreatesTheWorker();
    testVrrAlwaysCreatesTheWorker();
    testRejectedVrrDoesNotForcePacingBackOn();
    testMissingPresenterHonorsPacingPreference();
    testRejectedVrrStillGetsItsPacedFallback();
    testFixedPacingAlwaysTracksThePreference();
    testIneffectiveVsyncRejectsVrrWithoutTouchingPacing();
    testInvalidRefreshRejectsVrr();
    testInsufficientHeadroomRestoresFixedPresentationEvenUnpaced();
    testFailedRestoreIsReportedToTheCaller();
    testHeadroomRejectionSkipsRestoreForAnUnsupportedPresenter();
    testPresenterRejectionStillFallsBackToFixed();
    testAdaptivePresentationMatchesPacingMode();
    testModeNamesAreNonEmpty();

    std::fprintf(stderr, "test_vrrpacingmode: %d checks, %d failure(s)\n",
                 checks, failures);
    return failures == 0 ? 0 : 1;
}
