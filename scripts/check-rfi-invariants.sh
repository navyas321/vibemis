#!/usr/bin/env bash
# BL-2408 RFI-enabled-by-default regression guard.
# RCA: vibemis-agent-meta docs/engineering/claude_vrr_rca.md (+ addendum).
# The Artemis-derived base shipped the 2019-era VAAPI RFI latency workaround as
# OPT-OUT, silently zeroing getDecoderCapabilities() on every AMD/Gallium device.
# That pins the host encoder to maxNumReferenceFrames=1 at SDP negotiation and
# forces full-IDR loss recovery — the "huge stutters" on the Legion Go S.
# Upstream retired the workaround (moonlight-qt d3c23b55, opt-in via
# HAS_RFI_LATENCY_BUG=1); this script fails CI if the opt-out form ever comes
# back (e.g. via an Artemis/Apollo merge). Run from the repo root.
set -u
fail=0
err() { echo "RFI-INVARIANT FAIL: $1" >&2; fail=1; }

VAAPI="app/streaming/video/ffmpeg-renderers/vaapi.cpp"

# 1. The workaround must be OPT-IN (upstream d3c23b55 form).
grep -qF 'qgetenv("HAS_RFI_LATENCY_BUG") == "1"' "$VAAPI" \
  || err "vaapi.cpp: RFI latency workaround is no longer opt-in (HAS_RFI_LATENCY_BUG)"

# 2. The old OPT-OUT form must not reappear anywhere in app code.
if grep -rn --include='*.cpp' --include='*.h' 'IGNORE_RFI_LATENCY_BUG' app/ >/dev/null 2>&1; then
  err "app/: opt-out IGNORE_RFI_LATENCY_BUG form reappeared (pre-d3c23b55 default)"
fi

# 3. RFI capabilities are still advertised when the workaround is off.
grep -qF 'CAPABILITY_REFERENCE_FRAME_INVALIDATION_HEVC' "$VAAPI" \
  || err "vaapi.cpp: HEVC RFI capability advertisement removed"

# 4. Packaging must not re-disable via the retired env var (was in the Flatpak
#    manifest). Match assignments only, so prose mentions of the name are fine.
if grep -rn 'IGNORE_RFI_LATENCY_BUG=' packaging/ .github/workflows/ >/dev/null 2>&1; then
  err "packaging/workflows: retired IGNORE_RFI_LATENCY_BUG env var still set"
fi

# 5. BL-2419: packaging must not OPT IN to the workaround either. The opt-in
#    form (HAS_RFI_LATENCY_BUG=1) disables RFI just as effectively as the old
#    opt-out did -- it is meant to be a user's deliberate choice on affected
#    hardware, never something the AppImage/Flatpak exports for everyone. The
#    on-device confirmation (BL-2419: 87 invalidate-requests, 75 RFI waits,
#    "RFI: on") had to be verified BY HAND because nothing checked this; a
#    point-in-time report is not a regression guard, so here it is.
#    Assignments only, and only OUTSIDE comments: the `^[^#]*` prefix means a
#    line whose assignment is preceded by a `#` cannot match, so documenting
#    the flag (as dev-build.yml's AppRun hook now does) is fine while an actual
#    export is not.
if grep -rnE '^[^#]*(export[[:space:]]+)?HAS_RFI_LATENCY_BUG=' packaging/ .github/workflows/ >/dev/null 2>&1; then
  err "packaging/workflows: HAS_RFI_LATENCY_BUG is exported (silently disables RFI for every user)"
fi

if [ "$fail" -ne 0 ]; then
  echo "One or more BL-2408 RFI invariants failed." >&2
  echo "See vibemis-agent-meta docs/engineering/claude_vrr_rca.md before changing anything." >&2
  exit 1
fi
echo "All BL-2408 RFI invariants hold."
