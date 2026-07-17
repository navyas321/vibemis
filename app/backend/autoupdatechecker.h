#pragma once

#include <QObject>
#include <QNetworkAccessManager>

class QNetworkReply;

class AutoUpdateChecker : public QObject
{
    Q_OBJECT
public:
    explicit AutoUpdateChecker(QObject *parent = nullptr);

    Q_INVOKABLE void start();

    // Vibemis: user-initiated check from Settings. Unlike start(), it runs on
    // every platform, always reports an outcome via updateCheckFinished() (including
    // "up to date" and errors), and offers the channel's newest build even when it is
    // not strictly newer — switching channels means "get me what this channel has".
    Q_INVOKABLE void checkNow();

    // Vibemis: download the .AppImage asset and swap it over the running
    // AppImage ($APPIMAGE), then relaunch. Emits installProgress while downloading
    // and installFailed on any error (callers should fall back to the release page).
    Q_INVOKABLE void installUpdate(QString assetUrl);

    // True when running from an AppImage ($APPIMAGE set), i.e. in-place install works.
    Q_INVOKABLE bool canInstallUpdates();

    // The version string this build was compiled with (full CI tag on stamped builds).
    Q_INVOKABLE QString currentVersion();

signals:
    void onUpdateAvailable(QString newVersion, QString url);
    // Vibemis: manual-check outcome for the Settings UI. `available` is true
    // when the newest release on the selected channel differs from the running build;
    // assetUrl is the .AppImage browser_download_url ("" if the release has none).
    void updateCheckFinished(bool available, QString version, QString htmlUrl,
                             QString assetUrl, QString message);
    void installProgress(qint64 bytesReceived, qint64 bytesTotal);
    void installFailed(QString error, QString htmlUrl);
    // Vibemis: the downloaded AppImage has been swapped into place (emitted just
    // before the relaunch; the update-selftest harness uses it to verify and exit).
    void installCompleted(QString appImagePath);

private slots:
    void handleUpdateCheckRequestFinished(QNetworkReply* reply);

private:
    void requestReleaseFeed(bool manualCheck);

    void parseStringToVersionQuad(QString& string, QVector<int>& version);

    int compareVersion(QVector<int>& version1, QVector<int>& version2);

    // Vibemis: prerelease-aware ordering for CI tags like
    // "1.0.1-beta.20260713.0528+b6198e4" (see .cpp for the exact rules).
    static int compareSemanticVersions(const QString& v1, const QString& v2);

    QString getPlatform();

    QVector<int> m_CurrentVersionQuad;
    QNetworkAccessManager* m_Nam;
    bool m_ManualCheck;
    bool m_CheckInFlight;
    QString m_LastHtmlUrl;
};
