#pragma once

#include <QObject>
#include <QRect>

class SystemProperties : public QObject
{
    Q_OBJECT

    friend class QuerySdlVideoThread;
    friend class RefreshDisplaysThread;

public:
    SystemProperties();

    Q_PROPERTY(bool hasHardwareAcceleration MEMBER hasHardwareAcceleration CONSTANT)
    Q_PROPERTY(bool rendererAlwaysFullScreen MEMBER rendererAlwaysFullScreen CONSTANT)
    Q_PROPERTY(bool isRunningWayland MEMBER isRunningWayland CONSTANT)
    Q_PROPERTY(bool isRunningXWayland MEMBER isRunningXWayland CONSTANT)
    Q_PROPERTY(bool isWow64 MEMBER isWow64 CONSTANT)
    Q_PROPERTY(QString friendlyNativeArchName MEMBER friendlyNativeArchName CONSTANT)
    Q_PROPERTY(bool hasDesktopEnvironment MEMBER hasDesktopEnvironment CONSTANT)
    Q_PROPERTY(bool hasBrowser MEMBER hasBrowser CONSTANT)
    Q_PROPERTY(bool hasDiscordIntegration MEMBER hasDiscordIntegration CONSTANT)
    Q_PROPERTY(QString unmappedGamepads MEMBER unmappedGamepads NOTIFY unmappedGamepadsChanged)
    Q_PROPERTY(QSize maximumResolution MEMBER maximumResolution CONSTANT)
    Q_PROPERTY(QString versionString MEMBER versionString CONSTANT)
    Q_PROPERTY(bool supportsHdr MEMBER supportsHdr CONSTANT)
    Q_PROPERTY(bool usesMaterial3Theme MEMBER usesMaterial3Theme CONSTANT)
    Q_PROPERTY(bool isSteamDeck MEMBER isSteamDeck CONSTANT)
    Q_PROPERTY(bool hasVulkanHdr MEMBER hasVulkanHdr CONSTANT)

    Q_INVOKABLE void refreshDisplays();
    Q_INVOKABLE QRect getNativeResolution(int displayIndex);
    Q_INVOKABLE QRect getSafeAreaResolution(int displayIndex);
    Q_INVOKABLE int getRefreshRate(int displayIndex);

    // Run `tailscale status` in-app and return a short human-readable
    // status line (the device's tailnet IP if up, or an install/up hint) so the user can
    // confirm their tailnet from Settings without a terminal. Best-effort; never throws.
    Q_INVOKABLE QString checkTailscaleStatus();

    // BL-2356: read-only Wi-Fi power-save status for a visible Settings row.
    // Wi-Fi power management throttles the client radio (SteamOS re-enables it
    // every Game Mode session; it caused the 54 Mbps "delivery collapse").
    // vibemis cannot change it (that needs root / the NetworkManager
    // dispatcher) — this just reports the live state so the user can see it in
    // Settings. Returns a short human-readable line; best-effort, never throws.
    Q_INVOKABLE QString checkWifiPowerSaveStatus();

    // Open a URL in the HOST browser with a CLEANED environment.
    // Qt.openUrlExternally spawns xdg-open/the browser with the AppImage's LD_LIBRARY_PATH
    // and Qt plugin paths inherited, so the host browser loads bundled libs and dies
    // silently — About/Help links "did nothing" on device. Use this from QML instead.
    Q_INVOKABLE bool openUrl(const QString& url);
    
    static bool isSteamDeckOrGamescope();
    static bool hasVulkanHdrSupport();

signals:
    void unmappedGamepadsChanged();

private:
    void querySdlVideoInfo();
    void querySdlVideoInfoInternal();
    void refreshDisplaysInternal();

    bool hasHardwareAcceleration;
    bool rendererAlwaysFullScreen;
    bool isRunningWayland;
    bool isRunningXWayland;
    bool isWow64;
    QString friendlyNativeArchName;
    bool hasDesktopEnvironment;
    bool hasBrowser;
    bool hasDiscordIntegration;
    QString unmappedGamepads;
    QSize maximumResolution;
    QList<QRect> monitorNativeResolutions;
    QList<QRect> monitorSafeAreaResolutions;
    QList<int> monitorRefreshRates;
    QString versionString;
    bool supportsHdr;
    bool usesMaterial3Theme;
    bool isSteamDeck;
    bool hasVulkanHdr;
};

