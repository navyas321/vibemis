#pragma once

#include <QObject>
#include <QByteArray>
#include <QTimer>

#include "SDL_compat.h"

class QQmlEngine;

// BL-1776: tiny SDL player for the controller-nav UI sounds (focus tick +
// activation blip). Deliberately NOT Qt Multimedia — that module isn't linked
// today and would add a new runtime Qt library plus a GStreamer/FFmpeg media
// backend to the AppImage for two ~5 KB tones. SDL is already linked for
// streaming audio.
//
// Stream-safety contract with SdlAudioRenderer (sdlaud.cpp):
//  - SDL_InitSubSystem/SDL_QuitSubSystem are refcounted, so a reference held
//    here never tears down the renderer's subsystem (and vice versa).
//  - The playback device is opened lazily per sound burst and closed after a
//    short idle window. On mixing audio servers (PipeWire/PulseAudio — the
//    SteamOS case) the two open devices are independent server streams.
//  - If the device can't be opened (e.g. an exclusive raw-ALSA setup while a
//    stream owns audio), the sound is dropped silently; the stream's device
//    is never touched.
//  - streamStarting() closes our device up front so the streaming renderer's
//    own open never races a lingering UI-sound device on exclusive systems.
class UiSoundManager : public QObject
{
    Q_OBJECT

public:
    static UiSoundManager* get(QQmlEngine* qmlEngine = nullptr);

    // Focus moved to another control (d-pad/stick/arrow/Tab navigation)
    Q_INVOKABLE void focusMoved();

    // A control was activated (A/Enter/Space/click)
    Q_INVOKABLE void activated();

    // A stream session is about to start — release the audio device now
    Q_INVOKABLE void streamStarting();

private:
    UiSoundManager();

    struct Sound
    {
        QByteArray pcm;
        SDL_AudioSpec spec;
        bool valid;
    };

    bool loadWav(const char* qrcPath, Sound& sound);
    void play(const Sound& sound);
    void closeDevice();

    Sound m_Tick;
    Sound m_Blip;
    SDL_AudioDeviceID m_Device;
    QTimer m_IdleCloseTimer;
};
