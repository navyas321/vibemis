#include "autoupdatechecker.h"
#include "appimageswap.h"
#include "settings/streamingpreferences.h"

#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QSharedPointer>

#if defined(Q_OS_UNIX)
#include <unistd.h>
#endif

// ── Version comparison (SemVer 2.0.0 §11) ──────────────────────────────────

// Build metadata ("+<sha>") never participates in ordering — our CI stamps the
// commit hash there on some historical tags.
static QString stripBuildMetadata(const QString& version)
{
    int plusIdx = version.indexOf('+');
    return plusIdx >= 0 ? version.left(plusIdx) : version;
}

static bool isNumericIdentifier(const QString& s)
{
    if (s.isEmpty()) {
        return false;
    }
    for (const QChar& c : s) {
        if (!c.isDigit()) {
            return false;
        }
    }
    return true;
}

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

    // Numeric base versions compare first (0.4.0-beta.001 > 0.3.0)
    const QStringList baseParts1 = base1.split('.');
    const QStringList baseParts2 = base2.split('.');
    for (int i = 0; i < qMax(baseParts1.count(), baseParts2.count()); i++) {
        qlonglong b1 = i < baseParts1.count() ? baseParts1[i].toLongLong() : 0;
        qlonglong b2 = i < baseParts2.count() ? baseParts2[i].toLongLong() : 0;
        if (b1 != b2) {
            return b1 < b2 ? -1 : 1;
        }
    }

    // Equal base: a release with no prerelease suffix outranks any prerelease
    if (pre1.isEmpty() != pre2.isEmpty()) {
        return pre1.isEmpty() ? 1 : -1;
    }
    if (pre1.isEmpty()) {
        return 0;
    }

    // Two prereleases: compare dot-separated identifiers left to right.
    // Numeric identifiers compare numerically (leading zeros tolerated — our
    // CI zero-pads counters), alphanumeric ones lexically in ASCII order, and
    // numeric always ranks below alphanumeric. This is what orders
    // "alpha" < "beta" < "rc" at an equal base — the property the previous
    // implementation lacked (it skipped the words and compared only numbers,
    // so 0.3.0-beta.008 wrongly outranked 0.3.0-rc.002).
    const QStringList ids1 = pre1.split('.');
    const QStringList ids2 = pre2.split('.');
    for (int i = 0; i < qMax(ids1.count(), ids2.count()); i++) {
        if (i >= ids1.count()) {
            // Equal prefix, fewer fields = lower precedence (§11.4.4)
            return -1;
        }
        if (i >= ids2.count()) {
            return 1;
        }
        bool num1 = isNumericIdentifier(ids1[i]);
        bool num2 = isNumericIdentifier(ids2[i]);
        if (num1 && num2) {
            qlonglong p1 = ids1[i].toLongLong();
            qlonglong p2 = ids2[i].toLongLong();
            if (p1 != p2) {
                return p1 < p2 ? -1 : 1;
            }
        }
        else if (num1 != num2) {
            // Numeric identifiers rank below alphanumeric ones (§11.4.3)
            return num1 ? -1 : 1;
        }
        else {
            int cmp = QString::compare(ids1[i], ids2[i]);
            if (cmp != 0) {
                return cmp < 0 ? -1 : 1;
            }
        }
    }
    return 0;
}

// ── Release feed interpretation ────────────────────────────────────────────

int AutoUpdateChecker::releaseTier(const QJsonObject& release)
{
    if (release["draft"].toBool()) {
        return -1;
    }

    QString tag = stripBuildMetadata(release["tag_name"].toString());
    if (tag.startsWith('v')) {
        tag = tag.mid(1);
    }

    int dashIdx = tag.indexOf('-');
    if (dashIdx >= 0) {
        // Suffix tags: current scheme ("0.3.0-rc.002") and the legacy suffix
        // era ("…-beta.<ts>", "…-alpha.<branch>.<ts>"). "-dev." builds and
        // unrecognized suffixes are never served.
        QString suffix = tag.mid(dashIdx + 1);
        if (suffix.startsWith(QLatin1String("rc."))) {
            return 2;
        }
        if (suffix.startsWith(QLatin1String("beta"))) {
            return 1;
        }
        if (suffix.startsWith(QLatin1String("alpha"))) {
            return 0;
        }
        return -1;
    }

    const QStringList parts = tag.split('.');
    if (parts.count() == 4) {
        // Legacy W.X.Y.Z structural scheme: Y>0 = beta, Z>0 + prerelease-flag
        // = alpha, Y==0 with a free Z (hotfix counter) = stable.
        qlonglong y = parts[2].toLongLong();
        qlonglong z = parts[3].toLongLong();
        if (z > 0 && release["prerelease"].toBool()) {
            return 0;
        }
        if (y > 0 && z == 0) {
            return 1;
        }
        if (y == 0 && !release["prerelease"].toBool()) {
            return 3;
        }
        return -1;
    }

    // Bare semver tags ("0.2.0") are stable — unless the release was parked
    // (flipped to prerelease after the fact), which pulls it from every channel.
    return release["prerelease"].toBool() ? -1 : 3;
}

int AutoUpdateChecker::channelFloor(int updateChannel)
{
    switch (updateChannel) {
    case StreamingPreferences::UC_ALPHA:
        return 0;
    case StreamingPreferences::UC_BETA:
        return 1;
    case StreamingPreferences::UC_RC:
        return 2;
    case StreamingPreferences::UC_STABLE:
    default:
        return 3;
    }
}

QString AutoUpdateChecker::appImageAssetUrl(const QJsonObject& release)
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

// ── Lifecycle ──────────────────────────────────────────────────────────────

AutoUpdateChecker::AutoUpdateChecker(QObject *parent) :
    QObject(parent),
    m_CheckInFlight(false),
    m_CheckIsManual(false),
    m_UpdateAvailable(false),
    m_OfferAvailable(false),
    m_Installing(false)
{
    // One persistent QNAM. (The old implementation tore its manager down after
    // every check to silence the Qt 5 bearer plugin's background polling; Qt 6
    // removed bearer management, so the churn bought nothing.)
    m_Nam.setStrictTransportSecurityEnabled(true);
    m_Nam.setRedirectPolicy(QNetworkRequest::NoLessSafeRedirectPolicy);

    m_RecheckTimer.setInterval(RECHECK_INTERVAL_MS);
    connect(&m_RecheckTimer, &QTimer::timeout, this, [this]() {
        performCheck(false);
    });

    m_StatusMessage = tr("Current version: %1").arg(currentVersion());

    qDebug() << "Current Vibemis version:" << currentVersion();
}

void AutoUpdateChecker::start()
{
#if defined(Q_OS_WIN32) || defined(Q_OS_DARWIN) || defined(STEAM_LINK) || defined(APP_IMAGE)
    // Only platforms without an external update mechanism self-check. A
    // launch-only check left users blind to anything published while the app
    // was running (the 0.3.3 incident), so re-check periodically too.
    performCheck(false);
    m_RecheckTimer.start();
#endif
}

void AutoUpdateChecker::checkNow()
{
    // User-initiated — no platform gate; a dev/desktop build can still check
    // the feed even though it can't self-install ($APPIMAGE unset).
    performCheck(true);
}

bool AutoUpdateChecker::canInstallUpdates() const
{
    return !qEnvironmentVariable("APPIMAGE").isEmpty();
}

QString AutoUpdateChecker::currentVersion() const
{
    return QStringLiteral(VERSION_STR);
}

bool AutoUpdateChecker::canInstall() const
{
    return m_OfferAvailable && !m_AssetUrl.isEmpty()
            && canInstallUpdates() && !m_Installing;
}

void AutoUpdateChecker::clearOffer()
{
    m_UpdateAvailable = false;
    m_OfferAvailable = false;
    m_OfferVersion.clear();
    m_ReleaseUrl.clear();
    m_AssetUrl.clear();
    m_OfferTier = -1;
}

void AutoUpdateChecker::setStatus(const QString& message)
{
    if (m_StatusMessage != message) {
        m_StatusMessage = message;
        emit stateChanged();
    }
}

void AutoUpdateChecker::channelChanged()
{
    clearOffer();
    m_StatusMessage = tr("Channel changed — check for updates to see this channel's newest build.");
    emit stateChanged();
}

// ── Checking ───────────────────────────────────────────────────────────────

void AutoUpdateChecker::performCheck(bool manual)
{
    if (m_CheckInFlight) {
        // One check at a time; a manual click during an in-flight auto check
        // upgrades that check to a reporting one.
        if (manual && !m_CheckIsManual) {
            m_CheckIsManual = true;
            setStatus(tr("Checking for updates…"));
        }
        return;
    }

    m_CheckInFlight = true;
    m_CheckIsManual = manual;
    if (manual) {
        m_StatusMessage = tr("Checking for updates…");
    }
    emit stateChanged();

    // All releases including prereleases (ordered by created_at, not by version
    // — the selection loop below sorts). Never /releases/latest
    // — it can't see prereleases, and the beta/alpha/rc channels live there.
    // per_page=100 (default 30): the newest build a channel serves — the
    // stable, after a dense prerelease cycle — can sit dozens of entries deep.
    QUrl url("https://api.github.com/repos/navyas321/vibemis/releases?per_page=100");
    QNetworkRequest request(url);
    request.setRawHeader("Accept", "application/vnd.github+json");
    request.setRawHeader("User-Agent", "Vibemis-Updater/" VERSION_STR);
    // A hung feed must not wedge the checker forever (m_CheckInFlight gates
    // every future check).
    request.setTransferTimeout(30000);

    QNetworkReply* reply = m_Nam.get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        bool manualAtCompletion = m_CheckIsManual;
        m_CheckInFlight = false;
        m_CheckIsManual = false;
        handleFeedReply(reply, manualAtCompletion);
    });
}

void AutoUpdateChecker::handleFeedReply(QNetworkReply* reply, bool manual)
{
    reply->deleteLater();

    StreamingPreferences::UpdateChannel channel = StreamingPreferences::get()->updateChannel;
    QString channelName;
    switch (channel) {
    case StreamingPreferences::UC_BETA:
        channelName = tr("Beta");
        break;
    case StreamingPreferences::UC_ALPHA:
        channelName = tr("Alpha");
        break;
    case StreamingPreferences::UC_RC:
        channelName = tr("Release candidate");
        break;
    default:
        channelName = tr("Stable");
        break;
    }

    if (reply->error() != QNetworkReply::NoError) {
        qWarning() << "Update check failed:" << reply->error() << reply->errorString();
        if (manual) {
            setStatus(tr("Update check failed: %1").arg(reply->errorString()));
        }
        emit stateChanged();
        emit checkCompleted(manual, false);
        return;
    }

    QJsonParseError parseError;
    QJsonDocument jsonDoc = QJsonDocument::fromJson(reply->readAll(), &parseError);
    if (!jsonDoc.isArray()) {
        qWarning() << "Update feed malformed:" << parseError.errorString();
        if (manual) {
            setStatus(tr("The update feed could not be parsed."));
        }
        emit stateChanged();
        emit checkCompleted(manual, false);
        return;
    }

    // Pick the HIGHEST-VERSIONED release at or above the channel's stability floor
    // that actually ships an .AppImage — never merely the first one listed.
    // /releases is ordered by created_at, NOT by publish time or version: a hotfix
    // cut from an older commit (the version_override flow) lands further down the
    // feed than a newer prerelease, so "take the first match" could offer a Stable
    // user an OLDER stable than the newest one. Assetless entries (historical
    // catalog markers) are skipped so they can't shadow a real build.
    const QJsonArray releasesArray = jsonDoc.array();
    int floor = channelFloor(channel);
    QJsonObject releaseObj;
    QString bestVersion;
    for (const QJsonValue& relVal : releasesArray) {
        QJsonObject candidate = relVal.toObject();
        if (releaseTier(candidate) < floor || appImageAssetUrl(candidate).isEmpty()) {
            continue;
        }
        QString candTag = candidate["tag_name"].toString();
        QString candVersion = candTag.startsWith('v') ? candTag.mid(1) : candTag;
        if (releaseObj.isEmpty() || compareSemanticVersions(bestVersion, candVersion) < 0) {
            releaseObj = candidate;
            bestVersion = candVersion;
        }
    }

    if (releaseObj.isEmpty()) {
        qDebug() << "No installable release on channel" << channelName;
        clearOffer();
        if (manual) {
            setStatus(tr("No release has been published on the %1 channel yet.").arg(channelName));
        }
        emit stateChanged();
        emit checkCompleted(manual, false);
        return;
    }

    QString tagName = releaseObj["tag_name"].toString();
    QString version = tagName.startsWith('v') ? tagName.mid(1) : tagName;
    QString current = currentVersion();

    qDebug() << "Newest release on channel" << channelName << ":" << version;

    // A manual check treats ANY different build on the channel as an offer —
    // right after switching channels, "newest on this channel" may be an older
    // version (e.g. Beta → Stable), and that's exactly what the user asked
    // for. The toolbar banner (updateAvailable) stays strictly-newer only.
    bool different = QString::compare(stripBuildMetadata(current),
                                      stripBuildMetadata(version),
                                      Qt::CaseInsensitive) != 0;
    int cmp = compareSemanticVersions(current, version);

    m_OfferAvailable = different;
    m_UpdateAvailable = different && cmp < 0;
    m_OfferVersion = different ? version : QString();
    m_ReleaseUrl = releaseObj["html_url"].toString();
    m_AssetUrl = different ? appImageAssetUrl(releaseObj) : QString();
    m_OfferTier = different ? releaseTier(releaseObj) : -1;

    if (manual) {
        if (!different) {
            m_StatusMessage = tr("You're up to date — %1 is the newest %2 build.").arg(version, channelName);
        }
        else if (cmp < 0) {
            m_StatusMessage = tr("Update available on the %1 channel: %2").arg(channelName, version);
        }
        else {
            m_StatusMessage = tr("The newest %1 channel build is %2 (you are running %3).").arg(channelName, version, current);
        }
    }
    else if (m_UpdateAvailable) {
        m_StatusMessage = tr("Update available on the %1 channel: %2").arg(channelName, version);
    }

    emit stateChanged();
    emit checkCompleted(manual, m_OfferAvailable);
}

// ── Installing ─────────────────────────────────────────────────────────────

void AutoUpdateChecker::install()
{
    if (!canInstall()) {
        return;
    }

    // Defense in depth: re-assert the offer against the LIVE channel floor right
    // before downloading. "A Stable user must never receive a prerelease" is a
    // hard requirement, so it is enforced at the point of no return too — not
    // only where the offer was built. Catches a stale offer left over from a
    // channel change and any future regression in the selection loop (BL-2437).
    int liveFloor = channelFloor(StreamingPreferences::get()->updateChannel);
    if (m_OfferTier < liveFloor) {
        qWarning() << "Refusing to install tier" << m_OfferTier
                   << "build below the current channel floor" << liveFloor;
        clearOffer();
        m_StatusMessage = tr("That build isn't on your update channel any more — check for updates again.");
        emit stateChanged();
        return;
    }

    QString appImagePath = qEnvironmentVariable("APPIMAGE");
    QString assetUrl = m_AssetUrl;

    m_Installing = true;
    m_StatusMessage = tr("Downloading update…");
    emit stateChanged();

    // Download side-by-side with the current binary (same directory = same
    // filesystem, pid-unique name), fsync, then swap names atomically via
    // AppImageSwap and keep the previous build as "<AppImage>.old" for manual
    // rollback. Bytes are NEVER written into the live target path — the
    // running build's squashfs is mounted from that inode, and overwriting it
    // in place SIGBUSes every running instance (BL-2259). Every failure path
    // leaves a runnable AppImage on disk, drops the offer's asset (so the
    // next click falls back to the release page) and emits installFailed.
    auto fail = [this](const QString& error) {
        m_Installing = false;
        m_AssetUrl.clear();
        m_StatusMessage = tr("Install failed: %1").arg(error);
        emit stateChanged();
        emit installFailed(error, m_ReleaseUrl);
    };

    // A previous crashed/killed install may have stranded full-size staging
    // files next to the target — clear them before writing a fresh one.
    AppImageSwap::sweepStaleStaging(appImagePath);

    QString newPath = AppImageSwap::stagingPath(appImagePath,
                                                QCoreApplication::applicationPid());
    QFile* newFile = new QFile(newPath, this);
    if (!newFile->open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        QString error = newFile->errorString();
        newFile->deleteLater();
        fail(tr("Could not write next to the current AppImage: %1").arg(error));
        return;
    }

    QNetworkRequest request{QUrl(assetUrl)};
    request.setRawHeader("User-Agent", "Vibemis-Updater/" VERSION_STR);
    // Inactivity timeout — resets whenever bytes flow, so it can never abort a
    // slow-but-healthy download, only a black-holed one (which would otherwise
    // wedge m_Installing forever).
    request.setTransferTimeout(30000);
    QNetworkReply* reply = m_Nam.get(request);

    connect(reply, &QNetworkReply::downloadProgress, this,
            [this](qint64 bytesReceived, qint64 bytesTotal) {
        emit installProgress(bytesReceived, bytesTotal);
        if (bytesTotal > 0) {
            setStatus(tr("Downloading update… %1%").arg((int)(bytesReceived * 100 / bytesTotal)));
        }
        else {
            setStatus(tr("Downloading update… %1 MB").arg(QString::number(bytesReceived / 1048576.0, 'f', 1)));
        }
    });
    // Stream to disk as bytes arrive — the AppImage is ~90 MB; don't buffer it
    // in RAM. Track what actually hit the file so a short write (disk full)
    // can never masquerade as a complete download.
    auto bytesWritten = QSharedPointer<qint64>::create(0);
    auto writeFailed = QSharedPointer<bool>::create(false);
    connect(reply, &QNetworkReply::readyRead, this, [reply, newFile, bytesWritten, writeFailed]() {
        QByteArray chunk = reply->readAll();
        qint64 written = newFile->write(chunk);
        if (written != chunk.size()) {
            *writeFailed = true;
            reply->abort();
            return;
        }
        *bytesWritten += written;
    });
    connect(reply, &QNetworkReply::finished, this,
            [this, reply, newFile, appImagePath, newPath, fail, bytesWritten, writeFailed]() {
        QByteArray tail = reply->readAll();
        if (!tail.isEmpty() && !*writeFailed) {
            qint64 written = newFile->write(tail);
            if (written != tail.size()) {
                *writeFailed = true;
            }
            else {
                *bytesWritten += written;
            }
        }
        // Force the bytes to stable storage BEFORE the file can be renamed
        // into place: close() only hands Qt's buffer to the page cache, and a
        // crash between the swap and the kernel's own writeback would
        // otherwise leave a zero/partial-length AppImage at the stable path
        // (the classic rename-without-fsync window).
        bool synced = newFile->flush();
#if defined(Q_OS_UNIX)
        synced = synced && ::fsync(newFile->handle()) == 0;
#endif
        newFile->close();
        reply->deleteLater();

        // A truncated body must never be swapped in: require the transport to
        // have succeeded AND every byte to have reached the file AND the byte
        // count to match the advertised Content-Length (when the server sent one).
        qint64 expected = reply->header(QNetworkRequest::ContentLengthHeader).toLongLong();
        int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (reply->error() != QNetworkReply::NoError || httpStatus != 200 || *writeFailed
                || !synced || *bytesWritten == 0 || newFile->size() != *bytesWritten
                || (expected > 0 && *bytesWritten != expected)) {
            QString error;
            if (*writeFailed || !synced) {
                error = tr("could not write the full file (disk full?)");
            }
            else if (reply->error() != QNetworkReply::NoError) {
                error = reply->errorString();
            }
            else if (httpStatus != 200) {
                error = tr("unexpected HTTP status %1").arg(httpStatus);
            }
            else {
                error = tr("incomplete download (%1 of %2 bytes)").arg(*bytesWritten).arg(expected);
            }
            newFile->remove();
            newFile->deleteLater();
            fail(tr("Download failed: %1").arg(error));
            return;
        }

        if (!newFile->setPermissions(QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner |
                                     QFile::ReadGroup | QFile::ExeGroup |
                                     QFile::ReadOther | QFile::ExeOther)) {
            newFile->remove();
            newFile->deleteLater();
            fail(tr("Could not mark the downloaded AppImage executable."));
            return;
        }
        newFile->deleteLater();

        // Pure-rename swap (see appimageswap.cpp): current -> .old backup,
        // then staging -> current, both plain rename(2). Any failure rolls
        // the previous build back into place before reporting.
        switch (AppImageSwap::swap(appImagePath, newPath)) {
        case AppImageSwap::BackupRenameFailed:
            fail(tr("Could not replace the current AppImage (read-only filesystem?)."));
            return;
        case AppImageSwap::SwapRenameFailed:
            fail(tr("Swapping in the new AppImage failed; the previous version was restored."));
            return;
        case AppImageSwap::SwapOk:
            break;
        }

        qInfo() << "Update installed at" << appImagePath;
        m_Installing = false;
        m_StatusMessage = tr("Update installed — restarting…");
        emit stateChanged();
        emit installCompleted(appImagePath);
        // Under the update-selftest harness the swap is the end of the story —
        // the harness verifies the file and controls process exit (relaunching
        // a scratch AppImage would spawn a stray GUI). The production path
        // relaunches and quits: the running process keeps its mounted (old)
        // image alive; the relaunch picks up the new file. If the relaunch
        // fails the install still succeeded, so quit either way rather than
        // leaving two half-states.
        if (!qEnvironmentVariableIsSet("VIBEMIS_UPDATE_SELFTEST")) {
            // BL-2266: launch the new build from a neutral working directory.
            // Inheriting our CWD could hand the child a directory inside a
            // FUSE mount whose teardown is tied to our exit (keeping the old
            // mount busy past our death); paired with the startup fd-seal in
            // main.cpp (sealAppImageRuntimeFds), this fully decouples the
            // relaunched instance from the dying instance's mount lifetime.
            QProcess::startDetached(appImagePath, QStringList(), QDir::homePath());
            QCoreApplication::quit();
        }
    });
}
