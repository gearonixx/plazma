#include "part_file.h"

#include <QDebug>
#include <QDir>
#include <QFileInfo>

PartFile::PartFile(QString destPath) noexcept
    : destPath_(std::move(destPath)),
      partPath_(destPath_ + QStringLiteral(".part")) {}

PartFile::~PartFile() { closeQuietly(); }

bool PartFile::open(qint64 minResumeBytes, qint64 totalHint) {
    closeQuietly();
    error_.clear();

    QDir().mkpath(QFileInfo(partPath_).absolutePath());

    qint64 existing = 0;
    {
        const QFileInfo info(partPath_);
        if (info.exists() && info.isFile()) {
            existing = info.size();
            const bool tooSmall = existing < minResumeBytes;
            const bool tooLarge = (totalHint > 0 && existing >= totalHint);
            if (tooSmall || tooLarge) {
                // Junk leftover or somehow already complete-on-disk — the
                // latter shouldn't happen because a successful run renames
                // .part to the final path, but be defensive against a crash
                // between the disk flush and the rename.
                QFile::remove(partPath_);
                existing = 0;
            }
        }
    }

    file_ = std::make_unique<QFile>(partPath_);
    const auto openMode = (existing > 0)
        ? (QIODevice::WriteOnly | QIODevice::Append)
        : (QIODevice::WriteOnly | QIODevice::Truncate);
    if (!file_->open(openMode)) {
        error_ = file_->errorString();
        file_.reset();
        return false;
    }

    resumeFrom_ = existing;
    bytesOnDisk_ = existing;
    lastFlushBytes_ = existing;
    return true;
}

bool PartFile::write(const QByteArray& chunk) {
    if (!file_ || !file_->isOpen()) {
        error_ = QStringLiteral("write called on closed PartFile");
        return false;
    }
    if (chunk.isEmpty()) return true;

    const auto written = file_->write(chunk);
    if (written != chunk.size()) {
        error_ = file_->errorString();
        return false;
    }
    bytesOnDisk_ += written;

    if (bytesOnDisk_ - lastFlushBytes_ >= flushIntervalBytes_) {
        // Best-effort — a flush failure isn't fatal here, since the bytes
        // are still in the file's user-space buffer / kernel page cache.
        // We'll surface any genuine I/O error on the next write or at
        // finalize().
        file_->flush();
        lastFlushBytes_ = bytesOnDisk_;
    }
    return true;
}

bool PartFile::truncate() {
    if (!file_ || !file_->isOpen()) {
        error_ = QStringLiteral("truncate called on closed PartFile");
        return false;
    }
    if (!file_->resize(0) || !file_->seek(0)) {
        error_ = file_->errorString();
        return false;
    }
    bytesOnDisk_ = 0;
    lastFlushBytes_ = 0;
    resumeFrom_ = 0;
    return true;
}

bool PartFile::flush() {
    if (!file_ || !file_->isOpen()) return false;
    const bool ok = file_->flush();
    if (ok) lastFlushBytes_ = bytesOnDisk_;
    else error_ = file_->errorString();
    return ok;
}

bool PartFile::finalize() {
    if (!file_) {
        error_ = QStringLiteral("finalize called without open PartFile");
        return false;
    }

    if (file_->isOpen()) {
        file_->flush();
        file_->close();
    }

    // Remove any pre-existing destination — at this point the user has
    // chosen a path (collision-resolved by computeDestPath upstream) and
    // we own that filename for this transfer.
    if (QFile::exists(destPath_)) QFile::remove(destPath_);

    // Qt's rename falls back to copy+remove across volumes, so a false
    // here means the filesystem is in a state we can't recover from.
    if (!QFile::rename(partPath_, destPath_)) {
        error_ = QStringLiteral("could not rename %1 → %2").arg(partPath_, destPath_);
        QFile::remove(partPath_);
        file_.reset();
        return false;
    }

    file_.reset();
    return true;
}

void PartFile::discard() {
    closeQuietly();
    QFile::remove(partPath_);
}

void PartFile::closeQuietly() noexcept {
    if (file_) {
        if (file_->isOpen()) file_->close();
        file_.reset();
    }
}
