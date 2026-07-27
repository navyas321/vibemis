#pragma once

#include <stdio.h>
#include <string.h>

// Vibemis (BL-2417): pure formatting for the performance overlay's
// decoder-capability line.
//
// Why this exists: BL-2408 (reference frame invalidation silently disabled on
// every AMD/Gallium device, pinning the host encoder to one reference frame and
// forcing full-IDR loss recovery) went unnoticed for months because nothing in
// the app ever surfaced what the decoder had actually negotiated. This line
// puts the three facts that would have exposed it -- the active decoder, the
// driver vendor, and the FINAL RFI state -- into the first screenshot a user
// posts.
//
// Deliberately free of Qt/SDL/FFmpeg includes so tests/overlay can build it
// with bare qmake + testlib (same constraint as overlayplacement.h).

namespace DecoderStatus {

// Final, negotiated RFI state.
//
// "Unknown" is a real answer, not a placeholder: RFI is the AND of a server
// capability (parsed from the SDP during the RTSP handshake) and a client
// decoder capability, so before that handshake completes there is genuinely no
// negotiated value. Printing "off" then would be a guess, and the entire point
// of this line is that it must not guess -- a line that lies about RFI is worse
// than no line, because BL-2408 is exactly the case where the plausible guess
// was wrong for months.
enum RfiState {
    RfiUnknown = -1,
    RfiOff = 0,
    RfiOn = 1,
};

// Field width caps. The debug overlay renders into a fixed 1536-byte buffer
// (overlaymanager.h) that already carries six VRR lines; see the BL-2417 notes
// there for the measured budget. Mesa in particular reports driver strings like
//   "Mesa Gallium driver 24.2.8 for AMD Radeon Graphics (radeonsi, gfx1103_r1,
//    LLVM 18.1.8, DRM 3.57, 6.11.11)"
// -- over 100 characters, which would consume the remaining headroom on its
// own. Truncate deterministically rather than letting the line grow unbounded.
// 44 characters still reaches the "Gallium" token, which is the substring the
// BL-2408 workaround keys on and therefore the one a triager needs to see.
//
// BL-2529: the buffer was never the binding constraint -- SCREEN WIDTH is. On
// a handheld the single combined line ran off the right edge of the display
// and the RFI verdict at its end, the whole reason the line exists, was
// unreadable in the user's photo. The driver string is what pushed it there
// (a real Mesa value alone spends ~60 of the ~105 typical characters), and it
// is also the field a reader scans separately from the decoder identity. So it
// moved to its own line and the hwaccel cap dropped to 16 -- every real
// hwaccel type name ("videotoolbox" at 12 is the longest) fits well inside it.
// The renderer cap stays at 44 to hold "VideoToolbox (AVSampleBufferDisplayLayer)"
// (40) intact.
const int MaxDecoderChars = 24;
const int MaxHwTypeChars = 16;
const int MaxRendererChars = 44;
const int MaxVendorChars = 44;

// BL-2529: caps for the pacing line. The pacing names come from
// Pacer::pacingModeName() ("vrr-worker", "vrr-unpaced", "vsync", "none") and
// the present mode from IFFmpegRenderer::getPresentationModeName() ("Immediate",
// "Mailbox", "FIFO", "FIFO Relaxed").
const int MaxPacingModeChars = 12;
const int MaxPresentModeChars = 16;

inline const char* rfiStateText(int rfiState)
{
    switch (rfiState) {
    case RfiOn:
        return "on";
    case RfiOff:
        return "off";
    default:
        return "unknown";
    }
}

// Render
//   "Decoder: <name>[ (<hwType>)] via <renderer>; RFI: <state>\n"
//   "Driver: <vendor>\n"                       (omitted when vendor is unknown)
// into 'output'. Returns what snprintf() would: the length that WOULD have been
// written, so callers detect truncation exactly the way the rest of
// stringifyVideoStats() does (ret < 0 || ret >= remaining).
//
// Two lines from one call, deliberately: the call site keeps the single
// offset-chaining block it already had, and the two halves cannot drift apart
// or get separated by a later insertion.
//
// Any argument may be null. A null/empty decoder or renderer name degrades to
// "unknown"; a null/empty vendor drops the Driver line entirely rather than
// inventing one. An over-long vendor is truncated with a trailing "..." so a
// reader can tell the value continues instead of mistaking the prefix for the
// whole string.
inline int formatLine(char* output, int length,
                      const char* decoderName,
                      const char* hwType,
                      const char* rendererName,
                      const char* vendor,
                      int rfiState)
{
    char hwPart[MaxHwTypeChars + 8];
    if (hwType != nullptr && hwType[0] != '\0') {
        snprintf(hwPart, sizeof(hwPart), " (%.*s)", MaxHwTypeChars, hwType);
    }
    else {
        hwPart[0] = '\0';
    }

    char vendorLine[MaxVendorChars + 20];
    if (vendor != nullptr && vendor[0] != '\0') {
        if (strlen(vendor) > (size_t)MaxVendorChars) {
            snprintf(vendorLine, sizeof(vendorLine), "Driver: %.*s...\n",
                     MaxVendorChars, vendor);
        }
        else {
            snprintf(vendorLine, sizeof(vendorLine), "Driver: %s\n", vendor);
        }
    }
    else {
        vendorLine[0] = '\0';
    }

    return snprintf(output, length,
                    "Decoder: %.*s%s via %.*s; RFI: %s\n%s",
                    MaxDecoderChars,
                    (decoderName != nullptr && decoderName[0] != '\0') ? decoderName : "unknown",
                    hwPart,
                    MaxRendererChars,
                    (rendererName != nullptr && rendererName[0] != '\0') ? rendererName : "unknown",
                    rfiStateText(rfiState),
                    vendorLine);
}

// BL-2529: render
//   "Pacing: <mode>; present: <presentMode>\n"
// into 'output', with the same snprintf() return contract as formatLine().
//
// Why this line exists: "is the VRR pacing worker actually running, and did the
// swapchain actually get an adaptive present mode?" was unanswerable from the
// app. Both facts are decided once at decoder creation and then never
// restated, so a session that silently fell back to fixed pacing looked
// identical on screen to one that did not -- which is how the frame-pacing
// preference could be inert under VRR without anyone noticing. Pairing them on
// one line is the point: an adaptive present mode with "none" pacing and a
// FIFO swapchain with "vrr-worker" are both meaningful, and neither is legible
// from one value alone.
//
// A null/empty present mode renders "n/a" rather than "unknown": most renderers
// have no such concept, and that is a different statement from a Vulkan
// renderer whose mode could not be identified.
inline int formatPacingLine(char* output, int length,
                            const char* pacingMode,
                            const char* presentMode)
{
    return snprintf(output, length,
                    "Pacing: %.*s; present: %.*s\n",
                    MaxPacingModeChars,
                    (pacingMode != nullptr && pacingMode[0] != '\0') ? pacingMode : "unknown",
                    MaxPresentModeChars,
                    (presentMode != nullptr && presentMode[0] != '\0') ? presentMode : "n/a");
}

// Worst-case rendered length of the FIRST line of formatLine(), excluding the
// NUL. This is the number that has to stay small enough to fit a handheld
// screen; the buffer budget below cares about the total.
//
//   "Decoder: "                                              9
//   decoder name                            MaxDecoderChars 24
//   " (" + hwType + ")"              MaxHwTypeChars + 3     19
//   " via "                                                  5
//   renderer name                          MaxRendererChars 44
//   "; RFI: "                                                7
//   "unknown"                                                7
//   "\n"                                                     1
const int MaxDecoderLineChars = 9 + MaxDecoderChars + (MaxHwTypeChars + 3) +
                                5 + MaxRendererChars + 7 + 7 + 1;

//   "Driver: " + vendor + "..." + "\n"
const int MaxDriverLineChars = 8 + MaxVendorChars + 3 + 1;

//   "Pacing: " + mode + "; present: " + presentMode + "\n"
const int MaxPacingLineChars = 8 + MaxPacingModeChars + 11 +
                                MaxPresentModeChars + 1;

// Worst-case total rendered length of formatLine(), excluding the NUL. Used by
// the tests to pin the overlay buffer budget so a future field widening cannot
// silently eat the remaining headroom.
const int MaxLineChars = MaxDecoderLineChars + MaxDriverLineChars;

}
