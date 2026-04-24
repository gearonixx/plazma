#include "downloads_model.h"

#include <QDateTime>
#include <QDebug>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QMimeDatabase>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QTimer>
#include <QUrl>
#include <QVariant>
#include <algorithm>

#include "src/api.h"
#include "src/session.h"

namespace {

constexpr auto kPersistGroup = "downloads/completed";

}  // namespace

// ─── construction / teardown ─────────────────────────────────────────────

DownloadsModel::DownloadsModel(Api* api, Session* session, QObject* parent)
    : QAbstractListModel(parent), api_(api), session_(session) {
    Q_ASSERT(api_ != nullptr);

    hideTimer_ = new QTimer(this);
    hideTimer_->setSingleShot(true);
    connect(hideTimer_, &QTimer::timeout, this, [this] {
        if (!latestVisible_) return;
        latestVisible_ = false;
        emit latestChanged();
    });

    // Load persisted completed downloads; drop the stale ones on the spot.
    loadPersisted();
    purgeStaleCompleted();

    // Session lifecycle: drop in-flight transfers on logout. Kept as a
    // defensive measure — there's no per-download auth right now, but
    // when it lands these transfers will reference a token that just
    // went away. tdesktop's DownloadManager does the same on account
    // switch (data_download_manager.cpp).
    if (session_) {
        connect(session_, &Session::sessionChanged, this, [this] {
            if (!session_ || session_->valid()) return;
            // Abort every active transfer in place. Completed persisted
            // rows stay in the list so the user still sees their history
            // after logout — matching the Downloads page on YouTube.
            for (auto& e : entries_) {
                if (e->status == Status::Downloading || e->status == Status::Queued) {
                    if (e->reply) {
                        e->userCanceled = true;
                        e->reply->disconnect(this);
                        e->reply->abort();
                        e->reply->deleteLater();
                        e->reply = nullptr;
                    }
                    if (e->file) {
                        e->file->close();
                        e->file.reset();
                    }
                    QFile::remove(e->partPath);
                    setStatus(*e, Status::Canceled);
                }
            }
            emit activeCountChanged();
            emit queuedCountChanged();
            emit latestChanged();
        });
    }
}

DownloadsModel::~DownloadsModel() {
    // Abort any in-flight transfers so Qt doesn't tear down QNetworkReplys
    // behind our back during shutdown. QFile closes via the unique_ptr.
    for (auto& e : entries_) {
        if (e->reply) {
            e->reply->disconnect(this);
            e->reply->abort();
            e->reply->deleteLater();
        }
    }
}

// ─── QAbstractListModel plumbing ─────────────────────────────────────────

int DownloadsModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) return 0;
    return static_cast<int>(entries_.size());
}

QVariant DownloadsModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= static_cast<int>(entries_.size())) {
        return {};
    }
    const auto& e = *entries_[index.row()];
    switch (role) {
        case IdRole:         return e.id;
        case TitleRole:      return e.title;
        case UrlRole:        return e.sourceUrl;
        case DestPathRole:   return e.destPath;
        case ReceivedRole:   return e.received;
        case TotalRole:      return e.total;
        case ProgressRole:   return e.total > 0 ? static_cast<double>(e.received) / e.total : 0.0;
        case StatusRole:     return static_cast<int>(e.status);
        case ErrorRole:      return e.error;
        case SpeedRole:      return e.speedBps;
        case EtaSecRole: {
            if (e.status != Status::Downloading || e.speedBps <= 0.0 || e.total <= 0) return -1;
            const auto remaining = e.total - e.received;
            if (remaining <= 0) return 0;
            return static_cast<qint64>(static_cast<double>(remaining) / e.speedBps);
        }
        case FinishedAtRole: return e.finishedAtMsec;
        default:             return {};
    }
}

QHash<int, QByteArray> DownloadsModel::roleNames() const {
    return {
        {IdRole, "id"},
        {TitleRole, "title"},
        {UrlRole, "url"},
        {DestPathRole, "destPath"},
        {ReceivedRole, "received"},
        {TotalRole, "total"},
        {ProgressRole, "progress"},
        {StatusRole, "status"},
        {ErrorRole, "error"},
        {SpeedRole, "speed"},
        {EtaSecRole, "etaSec"},
        {FinishedAtRole, "finishedAt"},
    };
}

// ─── scalar accessors ────────────────────────────────────────────────────

int DownloadsModel::activeCount() const {
    int n = 0;
    for (const auto& e : entries_) {
        if (e->status == Status::Downloading) ++n;
    }
    return n;
}

int DownloadsModel::queuedCount() const {
    int n = 0;
    for (const auto& e : entries_) {
        if (e->status == Status::Queued) ++n;
    }
    return n;
}

QString DownloadsModel::latestId() const { return latestId_; }

QString DownloadsModel::latestTitle() const {
    const auto* e = find(latestId_);
    return e ? e->title : QString{};
}

qreal DownloadsModel::latestProgress() const {
    const auto* e = find(latestId_);
    if (!e) return 0.0;
    if (e->total <= 0) return 0.0;
    return static_cast<qreal>(e->received) / static_cast<qreal>(e->total);
}

qint64 DownloadsModel::latestReceived() const {
    const auto* e = find(latestId_);
    return e ? e->received : 0;
}

qint64 DownloadsModel::latestTotal() const {
    const auto* e = find(latestId_);
    return e ? e->total : 0;
}

int DownloadsModel::latestStatus() const {
    const auto* e = find(latestId_);
    return e ? static_cast<int>(e->status) : -1;
}

QString DownloadsModel::latestDestPath() const {
    const auto* e = find(latestId_);
    return e ? e->destPath : QString{};
}

QString DownloadsModel::latestError() const {
    const auto* e = find(latestId_);
    return e ? e->error : QString{};
}

qreal DownloadsModel::latestSpeed() const {
    const auto* e = find(latestId_);
    return e ? e->speedBps : 0.0;
}

qint64 DownloadsModel::latestEtaSec() const {
    const auto* e = find(latestId_);
    if (!e || e->status != Status::Downloading) return -1;
    if (e->speedBps <= 0.0 || e->total <= 0) return -1;
    const auto remaining = e->total - e->received;
    if (remaining <= 0) return 0;
    return static_cast<qint64>(static_cast<double>(remaining) / e->speedBps);
}

QString DownloadsModel::latestEtaText() const {
    const auto eta = latestEtaSec();
    if (eta < 0) return {};
    if (eta == 0) return tr("almost done");
    if (eta < 60) return tr("%1s left").arg(eta);
    if (eta < 3600) {
        const auto m = eta / 60;
        const auto s = eta % 60;
        return s > 0 ? tr("%1m %2s left").arg(m).arg(s) : tr("%1m left").arg(m);
    }
    const auto h = eta / 3600;
    const auto m = (eta % 3600) / 60;
    return m > 0 ? tr("%1h %2m left").arg(h).arg(m) : tr("%1h left").arg(h);
}

qreal DownloadsModel::aggregateProgress() const {
    qint64 received = 0, total = 0;
    for (const auto& e : entries_) {
        if (e->status != Status::Downloading) continue;
        if (e->total > 0) {
            received += e->received;
            total += e->total;
        }
    }
    if (total <= 0) return 0.0;
    return static_cast<qreal>(received) / static_cast<qreal>(total);
}

qint64 DownloadsModel::aggregateReceived() const {
    qint64 n = 0;
    for (const auto& e : entries_) {
        if (e->status == Status::Downloading) n += e->received;
    }
    return n;
}

qint64 DownloadsModel::aggregateTotal() const {
    qint64 n = 0;
    for (const auto& e : entries_) {
        if (e->status == Status::Downloading && e->total > 0) n += e->total;
    }
    return n;
}

qreal DownloadsModel::aggregateSpeed() const {
    qreal s = 0.0;
    for (const auto& e : entries_) {
        if (e->status == Status::Downloading) s += e->speedBps;
    }
    return s;
}

QString DownloadsModel::downloadsFolder() const {
    // MoviesLocation is the "right" pick: both Linux and Windows map it
    // to ~/Videos (or the locale-equivalent on Linux via xdg-user-dirs).
    // We then bucket into a Plazma/ subfolder so the app doesn't litter
    // the user's video library with arbitrarily-named files.
    auto base = QStandardPaths::writableLocation(QStandardPaths::MoviesLocation);
    if (base.isEmpty()) base = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    if (base.isEmpty()) base = QDir::homePath();
    return QDir(base).filePath(QStringLiteral("Plazma"));
}

bool DownloadsModel::has(const QString& id) const { return find(id) != nullptr; }

int DownloadsModel::statusOf(const QString& id) const {
    const auto* e = find(id);
    return e ? static_cast<int>(e->status) : -1;
}

int DownloadsModel::indexOf(const QString& id) const {
    for (int i = 0; i < static_cast<int>(entries_.size()); ++i) {
        if (entries_[i]->id == id) return i;
    }
    return -1;
}

DownloadsModel::Entry* DownloadsModel::find(const QString& id) {
    const int i = indexOf(id);
    return i >= 0 ? entries_[i].get() : nullptr;
}

const DownloadsModel::Entry* DownloadsModel::find(const QString& id) const {
    const int i = indexOf(id);
    return i >= 0 ? entries_[i].get() : nullptr;
}

// ─── public slots ────────────────────────────────────────────────────────

void DownloadsModel::start(const QVariantMap& video) {
    const auto id  = video.value(QStringLiteral("id")).toString();
    const auto url = video.value(QStringLiteral("url")).toString();
    if (id.isEmpty() || url.isEmpty()) {
        qWarning() << "[Downloads] start() ignored — missing id or url";
        emit notify(tr("Can't download — this video has no source URL"));
        return;
    }

    // Already in flight? Just surface the existing progress.
    if (auto* existing = find(id)) {
        if (existing->status == Status::Downloading || existing->status == Status::Queued) {
            latestId_ = id;
            latestVisible_ = true;
            hideTimer_->stop();
            emit latestChanged();
            return;
        }
        // Completed / Failed / Canceled: drop the old row so the retry
        // starts from a clean slate with a fresh collision-resolved path.
        const int row = indexOf(id);
        beginRemoveRows({}, row, row);
        entries_.erase(entries_.begin() + row);
        endRemoveRows();
        emit countChanged();
    }

    const auto title = video.value(QStringLiteral("title")).toString();
    const auto mime  = video.value(QStringLiteral("mime")).toString();
    const auto size  = video.value(QStringLiteral("size")).toLongLong();
    const auto dest  = computeDestPath(title, url, mime);

    auto entry = std::make_unique<Entry>();
    entry->id = id;
    entry->title = title;
    entry->sourceUrl = url;
    entry->destPath = dest;
    entry->partPath = dest + QStringLiteral(".part");
    entry->mime = mime;
    // Seed total from feed-provided size so the bar can show a percentage
    // before Content-Length arrives. Authoritative value overwrites via
    // downloadProgress() / Content-Length later.
    entry->total = size > 0 ? size : 0;
    entry->retriesLeft = kMaxRetries;
    entry->status = Status::Queued;
    entry->wallClock.start();

    const int row = static_cast<int>(entries_.size());
    beginInsertRows({}, row, row);
    entries_.push_back(std::move(entry));
    endInsertRows();
    emit countChanged();
    emit queuedCountChanged();

    latestId_ = id;
    latestVisible_ = true;
    hideTimer_->stop();
    emit latestChanged();

    processQueue();
}

void DownloadsModel::cancel(const QString& id) {
    auto* e = find(id);
    if (!e) return;
    if (e->status != Status::Queued && e->status != Status::Downloading) return;

    e->userCanceled = true;

    if (e->reply) {
        e->reply->abort();   // triggers finished() which handles cleanup
        return;
    }

    // Queued-but-not-yet-started: no file, no reply — just mark canceled.
    if (e->file) {
        e->file->close();
        e->file.reset();
    }
    QFile::remove(e->partPath);
    setStatus(*e, Status::Canceled);
    emit queuedCountChanged();
    notifyRowChanged(indexOf(id));
    if (id == latestId_) emit latestChanged();
}

void DownloadsModel::retry(const QString& id) {
    auto* e = find(id);
    if (!e) return;
    if (e->status == Status::Downloading || e->status == Status::Queued) return;
    if (e->status == Status::Completed) return;   // file's already on disk

    QVariantMap payload;
    payload[QStringLiteral("id")] = e->id;
    payload[QStringLiteral("title")] = e->title;
    payload[QStringLiteral("url")] = e->sourceUrl;
    payload[QStringLiteral("mime")] = e->mime;
    payload[QStringLiteral("size")] = e->total;
    start(payload);
}

void DownloadsModel::remove(const QString& id) {
    const int row = indexOf(id);
    if (row < 0) return;
    auto& e = *entries_[row];

    if (e.reply && (e.status == Status::Queued || e.status == Status::Downloading)) {
        e.userCanceled = true;
        e.reply->disconnect(this);
        e.reply->abort();
        e.reply->deleteLater();
        e.reply = nullptr;
        if (e.file) e.file->close();
        QFile::remove(e.partPath);
        e.file.reset();
    }

    const bool wasCompleted = (e.status == Status::Completed);

    beginRemoveRows({}, row, row);
    entries_.erase(entries_.begin() + row);
    endRemoveRows();
    emit countChanged();
    emit activeCountChanged();
    emit queuedCountChanged();

    if (latestId_ == id) {
        latestId_.clear();
        latestVisible_ = false;
        emit latestChanged();
    }

    if (wasCompleted) savePersisted();
}

void DownloadsModel::clearCompleted() {
    bool touched = false;
    bool completedTouched = false;
    for (int i = static_cast<int>(entries_.size()) - 1; i >= 0; --i) {
        const auto s = entries_[i]->status;
        if (s == Status::Completed || s == Status::Failed || s == Status::Canceled) {
            const auto id = entries_[i]->id;
            if (s == Status::Completed) completedTouched = true;
            beginRemoveRows({}, i, i);
            entries_.erase(entries_.begin() + i);
            endRemoveRows();
            if (latestId_ == id) {
                latestId_.clear();
                latestVisible_ = false;
            }
            touched = true;
        }
    }
    if (touched) {
        emit countChanged();
        emit latestChanged();
    }
    if (completedTouched) savePersisted();
}

void DownloadsModel::purgeStaleCompleted() {
    bool touched = false;
    for (int i = static_cast<int>(entries_.size()) - 1; i >= 0; --i) {
        if (entries_[i]->status != Status::Completed) continue;
        const auto& path = entries_[i]->destPath;
        if (path.isEmpty() || !QFile::exists(path)) {
            beginRemoveRows({}, i, i);
            entries_.erase(entries_.begin() + i);
            endRemoveRows();
            touched = true;
        }
    }
    if (touched) {
        emit countChanged();
        savePersisted();
    }
}

void DownloadsModel::openFile(const QString& id) {
    const auto* e = find(id);
    if (!e || e->status != Status::Completed) return;
    if (!QFile::exists(e->destPath)) {
        // User deleted the file behind our back; drop the stale entry.
        const_cast<DownloadsModel*>(this)->purgeStaleCompleted();
        emit notify(tr("File is no longer available"));
        return;
    }
    QDesktopServices::openUrl(QUrl::fromLocalFile(e->destPath));
}

void DownloadsModel::openFolder(const QString& id) {
    const auto* e = find(id);
    const auto path = (e && !e->destPath.isEmpty()) ? QFileInfo(e->destPath).absolutePath() : downloadsFolder();
    QDir().mkpath(path);
    QDesktopServices::openUrl(QUrl::fromLocalFile(path));
}

void DownloadsModel::dismissLatest() {
    if (!latestVisible_) return;
    latestVisible_ = false;
    hideTimer_->stop();
    emit latestChanged();
}

// ─── scheduling ──────────────────────────────────────────────────────────

void DownloadsModel::processQueue() {
    // Fill concurrency slots FIFO, i.e. in insertion order of the list.
    for (auto& e : entries_) {
        if (activeCount() >= kMaxConcurrent) return;
        if (e->status != Status::Queued) continue;
        kickOff(*e);
    }
}

void DownloadsModel::scheduleRetryKick(const QString& id, int delayMs) {
    QTimer::singleShot(delayMs, this, [this, id] {
        auto* e = find(id);
        if (!e) return;
        // If the user cancelled during the backoff, honor that.
        if (e->status == Status::Canceled || e->userCanceled) return;
        // Still queued? Try to grab a slot now.
        if (e->status == Status::Queued) processQueue();
    });
}

// ─── the heavy lifting: kickOff → attachReply → handleFinished ───────────

void DownloadsModel::kickOff(Entry& entry) {
    Q_ASSERT(entry.status == Status::Queued);
    Q_ASSERT(!entry.reply);

    // Disk-space pre-flight. If we know the final size and there isn't
    // room for it + a small safety margin, fail before we open any file
    // descriptor. Skipped when size is unknown.
    if (entry.total > 0) {
        const auto folder = QFileInfo(entry.partPath).absolutePath();
        QDir().mkpath(folder);
        const QStorageInfo storage(folder);
        const auto available = storage.bytesAvailable();
        // 64 MiB safety cushion — covers filesystem overhead + concurrent
        // writes by other apps while this transfer is in flight.
        constexpr qint64 kSafetyBytes = 64LL * 1024 * 1024;
        if (available >= 0 && available < entry.total + kSafetyBytes) {
            const auto msg = tr("Not enough disk space (%1 free, %2 needed)")
                                 .arg(QLocale::system().formattedDataSize(available))
                                 .arg(QLocale::system().formattedDataSize(entry.total));
            qWarning() << "[Downloads] disk check failed:" << available << "<" << entry.total;
            setStatus(entry, Status::Failed, msg);
            emit notify(tr("Download failed: %1").arg(msg));
            notifyRowChanged(indexOf(entry.id));
            if (entry.id == latestId_) {
                emit latestChanged();
                hideTimer_->start(kBarHideFailMs);
            }
            emit queuedCountChanged();
            return;
        }
    }

    // Open the .part file for a fresh WriteOnly+Truncate. We don't attempt
    // byte-range resume yet — the server spec (see docs) reserves that for
    // a later iteration once Range support ships.
    QDir().mkpath(QFileInfo(entry.partPath).absolutePath());
    entry.file = std::make_unique<QFile>(entry.partPath);
    if (!entry.file->open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        const auto msg = tr("Can't write to %1").arg(entry.partPath);
        qWarning() << "[Downloads] open failed:" << entry.partPath << entry.file->errorString();
        entry.file.reset();
        setStatus(entry, Status::Failed, msg);
        emit notify(tr("Download failed: %1").arg(msg));
        notifyRowChanged(indexOf(entry.id));
        if (entry.id == latestId_) {
            emit latestChanged();
            hideTimer_->start(kBarHideFailMs);
        }
        emit queuedCountChanged();
        return;
    }

    // Fire the request.
    entry.reply = api_->startDownload(QUrl(entry.sourceUrl));
    if (!entry.reply) {
        const auto msg = tr("Network is unavailable");
        entry.file.reset();
        QFile::remove(entry.partPath);
        setStatus(entry, Status::Failed, msg);
        emit notify(tr("Download failed: %1").arg(msg));
        notifyRowChanged(indexOf(entry.id));
        if (entry.id == latestId_) {
            emit latestChanged();
            hideTimer_->start(kBarHideFailMs);
        }
        emit queuedCountChanged();
        return;
    }

    // Idle-transfer timeout. Qt 6's setTransferTimeout resets on every
    // received byte, so this aborts when the connection stalls (wifi drop,
    // server stuck) without killing slow-but-alive transfers.
    entry.reply->setTransferTimeout(kTransferTimeoutMs);

    // Transition to Downloading *before* attachReply so the various
    // callbacks observe a consistent state.
    entry.received = 0;
    entry.speedBps = 0;
    entry.lastSampleMsec = 0;
    entry.lastSampleBytes = 0;
    entry.error.clear();
    entry.httpStatus = 0;
    entry.status = Status::Downloading;
    emit activeCountChanged();
    emit queuedCountChanged();

    attachReply(entry);

    notifyRowChanged(indexOf(entry.id));
    if (entry.id == latestId_) emit latestChanged();

    if (entry.id == latestId_) {
        emit notify(tr("Downloading “%1”").arg(entry.title.isEmpty() ? tr("video") : entry.title));
    }
}

void DownloadsModel::attachReply(Entry& entry) {
    Q_ASSERT(entry.reply);
    auto* reply = entry.reply.data();
    const auto id = entry.id;

    // HTTP status gate — fire-once check as soon as response headers
    // arrive. A 4xx / 5xx body is almost always HTML or JSON, and letting
    // it get written into the .mp4 file would produce an unplayable
    // file that the user eventually discovers by trying to open it.
    // Aborting here routes through finished() with OperationCanceledError,
    // where handleFinished() sees the non-zero httpStatus and reports a
    // clean "HTTP 404: Not Found"-style error.
    connect(reply, &QNetworkReply::metaDataChanged, this, [this, id] {
        auto* e = find(id);
        if (!e || !e->reply) return;
        const auto code = e->reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (code == 0) return;                          // not an HTTP reply or no status yet
        if (code >= 200 && code < 300) return;          // OK
        if (code >= 300 && code < 400) return;          // redirect; QNAM handles it
        if (e->httpStatus != 0) return;                 // already noticed, don't double-abort
        e->httpStatus = code;
        qWarning() << "[Downloads] HTTP" << code << "→ abort" << id;
        e->reply->abort();
    });

    // Chunked write. QNetworkReply is buffered, so readyRead() fires
    // whenever new bytes are available — we drain into the .part file
    // and update the byte counter + EMA speed.
    connect(reply, &QNetworkReply::readyRead, this, [this, id] {
        auto* e = find(id);
        if (!e || !e->reply || !e->file) return;
        // If a non-2xx slipped past metaDataChanged (HTTP/2 can deliver
        // body before headers are flushed in some edge cases), swallow
        // the bytes — we'll abort via handleFinished's status check.
        if (e->httpStatus >= 400) {
            e->reply->readAll();  // drain & discard
            return;
        }
        const auto chunk = e->reply->readAll();
        if (chunk.isEmpty()) return;
        const auto written = e->file->write(chunk);
        if (written < 0) {
            qWarning() << "[Downloads] write failed:" << e->partPath << e->file->errorString();
            e->userCanceled = false;  // real failure, not user cancel
            e->reply->abort();
            return;
        }
        e->received += written;
        updateSpeed(*e);
        notifyRowChanged(indexOf(id));
        if (id == latestId_) emit latestChanged();
    });

    // downloadProgress → we use this for `total` (Content-Length) only.
    // `received` comes from readyRead counting writes, since
    // downloadProgress aggregates buffered-but-unread bytes.
    connect(reply, &QNetworkReply::downloadProgress, this, [this, id](qint64 /*received*/, qint64 total) {
        auto* e = find(id);
        if (!e) return;
        if (total > 0 && e->total != total) {
            e->total = total;
            notifyRowChanged(indexOf(id));
            if (id == latestId_) emit latestChanged();
        }
    });

    connect(reply, &QNetworkReply::finished, this, [this, id] {
        auto* e = find(id);
        if (!e) return;
        handleFinished(*e);
    });
}

void DownloadsModel::handleFinished(Entry& e) {
    auto* reply = e.reply.data();
    const auto nerr = reply ? reply->error() : QNetworkReply::NoError;
    const bool aborted = nerr == QNetworkReply::OperationCanceledError;
    const bool anyError = nerr != QNetworkReply::NoError;

    // Drain any buffered tail bytes for SUCCESS only — on error we don't
    // want partial data landing in the .part file.
    if (!anyError && reply && e.file) {
        const auto tail = reply->readAll();
        if (!tail.isEmpty()) {
            const auto written = e.file->write(tail);
            if (written > 0) e.received += written;
        }
    }
    if (e.file) {
        e.file->flush();
        e.file->close();
        e.file.reset();
    }

    const int httpCode = e.httpStatus > 0
        ? e.httpStatus
        : (reply ? reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() : 0);

    if (reply) reply->deleteLater();
    e.reply = nullptr;

    const bool userCancel = aborted && e.userCanceled;
    const bool httpError = httpCode >= 400;
    // Transient categories worth an auto-retry. Keeping this list
    // conservative — anything network-shaped retries, anything server-
    // shaped (4xx/5xx) does not. Matches how tdesktop categorizes
    // download failures in storage/file_download_web.cpp.
    const bool transient = !userCancel && !httpError && (
        nerr == QNetworkReply::OperationTimeoutError
        || nerr == QNetworkReply::NetworkSessionFailedError
        || nerr == QNetworkReply::TemporaryNetworkFailureError
        || nerr == QNetworkReply::UnknownNetworkError
        || nerr == QNetworkReply::ConnectionRefusedError
        || nerr == QNetworkReply::RemoteHostClosedError
        || nerr == QNetworkReply::HostNotFoundError
        || nerr == QNetworkReply::ProxyConnectionRefusedError
        || nerr == QNetworkReply::ProxyConnectionClosedError
        || nerr == QNetworkReply::ProxyTimeoutError
    );

    e.userCanceled = false;   // reset flag — the next retry is not user-canceled

    if (userCancel) {
        QFile::remove(e.partPath);
        setStatus(e, Status::Canceled);

    } else if (transient && e.retriesLeft > 0) {
        const int attempt = kMaxRetries - e.retriesLeft;   // 0-indexed
        --e.retriesLeft;

        // Wipe .part, reset counters, schedule a backoff, re-queue.
        QFile::remove(e.partPath);
        e.received = 0;
        e.speedBps = 0;
        e.lastSampleMsec = 0;
        e.lastSampleBytes = 0;
        e.httpStatus = 0;
        e.status = Status::Queued;
        e.error = tr("Retrying… (%1 / %2)").arg(attempt + 1).arg(kMaxRetries);

        const int delay = kRetryBackoffMsBase * (1 << attempt);  // 1.5s, 3s, 6s
        qDebug() << "[Downloads] transient fail on" << e.id << "— retry in" << delay << "ms";
        scheduleRetryKick(e.id, delay);

        emit activeCountChanged();
        emit queuedCountChanged();
        notifyRowChanged(indexOf(e.id));
        if (e.id == latestId_) emit latestChanged();
        return;

    } else if (httpError) {
        QFile::remove(e.partPath);
        const auto msg = tr("HTTP %1").arg(httpCode);
        setStatus(e, Status::Failed, msg);
        emit notify(tr("Download failed: %1").arg(msg));

    } else if (anyError) {
        QFile::remove(e.partPath);
        const auto msg = reply && !reply->errorString().isEmpty() ? reply->errorString() : tr("Unknown error");
        setStatus(e, Status::Failed, msg);
        emit notify(tr("Download failed: %1").arg(msg));

    } else {
        // Clean finish — atomically publish .part → final.
        if (QFile::exists(e.destPath)) QFile::remove(e.destPath);
        if (!QFile::rename(e.partPath, e.destPath)) {
            // Cross-FS or permission flipped mid-transfer; Qt's rename
            // already falls back to copy+remove across volumes, so if we
            // still failed, the filesystem is the problem.
            const auto msg = tr("Could not finalize the downloaded file");
            QFile::remove(e.partPath);
            setStatus(e, Status::Failed, msg);
            emit notify(tr("Download failed: %1").arg(msg));
        } else {
            e.finishedAtMsec = QDateTime::currentMSecsSinceEpoch();
            if (e.total <= 0) e.total = e.received;
            setStatus(e, Status::Completed);
            savePersisted();
            emit notify(tr("Saved “%1”").arg(e.title.isEmpty() ? tr("video") : e.title));
        }
    }

    emit activeCountChanged();
    emit queuedCountChanged();
    notifyRowChanged(indexOf(e.id));
    if (e.id == latestId_) {
        emit latestChanged();
        hideTimer_->start(e.status == Status::Failed ? kBarHideFailMs : kBarHideDelayMs);
    }

    // A finishing transfer always frees a slot — push the queue forward.
    processQueue();
}

// ─── internal helpers ────────────────────────────────────────────────────

void DownloadsModel::notifyRowChanged(int i) {
    if (i < 0 || i >= static_cast<int>(entries_.size())) return;
    const auto idx = index(i);
    emit dataChanged(idx, idx, {ReceivedRole, TotalRole, ProgressRole, StatusRole,
                                ErrorRole, SpeedRole, EtaSecRole, FinishedAtRole});
}

void DownloadsModel::setStatus(Entry& entry, Status s, const QString& error) {
    if (entry.status == s && entry.error == error) return;
    entry.status = s;
    entry.error = error;
    if (s == Status::Downloading) {
        entry.wallClock.restart();
    }
}

void DownloadsModel::updateSpeed(Entry& entry) {
    const auto nowMs = entry.wallClock.elapsed();
    if (entry.lastSampleMsec == 0) {
        // First sample after kickOff — seed instead of computing.
        entry.lastSampleMsec = nowMs;
        entry.lastSampleBytes = entry.received;
        return;
    }
    const auto dt = nowMs - entry.lastSampleMsec;
    if (dt < kSpeedSampleMs) return;   // let enough time pass for a stable sample
    const auto db = entry.received - entry.lastSampleBytes;
    const double inst = (db > 0 && dt > 0) ? static_cast<double>(db) * 1000.0 / static_cast<double>(dt) : 0.0;
    // Exponential moving average — tolerates bursty chunk deliveries.
    if (entry.speedBps <= 0.0) {
        entry.speedBps = inst;
    } else {
        entry.speedBps = kSpeedAlpha * inst + (1.0 - kSpeedAlpha) * entry.speedBps;
    }
    entry.lastSampleMsec = nowMs;
    entry.lastSampleBytes = entry.received;
}

// ─── persistence ─────────────────────────────────────────────────────────

void DownloadsModel::loadPersisted() {
    QSettings s;
    const int n = s.beginReadArray(QString::fromUtf8(kPersistGroup));
    for (int i = 0; i < n; ++i) {
        s.setArrayIndex(i);
        auto entry = std::make_unique<Entry>();
        entry->id             = s.value(QStringLiteral("id")).toString();
        entry->title          = s.value(QStringLiteral("title")).toString();
        entry->sourceUrl      = s.value(QStringLiteral("url")).toString();
        entry->destPath       = s.value(QStringLiteral("destPath")).toString();
        entry->mime           = s.value(QStringLiteral("mime")).toString();
        entry->total          = s.value(QStringLiteral("size")).toLongLong();
        entry->finishedAtMsec = s.value(QStringLiteral("finishedAt")).toLongLong();
        entry->received       = entry->total;
        entry->status         = Status::Completed;
        entry->persisted      = true;

        if (entry->id.isEmpty() || entry->destPath.isEmpty()) continue;

        entries_.push_back(std::move(entry));
    }
    s.endArray();
    // Newest first — the order users expect when looking back at history.
    std::sort(entries_.begin(), entries_.end(),
              [](const std::unique_ptr<Entry>& a, const std::unique_ptr<Entry>& b) {
                  return a->finishedAtMsec > b->finishedAtMsec;
              });
}

void DownloadsModel::savePersisted() const {
    QSettings s;
    s.remove(QString::fromUtf8(kPersistGroup));

    // Gather completed entries, newest first.
    std::vector<const Entry*> completed;
    completed.reserve(entries_.size());
    for (const auto& e : entries_) {
        if (e->status == Status::Completed) completed.push_back(e.get());
    }
    std::sort(completed.begin(), completed.end(),
              [](const Entry* a, const Entry* b) { return a->finishedAtMsec > b->finishedAtMsec; });
    if (static_cast<int>(completed.size()) > kMaxPersistedCompleted) {
        completed.resize(kMaxPersistedCompleted);
    }

    s.beginWriteArray(QString::fromUtf8(kPersistGroup), static_cast<int>(completed.size()));
    for (int i = 0; i < static_cast<int>(completed.size()); ++i) {
        const auto* e = completed[i];
        s.setArrayIndex(i);
        s.setValue(QStringLiteral("id"),         e->id);
        s.setValue(QStringLiteral("title"),      e->title);
        s.setValue(QStringLiteral("url"),        e->sourceUrl);
        s.setValue(QStringLiteral("destPath"),   e->destPath);
        s.setValue(QStringLiteral("mime"),       e->mime);
        s.setValue(QStringLiteral("size"),       e->total);
        s.setValue(QStringLiteral("finishedAt"), e->finishedAtMsec);
    }
    s.endArray();
    s.sync();
}

// ─── filename / path resolution ──────────────────────────────────────────

QString DownloadsModel::computeDestPath(const QString& title, const QString& sourceUrl, const QString& mime) const {
    const auto dir = downloadsFolder();
    QDir().mkpath(dir);

    auto base = sanitizeFilename(title);
    if (base.isEmpty()) {
        // Last resort — pull the final path segment off the URL (without
        // query string). Usually produces something like "abc123" for
        // presigned URLs.
        const QUrl url(sourceUrl);
        base = sanitizeFilename(QFileInfo(url.path()).completeBaseName());
    }
    if (base.isEmpty()) base = QStringLiteral("video");

    const auto ext = extensionFor(sourceUrl, mime);

    QString candidate = QStringLiteral("%1/%2.%3").arg(dir, base, ext);
    int n = 1;
    while (QFile::exists(candidate) || QFile::exists(candidate + QStringLiteral(".part"))) {
        candidate = QStringLiteral("%1/%2 (%3).%4").arg(dir, base).arg(n).arg(ext);
        ++n;
        if (n > 999) break;  // don't spin forever
    }
    return candidate;
}

QString DownloadsModel::sanitizeFilename(const QString& title) {
    // Allowed-char rules have to be the intersection of what's valid on
    // Windows and Linux. Windows is the stricter one — it rejects the
    // following anywhere in the path: < > : " / \ | ? * and all control
    // chars.
    static const QRegularExpression illegal(QStringLiteral("[<>:\"/\\\\|?*\\x00-\\x1F]"));
    auto clean = title.trimmed();
    clean.replace(illegal, QStringLiteral("_"));

    // Collapse runs of whitespace — titles from the server occasionally
    // carry a trailing newline that would otherwise disguise a hidden
    // character.
    static const QRegularExpression ws(QStringLiteral("\\s+"));
    clean.replace(ws, QStringLiteral(" "));

    // Windows reserved device names (CON, PRN, AUX, NUL, COM1-9, LPT1-9)
    // — still illegal even with an extension on Windows. Sidestep by
    // prefixing.
    static const QRegularExpression reserved(
        QStringLiteral("^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$"), QRegularExpression::CaseInsensitiveOption
    );
    if (reserved.match(clean).hasMatch()) clean = QStringLiteral("_") + clean;

    // Clamp length. NTFS allows 255 chars in a name, ext4 allows 255
    // bytes. 120 is a safe value that leaves headroom for the
    // " (1).mp4" suffix and for UTF-8 multi-byte characters.
    if (clean.size() > 120) clean = clean.left(120).trimmed();

    // Trim trailing dots/spaces — Windows silently strips these, which
    // would make our "already exists?" check lie to us.
    while (!clean.isEmpty() && (clean.endsWith(QLatin1Char(' ')) || clean.endsWith(QLatin1Char('.')))) {
        clean.chop(1);
    }
    return clean;
}

QString DownloadsModel::extensionFor(const QString& sourceUrl, const QString& mime) {
    // Prefer the URL's own extension — it's what the server is actually
    // serving, and picking anything else leads to unplayable files.
    const QUrl url(sourceUrl);
    const auto urlExt = QFileInfo(url.path()).suffix().toLower();
    static const QStringList known{
        QStringLiteral("mp4"),  QStringLiteral("mkv"), QStringLiteral("webm"), QStringLiteral("mov"),
        QStringLiteral("avi"),  QStringLiteral("flv"), QStringLiteral("wmv"),  QStringLiteral("m4v"),
        QStringLiteral("ts"),
    };
    if (known.contains(urlExt)) return urlExt;

    // Fall back to MIME → extension.
    if (!mime.isEmpty()) {
        QMimeDatabase db;
        const auto type = db.mimeTypeForName(mime);
        if (type.isValid()) {
            const auto pref = type.preferredSuffix().toLower();
            if (!pref.isEmpty()) return pref;
        }
    }
    return QStringLiteral("mp4");
}
