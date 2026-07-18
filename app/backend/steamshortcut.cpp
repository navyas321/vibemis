#include "steamshortcut.h"

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTemporaryFile>
#include <QVector>
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
    static QVector<quint32> table;
    if (table.isEmpty()) {
        table.resize(256);
        for (int i = 0; i < 256; ++i) {
            quint32 c = static_cast<quint32>(i);
            for (int j = 0; j < 8; ++j) {
                c = (c & 1) ? (0xEDB88320u ^ (c >> 1)) : (c >> 1);
            }
            table[i] = c;
        }
    }
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

// Creates or repairs the "Vibemis" entry in one Steam profile's
// shortcuts.vdf. Returns false (and leaves the file untouched) on any
// parse ambiguity - never risk corrupting real user data.
bool upsertProfile(const QString &vdfPath, const QString &exe, const QString &startDir, const QString &icon)
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
            return true; // already correct - nothing to do
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

    for (const QString &cfgDir : configDirs) {
        upsertProfile(cfgDir + QStringLiteral("/shortcuts.vdf"), exe, startDir, icon);
    }
}

#else // !Q_OS_LINUX

void SteamShortcut::ensureRegistered()
{
    // Steam shortcut self-registration only applies on Linux.
}

#endif
