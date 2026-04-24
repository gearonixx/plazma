#pragma once

#include <QAbstractListModel>
#include <QElapsedTimer>
#include <QHash>
#include <QPointer>
#include <QString>
#include <QVariantMap>
#include <memory>
#include <vector>

class Api;
class QFile;
class QNetworkReply;
class QTimer;
class Session;

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
    Q_PROPERTY(QString downloadsFolder READ downloadsFolder CONSTANT)

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
    };
    Q_ENUM(Status)

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

    explicit DownloadsModel(Api* api, Session* session = nullptr, QObject* parent = nullptr);
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

    // Human-readable single-line notifications, consumed by toasts.
    void notify(QString message);

private:
    struct Entry {
        QString id;
        QString title;
        QString sourceUrl;
        QString destPath;       // final path, e.g. .../Plazma/Foo.mp4
        QString partPath;       // working path, destPath + ".part"
        QString mime;
        qint64 received = 0;
        qint64 total = 0;       // Content-Length (or feed-provided size)
        qint64 finishedAtMsec = 0;
        Status status = Status::Queued;
        QString error;

        // Transfer-time state (all live in RAM only — not persisted).
        QPointer<QNetworkReply> reply;
        std::unique_ptr<QFile> file;
        QElapsedTimer wallClock;   // started when the entry is first created
        qint64 lastSampleMsec = 0;
        qint64 lastSampleBytes = 0;
        double speedBps = 0.0;

        int retriesLeft = 0;
        bool userCanceled = false;
        int httpStatus = 0;        // stashed on metaDataChanged → drives "HTTP 404" error text
        bool persisted = false;    // loaded from QSettings (no reply ever)
    };

    // Lookup helpers (don't mutate).
    [[nodiscard]] int indexOf(const QString& id) const;
    [[nodiscard]] Entry* find(const QString& id);
    [[nodiscard]] const Entry* find(const QString& id) const;

    // Pick a destination path for `title` given the source URL + mime.
    // Handles collision by appending " (1)", " (2)", … if a file already
    // exists.
    [[nodiscard]] QString computeDestPath(const QString& title, const QString& sourceUrl, const QString& mime) const;

    // Open the .part file + start the reply for the first time (or after
    // a retry). Assumes entry is currently Queued. Transitions to
    // Downloading on success; to Failed on a pre-flight failure.
    void kickOff(Entry& entry);

    // Wire the reply → entry. Assumes the entry's QFile is already opened
    // and the entry is in Downloading state. Installs metaDataChanged
    // (HTTP status gate), readyRead (chunked write), downloadProgress
    // (total tracking), finished (flush + rename or retry).
    void attachReply(Entry& entry);

    // Handle a QNetworkReply::finished callback — cleanup file/reply,
    // decide whether to retry/cancel/complete, update row state.
    void handleFinished(Entry& entry);

    // Pull any Queued entries into active until we hit kMaxConcurrent.
    // Called from start() and at the end of handleFinished().
    void processQueue();

    // Push a Queued entry back into processQueue after an exponential
    // backoff — used when a transient network error just triggered a
    // retry.
    void scheduleRetryKick(const QString& id, int delayMs);

    // Notify the list view that entry `i` changed, and if it's the
    // entry driving the "latest*" scalars, republish those too.
    void notifyRowChanged(int i);

    void setStatus(Entry& entry, Status s, const QString& error = {});
    void updateSpeed(Entry& entry);

    // QSettings persistence of Completed entries only.
    void loadPersisted();
    void savePersisted() const;

    static QString sanitizeFilename(const QString& title);
    static QString extensionFor(const QString& sourceUrl, const QString& mime);

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

    Api* api_ = nullptr;
    Session* session_ = nullptr;
    std::vector<std::unique_ptr<Entry>> entries_;
    QString latestId_;
    bool latestVisible_ = false;
    QTimer* hideTimer_ = nullptr;
};
