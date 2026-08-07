#!/usr/bin/env bash
# BL-2213 audio no-crackle regression guard.
# RCA + rationale: vibemis-agent-meta docs/engineering/BL-2213-audio-no-crackle-rca.md
# vibemis is the only Moonlight fork WITHOUT audio crackling for a Bazzite/ROG Ally
# user (issue #239). The differentiators are packaging + pin freezes, so they can
# be lost SILENTLY by an upstream merge or the BL-2212 VRR port. This script fails
# CI the moment any guarded invariant changes. Run from the repo root.
# Do NOT weaken a check without an on-device audio A/B (RCA section 4 protocol).
set -u
fail=0
err() { echo "AUDIO-INVARIANT FAIL: $1" >&2; fail=1; }

SDLAUD="app/streaming/audio/renderers/sdlaud.cpp"
AUDIOCPP="app/streaming/audio/audio.cpp"

# 1. SDL device-open buffer request formula (non-Darwin path)
grep -qF 'want.samples = SDL_max(480, opusConfig->samplesPerFrame * 3);' "$SDLAUD" \
  || err "sdlaud.cpp: want.samples formula changed"

# 2. 50 ms SDL queue backpressure budget (upstream 4cf498b0's duration cap).
#    HISTORY (BL-2523): this check used to pin the 10-FRAME cap and named 4cf498b0 as
#    the thing to keep out. That cap was frame-counted, so the real buffer depth tracked
#    the negotiated Opus packet duration -- 50 ms at 5 ms frames, but 100 ms at the 10 ms
#    frames handed to slow decoders and low-bitrate links. The port was taken on maintainer
#    directive (2026-08-06) to make the budget 50 ms in both cases. The BL-2213 no-crackle
#    protection is unchanged in INTENT: what must never regress is a bounded SDL queue, and
#    at the 5 ms frames a normal session negotiates the bound is numerically identical to
#    what shipped before. The on-device A/B is the beta that carries this change; if
#    crackling returns on a Bazzite/ROG Ally (issue #239), revert to the 10-frame form and
#    restore this check with it.
grep -qF 'SDL_GetQueuedAudioSize(m_AudioDevice) / m_FrameSize * m_FrameDurationMs <= 50' "$SDLAUD" \
  || err "sdlaud.cpp: 50 ms backpressure budget changed"

# 2b. The duration the budget divides by must stay the NEGOTIATED packet duration.
#     Hardcoding it (or losing the assignment) silently turns the 50 ms budget into a
#     wrong-by-a-factor-of-two cap without touching the line above.
grep -qF 'm_FrameDurationMs = opusConfig->samplesPerFrame / (opusConfig->sampleRate / 1000);' "$SDLAUD" \
  || err "sdlaud.cpp: frame-duration derivation changed"

# 3. 30 ms pending-audio drop gate
grep -qF 'LiGetPendingAudioDuration() > 30' "$SDLAUD" \
  || err "sdlaud.cpp: 30 ms pending-audio gate changed"

# 4. libsoundio fallback retained (upstream removed it in 41899032)
grep -qF 'TRY_INIT_RENDERER(SoundIoAudioRenderer, opusConfig)' "$AUDIOCPP" \
  || err "audio.cpp: libsoundio fallback removed"

# 5. moonlight-common-c submodule is our ClassicOldSong-derived fork.
#    BL-2336 re-pointed it from ClassicOldSong to navyas321/moonlight-common-c
#    (an ADDITIVE fork: ClassicOldSong@ad329b24 + raw-90kHz-RTP-timestamp
#    thread-through for VRR pacing, touching only Limelight.h / RtpVideoQueue.*
#    / VideoDepacketizer.c — zero audio/FEC files, so the audio runtime is
#    unchanged). The fork MUST stay based on the ClassicOldSong lineage.
grep -qF 'url = https://github.com/navyas321/moonlight-common-c.git' .gitmodules \
  || err ".gitmodules: moonlight-common-c URL changed"

# 6. common-c gitlink pin is explicit. BL-2629 intentionally advances the pin
#    from f0e742ca to the negotiated microphone protocol commits. That change
#    adds the separate microphone stream; it must not alter the existing host
#    playback path (AudioStream.c / RtpAudioQueue.c).
#      $ git -C moonlight-common-c/moonlight-common-c diff --stat bf826ee8 f0e742ca
#       src/Limelight.h         | 18 ++++++++++++++----
#       src/VideoDepacketizer.c | 14 +++++++++++---
#      $ git ... diff bf826ee8 f0e742ca | grep -iE 'audio|opus|AUDIO_|SAMPLE|CHANNEL'
#      (no matches)
#    The old pin remains the comparison base for this guard, while the new pin
#    is the pushed BL-2629 protocol result.
OLD_PIN="f0e742ca69eec93eba286fab62a57eef2006496c"
PIN="ee67c92848ee47b6c71d1cfb444c5854f50d893f"
ACTUAL=$(git ls-tree HEAD moonlight-common-c/moonlight-common-c | awk '{print $3}')
[ "$ACTUAL" = "$PIN" ] \
  || err "moonlight-common-c gitlink moved: ${ACTUAL:-<none>} (expected $PIN)"

if git -C moonlight-common-c/moonlight-common-c diff --name-only "$OLD_PIN" "$PIN" \
    | grep -E '(^|/)(AudioStream|RtpAudioQueue)\.c$' >/dev/null 2>&1; then
  err "common-c: existing host playback audio path changed while adding microphone support"
fi

# 6b. The qmake wrapper owns the static-library source list. A submodule pin can
#     contain the microphone implementation while the final app still fails to
#     link if MicrophoneStream.c is omitted here.
grep -qF '$$COMMON_C_DIR/src/MicrophoneStream.c' moonlight-common-c/moonlight-common-c.pro \
  || err "moonlight-common-c.pro: MicrophoneStream.c is not linked into the client"

# 7. No SDL3/sdl2-compat adoption in CI packaging (upstream e1bbf814 territory).
#    The SDL3+sdl2-compat AppImage runtime prefers the native PipeWire backend,
#    which is the prime crackle suspect on PipeWire handhelds.
if grep -rEl 'sdl2-compat|libsdl-org/SDL' .github/workflows/ >/dev/null 2>&1; then
  err "workflows: SDL3/sdl2-compat build steps detected (do not inherit upstream e1bbf814)"
fi

# 8. AppImage job still provisions the distro SDL2 (real SDL2 runtime, pulse-first)
grep -q 'libsdl2-dev' .github/workflows/dev-build.yml \
  || err "dev-build.yml: libsdl2-dev provisioning missing"

# 9. No SDL audio driver forcing crept into app code
if grep -rn --include='*.cpp' --include='*.h' 'SDL_AUDIODRIVER' app/ >/dev/null 2>&1; then
  err "app/: unexpected SDL_AUDIODRIVER forcing"
fi

if [ "$fail" -ne 0 ]; then
  echo "One or more BL-2213 audio invariants failed." >&2
  echo "See vibemis-agent-meta docs/engineering/BL-2213-audio-no-crackle-rca.md before changing anything." >&2
  exit 1
fi
echo "All BL-2213 audio invariants hold."
