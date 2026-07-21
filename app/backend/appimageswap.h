#pragma once

#include <QString>
#include <QtGlobal>

// The atomic tail of an AppImage self-update (BL-2259), extracted pure so the
// replacement sequencing is unit-testable (tests/updater).
//
// The invariant this module exists to enforce: BYTES ARE NEVER WRITTEN INTO
// THE LIVE TARGET PATH. A running AppImage keeps its squashfs mounted from the
// stable path's inode — overwriting that inode's content in place invalidates
// the mapped pages of every running instance (SIGBUS; the test135 crash).
// Renaming a mounted inode is always safe (the name changes, the inode
// doesn't); streaming new content into the name is not. So: download to a
// same-directory staging file, then swap names with plain rename(2).
namespace AppImageSwap {

enum Result {
    SwapOk = 0,
    // current -> .old failed; the staging file was removed; target untouched.
    BackupRenameFailed,
    // staging -> target failed; the previous build was restored at the target.
    SwapRenameFailed,
};

// Staging-file path for a download: lives in the SAME directory as the target
// (same filesystem, so the final rename is a true atomic rename(2), never a
// cross-device copy) and is pid-unique so two concurrent instances can never
// interleave writes into one staging file.
QString stagingPath(const QString& appImagePath, qint64 pid);

// Remove staging files a previous crashed/killed install left behind (each is
// a full-size orphan). Matches "<name>.new*" only — never the AppImage itself
// or its ".old" rollback backup.
void sweepStaleStaging(const QString& appImagePath);

// The swap: current -> "<name>.old" (rollback backup, replacing any stale
// one), then newPath -> current. Both steps are plain rename(2) — NOT
// QFile::rename, whose silent copy-and-delete fallback would stream bytes
// into the destination path non-atomically when a native rename fails. On
// failure the previous build is put back; every return path leaves a runnable
// AppImage at appImagePath and no staging file behind.
Result swap(const QString& appImagePath, const QString& newPath);

}
