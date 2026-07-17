#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QTimer>

class QNetworkReply;

// Vibemis auto-updater — 2026-07 from-scratch reimplementation (BL-2147).
//
// Design rule: this object is the SINGLE SOURCE OF TRUTH for update state,
// exposed to QML as properties. UI surfaces (the toolbar button and the
// Settings page) only bind to the properties and call the invokables — they
// hold no update state of their own. The 0.3.1 regression class (a surface
// assembling its state from two loosely-paired signals and acting on half of
// it) is structurally impossible under this contract: whoever can see
// `canInstall` true can call install(), full stop.
//
// Update feed: the GitHub releases list of navyas321/vibemis (all releases,
// newest-first — never /releases/latest, which hides prereleases). A release
// is served to a channel by MINIMUM STABILITY: a channel accepts its own tier
// and every tier above it (Alpha ⊇ Beta ⊇ RC ⊇ Stable), so an RC-channel
// install graduates to the stable it was a candidate for instead of going
// silent after the stable ships. Draft releases, "-dev." builds, and parked
// releases (bare tags flipped to prerelease) are never served to any channel.
class AutoUpdateChecker : public QObject
{
    Q_OBJECT

    // A strictly-newer build exists on the channel — powers the toolbar banner.
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY stateChanged)
    // The channel's newest build differs from the running one (may be older —
    // e.g. right after switching channels). Powers the Settings offer row.
    Q_PROPERTY(bool offerAvailable READ offerAvailable NOTIFY stateChanged)
    // Version string of the offered build ("" when offerAvailable is false).
    Q_PROPERTY(QString availableVersion READ availableVersion NOTIFY stateChanged)
    // GitHub release page of the offered build (browser fallback target).
    Q_PROPERTY(QString releaseUrl READ releaseUrl NOTIFY stateChanged)
    // install() would work right now: an offer exists, it ships an .AppImage
    // asset, we run as an AppImage, and no install is already in flight.
    Q_PROPERTY(bool canInstall READ canInstall NOTIFY stateChanged)
    Q_PROPERTY(bool checking READ checking NOTIFY stateChanged)
    Q_PROPERTY(bool installing READ installing NOTIFY stateChanged)
    // Human-readable status for the Settings page: current version at rest,
    // check outcomes, download progress, install errors.
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY stateChanged)

public:
    explicit AutoUpdateChecker(QObject *parent = nullptr);

    // Launch-time entry point: quiet check now, then a periodic re-check every
    // RECHECK_INTERVAL_MS (a launch-only check kept users blind to anything
    // published while the app was already running). Only runs on platforms
    // that self-serve updates (the AppImage build).
    Q_INVOKABLE void start();

    // User-initiated check from Settings. Runs on every platform and always
    // reports an outcome in statusMessage (including "up to date" and errors),
    // and offers the channel's newest build even when it is not strictly newer
    // — switching channels means "get me what this channel has".
    Q_INVOKABLE void checkNow();

    // Download the offered .AppImage, swap it atomically over the running one
    // ($APPIMAGE, previous build kept as "<file>.old"), then relaunch. No-op
    // unless canInstall. Progress lands in statusMessage/installProgress;
    // failure clears the offer's asset (so the next click falls back to the
    // release page) and emits installFailed.
    Q_INVOKABLE void install();

    // Settings calls this when the user picks a different update channel: the
    // previous check's offer no longer applies, so drop it and say so.
    Q_INVOKABLE void channelChanged();

    // True when running from an AppImage ($APPIMAGE set).
    Q_INVOKABLE bool canInstallUpdates() const;

    // The version string this build was compiled with (full CI tag on stamped builds).
    Q_INVOKABLE QString currentVersion() const;

    bool updateAvailable() const { return m_UpdateAvailable; }
    bool offerAvailable() const { return m_OfferAvailable; }
    QString availableVersion() const { return m_OfferVersion; }
    QString releaseUrl() const { return m_ReleaseUrl; }
    bool canInstall() const;
    bool checking() const { return m_CheckInFlight; }
    bool installing() const { return m_Installing; }
    QString statusMessage() const { return m_StatusMessage; }

    // SemVer 2.0.0 precedence (§11), including proper prerelease identifier
    // comparison — "alpha" < "beta" < "rc" at equal base, and a bare release
    // outranks any prerelease of the same base. Build metadata ("+sha") never
    // participates. Public/static so the selftest harness can sanity-check it.
    // Returns <0 / 0 / >0 like strcmp.
    static int compareSemanticVersions(const QString& v1, const QString& v2);

signals:
    // Any exposed property may have changed. Coarse by design: QML re-reads
    // cheap getters; no risk of a surface missing one narrow signal.
    void stateChanged();

    // One-shot check outcome (both auto and manual), for imperative consumers
    // (the update-selftest harness). UI surfaces should bind properties instead.
    void checkCompleted(bool manual, bool offerAvailable);

    void installProgress(qint64 bytesReceived, qint64 bytesTotal);
    void installFailed(QString error, QString releaseUrl);
    // The downloaded AppImage has been swapped into place (emitted just before
    // the relaunch; the update-selftest harness uses it to verify and exit).
    void installCompleted(QString appImagePath);

private:
    static const int RECHECK_INTERVAL_MS = 4 * 60 * 60 * 1000;

    void performCheck(bool manual);
    void handleFeedReply(QNetworkReply* reply, bool manual);

    // Stability tier of a release from its tag shape + flags:
    // 3 stable, 2 rc, 1 beta, 0 alpha, -1 never served (draft/dev/parked).
    // Understands the current suffix scheme ("0.3.0-rc.002"), the legacy
    // four-part W.X.Y.Z structural scheme, and legacy suffix-era tags.
    static int releaseTier(const QJsonObject& release);
    // Minimum tier the user's channel accepts (Alpha 0 … Stable 3).
    static int channelFloor(int updateChannel);
    // browser_download_url of the release's .AppImage asset ("" if none).
    static QString appImageAssetUrl(const QJsonObject& release);

    void clearOffer();
    void setStatus(const QString& message);

    QNetworkAccessManager m_Nam;
    QTimer m_RecheckTimer;

    bool m_CheckInFlight;
    bool m_CheckIsManual;

    bool m_UpdateAvailable;
    bool m_OfferAvailable;
    QString m_OfferVersion;
    QString m_ReleaseUrl;
    QString m_AssetUrl;

    bool m_Installing;
    QString m_StatusMessage;
};
