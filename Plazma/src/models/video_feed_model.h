#pragma once

#include <QAbstractListModel>
#include <QElapsedTimer>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <vector>

class Api;
class QTimer;

class VideoFeedModel : public QAbstractListModel {
    Q_OBJECT

    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
    Q_PROPERTY(QString currentUrl READ currentUrl NOTIFY currentChanged)
    Q_PROPERTY(QString currentTitle READ currentTitle NOTIFY currentChanged)
    Q_PROPERTY(QVariantMap currentVideo READ currentVideo NOTIFY currentChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        TitleRole,
        UrlRole,
        SizeRole,
        MimeRole,
        AuthorRole,
        CreatedAtRole,
        ThumbnailRole,
        StoryboardRole,
        DescriptionRole,
    };

    // TODO(grnx): yeah like that's too simple
    struct VideoItem {
        QString id;
        QString title;
        QString url;
        qint64 size = 0;
        QString mime;
        QString author;
        QString createdAt;
        QString thumbnail;
        QString storyboard;
        // Long-form description shown on the watch page. Server-optional:
        // older / unextended payloads omit it and the player renders an
        // empty-state placeholder instead.
        QString description;
    };

    explicit VideoFeedModel(Api* api, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    [[nodiscard]] bool loading() const { return loading_; }
    [[nodiscard]] QString errorMessage() const { return errorMessage_; }
    [[nodiscard]] QString currentUrl() const { return currentUrl_; }
    [[nodiscard]] QString currentTitle() const { return currentTitle_; }
    [[nodiscard]] QVariantMap currentVideo() const { return currentVideo_; }
    [[nodiscard]] int count() const { return static_cast<int>(items_.size()); }

public slots:
    void refresh();

    // Minimal form — used by the drag-and-drop / file-open flows in
    // PagePlayer where we don't have a full feed row, just a URL + title.
    // Clears the rest of currentVideo so QML never reads stale metadata.
    void setCurrent(const QString& url, const QString& title);

    // Full form — call this from feed / profile / playlist-detail card clicks
    // so the player page gets author, createdAt, thumbnail, size, etc. The
    // map has the same shape as a feed row: id, title, url, size, mime,
    // author, createdAt, thumbnail, storyboard.
    Q_INVOKABLE void setCurrentVideo(const QVariantMap& video);

    void clearCurrent();

    void onSearchTyped(const QString& query);
    void onSearchSubmitted(const QString& query);

    // Neighbor lookups used by the watch page to implement autoplay +
    // next/previous shortcuts. Returns the row after/before `currentId` as
    // a QVariantMap (same shape the feed → setCurrentVideo() roundtrip
    // expects). Empty map if the id isn't in the current feed or we're at
    // the edge — callers should test `out.contains("url")` before playing.
    Q_INVOKABLE QVariantMap nextVideo(const QString& currentId) const;
    Q_INVOKABLE QVariantMap previousVideo(const QString& currentId) const;

signals:
    void loadingChanged();
    void errorMessageChanged();
    void currentChanged();
    void countChanged();
    void refreshed();
    void uploadFinished(QString filename);
    void uploadFailed(int statusCode, QString error);

private:
    void setLoading(bool loading);
    void setErrorMessage(const QString& message);
    void fireSearch(const QString& query);
    void doFetch(const QString& query);

    static constexpr int kSearchDebounceMs = 250;
    static constexpr int kSubmitThrottleMs = 400;

    Api* api_ = nullptr;
    std::vector<VideoItem> items_;
    bool loading_ = false;
    QString errorMessage_;
    QString currentUrl_;
    QString currentTitle_;
    QVariantMap currentVideo_;

    QTimer* searchDebounce_ = nullptr;
    QString pendingQuery_;
    QString lastFiredQuery_;
    QString activeQuery_;     // query backing the currently displayed list
    quint32 requestSeq_ = 0;  // monotonic id; stale responses are dropped
    QElapsedTimer submitThrottle_;
};
