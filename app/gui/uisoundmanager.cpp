#include "uisoundmanager.h"

#include "settings/streamingpreferences.h"

#include <QFile>

// Idle window before the device is released. Long enough to amortize rapid
// d-pad scrolling into one device session, short enough that the subsystem is
// rarely held when something else wants exclusive audio.
// Must stay well under the ~2s gap between a launcher activation blip and a stream's
// audio-device open (StreamSegue calls streamStarting() as the hard guarantee; this
// window is the soft one that keeps the device free during normal navigation pauses).
#define UI_SOUND_IDLE_CLOSE_MS 1500

UiSoundManager* UiSoundManager::get(QQmlEngine*)
{
    // Shared across QML engines (launcher + the Quick Menu's offscreen engine),
    // so it must outlive any single engine — see the CppOwnership note at the
    // registration site in main.cpp.
    static UiSoundManager* instance = new UiSoundManager();
    return instance;
}

UiSoundManager::UiSoundManager()
    : m_Device(0)
{
    loadWav(":/res/sounds/nav_tick.wav", m_Tick);
    loadWav(":/res/sounds/nav_blip.wav", m_Blip);

    m_IdleCloseTimer.setSingleShot(true);
    m_IdleCloseTimer.setInterval(UI_SOUND_IDLE_CLOSE_MS);
    connect(&m_IdleCloseTimer, &QTimer::timeout, this, &UiSoundManager::closeDevice);
}

bool UiSoundManager::loadWav(const char* qrcPath, Sound& sound)
{
    sound.valid = false;

    // SDL can't read qrc paths, so parse from memory
    QFile file(qrcPath);
    if (!file.open(QFile::ReadOnly)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "UiSoundManager: missing sound resource: %s",
                     qrcPath);
        return false;
    }
    QByteArray fileData = file.readAll();

    SDL_AudioSpec spec;
    Uint8* buffer;
    Uint32 length;
    if (SDL_LoadWAV_RW(SDL_RWFromConstMem(fileData.constData(), fileData.size()),
                       1, &spec, &buffer, &length) == nullptr) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "UiSoundManager: SDL_LoadWAV_RW(%s) failed: %s",
                     qrcPath, SDL_GetError());
        return false;
    }

    sound.pcm = QByteArray((const char*)buffer, (int)length);
    sound.spec = spec;
    sound.valid = true;
    SDL_FreeWAV(buffer);
    return true;
}

void UiSoundManager::focusMoved()
{
    play(m_Tick);
}

void UiSoundManager::activated()
{
    play(m_Blip);
}

void UiSoundManager::streamStarting()
{
    m_IdleCloseTimer.stop();
    closeDevice();
}

void UiSoundManager::play(const Sound& sound)
{
    if (!sound.valid || !StreamingPreferences::get()->uiSounds) {
        return;
    }

    if (m_Device == 0) {
        // Refcounted — safe while SdlAudioRenderer holds the subsystem too
        if (SDL_InitSubSystem(SDL_INIT_AUDIO) != 0) {
            return;
        }

        // Both shipped WAVs share one spec, so either sound can reuse the device
        SDL_AudioSpec want = sound.spec;
        want.samples = 512;
        want.callback = nullptr; // push audio via SDL_QueueAudio

        m_Device = SDL_OpenAudioDevice(nullptr, 0, &want, nullptr, 0);
        if (m_Device == 0) {
            // Device busy/exclusive — drop the sound rather than disturb
            // whoever owns audio (possibly an active stream)
            SDL_QuitSubSystem(SDL_INIT_AUDIO);
            return;
        }

        SDL_PauseAudioDevice(m_Device, 0);
    }

    // Retrigger: rapid navigation cuts the previous tail instead of lagging
    // behind a growing queue
    SDL_ClearQueuedAudio(m_Device);
    SDL_QueueAudio(m_Device, sound.pcm.constData(), (Uint32)sound.pcm.size());

    m_IdleCloseTimer.start();
}

void UiSoundManager::closeDevice()
{
    if (m_Device != 0) {
        SDL_CloseAudioDevice(m_Device);
        SDL_QuitSubSystem(SDL_INIT_AUDIO);
        m_Device = 0;
    }
}
