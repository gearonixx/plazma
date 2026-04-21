#pragma once

#include <QAbstractListModel>
#include <QElapsedTimer>
#include <QString>
#include <QStringList>
#include <vector>

class Api;
class QTimer;

class VideoFeedModel : public QAbstractListModel {
    Q_OBJECT

    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
    Q_PROPERTY(QString currentUrl READ currentUrl NOTIFY currentChanged)
    Q_PROPERTY(QString currentTitle READ currentTitle NOTIFY currentChanged)
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
    };

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
    };

    explicit VideoFeedModel(Api* api, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    [[nodiscard]] bool loading() const { return loading_; }
    [[nodiscard]] QString errorMessage() const { return errorMessage_; }
    [[nodiscard]] QString currentUrl() const { return currentUrl_; }
    [[nodiscard]] QString currentTitle() const { return currentTitle_; }
    [[nodiscard]] int count() const { return static_cast<int>(items_.size()); }

public slots:
    void refresh();
    void setCurrent(const QString& url, const QString& title);
    void clearCurrent();

    void onSearchTyped(const QString& query);
    void onSearchSubmitted(const QString& query);

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

    QTimer* searchDebounce_ = nullptr;
    QString pendingQuery_;
    QString lastFiredQuery_;
    QString activeQuery_;     // query backing the currently displayed list
    quint32 requestSeq_ = 0;  // monotonic id; stale responses are dropped
    QElapsedTimer submitThrottle_;
};
