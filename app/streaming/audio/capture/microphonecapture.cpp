#include "microphonecapture.h"

#include <chrono>

#include <Limelight.h>

MicrophoneCapture::MicrophoneCapture()
    : m_DeviceId(0)
    , m_ObtainedSpec({})
    , m_Encoder(nullptr)
    , m_SampleReadOffset(0)
    , m_SampleCount(0)
    , m_Streaming(false)
    , m_StopEncoderThread(false)
    , m_Initialized(false)
    , m_Enabled(false)
    , m_FirstPacketLogged(false)
{
}

MicrophoneCapture::~MicrophoneCapture()
{
    stop();

    m_StopEncoderThread.store(true, std::memory_order_release);
    m_BufferCondition.notify_all();
    if (m_EncoderThread.joinable()) {
        m_EncoderThread.join();
    }

    if (m_DeviceId != 0) {
        SDL_CloseAudioDevice(m_DeviceId);
        m_DeviceId = 0;
    }

    if (m_Encoder != nullptr) {
        opus_encoder_destroy(m_Encoder);
        m_Encoder = nullptr;
    }
}

bool MicrophoneCapture::initialize(const std::string& deviceName)
{
    if (m_Initialized) {
        return true;
    }

    if (SDL_InitSubSystem(SDL_INIT_AUDIO) != 0) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "SDL_InitSubSystem(SDL_INIT_AUDIO) failed for microphone capture: %s",
                    SDL_GetError());
        return false;
    }

    int opusError = OPUS_OK;
    m_Encoder = opus_encoder_create(kSampleRate, kChannels, OPUS_APPLICATION_VOIP, &opusError);
    if (m_Encoder == nullptr || opusError != OPUS_OK) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "opus_encoder_create() failed for microphone capture: %s",
                    opus_strerror(opusError));
        return false;
    }

    opus_encoder_ctl(m_Encoder, OPUS_SET_BITRATE(kBitrate));
    opus_encoder_ctl(m_Encoder, OPUS_SET_VBR(1));
    opus_encoder_ctl(m_Encoder, OPUS_SET_COMPLEXITY(10));
    opus_encoder_ctl(m_Encoder, OPUS_SET_SIGNAL(OPUS_SIGNAL_VOICE));
    opus_encoder_ctl(m_Encoder, OPUS_SET_LSB_DEPTH(16));
    opus_encoder_ctl(m_Encoder, OPUS_SET_DTX(0));
    opus_encoder_ctl(m_Encoder, OPUS_SET_INBAND_FEC(1));
    opus_encoder_ctl(m_Encoder, OPUS_SET_PACKET_LOSS_PERC(5));
    opus_encoder_ctl(m_Encoder, OPUS_SET_EXPERT_FRAME_DURATION(OPUS_FRAMESIZE_20_MS));

    SDL_AudioSpec desired = {};
    desired.freq = kSampleRate;
    desired.format = AUDIO_S16SYS;
    desired.channels = kChannels;
    desired.samples = kFrameSize;
    desired.callback = &MicrophoneCapture::audioCallback;
    desired.userdata = this;

    const char* selectedDevice = deviceName.empty() ? nullptr : deviceName.c_str();
    m_DeviceId = SDL_OpenAudioDevice(selectedDevice, 1, &desired, &m_ObtainedSpec, 0);
    if (m_DeviceId == 0 && selectedDevice != nullptr) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "SDL_OpenAudioDevice() failed for requested microphone '%s': %s. Falling back to default input device.",
                    selectedDevice,
                    SDL_GetError());
        m_DeviceId = SDL_OpenAudioDevice(nullptr, 1, &desired, &m_ObtainedSpec, 0);
    }

    if (m_DeviceId == 0) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "SDL_OpenAudioDevice() failed for microphone capture: %s",
                    SDL_GetError());
        return false;
    }

    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "Microphone capture device: %s (%d Hz, %d channels, format 0x%x, %d sample callback target)",
                selectedDevice != nullptr ? selectedDevice : "<default>",
                m_ObtainedSpec.freq,
                m_ObtainedSpec.channels,
                m_ObtainedSpec.format,
                m_ObtainedSpec.samples);

    if (m_ObtainedSpec.freq != kSampleRate ||
            m_ObtainedSpec.channels != kChannels ||
            m_ObtainedSpec.format != AUDIO_S16SYS) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "Microphone capture format mismatch: got %d Hz, %d channels, format 0x%x",
                    m_ObtainedSpec.freq,
                    m_ObtainedSpec.channels,
                    m_ObtainedSpec.format);
        return false;
    }

    if (m_ObtainedSpec.samples != kFrameSize) {
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                    "Microphone capture backend is delivering %d-sample callbacks; outgoing Opus packets will be paced at %d-sample (%d ms) intervals",
                    m_ObtainedSpec.samples,
                    kFrameSize,
                    (kFrameSize * 1000) / kSampleRate);
    }

    SDL_PauseAudioDevice(m_DeviceId, 1);
    m_StopEncoderThread.store(false, std::memory_order_release);
    m_EncoderThread = std::thread(&MicrophoneCapture::encoderLoop, this);
    m_Initialized = true;
    return true;
}

bool MicrophoneCapture::start()
{
    if (!m_Enabled || !m_Initialized || m_DeviceId == 0 || !LiIsMicrophoneStreamActive()) {
        return false;
    }

    clearBufferedSamples();
    m_FirstPacketLogged = false;
    m_Streaming.store(true, std::memory_order_release);
    m_BufferCondition.notify_all();
    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "Microphone capture streaming started; negotiated mic stream is active");
    SDL_PauseAudioDevice(m_DeviceId, 0);
    return true;
}

void MicrophoneCapture::stop()
{
    if (m_DeviceId != 0) {
        SDL_PauseAudioDevice(m_DeviceId, 1);
    }

    m_Streaming.store(false, std::memory_order_release);
    clearBufferedSamples();
    m_BufferCondition.notify_all();
}

void MicrophoneCapture::setEnabled(bool enabled)
{
    m_Enabled = enabled;
    if (!m_Enabled) {
        stop();
    }
}

bool MicrophoneCapture::isEnabled() const
{
    return m_Enabled;
}

bool MicrophoneCapture::isStreaming() const
{
    return m_Streaming.load(std::memory_order_acquire);
}

void MicrophoneCapture::audioCallback(void* userdata, Uint8* stream, int len)
{
    auto* capture = static_cast<MicrophoneCapture*>(userdata);
    if (capture != nullptr) {
        capture->handleAudioData(stream, len);
    }
}

void MicrophoneCapture::handleAudioData(const Uint8* stream, int len)
{
    if (!m_Streaming.load(std::memory_order_acquire) || stream == nullptr || len <= 0) {
        return;
    }

    const auto* inputSamples = reinterpret_cast<const opus_int16*>(stream);
    const int sampleCount = len / static_cast<int>(sizeof(opus_int16));

    {
        std::lock_guard lock(m_BufferMutex);
        for (int i = 0; i < sampleCount; ++i) {
            if (m_SampleCount == kMaxBufferedSamples) {
                m_SampleReadOffset = (m_SampleReadOffset + 1) % kMaxBufferedSamples;
                --m_SampleCount;
            }

            const size_t writeOffset = (m_SampleReadOffset + m_SampleCount) % kMaxBufferedSamples;
            m_SampleBuffer[writeOffset] = inputSamples[i];
            ++m_SampleCount;
        }
    }
    m_BufferCondition.notify_one();
}

void MicrophoneCapture::encoderLoop()
{
    std::vector<opus_int16> frame(kFrameSize);
    const auto frameDuration = std::chrono::milliseconds((kFrameSize * 1000) / kSampleRate);
    auto nextSendDeadline = std::chrono::steady_clock::now();
    bool pacingActive = false;

    for (;;) {
        {
            std::unique_lock lock(m_BufferMutex);
            m_BufferCondition.wait(lock, [this] {
                return m_StopEncoderThread.load(std::memory_order_acquire) ||
                       (m_Streaming.load(std::memory_order_acquire) && m_SampleCount >= static_cast<size_t>(kFrameSize));
            });

            if (m_StopEncoderThread.load(std::memory_order_acquire)) {
                break;
            }

            if (!m_Streaming.load(std::memory_order_acquire) || m_SampleCount < static_cast<size_t>(kFrameSize)) {
                pacingActive = false;
                continue;
            }

            for (int i = 0; i < kFrameSize; ++i) {
                frame[i] = m_SampleBuffer[(m_SampleReadOffset + static_cast<size_t>(i)) % kMaxBufferedSamples];
            }
            m_SampleReadOffset = (m_SampleReadOffset + kFrameSize) % kMaxBufferedSamples;
            m_SampleCount -= kFrameSize;
        }

        const auto now = std::chrono::steady_clock::now();
        if (!pacingActive) {
            nextSendDeadline = now;
            pacingActive = true;
        }
        else if (now > nextSendDeadline + (frameDuration * 2)) {
            nextSendDeadline = now;
        }

        if (nextSendDeadline > now) {
            std::this_thread::sleep_until(nextSendDeadline);
        }
        nextSendDeadline += frameDuration;

        const int encodedBytes = opus_encode(m_Encoder,
                                             frame.data(),
                                             kFrameSize,
                                             m_EncodedPacket.data(),
                                             static_cast<opus_int32>(m_EncodedPacket.size()));
        if (encodedBytes <= 0) {
            continue;
        }

        const int sendResult = LiSendMicrophoneOpusDataEx(m_EncodedPacket.data(), encodedBytes, kFrameSize);
        if (sendResult >= 0 && !m_FirstPacketLogged) {
            m_FirstPacketLogged = true;
            SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                        "Sent first client microphone packet (%d bytes Opus)",
                        encodedBytes);
        }
        else if (sendResult < 0) {
            SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                        "LiSendMicrophoneOpusDataEx() failed for microphone capture");
        }
    }
}

void MicrophoneCapture::clearBufferedSamples()
{
    std::lock_guard lock(m_BufferMutex);
    m_SampleReadOffset = 0;
    m_SampleCount = 0;
}
