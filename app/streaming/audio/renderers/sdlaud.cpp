#include "sdl.h"

#include <Limelight.h>

SdlAudioRenderer::SdlAudioRenderer()
    : m_AudioDevice(0),
      m_AudioBuffer(nullptr),
      m_FrameSize(0),
      m_FrameDurationMs(0)
{
    // Upstream asserted sole ownership of SDL_INIT_AUDIO here, but
    // UiSoundManager may hold a transient refcounted reference (UI nav sounds,
    // incl. the Quick Menu mid-stream). SDL_InitSubSystem/SDL_QuitSubSystem
    // refcounting keeps both owners correct, so the assert had to go.

    if (SDL_InitSubSystem(SDL_INIT_AUDIO) != 0) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "SDL_InitSubSystem(SDL_INIT_AUDIO) failed: %s",
                     SDL_GetError());
        SDL_assert(SDL_WasInit(SDL_INIT_AUDIO));
    }
}

bool SdlAudioRenderer::prepareForPlayback(const OPUS_MULTISTREAM_CONFIGURATION* opusConfig)
{
    SDL_AudioSpec want, have;

    SDL_zero(want);
    want.freq = opusConfig->sampleRate;
    want.format = AUDIO_F32SYS;
    want.channels = opusConfig->channelCount;

    // On PulseAudio systems, setting a value too small can cause underruns for other
    // applications sharing this output device. We impose a floor of 480 samples (10 ms)
    // to mitigate this issue. Otherwise, we will buffer up to 3 frames of audio which
    // is 15 ms at regular 5 ms frames and 30 ms at 10 ms frames for slow connections.
    // The buffering helps avoid audio underruns due to network jitter.
#ifndef Q_OS_DARWIN
    want.samples = SDL_max(480, opusConfig->samplesPerFrame * 3);
#else
    // HACK: Changing the buffer size can lead to Bluetooth HFP
    // audio issues on macOS, so we're leaving this alone.
    // https://github.com/moonlight-stream/moonlight-qt/issues/1071
    want.samples = SDL_max(480, opusConfig->samplesPerFrame);
#endif

    m_FrameSize = opusConfig->samplesPerFrame *
                  opusConfig->channelCount *
                  getAudioBufferSampleSize();

    // Duration of one Opus frame in ms, so the queue backpressure below can budget
    // in TIME rather than in frames. samplesPerFrame is 48 * AudioPacketDuration and
    // sampleRate is always 48000 (moonlight-common-c AudioStream.c / RtspConnection.c),
    // so this is exactly the negotiated packet duration: 5 ms normally, 10 ms on slow
    // decoders and low-bitrate links. No div-by-zero: sampleRate is hardcoded 48000
    // here and in audio.cpp, and the identical unguarded expression already ships in
    // soundioaudiorenderer.cpp.
    m_FrameDurationMs = opusConfig->samplesPerFrame / (opusConfig->sampleRate / 1000);

    m_AudioDevice = SDL_OpenAudioDevice(NULL, 0, &want, &have, 0);
    if (m_AudioDevice == 0) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "Failed to open audio device: %s",
                     SDL_GetError());
        return false;
    }

    m_AudioBuffer = SDL_malloc(m_FrameSize);
    if (m_AudioBuffer == nullptr) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "Failed to allocate audio buffer");
        return false;
    }

    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "Desired audio buffer: %u samples (%u bytes)",
                want.samples,
                want.samples * want.channels * getAudioBufferSampleSize());

    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "Obtained audio buffer: %u samples (%u bytes)",
                have.samples,
                have.size);

    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "SDL audio driver: %s",
                SDL_GetCurrentAudioDriver());

    // Start playback
    SDL_PauseAudioDevice(m_AudioDevice, 0);

    return true;
}

SdlAudioRenderer::~SdlAudioRenderer()
{
    if (m_AudioDevice != 0) {
        // Stop playback
        SDL_PauseAudioDevice(m_AudioDevice, 1);
        SDL_CloseAudioDevice(m_AudioDevice);
    }

    if (m_AudioBuffer != nullptr) {
        SDL_free(m_AudioBuffer);
    }

    // No !SDL_WasInit(SDL_INIT_AUDIO) assert after this — see ctor;
    // UiSoundManager's refcounted reference may legitimately keep the
    // subsystem alive past our teardown.
    SDL_QuitSubSystem(SDL_INIT_AUDIO);
}

void* SdlAudioRenderer::getAudioBuffer(int*)
{
    return m_AudioBuffer;
}

bool SdlAudioRenderer::submitAudio(int bytesWritten)
{
    if (bytesWritten == 0) {
        // Nothing to do
        return true;
    }

    // Don't queue if there's already more than 30 ms of audio data waiting
    // in Moonlight's audio queue.
    if (LiGetPendingAudioDuration() > 30) {
        return true;
    }

    // Provide backpressure on the queue to ensure too many frames don't build up
    // in SDL's audio queue, but don't wait forever to avoid a deadlock if the
    // audio device fails.
    for (int i = 0; i < 100; i++) {
        // Our device may enter a permanent error status upon removal, so we need
        // to recreate the audio device to pick up the new default audio device.
        if (SDL_GetAudioDeviceStatus(m_AudioDevice) == SDL_AUDIO_STOPPED) {
            return false;
        }

        // Only queue more samples when 50 ms or less of audio is left in SDL's queue.
        // This was a flat 10-FRAME cap, which meant the buffer depth silently tracked
        // the negotiated packet duration: 50 ms at 5 ms frames but 100 ms at 10 ms
        // frames, i.e. the slow decoders and low-bitrate links that get 10 ms packets
        // were also handed double the latency. Budgeting in time keeps it at 50 ms
        // either way (upstream moonlight-qt 4cf498b0).
        if (SDL_GetQueuedAudioSize(m_AudioDevice) / m_FrameSize * m_FrameDurationMs <= 50) {
            break;
        }

        SDL_Delay(1);
    }

    if (SDL_QueueAudio(m_AudioDevice, m_AudioBuffer, bytesWritten) < 0) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "Failed to queue audio sample: %s",
                     SDL_GetError());
    }

    return true;
}

int SdlAudioRenderer::getCapabilities()
{
    // Direct submit can't be used because we use LiGetPendingAudioDuration()
    return CAPABILITY_SUPPORTS_ARBITRARY_AUDIO_DURATION;
}

IAudioRenderer::AudioFormat SdlAudioRenderer::getAudioBufferFormat()
{
    return AudioFormat::Float32NE;
}
