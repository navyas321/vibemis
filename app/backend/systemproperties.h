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

    // Vibemis P3.7 (test93): run `tailscale status` in-app and return a short human-readable
    // status line (the device's tailnet IP if up, or an install/up hint) so the user can
    // confirm their tailnet from Settings without a terminal. Best-effort; never throws.
    Q_INVOKABLE QString checkTailscaleStatus();

    // Maintainer 2026-07-13: open a URL in the HOST browser with a CLEANED environment.
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

