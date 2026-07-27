// Vibemis: wrapper-level compatibility/accessor shims for moonlight-common-c.
//
// This translation unit is compiled INTO the moonlight-common-c static library
// (see moonlight-common-c.pro), so it links against the fork's internal symbols
// and may include Limelight-internal.h -- $$COMMON_C_DIR/src is already on the
// INCLUDEPATH. That is what lets the shims below read authoritative connection
// state without patching the submodule.
//
// Limelight-internal.h must come first: it pulls in Platform.h, which sets
// _CRT_NO_POSIX_ERROR_CODES and orders <Windows.h> before <Winsock2.h>. Every
// other .c in the library includes it first for the same reason.
#include "Limelight-internal.h"

// Vibemis (BL-2417): expose the FINAL, negotiated reference-frame-invalidation
// state to the app so the performance overlay can display it.
//
// This must not be re-derived app-side. RFI is the AND of two halves:
//   - the server half, ReferenceFrameInvalidationSupported, parsed from the
//     SDP in RtspConnection.c; and
//   - the client half, isReferenceFrameInvalidationSupportedByDecoder(), which
//     tests VideoCallbacks.capabilities -- the capabilities of the THROWAWAY
//     test decoder built in Session::populateDecoderProperties(), not those of
//     the live renderer the overlay can see.
// The authoritative AND is isReferenceFrameInvalidationEnabled() in Misc.c,
// which is internal and unexported. Asking the live renderer instead would have
// printed "RFI: on" throughout the entire BL-2408 defect this overlay line
// exists to expose, because the renderer that zeroed the capability was a
// different object from the one on screen. Read the truth or print nothing.
//
// Returns 1 (on), 0 (off), or -1 (not yet negotiated). The -1 case is real: the
// SDP exchange has not happened yet, so there is no answer to give, and
// isReferenceFrameInvalidationSupportedByDecoder() would trip its
// LC_ASSERT(NegotiatedVideoFormat != 0) on debug builds if called that early.
//
// Threading: all three inputs are written once during connection setup, before
// video flows, and are never mutated for the life of the stream. The overlay
// reads them from the decoder/render thread; there is no torn-read hazard for
// word-sized reads of settled values.
int VibemisGetRfiState(void) {
    if (NegotiatedVideoFormat == 0) {
        return -1;
    }

    return isReferenceFrameInvalidationEnabled() ? 1 : 0;
}

// Vibemis (BL-2212): LiGetMicroseconds() compatibility implementation.
//
// Mainline moonlight-common-c exports LiGetMicroseconds() as the monotonic
// microsecond pacing clock used by moonlight-qt's VRR pacing code. The
// ClassicOldSong (Apollo-lineage) fork this project pins as a submodule
// predates that export, so — following the same precedent as the rs.c
// Reed-Solomon indirection above in moonlight-common-c.pro — we provide it
// at the wrapper level. The declaration lives in app/streaming/video/decoder.h.
//
// Contract: monotonic, microsecond resolution, only ever compared against
// itself (never mixed with LiGetMillis()/PltGetMillis() values).

#include <stdint.h>

#if defined(_WIN32) || defined(_WIN64)

#define WIN32_LEAN_AND_MEAN
#include <Windows.h>

uint64_t LiGetMicroseconds(void) {
    static LARGE_INTEGER frequency;
    LARGE_INTEGER counter;

    if (frequency.QuadPart == 0) {
        QueryPerformanceFrequency(&frequency);
    }

    QueryPerformanceCounter(&counter);
    return (uint64_t)(counter.QuadPart * 1000000ULL / (uint64_t)frequency.QuadPart);
}

#else

#include <time.h>
#include <sys/time.h>

uint64_t LiGetMicroseconds(void) {
#if defined(CLOCK_MONOTONIC) && !defined(NO_CLOCK_GETTIME)
    struct timespec tv;

    clock_gettime(CLOCK_MONOTONIC, &tv);

    return ((uint64_t)tv.tv_sec * 1000000) + ((uint64_t)tv.tv_nsec / 1000);
#else
    struct timeval tv;

    gettimeofday(&tv, NULL);

    return ((uint64_t)tv.tv_sec * 1000000) + (uint64_t)tv.tv_usec;
#endif
}

#endif
