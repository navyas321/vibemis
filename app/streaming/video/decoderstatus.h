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
// 48 characters still reaches the "Gallium" token, which is the substring the
// BL-2408 workaround keys on and therefore the one a triager needs to see.
const int MaxDecoderChars = 24;
const int MaxHwTypeChars = 24;
const int MaxRendererChars = 44;
const int MaxVendorChars = 48;

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
//   "Decoder: <name>[ (<hwType>)] via <renderer>[; driver: <vendor>]; RFI: <state>\n"
// into 'output'. Returns what snprintf() would: the length that WOULD have been
// written, so callers detect truncation exactly the way the rest of
// stringifyVideoStats() does (ret < 0 || ret >= remaining).
//
// Any argument may be null. A null/empty decoder or renderer name degrades to
// "unknown"; a null/empty vendor drops the "; driver:" clause entirely rather
// than inventing one. An over-long vendor is truncated with a trailing "..." so
// a reader can tell the value continues instead of mistaking the prefix for the
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

    char vendorPart[MaxVendorChars + 20];
    if (vendor != nullptr && vendor[0] != '\0') {
        if (strlen(vendor) > (size_t)MaxVendorChars) {
            snprintf(vendorPart, sizeof(vendorPart), "; driver: %.*s...",
                     MaxVendorChars, vendor);
        }
        else {
            snprintf(vendorPart, sizeof(vendorPart), "; driver: %s", vendor);
        }
    }
    else {
        vendorPart[0] = '\0';
    }

    return snprintf(output, length,
                    "Decoder: %.*s%s via %.*s%s; RFI: %s\n",
                    MaxDecoderChars,
                    (decoderName != nullptr && decoderName[0] != '\0') ? decoderName : "unknown",
                    hwPart,
                    MaxRendererChars,
                    (rendererName != nullptr && rendererName[0] != '\0') ? rendererName : "unknown",
                    vendorPart,
                    rfiStateText(rfiState));
}

// Worst-case rendered length of formatLine(), excluding the NUL. Used by the
// tests to pin the overlay buffer budget so a future field widening cannot
// silently eat the remaining headroom.
//
//   "Decoder: "                                              9
//   decoder name                            MaxDecoderChars 24
//   " (" + hwType + ")"              MaxHwTypeChars + 3     27
//   " via "                                                  5
//   renderer name                          MaxRendererChars 44
//   "; driver: " + vendor + "..."    MaxVendorChars + 13    61
//   "; RFI: "                                                7
//   "unknown"                                                7
//   "\n"                                                     1
const int MaxLineChars = 9 + MaxDecoderChars + (MaxHwTypeChars + 3) + 5 +
                         MaxRendererChars + (MaxVendorChars + 13) + 7 + 7 + 1;

}
