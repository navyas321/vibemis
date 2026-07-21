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
