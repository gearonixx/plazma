#pragma once

#include <QAbstractListModel>
#include <QElapsedTimer>
#include <QHash>
#include <QPointer>
#include <QString>
#include <QVariantMap>
#include <memory>
#include <vector>

#include "src/storage/part_file.h"
#include "src/utils/speed_meter.h"

class Api;
class QNetworkReply;
class QTimer;
class Session;
class Settings;
class SignalThrottle;

// DownloadsModel
// ──────────────
// Owns every "save this video to disk" job in the app. The context-menu
// "Download" action (see PageFeed / PageProfile / PagePlaylistDetail /
// PagePlayer) calls start() with a video payload; the model streams the
// HTTP response into a .part file next to its final destination, then
// atomically renames it on completion. Cross-platform by construction —
// QStandardPaths resolves to ~/Videos/Plazma on Linux and
// %USERPROFILE%\Videos\Plazma on Windows.
//
// Besides the list-model view (one row per download, active or not), the
// model publishes "latest*" scalars so a single-row DownloadBar stays
// trivial in QML, plus "aggregate*" scalars for a compact "N downloads"
// summary when multiple transfers are active.
//
// Shape follows tdesktop's Data::DownloadManager — one authoritative list
// keyed by content id (video id in our case), with concurrency-capped
// scheduling, auto-retry on transient network errors, and a persistent
// registry of completed entries so the context menu's "Open downloaded"
// action stays consistent across app restarts.
class DownloadsModel : public QAbstractListModel {
    Q_OBJECT

    Q_PROPERTY(int count READ count NOTIFY countChanged)

    // Downloads currently transferring bytes (Status::Downloading).
    Q_PROPERTY(int activeCount READ activeCount NOTIFY activeCountChanged)
    // Downloads waiting for a concurrency slot (Status::Queued).
    Q_PROPERTY(int queuedCount READ queuedCount NOTIFY queuedCountChanged)

    // ── Single-row "latest" scalars ──────────────────────────────────
    // Track whatever download the user most recently interacted with
    // (started / cancelled / retried). Stays visible a few seconds after
    // the download finishes so the user can see the "Saved" state before
    // the bar auto-collapses.
    Q_PROPERTY(QString latestId READ latestId NOTIFY latestChanged)
    Q_PROPERTY(QString latestTitle READ latestTitle NOTIFY latestChanged)
    Q_PROPERTY(qreal latestProgress READ latestProgress NOTIFY latestChanged)
    Q_PROPERTY(qint64 latestReceived READ latestReceived NOTIFY latestChanged)
    Q_PROPERTY(qint64 latestTotal READ latestTotal NOTIFY latestChanged)
    Q_PROPERTY(int latestStatus READ latestStatus NOTIFY latestChanged)
    Q_PROPERTY(QString latestDestPath READ latestDestPath NOTIFY latestChanged)
    Q_PROPERTY(QString latestError READ latestError NOTIFY latestChanged)
    // Categorized failure reason — defaults to ErrorNone. QML can switch on
    // it to show a tailored icon (cloud-off vs disk-full vs server-error)
    // or surface a "Free up space" link when it's ErrorDiskSpace.
    Q_PROPERTY(int latestErrorReason READ latestErrorReason NOTIFY latestChanged)
    // Pre-formatted scalars so QML doesn't re-implement size/speed/eta
    // formatting in three different places. All locale-aware.
    Q_PROPERTY(QString latestSpeedText READ latestSpeedText NOTIFY latestChanged)
    Q_PROPERTY(QString latestSizeText READ latestSizeText NOTIFY latestChanged)
    Q_PROPERTY(bool latestVisible READ latestVisible NOTIFY latestChanged)
    // Instantaneous throughput in bytes / second (EMA-smoothed). Zero when
    // not active or when we haven't accumulated enough samples yet.
    Q_PROPERTY(qreal latestSpeed READ latestSpeed NOTIFY latestChanged)
    // Remaining time in seconds, or -1 if unknown (no Content-Length, or
    // speed still converging). Use latestEtaText for display.
    Q_PROPERTY(qint64 latestEtaSec READ latestEtaSec NOTIFY latestChanged)
    Q_PROPERTY(QString latestEtaText READ latestEtaText NOTIFY latestChanged)

    // ── Aggregate across all active transfers ────────────────────────
    // Used by the DownloadBar to switch into a "3 downloads · 42%" mode
    // when activeCount > 1. Weighted by Content-Length when known,
    // unweighted otherwise.
    Q_PROPERTY(qreal aggregateProgress READ aggregateProgress NOTIFY latestChanged)
    Q_PROPERTY(qint64 aggregateReceived READ aggregateReceived NOTIFY latestChanged)
    Q_PROPERTY(qint64 aggregateTotal READ aggregateTotal NOTIFY latestChanged)
    Q_PROPERTY(qreal aggregateSpeed READ aggregateSpeed NOTIFY latestChanged)

    // Where the next download will land. Surfaced so the UI can render
    // "Saved to ~/Videos/Plazma" in the completion row and in tooltips.
    // NOTIFY-driven (not CONSTANT) — the user can change the destination
    // folder from the settings dialog at any time.
    Q_PROPERTY(QString downloadsFolder READ downloadsFolder NOTIFY downloadsFolderChanged)

    // Soft concurrency ceiling. Exposed so QML can say "2 of 3 slots in
    // use" if we ever build a detail view.
    Q_PROPERTY(int maxConcurrent READ maxConcurrent CONSTANT)

public:
    enum Status : int {
        Queued = 0,        // waiting for a concurrency slot (or for backoff)
        Downloading = 1,   // bytes actively flowing
        Completed = 2,     // file finalized on disk
        Failed = 3,        // gave up after exhausting retries
        Canceled = 4,      // user-initiated abort
        Paused = 5,        // user-initiated pause; .part is preserved for resume
    };
    Q_ENUM(Status)

    // Categorized failure reasons so QML can pick an icon / tone / action
    // without parsing the human-readable error string. Mirrors the same idea
    // as tdesktop's FailureReason in storage/file_download.h.
    enum ErrorReason : int {
        ErrorNone = 0,
        ErrorNetwork = 1,         // connection refused, DNS, host unreachable
        ErrorTimeout = 2,         // idle timeout fired mid-transfer
        ErrorHttp = 3,            // 4xx / 5xx after redirects resolved
        ErrorDiskSpace = 4,       // pre-flight or in-flight disk-full
        ErrorDiskWrite = 5,       // write/flush/rename failed
        ErrorAuth = 6,            // session vanished or 401/403
        ErrorOther = 7,
    };
    Q_ENUM(ErrorReason)

    enum Roles {
        IdRole = Qt::UserRole + 1,
        TitleRole,
        UrlRole,
        DestPathRole,
        ReceivedRole,
        TotalRole,
        ProgressRole,
        StatusRole,
        ErrorRole,
        SpeedRole,
        EtaSecRole,
        FinishedAtRole,
    };

    explicit DownloadsModel(
        Api* api,
        Session* session = nullptr,
        Settings* settings = nullptr,
        QObject* parent = nullptr
    );
    ~DownloadsModel() override;

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    [[nodiscard]] int count() const { return static_cast<int>(entries_.size()); }
    [[nodiscard]] int activeCount() const;
    [[nodiscard]] int queuedCount() const;
    [[nodiscard]] int maxConcurrent() const { return kMaxConcurrent; }

    [[nodiscard]] QString latestId() const;
    [[nodiscard]] QString latestTitle() const;
    [[nodiscard]] qreal latestProgress() const;
    [[nodiscard]] qint64 latestReceived() const;
    [[nodiscard]] qint64 latestTotal() const;
    [[nodiscard]] int latestStatus() const;
    [[nodiscard]] QString latestDestPath() const;
    [[nodiscard]] QString latestError() const;
    [[nodiscard]] int latestErrorReason() const;
    [[nodiscard]] QString latestSpeedText() const;
    [[nodiscard]] QString latestSizeText() const;
    [[nodiscard]] bool latestVisible() const { return latestVisible_; }
    [[nodiscard]] qreal latestSpeed() const;
    [[nodiscard]] qint64 latestEtaSec() const;
    [[nodiscard]] QString latestEtaText() const;

    [[nodiscard]] qreal aggregateProgress() const;
    [[nodiscard]] qint64 aggregateReceived() const;
    [[nodiscard]] qint64 aggregateTotal() const;
    [[nodiscard]] qreal aggregateSpeed() const;

    [[nodiscard]] QString downloadsFolder() const;

public slots:
    // Kick off a download for `video`. The map is the same shape as a
    // feed card payload: { id, title, url, size, mime }. No-op if this
    // id is already Downloading or Queued — brings the bar to the front
    // instead so the user sees what they just asked for.
    Q_INVOKABLE void start(const QVariantMap& video);

    // Abort an in-flight transfer and delete its .part file. Idempotent.
    Q_INVOKABLE void cancel(const QString& id);

    // Re-run a failed / canceled download using the cached payload. For
    // a completed entry, this is a no-op (the file is already on disk).
    Q_INVOKABLE void retry(const QString& id);

    // User-initiated pause. The current network reply is aborted, the .part
    // file is preserved on disk, and the entry transitions to Paused. The
    // free concurrency slot is given to whatever's next in the queue.
    // No-op on entries that aren't actively transferring.
    Q_INVOKABLE void pause(const QString& id);

    // User-initiated resume. Re-queues a Paused entry — kickOff() will see
    // the leftover .part and ask the server for a Range continuation. No-op
    // on entries that aren't paused.
    Q_INVOKABLE void resume(const QString& id);

    // Bulk pause / resume. Pause-all walks active+queued entries and pauses
    // each (preserving .part files). Resume-all walks paused entries and
    // re-queues them. Both no-op when there's nothing in the relevant
    // state. Useful for the "going on metered network" case.
    Q_INVOKABLE void pauseAll();
    Q_INVOKABLE void resumeAll();

    // Remove an entry from the list. On an active row this also cancels.
    // Removes the persisted record for Completed rows.
    Q_INVOKABLE void remove(const QString& id);

    // Drop every non-active row (Completed / Failed / Canceled). Active
    // downloads are kept. Also rewrites the persisted registry.
    Q_INVOKABLE void clearCompleted();

    // Drop Completed rows whose file is no longer on disk (user deleted
    // it via the file manager, etc.). Runs once on startup and can be
    // re-invoked from QML.
    Q_INVOKABLE void purgeStaleCompleted();

    // Launch the completed file in the system's default player via
    // QDesktopServices::openUrl(file://…). No-op if the download hasn't
    // finished yet.
    Q_INVOKABLE void openFile(const QString& id);

    // Reveal the saved file's parent folder in the system file manager.
    Q_INVOKABLE void openFolder(const QString& id);

    // True if there's an entry for this id in any state.
    Q_INVOKABLE bool has(const QString& id) const;

    // Current status of the id, or -1 if no entry. QML switches on this
    // int against the Status enum values.
    Q_INVOKABLE int statusOf(const QString& id) const;

    // Dismiss the inline download-bar (the user hit close). The entry
    // itself stays in the list and the download keeps running — only
    // the single-row banner is suppressed.
    Q_INVOKABLE void dismissLatest();

signals:
    void countChanged();
    void activeCountChanged();
    void queuedCountChanged();
    void latestChanged();
    void downloadsFolderChanged();

    // Human-readable single-line notifications, consumed by toasts.
    void notify(QString message);

private:
    struct Entry {
        QString id;
        QString title;
        QString sourceUrl;
        QString destPath;       // final path, e.g. .../Plazma/Foo.mp4 (kept in
                                // sync with file_->destPath() once attached)
        QString mime;
        qint64 received = 0;
        qint64 total = 0;       // Content-Length (or feed-provided size)
        qint64 finishedAtMsec = 0;
        Status status = Status::Queued;
        QString error;
        ErrorReason errorReason = ErrorReason::ErrorNone;

        // Per-job abstractions — own the moving parts so the surrounding
        // model only deals with high-level state transitions.
        std::unique_ptr<PartFile> file;
        SpeedMeter speed;
        QElapsedTimer wallClock;   // started when the entry is first created

        // Transfer-time network state (RAM only — not persisted).
        QPointer<QNetworkReply> reply;

        int retriesLeft = 0;
        bool userCanceled = false;
        bool userPaused = false;   // distinguishes user-initiated pause from
                                   // a transient network drop
        int httpStatus = 0;        // stashed on metaDataChanged → drives "HTTP 404" error text
        bool persisted = false;    // loaded from QSettings (no reply ever)
        bool destReconciled = false;  // dest path already updated to match
                                      // the response's Content-Type
    };

    // Lookup helpers (don't mutate).
    [[nodiscard]] int indexOf(const QString& id) const;
    [[nodiscard]] Entry* find(const QString& id);
    [[nodiscard]] const Entry* find(const QString& id) const;

    // Open the .part file + start the reply for the first time (or after
    // a retry). Assumes entry is currently Queued. Transitions to
    // Downloading on success; to Failed on a pre-flight failure.
    void kickOff(Entry& entry);

    // Wire the reply → entry. Assumes the entry's PartFile is already opened
    // and the entry is in Downloading state. Installs metaDataChanged
    // (HTTP status gate + content-type sniff + 206/200 reconciliation),
    // readyRead (chunked write), downloadProgress (total tracking),
    // finished (flush + rename or retry).
    void attachReply(Entry& entry);

    // Handle a QNetworkReply::finished callback — cleanup file/reply,
    // decide whether to retry/cancel/complete, update row state.
    void handleFinished(Entry& entry);

    // Apply the response's Content-Type header to the entry's destination
    // path. Re-derives the path with the right extension if the URL guess
    // was wrong. Idempotent — runs at most once per attempt, and only
    // before any bytes have hit the .part file.
    void reconcileDestFromContentType(Entry& entry);

    // Pull any Queued entries into active until we hit kMaxConcurrent.
    // Called from start() and at the end of handleFinished().
    void processQueue();

    // Push a Queued entry back into processQueue after an exponential
    // backoff — used when a transient network error just triggered a
    // retry.
    void scheduleRetryKick(const QString& id, int delayMs);

    // Notify the list view that entry `i` changed, and if it's the
    // entry driving the "latest*" scalars, route through the latest signal
    // throttle so a chunk-storm doesn't saturate QML bindings.
    void notifyRowChanged(int i);

    // Bypass the throttle for terminal transitions (Completed / Failed /
    // Canceled / Paused) so the user sees the final state immediately.
    void emitLatestImmediately();

    void setStatus(Entry& entry, Status s, const QString& error = {},
                   ErrorReason reason = ErrorReason::ErrorNone);

    // Pre-flight: enough free disk for `entry.total` (when known) plus a
    // safety margin? Returns true on pass; on fail, transitions the entry
    // to Failed with a localized error and emits notify().
    [[nodiscard]] bool checkDiskBudget(Entry& entry);

    // Cleanly tear down a transfer's network reply + file handle. Used by
    // pause(), cancel(), session-logout, and the destructor. The .part is
    // kept on disk iff `keepPartFile` is true.
    void teardownTransfer(Entry& entry, bool keepPartFile);

    // QSettings persistence — two independent groups so one rewrite can't
    // corrupt the other:
    //   * downloads/completed — history of finished downloads (file on disk)
    //   * downloads/paused    — user-paused or session-stranded transfers
    //                            with their .part files preserved on disk.
    //                            Reconstructed as Status::Paused on load so
    //                            the user explicitly resumes.
    void loadPersisted();
    void savePersisted() const;
    void savePaused() const;

    // Tuning constants — picked to match the "feel" of YouTube Premium
    // and tdesktop's download manager.
    static constexpr int kMaxConcurrent      = 3;
    static constexpr int kMaxRetries         = 2;
    static constexpr int kRetryBackoffMsBase = 1500;  // 1.5s → 3s → 6s
    static constexpr int kTransferTimeoutMs  = 30000; // 30s of no activity
    static constexpr int kSpeedSampleMs      = 300;   // EMA window
    static constexpr double kSpeedAlpha      = 0.30;  // EMA smoothing
    static constexpr int kBarHideDelayMs     = 4500;
    static constexpr int kBarHideFailMs      = 8000;
    static constexpr int kMaxPersistedCompleted = 100;
    // UI signal coalescing window. ~60 Hz keeps a fast download bar smooth
    // without firing latestChanged on every readyRead chunk.
    static constexpr int kLatestThrottleMs   = 16;
    // Minimum bytes already on disk before resume is worth attempting —
    // below this threshold the round-trip cost of a Range request usually
    // beats the savings.
    static constexpr qint64 kMinResumeBytes  = 64LL * 1024;
    // Disk-space safety cushion above the declared file size.
    static constexpr qint64 kDiskSafetyBytes = 64LL * 1024 * 1024;

    Api* api_ = nullptr;
    Session* session_ = nullptr;
    Settings* settings_ = nullptr;
    std::vector<std::unique_ptr<Entry>> entries_;
    QString latestId_;
    bool latestVisible_ = false;
    QTimer* hideTimer_ = nullptr;
    SignalThrottle* latestThrottle_ = nullptr;
};
