#include "steamshortcut.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTemporaryFile>
#include <QHash>
#include <QVector>
#include <cstdio>
#include <cstring>

#ifdef Q_OS_LINUX

namespace {

const char kAppName[] = "Vibemis";

// Minimal, defensive binary-VDF (Steam shortcuts.vdf) node model.
// type: 0x00 = map, 0x01 = string, 0x02 = int32.
struct VdfNode
{
    quint8 type = 0x00;
    QString key;
    QString strVal;
    qint32 intVal = 0;
    QVector<VdfNode> children;
};

bool readCString(const QByteArray &data, int &pos, QString &out)
{
    int start = pos;
    while (pos < data.size() && data.at(pos) != '\0') {
        ++pos;
    }
    if (pos >= data.size()) {
        return false; // unterminated string - malformed
    }
    out = QString::fromUtf8(data.mid(start, pos - start));
    ++pos; // skip the null terminator
    return true;
}

bool parseMap(const QByteArray &data, int &pos, QVector<VdfNode> &out, int depth)
{
    if (depth > 32) {
        return false; // guard against pathological/corrupt input
    }
    while (true) {
        if (pos >= data.size()) {
            return false; // truncated - malformed
        }
        quint8 t = static_cast<quint8>(data.at(pos));
        ++pos;
        if (t == 0x08) {
            return true; // end of this map
        }
        VdfNode node;
        node.type = t;
        if (!readCString(data, pos, node.key)) {
            return false;
        }
        if (t == 0x00) {
            if (!parseMap(data, pos, node.children, depth + 1)) {
                return false;
            }
        } else if (t == 0x01) {
            if (!readCString(data, pos, node.strVal)) {
                return false;
            }
        } else if (t == 0x02) {
            if (pos + 4 > data.size()) {
                return false;
            }
            qint32 v;
            memcpy(&v, data.constData() + pos, 4);
            node.intVal = v;
            pos += 4;
        } else {
            return false; // unrecognized field type - be conservative, don't guess
        }
        out.append(node);
    }
}

void writeMap(QByteArray &out, const QVector<VdfNode> &nodes)
{
    for (const VdfNode &node : nodes) {
        out.append(static_cast<char>(node.type));
        out.append(node.key.toUtf8());
        out.append('\0');
        if (node.type == 0x00) {
            writeMap(out, node.children);
            out.append(static_cast<char>(0x08));
        } else if (node.type == 0x01) {
            out.append(node.strVal.toUtf8());
            out.append('\0');
        } else if (node.type == 0x02) {
            qint32 v = node.intVal;
            out.append(reinterpret_cast<const char *>(&v), sizeof(v));
        }
    }
}

VdfNode *findChild(QVector<VdfNode> &nodes, const QString &key)
{
    for (VdfNode &n : nodes) {
        if (n.key.compare(key, Qt::CaseInsensitive) == 0) {
            return &n;
        }
    }
    return nullptr;
}

// Same CRC-32/appid derivation Steam itself uses to key non-Steam shortcuts.
qint32 computeAppId(const QString &exe, const QString &name)
{
    // Magic static: C++11 guarantees the initializer runs exactly once, even under
    // concurrent first calls. The previous `static QVector; if (isEmpty()) fill;` form
    // guarded construction but not the lazy fill -- benign while ensureRegistered() was
    // the only caller, fragile now that entryAppId() reaches it too.
    static const QVector<quint32> table = [] {
        QVector<quint32> t(256);
        for (int i = 0; i < 256; ++i) {
            quint32 c = static_cast<quint32>(i);
            for (int j = 0; j < 8; ++j) {
                c = (c & 1) ? (0xEDB88320u ^ (c >> 1)) : (c >> 1);
            }
            t[i] = c;
        }
        return t;
    }();
    const QByteArray combined = (exe + name).toUtf8();
    quint32 crc = 0xFFFFFFFFu;
    for (unsigned char byte : combined) {
        crc = table[(crc ^ byte) & 0xFF] ^ (crc >> 8);
    }
    crc = ~crc;
    const quint32 v = crc | 0x80000000u;
    return static_cast<qint32>(v);
}

VdfNode makeStringField(const QString &key, const QString &val)
{
    VdfNode n;
    n.type = 0x01;
    n.key = key;
    n.strVal = val;
    return n;
}

VdfNode makeIntField(const QString &key, qint32 val)
{
    VdfNode n;
    n.type = 0x02;
    n.key = key;
    n.intVal = val;
    return n;
}

QVector<VdfNode> buildShortcutFields(const QString &exe, const QString &startDir, const QString &icon)
{
    QVector<VdfNode> fields;
    fields.append(makeIntField("appid", computeAppId(exe, kAppName)));
    fields.append(makeStringField("AppName", kAppName));
    fields.append(makeStringField("Exe", QStringLiteral("\"%1\"").arg(exe)));
    fields.append(makeStringField("StartDir", QStringLiteral("\"%1\"").arg(startDir)));
    fields.append(makeStringField("icon", icon));
    fields.append(makeStringField("ShortcutPath", QString()));
    fields.append(makeStringField("LaunchOptions", QString()));
    fields.append(makeIntField("IsHidden", 0));
    fields.append(makeIntField("AllowDesktopConfig", 1));
    fields.append(makeIntField("AllowOverlay", 1));
    fields.append(makeIntField("OpenVR", 0));
    fields.append(makeIntField("Devkit", 0));
    fields.append(makeStringField("DevkitGameID", QString()));
    fields.append(makeIntField("DevkitOverrideAppID", 0));
    fields.append(makeIntField("LastPlayTime", 0));
    fields.append(makeStringField("FlatpakAppID", QString()));
    VdfNode tags;
    tags.type = 0x00;
    tags.key = QStringLiteral("tags");
    fields.append(tags);
    return fields;
}

// Writes the app's own window-icon resource to a stable icon-theme path.
// Returns the icon path on success, or an empty string on failure.
QString ensureIconOnDisk()
{
    const QString dir = QDir::homePath() + QStringLiteral("/.local/share/icons/hicolor/256x256/apps");
    const QString dest = dir + QStringLiteral("/vibemis.png");
    if (QFile::exists(dest)) {
        return dest;
    }
    if (!QDir().mkpath(dir)) {
        return QString();
    }
    QFile src(QStringLiteral(":/res/vibemis-mark-256.png"));
    if (!src.open(QIODevice::ReadOnly)) {
        return QString();
    }
    const QByteArray bytes = src.readAll();
    src.close();
    if (bytes.isEmpty()) {
        return QString();
    }
    QFile out(dest);
    if (!out.open(QIODevice::WriteOnly)) {
        return QString();
    }
    out.write(bytes);
    out.close();
    return dest;
}

// Installs the Steam LIBRARY ARTWORK for our shortcut.
//
// The `icon` field above only feeds Steam's small list icon. The library tile is a
// separate mechanism entirely: Steam looks for PNGs in <config>/grid/ named after the
// shortcut's appid, and with none present it draws a flat coloured rectangle with the
// app name in plain text. That is why Vibemis was the one entry in Game Mode that
// looked like a placeholder while apps beside it showed full hero art.
//
//   <appid>p.png      600x900   portrait capsule -- the library grid tile
//   <appid>.png       920x430   landscape capsule
//   <appid>_hero.png  1920x620  hero banner behind the detail page
//   <appid>_logo.png  transparent, composited over the hero BY Steam
//   <appid>_icon.png  256x256
//
// Idempotent: a size check short-circuits the common "already current" case to one
// stat() per asset, and a new build shipping new artwork still refreshes the tile
// automatically.
//
// It will NOT clobber artwork the user chose. A digest of what we last wrote is kept in
// grid/.vibemis-artwork, so a file that is neither the bundled asset nor our own
// previous write is treated as the user's (SteamGridDB, Decky, steam-rom-manager) and
// left alone. Without that record the staleness test is just "differs from bundled
// asset", which is true forever for custom art -- so this would silently re-theme a
// deliberately customised library on every single launch, with no way to opt out.
//
// Best-effort by design. Library decoration must never interfere with launching the
// app, so every failure path here is a silent no-op.
void ensureGridArtwork(const QString &cfgDir, qint32 appId)
{
    static const struct { const char *suffix; const char *resource; } assets[] = {
        { "p",     ":/res/steam/vibemis_p.png" },
        { "",      ":/res/steam/vibemis.png" },
        { "_hero", ":/res/steam/vibemis_hero.png" },
        { "_logo", ":/res/steam/vibemis_logo.png" },
        { "_icon", ":/res/steam/vibemis_icon.png" },
    };

    // Steam keys grid files by the UNSIGNED appid; computeAppId() returns it as qint32
    // (the width shortcuts.vdf stores), so the high-bit-set value arrives negative.
    // Formatting that directly would produce "-591349104p.png", which Steam never reads.
    const quint32 unsignedId = static_cast<quint32>(appId);
    const QString gridDir = cfgDir + QStringLiteral("/grid");

    // What we wrote last time, so we can tell OUR stale artwork apart from artwork the
    // USER chose. Without this the staleness check is just "bytes != bundled asset",
    // which is true forever for SteamGridDB/Decky/steam-rom-manager art -- so every
    // launch would silently overwrite a deliberately themed library, permanently and
    // with no way to opt out. Steam ignores dotfiles in grid/.
    const QString stateFile = gridDir + QStringLiteral("/.vibemis-artwork");
    QHash<QString, QByteArray> priorDigests;
    {
        QFile sf(stateFile);
        if (sf.open(QIODevice::ReadOnly | QIODevice::Text)) {
            const QList<QByteArray> lines = sf.readAll().split('\n');
            for (const QByteArray &line : lines) {
                const int sep = line.indexOf('=');
                if (sep > 0) {
                    priorDigests.insert(QString::fromUtf8(line.left(sep)), line.mid(sep + 1).trimmed());
                }
            }
            sf.close();
        }
    }

    // Sweep any temp file a previous crash left behind; grid/ is a directory Steam scans.
    {
        QDir gd(gridDir);
        const auto strays = gd.entryList({ QStringLiteral("*.vibemis-tmp") }, QDir::Files);
        for (const QString &stray : strays) {
            QFile::remove(gd.filePath(stray));
        }
    }

    QHash<QString, QByteArray> newDigests = priorDigests;
    bool stateDirty = false;

    for (const auto &a : assets) {
        QFile src(QLatin1String(a.resource));
        if (!src.open(QIODevice::ReadOnly)) {
            continue; // artwork missing from this build - nothing sensible to do
        }
        const QByteArray bytes = src.readAll();
        src.close();
        if (bytes.isEmpty()) {
            continue;
        }
        const QByteArray wantDigest =
            QCryptographicHash::hash(bytes, QCryptographicHash::Sha256).toHex();

        const QString key = QLatin1String(a.suffix[0] ? a.suffix : "capsule");
        const QString dest = gridDir + QStringLiteral("/") + QString::number(unsignedId)
                             + QLatin1String(a.suffix) + QStringLiteral(".png");

        QFileInfo destInfo(dest);
        if (destInfo.exists()) {
            // Size first: a mismatch rules out equality without reading a 100 KB PNG,
            // which keeps the steady-state launch cost to a stat() per asset.
            QByteArray haveDigest;
            if (destInfo.size() == bytes.size()) {
                QFile df(dest);
                if (df.open(QIODevice::ReadOnly)) {
                    haveDigest = QCryptographicHash::hash(df.readAll(),
                                                          QCryptographicHash::Sha256).toHex();
                    df.close();
                }
                if (haveDigest == wantDigest) {
                    if (newDigests.value(key) != wantDigest) {
                        newDigests.insert(key, wantDigest);
                        stateDirty = true;
                    }
                    continue; // already current
                }
            }
            // Present, and not what we are about to write. Only replace it if it is
            // OUR previous artwork; anything else is the user's and stays.
            const QByteArray prior = priorDigests.value(key);
            if (prior.isEmpty()) {
                continue; // never written by us -> user's art (or pre-dates this feature)
            }
            if (haveDigest.isEmpty()) {
                QFile df(dest);
                if (!df.open(QIODevice::ReadOnly)) {
                    continue;
                }
                haveDigest = QCryptographicHash::hash(df.readAll(),
                                                      QCryptographicHash::Sha256).toHex();
                df.close();
            }
            if (haveDigest != prior) {
                continue; // user replaced our tile since we wrote it - leave it alone
            }
        }

        if (!QDir().mkpath(gridDir)) {
            return;
        }
        // Write beside the target and rename over it. std::rename replaces atomically on
        // Linux (the only platform this compiles for); QFile::rename refuses to
        // overwrite, which would force a remove-then-rename and leave a window where the
        // user has no artwork at all if the rename then failed.
        const QString tmpPath = dest + QStringLiteral(".vibemis-tmp");
        QFile tmp(tmpPath);
        if (!tmp.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            continue;
        }
        const qint64 written = tmp.write(bytes);
        const bool flushed = tmp.flush();   // check BEFORE close(), which swallows it
        tmp.close();
        if (!flushed || written != bytes.size()) {
            QFile::remove(tmpPath);
            continue;   // a short write must never be renamed into place
        }
        if (std::rename(QFile::encodeName(tmpPath).constData(),
                        QFile::encodeName(dest).constData()) != 0) {
            QFile::remove(tmpPath);
            continue;
        }
        newDigests.insert(key, wantDigest);
        stateDirty = true;
    }

    if (stateDirty) {
        QFile sf(stateFile);
        if (sf.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
            for (auto it = newDigests.constBegin(); it != newDigests.constEnd(); ++it) {
                sf.write(it.key().toUtf8() + '=' + it.value() + '\n');
            }
            sf.close();
        }
    }
}

// Reads an entry's stored appid, falling back to the derivation when the field is
// absent (very old Steam builds wrote none).
qint32 entryAppId(QVector<VdfNode> &entryChildren, const QString &exe)
{
    VdfNode *f = findChild(entryChildren, QStringLiteral("appid"));
    if (f && f->type == 0x02 && f->intVal != 0) {
        return f->intVal;
    }
    // No stored appid (very old Steam builds wrote none), so derive it the way Steam
    // does -- from the QUOTED Exe string, which is how the field is stored. Hashing the
    // bare path here would yield an id Steam never uses and park the artwork where
    // nothing reads it.
    return computeAppId(QStringLiteral("\"%1\"").arg(exe), kAppName);
}

// Creates or repairs the "Vibemis" entry in one Steam profile's
// shortcuts.vdf. Returns false (and leaves the file untouched) on any
// parse ambiguity - never risk corrupting real user data.
//
// On success, *outAppId receives the EFFECTIVE appid of the entry -- read from an
// existing entry, or the freshly computed one for an entry we just created. Callers
// must use this rather than recomputing: when the user added Vibemis to Steam by hand,
// Steam assigned the appid itself, and this function deliberately does not rewrite it
// (changing an appid would orphan the user's playtime, controller layout and
// collections). Deriving it instead of reading it is how library artwork ends up
// written under an id nothing references, leaving the tile stubbornly blank.
bool upsertProfile(const QString &vdfPath, const QString &exe, const QString &startDir,
                   const QString &icon, qint32 *outAppId)
{
    QVector<VdfNode> root;
    const bool haveExisting = QFile::exists(vdfPath);

    if (haveExisting) {
        QFile f(vdfPath);
        if (!f.open(QIODevice::ReadOnly)) {
            qWarning("SteamShortcut: could not open %s for reading; skipping.", qUtf8Printable(vdfPath));
            return false;
        }
        const QByteArray data = f.readAll();
        f.close();
        int pos = 0;
        if (!parseMap(data, pos, root, 0)) {
            qWarning("SteamShortcut: could not parse %s; leaving it untouched.", qUtf8Printable(vdfPath));
            return false;
        }
    } else {
        VdfNode shortcuts;
        shortcuts.type = 0x00;
        shortcuts.key = QStringLiteral("shortcuts");
        root.append(shortcuts);
    }

    VdfNode *shortcutsNode = findChild(root, QStringLiteral("shortcuts"));
    if (!shortcutsNode || shortcutsNode->type != 0x00) {
        qWarning("SteamShortcut: unexpected structure in %s; leaving it untouched.", qUtf8Printable(vdfPath));
        return false;
    }

    bool updated = false;
    for (VdfNode &entry : shortcutsNode->children) {
        if (entry.type != 0x00) {
            continue;
        }
        VdfNode *appNameField = findChild(entry.children, QStringLiteral("AppName"));
        if (!appNameField || appNameField->strVal != QLatin1String(kAppName)) {
            continue;
        }
        VdfNode *exeField = findChild(entry.children, QStringLiteral("Exe"));
        VdfNode *iconField = findChild(entry.children, QStringLiteral("icon"));
        const QString exeQuoted = QStringLiteral("\"%1\"").arg(exe);
        if (exeField && iconField && exeField->strVal == exeQuoted && !iconField->strVal.isEmpty()
            && QFile::exists(iconField->strVal)) {
            // Nothing to write to shortcuts.vdf -- but still report the appid, because
            // the artwork may be missing even when the shortcut entry is perfect. This
            // is the common path on every launch after the first.
            if (outAppId) { *outAppId = entryAppId(entry.children, exe); }
            return true;
        }
        if (exeField) {
            exeField->strVal = exeQuoted;
        }
        VdfNode *startDirField = findChild(entry.children, QStringLiteral("StartDir"));
        if (startDirField) {
            startDirField->strVal = QStringLiteral("\"%1\"").arg(startDir);
        }
        if (iconField && !icon.isEmpty()) {
            iconField->strVal = icon;
        }
        if (outAppId) { *outAppId = entryAppId(entry.children, exe); }
        updated = true;
        break;
    }

    if (!updated) {
        int nextIdx = 0;
        for (const VdfNode &entry : shortcutsNode->children) {
            bool ok = false;
            const int v = entry.key.toInt(&ok);
            if (ok && v >= nextIdx) {
                nextIdx = v + 1;
            }
        }
        VdfNode newEntry;
        newEntry.type = 0x00;
        newEntry.key = QString::number(nextIdx);
        newEntry.children = buildShortcutFields(exe, startDir, icon);
        shortcutsNode->children.append(newEntry);
        if (outAppId) { *outAppId = computeAppId(exe, kAppName); }
    }

    QByteArray serialized;
    writeMap(serialized, root);
    serialized.append(static_cast<char>(0x08));

    if (haveExisting) {
        QFile::copy(vdfPath, vdfPath + QStringLiteral(".bak-vibemis"));
    }

    const QFileInfo fi(vdfPath);
    QTemporaryFile tmp(fi.absolutePath() + QStringLiteral("/shortcuts.vdf.XXXXXX"));
    tmp.setAutoRemove(false);
    if (!tmp.open()) {
        qWarning("SteamShortcut: could not create a temp file next to %s", qUtf8Printable(vdfPath));
        return false;
    }
    tmp.write(serialized);
    tmp.close();

    QFile::remove(vdfPath);
    if (!QFile::rename(tmp.fileName(), vdfPath)) {
        qWarning("SteamShortcut: failed to move the new shortcuts.vdf into place at %s", qUtf8Printable(vdfPath));
        return false;
    }
    return true;
}

QStringList findSteamUserdataConfigDirs()
{
    const QStringList candidateRoots = {
        QDir::homePath() + QStringLiteral("/.steam/steam/userdata"),
        QDir::homePath() + QStringLiteral("/.var/app/com.valvesoftware.Steam/.steam/steam/userdata"),
        QDir::homePath() + QStringLiteral("/.local/share/Steam/userdata"),
    };
    QStringList configDirs;
    for (const QString &root : candidateRoots) {
        QDir dir(root);
        if (!dir.exists()) {
            continue;
        }
        const QStringList profiles = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString &profile : profiles) {
            const QString cfg = root + QStringLiteral("/") + profile + QStringLiteral("/config");
            if (QDir(cfg).exists() && !configDirs.contains(cfg)) {
                configDirs.append(cfg);
            }
        }
    }
    return configDirs;
}

} // namespace

void SteamShortcut::ensureRegistered()
{
    const QStringList configDirs = findSteamUserdataConfigDirs();
    if (configDirs.isEmpty()) {
        return; // no Steam installation found on this machine - nothing to do
    }

    // Under an AppImage, applicationFilePath() resolves to the ephemeral
    // FUSE mount point (/tmp/.mount_*), which stops existing the moment this
    // process exits - writing that into shortcuts.vdf would break the tile on
    // the very next launch. $APPIMAGE is the runtime-provided stable path to
    // the outer .AppImage file itself; same convention main.cpp's updater
    // already relies on (see UpdateSelfTestRequested).
    QString exe = qEnvironmentVariable("APPIMAGE");
    if (exe.isEmpty()) {
        exe = QCoreApplication::applicationFilePath();
    }
    if (exe.isEmpty()) {
        return;
    }
    const QString startDir = QFileInfo(exe).absolutePath();
    const QString icon = ensureIconOnDisk();

    // The library tile is keyed off the appid the shortcut entry ACTUALLY carries, which
    // upsertProfile() reports back. When the user added Vibemis to Steam by hand, Steam
    // chose that id itself and it will not match a local derivation -- recomputing here
    // would scatter PNGs under an id nothing references and leave the tile blank.
    for (const QString &cfgDir : configDirs) {
        qint32 appId = 0;
        if (upsertProfile(cfgDir + QStringLiteral("/shortcuts.vdf"), exe, startDir, icon, &appId)
            && appId != 0) {
            ensureGridArtwork(cfgDir, appId);
        }
        // On a parse ambiguity upsertProfile leaves the file untouched and reports
        // nothing; we then have no trustworthy appid, and writing artwork under a
        // guessed one would just litter grid/ with files Steam never reads.
    }
}

#else // !Q_OS_LINUX

void SteamShortcut::ensureRegistered()
{
    // Steam shortcut self-registration only applies on Linux.
}

#endif
