#include "appimageswap.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>

#include <cstdio>

namespace AppImageSwap {

QString stagingPath(const QString& appImagePath, qint64 pid)
{
    return appImagePath + QStringLiteral(".new-") + QString::number(pid);
}

// Plain rename(2). QFile::rename is deliberately NOT used here: when the
// native rename fails it silently falls back to copy-then-delete, which
// streams bytes into the destination path — exactly the non-atomic in-place
// write this module exists to rule out. std::rename maps straight to
// rename(2) on POSIX (atomic, replaces an existing destination) with no
// fallback of any kind: it either renames or fails.
static bool renameNoCopyFallback(const QString& from, const QString& to)
{
    return std::rename(QFile::encodeName(from).constData(),
                       QFile::encodeName(to).constData()) == 0;
}

void sweepStaleStaging(const QString& appImagePath)
{
    QFileInfo target(appImagePath);
    QDir dir = target.dir();
    const QStringList stale =
        dir.entryList({target.fileName() + QStringLiteral(".new*")}, QDir::Files);
    for (const QString& name : stale) {
        QFile::remove(dir.filePath(name));
    }
}

Result swap(const QString& appImagePath, const QString& newPath)
{
    QString oldPath = appImagePath + QStringLiteral(".old");

    // Move the running build aside as the rollback backup. A pure rename: a
    // mounted squashfs keeps its inode, only the name changes — always safe
    // while the app is running. (If a stale .old resists removal, rename(2)
    // atomically replaces it anyway.)
    QFile::remove(oldPath);
    if (!renameNoCopyFallback(appImagePath, oldPath)) {
        QFile::remove(newPath);
        return BackupRenameFailed;
    }

    // The swap: the fully-written, fsynced staging file takes over the stable
    // name in one atomic step. At no point does partial content ever exist at
    // the target path.
    if (!renameNoCopyFallback(newPath, appImagePath)) {
        // Put the original back so the user still has a working install.
        renameNoCopyFallback(oldPath, appImagePath);
        QFile::remove(newPath);
        return SwapRenameFailed;
    }
    return SwapOk;
}

}
