#pragma once

#include <QFile>
#include <QString>
#include <memory>

// PartFile
// ────────
// RAII wrapper for the "download into <name>.part, atomically rename to
// <name> on success" idiom that backs every offline download. Encapsulates
// three things that the callers used to inline:
//   1. Resume-aware open() — if the .part file already has a sane prefix on
//      disk, open in append mode and report the offset so the network layer
//      can ask the server for a Range continuation. Otherwise truncate.
//   2. Periodic flush() while writing — caps the loss-window of a crashed
//      transfer to a few MiB instead of letting up to GBs sit in the kernel
//      page cache until close().
//   3. Atomic finalize() — flush + close + rename .part → final, with a
//      best-effort fall-through to copy-and-delete on cross-volume renames
//      (Qt's QFile::rename already does this internally on most platforms).
//
// All disk-reachable failures surface through the bool return on each
// method. The caller is expected to inspect errorString() after a false
// return. Construction is cheap; the file is not opened until open() is
// called explicitly.
class PartFile {
public:
    explicit PartFile(QString destPath) noexcept;
    ~PartFile();

    PartFile(const PartFile&) = delete;
    PartFile& operator=(const PartFile&) = delete;

    // Final destination after successful finalize().
    [[nodiscard]] QString destPath() const noexcept { return destPath_; }
    // Working path: destPath() + ".part".
    [[nodiscard]] QString partPath() const noexcept { return partPath_; }

    // Open the .part file for writing. If a leftover .part of size >=
    // `minResumeBytes` exists, opens in append mode and `resumeFrom()` will
    // return the existing size; otherwise opens truncated. A leftover that
    // already meets or exceeds `totalHint` (when known) is treated as
    // suspicious and discarded — we'd rather refetch a slightly stale tail
    // than rename garbage to the user-visible filename.
    [[nodiscard]] bool open(qint64 minResumeBytes, qint64 totalHint = 0);

    // Bytes already on disk at open() time. 0 on a fresh transfer; non-zero
    // when we're resuming. The network layer uses this to set the Range
    // header.
    [[nodiscard]] qint64 resumeFrom() const noexcept { return resumeFrom_; }

    // True between open() and close() / finalize() / discard().
    [[nodiscard]] bool isOpen() const noexcept { return file_ && file_->isOpen(); }

    // Append a chunk. Updates the internal byte counter and may trigger a
    // background flush once `flushIntervalBytes` worth of new data has been
    // written since the last flush. Returns false on a hard write failure;
    // partial writes (write returns less than requested) are reported as
    // failure, since at that point the on-disk file is undefined.
    [[nodiscard]] bool write(const QByteArray& chunk);

    // Total bytes currently on disk (resume offset + everything written()
    // since open). Cheap — incremented on each successful write.
    [[nodiscard]] qint64 bytesOnDisk() const noexcept { return bytesOnDisk_; }

    // Discard everything written so far and start over from byte 0. Used
    // when the server ignores a Range request and serves 200 with the
    // whole body — the partially-stale prefix has to go.
    [[nodiscard]] bool truncate();

    // Force any buffered bytes to disk. Called automatically by write()
    // every flushIntervalBytes; exposed for callers that want a sync point
    // (e.g., right before computing a checksum).
    bool flush();

    // Atomic rename .part → final destination. Caller is responsible for
    // having drained the source first; this method flushes + closes before
    // attempting the rename. After a true return the PartFile is no longer
    // open and the bytes are at destPath(). Pre-existing destination files
    // are removed first.
    [[nodiscard]] bool finalize();

    // Close + delete the .part file. Used for user-cancelled or hard-
    // failed transfers. Idempotent — safe to call after finalize() too.
    void discard();

    // Error message of the last failed operation (open / write / finalize).
    [[nodiscard]] QString errorString() const noexcept { return error_; }

    // Periodic flush window — exposed so the surrounding model can pick a
    // value that matches its UX expectation (smaller = less data lost on
    // crash, larger = better throughput).
    void setFlushIntervalBytes(qint64 n) noexcept { flushIntervalBytes_ = n; }

private:
    void closeQuietly() noexcept;

    QString destPath_;
    QString partPath_;
    std::unique_ptr<QFile> file_;
    qint64 resumeFrom_ = 0;
    qint64 bytesOnDisk_ = 0;
    qint64 lastFlushBytes_ = 0;
    qint64 flushIntervalBytes_ = 4LL * 1024 * 1024;
    QString error_;
};
