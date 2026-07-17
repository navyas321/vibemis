#pragma once

#include <QObject>
#include <QString>

class StreamingPreferences;

/**
 * @brief Per-game stream profiles (Android-parity headline feature)
 *
 * Persists a small set of stream settings (resolution, FPS, bitrate, HDR) per
 * host+app in QSettings under `appprofiles/<computerUuid>/<appId>/...`. When a
 * profile exists for the app being launched, Session runs on a private
 * StreamingPreferences copy with the profile applied — the global preferences
 * object (and whatever the Settings UI later saves) is never touched.
 *
 * Saving a profile snapshots the CURRENT global settings; there is no separate
 * profile editor in this first slice. Set your resolution/FPS/bitrate/HDR in
 * Settings, then "save for this game" from the app grid's context menu.
 */
class AppProfileManager : public QObject
{
    Q_OBJECT

public:
    explicit AppProfileManager(QObject *parent = nullptr);

    Q_INVOKABLE bool hasProfile(const QString& computerUuid, int appId) const;

    // Human-readable one-liner for menus/tooltips, e.g. "1920x1200 @ 120 FPS, 30 Mbps, HDR".
    // Empty string if no profile is stored.
    Q_INVOKABLE QString profileSummary(const QString& computerUuid, int appId) const;

    // Snapshot the current global StreamingPreferences into this app's profile.
    Q_INVOKABLE void saveCurrentAsProfile(const QString& computerUuid, int appId);

    Q_INVOKABLE void clearProfile(const QString& computerUuid, int appId);

    // Overwrite the stream-shape fields of 'prefs' from the stored profile.
    // Returns true if a profile existed and was applied. Never persists anything.
    static bool applyProfile(StreamingPreferences* prefs, const QString& computerUuid, int appId);

    static bool hasProfileStatic(const QString& computerUuid, int appId);

private:
    static QString profileGroup(const QString& computerUuid, int appId);
};
