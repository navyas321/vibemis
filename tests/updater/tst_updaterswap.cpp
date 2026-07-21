// BL-2259 — replacement-sequencing tests for the AppImage self-update swap.
//
// The invariant under test: the updater NEVER writes bytes into the live
// target path. The running AppImage's squashfs is mounted from the stable
// path's inode; overwriting that inode in place SIGBUSes every running
// instance (the test135 crash). The swap must therefore be: stage in the
// same directory, then pure rename(2) — current -> .old, staging -> current
// — with rollback on any failure.

#include <QtTest>
#include <QTemporaryDir>

#include "../../app/backend/appimageswap.h"

#if defined(Q_OS_UNIX)
#include <sys/stat.h>
static qint64 inodeOf(const QString& path)
{
    struct stat st;
    if (::stat(QFile::encodeName(path).constData(), &st) != 0) {
        return -1;
    }
    return (qint64)st.st_ino;
}
#endif

static bool writeFile(const QString& path, const QByteArray& content)
{
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return false;
    }
    return f.write(content) == content.size();
}

static QByteArray readFile(const QString& path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        return QByteArray();
    }
    return f.readAll();
}

class tst_UpdaterSwap : public QObject
{
    Q_OBJECT

private slots:
    void stagingPathIsSameDirAndPidUnique();
    void swapInstallsNewAndKeepsBackup();
    void swapReplacesStaleOldBackup();
    void swapNeverRewritesTheRunningInode();
    void backupRenameFailureRemovesStaging();
    void swapRenameFailureRollsBack();
    void sweepRemovesOnlyStagingFiles();
};

void tst_UpdaterSwap::stagingPathIsSameDirAndPidUnique()
{
    QString target = QStringLiteral("/some/dir/Vibemis.AppImage");
    QString s1 = AppImageSwap::stagingPath(target, 42);
    QString s2 = AppImageSwap::stagingPath(target, 43);

    // Same directory as the target (same filesystem => the final rename is a
    // true atomic rename(2), never a cross-device copy)...
    QCOMPARE(QFileInfo(s1).path(), QFileInfo(target).path());
    QCOMPARE(s1, QStringLiteral("/some/dir/Vibemis.AppImage.new-42"));
    // ...and pid-unique so concurrent instances can't share a staging file.
    QVERIFY(s1 != s2);
}

void tst_UpdaterSwap::swapInstallsNewAndKeepsBackup()
{
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    QString target = dir.filePath(QStringLiteral("Vibemis.AppImage"));
    QString staging = AppImageSwap::stagingPath(target, 1);
    QVERIFY(writeFile(target, "RUNNING-BUILD"));
    QVERIFY(writeFile(staging, "NEW-BUILD"));

    QCOMPARE(AppImageSwap::swap(target, staging), AppImageSwap::SwapOk);

    QCOMPARE(readFile(target), QByteArray("NEW-BUILD"));
    QCOMPARE(readFile(target + QStringLiteral(".old")), QByteArray("RUNNING-BUILD"));
    QVERIFY(!QFile::exists(staging));
}

void tst_UpdaterSwap::swapReplacesStaleOldBackup()
{
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    QString target = dir.filePath(QStringLiteral("Vibemis.AppImage"));
    QString staging = AppImageSwap::stagingPath(target, 1);
    QVERIFY(writeFile(target, "RUNNING-BUILD"));
    QVERIFY(writeFile(staging, "NEW-BUILD"));
    QVERIFY(writeFile(target + QStringLiteral(".old"), "ANCIENT-BUILD"));

    QCOMPARE(AppImageSwap::swap(target, staging), AppImageSwap::SwapOk);

    // The .old backup always holds the build that was just replaced.
    QCOMPARE(readFile(target + QStringLiteral(".old")), QByteArray("RUNNING-BUILD"));
    QCOMPARE(readFile(target), QByteArray("NEW-BUILD"));
}

void tst_UpdaterSwap::swapNeverRewritesTheRunningInode()
{
#if defined(Q_OS_UNIX)
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    QString target = dir.filePath(QStringLiteral("Vibemis.AppImage"));
    QString staging = AppImageSwap::stagingPath(target, 1);
    QVERIFY(writeFile(target, "RUNNING-BUILD"));
    QVERIFY(writeFile(staging, "NEW-BUILD"));

    qint64 runningInode = inodeOf(target);
    qint64 stagingInode = inodeOf(staging);
    QVERIFY(runningInode > 0);
    QVERIFY(stagingInode > 0);

    QCOMPARE(AppImageSwap::swap(target, staging), AppImageSwap::SwapOk);

    // The running build's inode was RENAMED to .old — never copied, never
    // rewritten. This is what keeps a live squashfs mount alive (no SIGBUS).
    QCOMPARE(inodeOf(target + QStringLiteral(".old")), runningInode);
    // The target name now points at the staging file's inode — the content
    // arrived by rename, not by writing bytes into the old name.
    QCOMPARE(inodeOf(target), stagingInode);
#else
    QSKIP("inode identity is a POSIX-only observable");
#endif
}

void tst_UpdaterSwap::backupRenameFailureRemovesStaging()
{
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    // No file at the target path => the current -> .old rename must fail.
    QString target = dir.filePath(QStringLiteral("Vibemis.AppImage"));
    QString staging = AppImageSwap::stagingPath(target, 1);
    QVERIFY(writeFile(staging, "NEW-BUILD"));

    QCOMPARE(AppImageSwap::swap(target, staging), AppImageSwap::BackupRenameFailed);

    // The failed install must not strand its staging file.
    QVERIFY(!QFile::exists(staging));
    QVERIFY(!QFile::exists(target + QStringLiteral(".old")));
}

void tst_UpdaterSwap::swapRenameFailureRollsBack()
{
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    QString target = dir.filePath(QStringLiteral("Vibemis.AppImage"));
    // No staging file => stage 1 (current -> .old) succeeds, stage 2 fails.
    QString staging = AppImageSwap::stagingPath(target, 1);
    QVERIFY(writeFile(target, "RUNNING-BUILD"));

    QCOMPARE(AppImageSwap::swap(target, staging), AppImageSwap::SwapRenameFailed);

    // Rollback: the previous build is back at the stable path, runnable.
    QCOMPARE(readFile(target), QByteArray("RUNNING-BUILD"));
    QVERIFY(!QFile::exists(target + QStringLiteral(".old")));
}

void tst_UpdaterSwap::sweepRemovesOnlyStagingFiles()
{
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    QString target = dir.filePath(QStringLiteral("Vibemis.AppImage"));
    QVERIFY(writeFile(target, "RUNNING-BUILD"));
    QVERIFY(writeFile(target + QStringLiteral(".old"), "PREVIOUS-BUILD"));
    QVERIFY(writeFile(target + QStringLiteral(".new"), "LEGACY-STAGING"));
    QVERIFY(writeFile(AppImageSwap::stagingPath(target, 999), "CRASHED-STAGING"));

    AppImageSwap::sweepStaleStaging(target);

    // Staging leftovers (legacy fixed ".new" and pid-suffixed) are gone...
    QVERIFY(!QFile::exists(target + QStringLiteral(".new")));
    QVERIFY(!QFile::exists(AppImageSwap::stagingPath(target, 999)));
    // ...while the install and its rollback backup are untouched.
    QCOMPARE(readFile(target), QByteArray("RUNNING-BUILD"));
    QCOMPARE(readFile(target + QStringLiteral(".old")), QByteArray("PREVIOUS-BUILD"));
}

QTEST_GUILESS_MAIN(tst_UpdaterSwap)
#include "tst_updaterswap.moc"
