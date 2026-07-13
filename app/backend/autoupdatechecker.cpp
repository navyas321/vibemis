#include "autoupdatechecker.h"
#include "settings/streamingpreferences.h"

#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QCoreApplication>
#include <QFile>
#include <QProcess>

AutoUpdateChecker::AutoUpdateChecker(QObject *parent) :
    QObject(parent),
    m_Nam(nullptr),
    m_ManualCheck(false),
    m_CheckInFlight(false)
{
    QString currentVersion(VERSION_STR);
    qDebug() << "Current Vibemis version:" << currentVersion;
    parseStringToVersionQuad(currentVersion, m_CurrentVersionQuad);

    // Should at least have a 1.0-style version number
    Q_ASSERT(m_CurrentVersionQuad.count() > 1);
}

void AutoUpdateChecker::start()
{
#if defined(Q_OS_WIN32) || defined(Q_OS_DARWIN) || defined(STEAM_LINK) || defined(APP_IMAGE) // Only run update checker on platforms without auto-update
    requestReleaseFeed(false);
#endif
}

void AutoUpdateChecker::checkNow()
{
    // Vibemis BL-1665: user-initiated — no platform gate; a dev/desktop build can
    // still check the feed even though it can't self-install ($APPIMAGE unset).
    requestReleaseFeed(true);
}

bool AutoUpdateChecker::canInstallUpdates()
{
    return !qEnvironmentVariable("APPIMAGE").isEmpty();
}

QString AutoUpdateChecker::currentVersion()
{
    return QStringLiteral(VERSION_STR);
}

void AutoUpdateChecker::requestReleaseFeed(bool manualCheck)
{
    if (m_CheckInFlight) {
        // One check at a time; a manual click during an in-flight auto check just
        // upgrades that check to a reporting one.
        if (manualCheck) {
            m_ManualCheck = true;
        }
        return;
    }

    // The finished handler tears the QNetworkAccessManager down after each check
    // (to stop bearer-plugin background polling), so recreate it on demand.
    if (!m_Nam) {
        m_Nam = new QNetworkAccessManager(this);

        // Never communicate over HTTP
        m_Nam->setStrictTransportSecurityEnabled(true);

        // Allow HTTP redirects
        m_Nam->setRedirectPolicy(QNetworkRequest::NoLessSafeRedirectPolicy);

        connect(m_Nam, &QNetworkAccessManager::finished,
                this, &AutoUpdateChecker::handleUpdateCheckRequestFinished);
    }

#if QT_VERSION >= QT_VERSION_CHECK(5, 14, 0) && QT_VERSION < QT_VERSION_CHECK(5, 15, 1) && !defined(QT_NO_BEARERMANAGEMENT)
    // HACK: Set network accessibility to work around QTBUG-80947 (introduced in Qt 5.14.0 and fixed in Qt 5.15.1)
    QT_WARNING_PUSH
    QT_WARNING_DISABLE_DEPRECATED
    m_Nam->setNetworkAccessible(QNetworkAccessManager::Accessible);
    QT_WARNING_POP
#endif

    m_ManualCheck = manualCheck;
    m_CheckInFlight = true;

    // Point to Vibemis GitHub releases (all releases including prereleases)
    // Using /releases instead of /releases/latest because /latest never returns
    // prereleases, and the beta/alpha channels live entirely in prereleases.
    QUrl url("https://api.github.com/repos/navyas321/vibemis/releases");
    QNetworkRequest request(url);
#if QT_VERSION >= QT_VERSION_CHECK(5, 15, 0)
    request.setAttribute(QNetworkRequest::Http2AllowedAttribute, true);
#else
    request.setAttribute(QNetworkRequest::HTTP2AllowedAttribute, true);
#endif
    m_Nam->get(request);
}

void AutoUpdateChecker::parseStringToVersionQuad(QString& string, QVector<int>& version)
{
    QStringList list = string.split('.');
    for (const QString& component : std::as_const(list)) {
        version.append(component.toInt());
    }
}

QString AutoUpdateChecker::getPlatform()
{
#if defined(STEAM_LINK)
    return QStringLiteral("steamlink");
#elif defined(APP_IMAGE)
    return QStringLiteral("appimage");
#elif defined(Q_OS_DARWIN) && QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    // Qt 6 changed this from 'osx' to 'macos'. Use the old one
    // to be consistent (and not require another entry in the manifest).
    return QStringLiteral("osx");
#else
    return QSysInfo::productType();
#endif
}

int AutoUpdateChecker::compareVersion(QVector<int>& version1, QVector<int>& version2) {
    for (int i = 0;; i++) {
        int v1Val = 0;
        int v2Val = 0;

        // Treat missing decimal places as 0
        if (i < version1.count()) {
            v1Val = version1[i];
        }
        if (i < version2.count()) {
            v2Val = version2[i];
        }
        if (i >= version1.count() && i >= version2.count()) {
            // Equal versions
            return 0;
        }

        if (v1Val < v2Val) {
            return -1;
        }
        else if (v1Val > v2Val) {
            return 1;
        }
    }
}

// Vibemis BL-1665: strip "+<build-metadata>" (e.g. "+b6198e4") — semver says build
// metadata never participates in ordering, and our CI stamps the commit hash there.
static QString stripBuildMetadata(const QString& version)
{
    int plusIdx = version.indexOf('+');
    return plusIdx >= 0 ? version.left(plusIdx) : version;
}

// Vibemis BL-1665: numeric segments of a prerelease suffix, in order. For
// "beta.20260713.0528" that's [20260713, 528]; branch-name segments in alpha tags
// ("alpha.test109-gamescope-scaling.20260713.0528") are skipped, leaving the same
// comparable [date, build-number] key across channels.
static QVector<qlonglong> prereleaseNumericSegments(const QString& prerelease)
{
    QVector<qlonglong> segments;
    const QStringList parts = prerelease.split('.');
    for (const QString& part : parts) {
        bool ok = false;
        qlonglong value = part.toLongLong(&ok);
        if (ok) {
            segments.append(value);
        }
    }
    return segments;
}

// Vibemis BL-1665: ordering for our CI tags ("1.0.1", "1.0.1-beta.20260713.0528+sha",
// "1.0.1-alpha.<branch>.20260713.0528+sha"). Rules:
//   1. numeric base versions compare first (1.0.2-beta.* > 1.0.1);
//   2. equal base: a release with no prerelease suffix outranks any prerelease
//      (semver — and our continuous-beta model cuts stable X only after X's betas);
//   3. two prereleases: their numeric segments (CI date + build number) decide.
// Returns <0 / 0 / >0 like strcmp.
int AutoUpdateChecker::compareSemanticVersions(const QString& v1, const QString& v2)
{
    QString s1 = stripBuildMetadata(v1);
    QString s2 = stripBuildMetadata(v2);

    int dash1 = s1.indexOf('-');
    int dash2 = s2.indexOf('-');
    QString base1 = dash1 >= 0 ? s1.left(dash1) : s1;
    QString base2 = dash2 >= 0 ? s2.left(dash2) : s2;
    QString pre1 = dash1 >= 0 ? s1.mid(dash1 + 1) : QString();
    QString pre2 = dash2 >= 0 ? s2.mid(dash2 + 1) : QString();

    const QStringList baseParts1 = base1.split('.');
    const QStringList baseParts2 = base2.split('.');
    for (int i = 0; i < qMax(baseParts1.count(), baseParts2.count()); i++) {
        int b1 = i < baseParts1.count() ? baseParts1[i].toInt() : 0;
        int b2 = i < baseParts2.count() ? baseParts2[i].toInt() : 0;
        if (b1 != b2) {
            return b1 < b2 ? -1 : 1;
        }
    }

    if (pre1.isEmpty() != pre2.isEmpty()) {
        // Same base: the non-prerelease build is the newer one
        return pre1.isEmpty() ? 1 : -1;
    }
    if (pre1.isEmpty()) {
        return 0;
    }

    QVector<qlonglong> segs1 = prereleaseNumericSegments(pre1);
    QVector<qlonglong> segs2 = prereleaseNumericSegments(pre2);
    for (int i = 0; i < qMax(segs1.count(), segs2.count()); i++) {
        qlonglong p1 = i < segs1.count() ? segs1[i] : 0;
        qlonglong p2 = i < segs2.count() ? segs2[i] : 0;
        if (p1 != p2) {
            return p1 < p2 ? -1 : 1;
        }
    }
    return 0;
}

// Vibemis BL-1665: does this release belong on the given update channel?
// Drafts never do. Stable = a real (non-prerelease) release; Beta/Alpha key off
// the CI tag naming ("<base>-beta.<ts>…" / "<base>-alpha.<branch>.<ts>…").
static bool releaseMatchesChannel(const QJsonObject& release,
                                  StreamingPreferences::UpdateChannel channel)
{
    if (release["draft"].toBool()) {
        return false;
    }
    QString tagName = release["tag_name"].toString();
    switch (channel) {
    case StreamingPreferences::UC_BETA:
        return tagName.contains(QLatin1String("-beta"));
    case StreamingPreferences::UC_ALPHA:
        return tagName.contains(QLatin1String("-alpha"));
    case StreamingPreferences::UC_STABLE:
    default:
        return !release["prerelease"].toBool();
    }
}

// Vibemis BL-1665: browser_download_url of the release's .AppImage asset ("" if none).
static QString appImageAssetUrl(const QJsonObject& release)
{
    const QJsonArray assets = release["assets"].toArray();
    for (const QJsonValue& assetVal : assets) {
        QJsonObject asset = assetVal.toObject();
        if (asset["name"].toString().endsWith(QLatin1String(".AppImage"), Qt::CaseInsensitive)) {
            return asset["browser_download_url"].toString();
        }
    }
    return QString();
}

void AutoUpdateChecker::handleUpdateCheckRequestFinished(QNetworkReply* reply)
{
    Q_ASSERT(reply->isFinished());

    bool manualCheck = m_ManualCheck;
    m_ManualCheck = false;
    m_CheckInFlight = false;

    // Delete the QNetworkAccessManager to free resources and
    // prevent the bearer plugin from polling in the background.
    // (requestReleaseFeed() recreates it for the next check.)
    m_Nam->deleteLater();
    m_Nam = nullptr;

    StreamingPreferences::UpdateChannel channel = StreamingPreferences::get()->updateChannel;
    QString channelName;
    switch (channel) {
    case StreamingPreferences::UC_BETA:
        channelName = tr("Beta");
        break;
    case StreamingPreferences::UC_ALPHA:
        channelName = tr("Alpha");
        break;
    default:
        channelName = tr("Stable");
        break;
    }

    if (reply->error() == QNetworkReply::NoError) {
        QTextStream stream(reply);

#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
        stream.setEncoding(QStringConverter::Utf8);
#else
        stream.setCodec("UTF-8");
#endif

        // Read all data and queue the reply for deletion
        QString jsonString = stream.readAll();
        reply->deleteLater();

        QJsonParseError error;
        QJsonDocument jsonDoc = QJsonDocument::fromJson(jsonString.toUtf8(), &error);
        if (jsonDoc.isNull()) {
            qWarning() << "Update manifest malformed:" << error.errorString();
            if (manualCheck) {
                emit updateCheckFinished(false, QString(), QString(), QString(),
                                         tr("The update feed could not be parsed."));
            }
            return;
        }

        // GitHub API returns an array of releases sorted newest-first
        QJsonArray releasesArray = jsonDoc.array();
        if (releasesArray.isEmpty()) {
            qWarning() << "GitHub API response doesn't contain any releases";
            if (manualCheck) {
                emit updateCheckFinished(false, QString(), QString(), QString(),
                                         tr("No releases were found in the update feed."));
            }
            return;
        }

        // Vibemis: keep wjbeckett's GitHub-Releases-based update path (checks our own
        // navyas321/vibemis releases). Upstream moonlight-qt switched to a server-hosted
        // manifest at this point — not applicable to a fork that publishes via GitHub.
        //
        // BL-1646 established that releasesArray[0] (newest INCLUDING prereleases) must
        // not be offered blindly to stable users. BL-1665 generalizes that stable-only
        // scan to the user's selected channel: take the newest release that belongs to
        // the channel (the feed is newest-first, so the first match wins).
        QJsonObject releaseObj;
        for (const QJsonValue& relVal : std::as_const(releasesArray)) {
            QJsonObject candidate = relVal.toObject();
            if (releaseMatchesChannel(candidate, channel)) {
                releaseObj = candidate;
                break;
            }
        }
        if (releaseObj.isEmpty()) {
            qDebug() << "No release found on the selected update channel";
            if (manualCheck) {
                emit updateCheckFinished(false, QString(), QString(), QString(),
                                         tr("No release has been published on the %1 channel yet.").arg(channelName));
            }
            return;
        }

        // Extract version from tag_name (remove 'v' prefix if present)
        QString tagName = releaseObj["tag_name"].toString();
        QString version = tagName.startsWith("v") ? tagName.mid(1) : tagName;

        if (version.isEmpty()) {
            qWarning() << "GitHub release missing tag_name";
            if (manualCheck) {
                emit updateCheckFinished(false, QString(), QString(), QString(),
                                         tr("The update feed entry is missing its version tag."));
            }
            return;
        }

        qDebug() << "Newest release on channel" << channelName << ":" << version;

        QString htmlUrl = releaseObj["html_url"].toString();
        QString assetUrl = appImageAssetUrl(releaseObj);
        m_LastHtmlUrl = htmlUrl;

        QString current = QStringLiteral(VERSION_STR);
        int res = compareSemanticVersions(current, version);
        if (res < 0) {
            // Strictly newer: light up the toolbar banner (auto + manual)
            qDebug() << "Update available";
            emit onUpdateAvailable(version, htmlUrl);
        }

        if (manualCheck) {
            // A manual check treats ANY different build on the channel as available —
            // after switching channels, "newest on this channel" may be an older
            // version (e.g. Beta → Stable), and that's exactly what the user asked for.
            // NOTE: pre-BL-1665 builds compile VERSION_STR as the bare base version
            // ("1.0.1"), so equal-version detection only becomes exact from the first
            // CI-stamped build onward; those legacy builds just see the newest channel
            // build offered once.
            bool available = QString::compare(stripBuildMetadata(current),
                                              stripBuildMetadata(version),
                                              Qt::CaseInsensitive) != 0;
            QString message;
            if (!available) {
                message = tr("You're up to date — %1 is the newest %2 build.").arg(version, channelName);
            }
            else if (res < 0) {
                message = tr("Update available on the %1 channel: %2").arg(channelName, version);
            }
            else {
                message = tr("The newest %1 channel build is %2 (you are running %3).").arg(channelName, version, current);
            }
            emit updateCheckFinished(available, version, htmlUrl, assetUrl, message);
        }
    }
    else {
        qWarning() << "Update checking failed with error:" << reply->error();
        QString errorString = reply->errorString();
        reply->deleteLater();
        if (manualCheck) {
            emit updateCheckFinished(false, QString(), QString(), QString(),
                                     tr("Update check failed: %1").arg(errorString));
        }
    }
}

void AutoUpdateChecker::installUpdate(QString assetUrl)
{
    QString htmlUrl = m_LastHtmlUrl;

    if (assetUrl.isEmpty()) {
        emit installFailed(tr("This release has no AppImage download."), htmlUrl);
        return;
    }

    QString appImagePath = qEnvironmentVariable("APPIMAGE");
    if (appImagePath.isEmpty()) {
        emit installFailed(tr("Not running as an AppImage — download the update from the release page instead."), htmlUrl);
        return;
    }

    // Download side-by-side with the current binary, then swap atomically and keep
    // the previous build as "<AppImage>.old" for manual rollback. Every failure path
    // leaves a runnable AppImage on disk.
    QString newPath = appImagePath + QStringLiteral(".new");
    QFile* newFile = new QFile(newPath, this);
    if (!newFile->open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        QString error = newFile->errorString();
        newFile->deleteLater();
        emit installFailed(tr("Could not write next to the current AppImage: %1").arg(error), htmlUrl);
        return;
    }

    QNetworkAccessManager* nam = new QNetworkAccessManager(this);
    nam->setStrictTransportSecurityEnabled(true);
    // GitHub asset downloads redirect to a CDN host
    nam->setRedirectPolicy(QNetworkRequest::NoLessSafeRedirectPolicy);

    QNetworkRequest request{QUrl(assetUrl)};
    QNetworkReply* reply = nam->get(request);

    connect(reply, &QNetworkReply::downloadProgress,
            this, &AutoUpdateChecker::installProgress);
    // Stream to disk as bytes arrive — the AppImage is ~45 MB; don't buffer it in RAM
    connect(reply, &QNetworkReply::readyRead, this, [reply, newFile]() {
        newFile->write(reply->readAll());
    });
    connect(reply, &QNetworkReply::finished, this,
            [this, reply, nam, newFile, appImagePath, newPath, htmlUrl]() {
        newFile->write(reply->readAll());
        newFile->close();
        reply->deleteLater();
        nam->deleteLater();

        int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (reply->error() != QNetworkReply::NoError || httpStatus != 200 || newFile->size() == 0) {
            QString error = reply->error() != QNetworkReply::NoError
                    ? reply->errorString()
                    : tr("unexpected HTTP status %1").arg(httpStatus);
            newFile->remove();
            newFile->deleteLater();
            emit installFailed(tr("Download failed: %1").arg(error), htmlUrl);
            return;
        }

        if (!newFile->setPermissions(QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner |
                                     QFile::ReadGroup | QFile::ExeGroup |
                                     QFile::ReadOther | QFile::ExeOther)) {
            newFile->remove();
            newFile->deleteLater();
            emit installFailed(tr("Could not mark the downloaded AppImage executable."), htmlUrl);
            return;
        }
        newFile->deleteLater();

        QString oldPath = appImagePath + QStringLiteral(".old");
        QFile::remove(oldPath);
        if (!QFile::rename(appImagePath, oldPath)) {
            QFile::remove(newPath);
            emit installFailed(tr("Could not replace the current AppImage (read-only filesystem?)."), htmlUrl);
            return;
        }
        if (!QFile::rename(newPath, appImagePath)) {
            // Put the original back so the user still has a working install
            QFile::rename(oldPath, appImagePath);
            QFile::remove(newPath);
            emit installFailed(tr("Swapping in the new AppImage failed; the previous version was restored."), htmlUrl);
            return;
        }

        qInfo() << "Update installed at" << appImagePath << "- relaunching";
        // The running process keeps its mounted (old) image alive; the relaunch
        // picks up the new file. If the relaunch fails the install still succeeded,
        // so quit either way rather than leaving two half-states.
        QProcess::startDetached(appImagePath, QStringList());
        QCoreApplication::quit();
    });
}
