#include "systemproperties.h"
#include "utils.h"

#include <QGuiApplication>
#include <QLibraryInfo>
#include <QFile>
#include <QProcess>

#include "streaming/session.h"
#include "streaming/streamutils.h"

#ifdef Q_OS_WIN32
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#endif

SystemProperties::SystemProperties()
{
    versionString = QString(VERSION_STR);
    hasDesktopEnvironment = WMUtils::isRunningDesktopEnvironment();
    isRunningWayland = WMUtils::isRunningWayland();
    isRunningXWayland = isRunningWayland && QGuiApplication::platformName() == "xcb";
    usesMaterial3Theme = QLibraryInfo::version() >= QVersionNumber(6, 5, 0);
    QString nativeArch = QSysInfo::currentCpuArchitecture();

#ifdef Q_OS_WIN32
    {
        USHORT processArch, machineArch;

        // Use IsWow64Process2 on TH2 and later, because it supports ARM64
        auto fnIsWow64Process2 = (decltype(IsWow64Process2)*)GetProcAddress(GetModuleHandleA("kernel32.dll"), "IsWow64Process2");
        if (fnIsWow64Process2 != nullptr && fnIsWow64Process2(GetCurrentProcess(), &processArch, &machineArch)) {
            switch (machineArch) {
            case IMAGE_FILE_MACHINE_I386:
                nativeArch = "i386";
                break;
            case IMAGE_FILE_MACHINE_AMD64:
                nativeArch = "x86_64";
                break;
            case IMAGE_FILE_MACHINE_ARM64:
                nativeArch = "arm64";
                break;
            }
        }

        isWow64 = nativeArch != QSysInfo::buildCpuArchitecture();
    }
#else
    isWow64 = false;
#endif

    if (nativeArch == "i386") {
        friendlyNativeArchName = "x86";
    }
    else if (nativeArch == "x86_64") {
        friendlyNativeArchName = "x64";
    }
    else {
        friendlyNativeArchName = nativeArch.toUpper();
    }

    // Assume we can probably launch a browser if we're in a GUI environment
    hasBrowser = hasDesktopEnvironment;

#ifdef HAVE_DISCORD
    hasDiscordIntegration = true;
#else
    hasDiscordIntegration = false;
#endif

    unmappedGamepads = SdlInputHandler::getUnmappedGamepads();


    // Populate data that requires talking to SDL. We do it all in one shot
    // and cache the results to speed up future queries on this data.
    querySdlVideoInfo();

    Q_ASSERT(!monitorRefreshRates.isEmpty());
    Q_ASSERT(!monitorNativeResolutions.isEmpty());
    Q_ASSERT(!monitorSafeAreaResolutions.isEmpty());
}

QRect SystemProperties::getNativeResolution(int displayIndex)
{
    // Returns default constructed QRect if out of bounds
    return monitorNativeResolutions.value(displayIndex);
}

QRect SystemProperties::getSafeAreaResolution(int displayIndex)
{
    // Returns default constructed QRect if out of bounds
    return monitorSafeAreaResolutions.value(displayIndex);
}

int SystemProperties::getRefreshRate(int displayIndex)
{
    // Returns 0 if out of bounds
    return monitorRefreshRates.value(displayIndex);
}

QString SystemProperties::checkTailscaleStatus()
{
    // `tailscale ip -4` prints the device's tailnet IPv4 on its own line when the tailnet is
    // up; a non-zero exit (or empty output) means Tailscale isn't installed or isn't connected.
    QProcess proc;
    proc.setProcessChannelMode(QProcess::MergedChannels);
    proc.start("tailscale", QStringList() << "ip" << "-4");
    if (!proc.waitForStarted(2000)) {
        return tr("Tailscale not found. Install it, then run the one-command setup.");
    }
    proc.waitForFinished(4000);
    QString out = QString::fromUtf8(proc.readAll()).trimmed();
    if (proc.exitStatus() == QProcess::NormalExit && proc.exitCode() == 0 && !out.isEmpty()) {
        // Take the first line (the primary tailnet IPv4).
        QString ip = out.split(QLatin1Char('\n')).first().trimmed();
        return tr("Connected — this device's Tailscale IP is %1.").arg(ip);
    }
    return tr("Tailscale is installed but not connected. Run the one-command setup or `tailscale up`.");
}

class QuerySdlVideoThread : public QThread
{
public:
    QuerySdlVideoThread(SystemProperties* me) :
        QThread(nullptr),
        m_Me(me) {}

    void run() override
    {
        m_Me->querySdlVideoInfoInternal();
    }

    SystemProperties* m_Me;
};

void SystemProperties::querySdlVideoInfo()
{
    if (WMUtils::isRunningX11() || WMUtils::isRunningWayland()) {
        // Use a separate thread to temporarily initialize SDL
        // video to avoid stomping on Qt's X11 and OGL state.
        QuerySdlVideoThread thread(this);
        thread.start();
        thread.wait();
    }
    else {
        querySdlVideoInfoInternal();
    }
}

void SystemProperties::querySdlVideoInfoInternal()
{
    hasHardwareAcceleration = false;

    if (SDL_InitSubSystem(SDL_INIT_VIDEO) != 0) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "SDL_InitSubSystem(SDL_INIT_VIDEO) failed: %s",
                     SDL_GetError());
        return;
    }

    // Update display related attributes (max FPS, native resolution, etc).
    // We call the internal variant because we're already in a safe thread context.
    refreshDisplaysInternal();

    SDL_Window* testWindow = SDL_CreateWindow("", 0, 0, 1280, 720,
                                              SDL_WINDOW_HIDDEN | StreamUtils::getPlatformWindowFlags());
    if (!testWindow) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "Failed to create test window with platform flags: %s",
                    SDL_GetError());

        testWindow = SDL_CreateWindow("", 0, 0, 1280, 720, SDL_WINDOW_HIDDEN);
        if (!testWindow) {
            SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                         "Failed to create window for hardware decode test: %s",
                         SDL_GetError());
            SDL_QuitSubSystem(SDL_INIT_VIDEO);
            return;
        }
    }

    Session::getDecoderInfo(testWindow, hasHardwareAcceleration, rendererAlwaysFullScreen, supportsHdr, maximumResolution);

    // Allow environment variable override for HDR support (for testing and debugging)
    if (qgetenv("FORCE_HDR_SUPPORT") == "1") {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "SystemProperties: Forcing HDR support via FORCE_HDR_SUPPORT environment variable (was: %s)",
                    supportsHdr ? "ENABLED" : "DISABLED");
        supportsHdr = true;
    }
    
    // Allow environment variable override for hardware acceleration (for Flatpak and testing)
    if (qgetenv("VIBEMIS_FORCE_HW_ACCEL") == "1") {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "SystemProperties: Forcing hardware acceleration via VIBEMIS_FORCE_HW_ACCEL environment variable (was: %s)",
                    hasHardwareAcceleration ? "ENABLED" : "DISABLED");
        hasHardwareAcceleration = true;
    }
    
    // Additional debug logging for HDR capability investigation
    if (qgetenv("HDR_DEBUG") == "1") {
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                    "SystemProperties HDR Debug: Hardware acceleration=%s, Renderer fullscreen=%s, HDR support=%s",
                    hasHardwareAcceleration ? "YES" : "NO",
                    rendererAlwaysFullScreen ? "YES" : "NO", 
                    supportsHdr ? "YES" : "NO");
    }

    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "SystemProperties: Final HDR support status: %s", 
                supportsHdr ? "ENABLED" : "DISABLED");

    SDL_DestroyWindow(testWindow);

    SDL_QuitSubSystem(SDL_INIT_VIDEO);
}

class RefreshDisplaysThread : public QThread
{
public:
    RefreshDisplaysThread(SystemProperties* me) :
        QThread(nullptr),
        m_Me(me) {}

    void run() override
    {
        m_Me->refreshDisplaysInternal();
    }

    SystemProperties* m_Me;
};

void SystemProperties::refreshDisplays()
{
    if (WMUtils::isRunningX11() || WMUtils::isRunningWayland()) {
        // Use a separate thread to temporarily initialize SDL
        // video to avoid stomping on Qt's X11 and OGL state.
        RefreshDisplaysThread thread(this);
        thread.start();
        thread.wait();
    }
    else {
        refreshDisplaysInternal();
    }
}

void SystemProperties::refreshDisplaysInternal()
{
    if (SDL_InitSubSystem(SDL_INIT_VIDEO) != 0) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "SDL_InitSubSystem(SDL_INIT_VIDEO) failed: %s",
                     SDL_GetError());
        return;
    }

    monitorNativeResolutions.clear();

    SDL_DisplayMode bestMode;
    for (int displayIndex = 0; displayIndex < SDL_GetNumVideoDisplays(); displayIndex++) {
        SDL_DisplayMode desktopMode;
        SDL_Rect safeArea;

        if (StreamUtils::getNativeDesktopMode(displayIndex, &desktopMode, &safeArea)) {
            if (desktopMode.w <= 8192 && desktopMode.h <= 8192) {
                monitorNativeResolutions.insert(displayIndex, QRect(0, 0, desktopMode.w, desktopMode.h));
                monitorSafeAreaResolutions.insert(displayIndex, QRect(0, 0, safeArea.w, safeArea.h));
            }
            else {
                SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                            "Skipping resolution over 8K: %dx%d",
                            desktopMode.w, desktopMode.h);
            }

            // Start at desktop mode and work our way up
            bestMode = desktopMode;
            for (int i = 0; i < SDL_GetNumDisplayModes(displayIndex); i++) {
                SDL_DisplayMode mode;
                if (SDL_GetDisplayMode(displayIndex, i, &mode) == 0) {
                    if (mode.w == desktopMode.w && mode.h == desktopMode.h) {
                        if (mode.refresh_rate > bestMode.refresh_rate) {
                            bestMode = mode;
                        }
                    }
                }
            }

            // Try to normalize values around our our standard refresh rates.
            // Some displays/OSes report values that are slightly off.
            if (bestMode.refresh_rate >= 58 && bestMode.refresh_rate <= 62) {
                monitorRefreshRates.append(60);
            }
            else if (bestMode.refresh_rate >= 28 && bestMode.refresh_rate <= 32) {
                monitorRefreshRates.append(30);
            }
            else {
                monitorRefreshRates.append(bestMode.refresh_rate);
            }
        }
    }
}

