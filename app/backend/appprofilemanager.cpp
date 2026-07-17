#include "appprofilemanager.h"
#include "settings/streamingpreferences.h"

#include <QSettings>

#include <SDL.h>

#define SER_APPPROFILES "appprofiles"
#define SER_PROF_WIDTH "width"
#define SER_PROF_HEIGHT "height"
#define SER_PROF_FPS "fps"
#define SER_PROF_BITRATE "bitrate"
#define SER_PROF_HDR "hdr"

AppProfileManager::AppProfileManager(QObject *parent)
    : QObject(parent)
{
}

QString AppProfileManager::profileGroup(const QString& computerUuid, int appId)
{
    // QSettings splits on '/', so a uuid (no slashes) and an int are safe key parts.
    return QStringLiteral(SER_APPPROFILES "/%1/%2").arg(computerUuid).arg(appId);
}

bool AppProfileManager::hasProfileStatic(const QString& computerUuid, int appId)
{
    if (computerUuid.isEmpty() || appId == 0) {
        return false;
    }

    QSettings settings;
    return settings.contains(profileGroup(computerUuid, appId) + "/" SER_PROF_WIDTH);
}

bool AppProfileManager::hasProfile(const QString& computerUuid, int appId) const
{
    return hasProfileStatic(computerUuid, appId);
}

QString AppProfileManager::profileSummary(const QString& computerUuid, int appId) const
{
    if (!hasProfileStatic(computerUuid, appId)) {
        return QString();
    }

    QSettings settings;
    settings.beginGroup(profileGroup(computerUuid, appId));
    QString summary = QStringLiteral("%1x%2 @ %3 FPS, %4 Mbps%5")
            .arg(settings.value(SER_PROF_WIDTH).toInt())
            .arg(settings.value(SER_PROF_HEIGHT).toInt())
            .arg(settings.value(SER_PROF_FPS).toInt())
            .arg(settings.value(SER_PROF_BITRATE).toInt() / 1000.0, 0, 'g', 3)
            .arg(settings.value(SER_PROF_HDR).toBool() ? QStringLiteral(", HDR") : QString());
    settings.endGroup();
    return summary;
}

void AppProfileManager::saveCurrentAsProfile(const QString& computerUuid, int appId)
{
    if (computerUuid.isEmpty() || appId == 0) {
        return;
    }

    StreamingPreferences* prefs = StreamingPreferences::get();

    QSettings settings;
    settings.beginGroup(profileGroup(computerUuid, appId));
    settings.setValue(SER_PROF_WIDTH, prefs->width);
    settings.setValue(SER_PROF_HEIGHT, prefs->height);
    settings.setValue(SER_PROF_FPS, prefs->fps);
    settings.setValue(SER_PROF_BITRATE, prefs->bitrateKbps);
    settings.setValue(SER_PROF_HDR, prefs->enableHdr);
    settings.endGroup();

    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "AppProfileManager: saved profile for app %d on %s: %dx%d@%d %d kbps HDR=%d",
                appId, computerUuid.toUtf8().constData(),
                prefs->width, prefs->height, prefs->fps, prefs->bitrateKbps, prefs->enableHdr);
}

void AppProfileManager::clearProfile(const QString& computerUuid, int appId)
{
    QSettings settings;
    settings.remove(profileGroup(computerUuid, appId));

    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "AppProfileManager: cleared profile for app %d on %s",
                appId, computerUuid.toUtf8().constData());
}

bool AppProfileManager::applyProfile(StreamingPreferences* prefs, const QString& computerUuid, int appId)
{
    if (!hasProfileStatic(computerUuid, appId)) {
        return false;
    }

    QSettings settings;
    settings.beginGroup(profileGroup(computerUuid, appId));
    prefs->width = settings.value(SER_PROF_WIDTH, prefs->width).toInt();
    prefs->height = settings.value(SER_PROF_HEIGHT, prefs->height).toInt();
    prefs->fps = settings.value(SER_PROF_FPS, prefs->fps).toInt();
    prefs->bitrateKbps = settings.value(SER_PROF_BITRATE, prefs->bitrateKbps).toInt();
    prefs->enableHdr = settings.value(SER_PROF_HDR, prefs->enableHdr).toBool();
    settings.endGroup();

    // A profile pins the exact stream shape — don't let the global resolution-scaling
    // toggle silently rescale it (e.g. a saved 1920x1200 profile streaming at 960x600
    // because global 50% scaling was enabled later).
    prefs->enableResolutionScaling = false;

    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "AppProfileManager: applying per-app profile for app %d on %s: %dx%d@%d %d kbps HDR=%d",
                appId, computerUuid.toUtf8().constData(),
                prefs->width, prefs->height, prefs->fps, prefs->bitrateKbps, prefs->enableHdr);
    return true;
}
