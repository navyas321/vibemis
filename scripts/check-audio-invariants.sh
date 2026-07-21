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

# 2. 10-frame SDL queue backpressure (NOT upstream 4cf498b0's 50 ms duration cap)
grep -qF 'SDL_GetQueuedAudioSize(m_AudioDevice) / m_FrameSize <= 10' "$SDLAUD" \
  || err "sdlaud.cpp: 10-frame backpressure cap changed"

# 3. 30 ms pending-audio drop gate
grep -qF 'LiGetPendingAudioDuration() > 30' "$SDLAUD" \
  || err "sdlaud.cpp: 30 ms pending-audio gate changed"

# 4. libsoundio fallback retained (upstream removed it in 41899032)
grep -qF 'TRY_INIT_RENDERER(SoundIoAudioRenderer, opusConfig)' "$AUDIOCPP" \
  || err "audio.cpp: libsoundio fallback removed"

# 5. moonlight-common-c submodule still the ClassicOldSong fork
grep -qF 'url = https://github.com/ClassicOldSong/moonlight-common-c.git' .gitmodules \
  || err ".gitmodules: moonlight-common-c URL changed"

# 6. common-c gitlink pin frozen (classic reedsolomon audio FEC, pre-nanors de364b6).
#    An intentional bump MUST update this hash in the same PR and cite an
#    on-device audio A/B in the commit message.
PIN="ad329b240f18826f320ce6a99226b36354b86b59"
ACTUAL=$(git ls-tree HEAD moonlight-common-c/moonlight-common-c | awk '{print $3}')
[ "$ACTUAL" = "$PIN" ] \
  || err "moonlight-common-c gitlink moved: ${ACTUAL:-<none>} (expected $PIN)"

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
