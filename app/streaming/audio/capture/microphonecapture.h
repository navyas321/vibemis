#pragma once

#include <atomic>
#include <array>
#include <condition_variable>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include <SDL.h>
#include <opus.h>

class MicrophoneCapture
{
public:
    MicrophoneCapture();
    ~MicrophoneCapture();

    bool initialize(const std::string& deviceName = {});
    bool start();
    void stop();

    void setEnabled(bool enabled);
    bool isEnabled() const;
    bool isStreaming() const;

private:
    static void audioCallback(void* userdata, Uint8* stream, int len);
    void handleAudioData(const Uint8* stream, int len);
    void clearBufferedSamples();
    void encoderLoop();

    SDL_AudioDeviceID m_DeviceId;
    SDL_AudioSpec m_ObtainedSpec;
    OpusEncoder* m_Encoder;
    std::vector<opus_int16> m_SampleBuffer;
    std::array<unsigned char, 1400> m_EncodedPacket;
    std::atomic_bool m_Streaming;
    std::atomic_bool m_StopEncoderThread;
    bool m_Initialized;
    bool m_Enabled;
    bool m_FirstPacketLogged;
    std::mutex m_BufferMutex;
    std::condition_variable m_BufferCondition;
    std::thread m_EncoderThread;

    static constexpr int kSampleRate = 48000;
    static constexpr int kChannels = 1;
    static constexpr int kFrameSize = 960;
    static constexpr int kBitrate = 64000;
};
