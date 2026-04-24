#include "video_feed_model.h"

#include <QDebug>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonValue>
#include <QTimer>

#include "src/api.h"

VideoFeedModel::VideoFeedModel(Api* api, QObject* parent) : QAbstractListModel(parent), api_(api) {
    Q_ASSERT(api != nullptr);

    searchDebounce_ = new QTimer(this);
    searchDebounce_->setSingleShot(true);
    searchDebounce_->setInterval(kSearchDebounceMs);
    connect(searchDebounce_, &QTimer::timeout, this, [this] { fireSearch(pendingQuery_); });
}

int VideoFeedModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) return 0;
    return static_cast<int>(items_.size());
}

QVariant VideoFeedModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= static_cast<int>(items_.size())) {
        return {};
    }
    const auto& item = items_[index.row()];
    switch (role) {
        case IdRole:
            return item.id;
        case TitleRole:
            return item.title;
        case UrlRole:
            return item.url;
        case SizeRole:
            return item.size;
        case MimeRole:
            return item.mime;
        case AuthorRole:
            return item.author;
        case CreatedAtRole:
            return item.createdAt;
        case ThumbnailRole:
            return item.thumbnail;
        case StoryboardRole:
            return item.storyboard;
        case DescriptionRole:
            return item.description;
        default:
            return {};
    }
}

QHash<int, QByteArray> VideoFeedModel::roleNames() const {
    return {
        {IdRole, "id"},
        {TitleRole, "title"},
        {UrlRole, "url"},
        {SizeRole, "size"},
        {MimeRole, "mime"},
        {AuthorRole, "author"},
        {CreatedAtRole, "createdAt"},
        {ThumbnailRole, "thumbnail"},
        {StoryboardRole, "storyboard"},
        {DescriptionRole, "description"},
    };
}

void VideoFeedModel::refresh() {
    if (loading_) return;
    doFetch(activeQuery_);
}

void VideoFeedModel::onSearchTyped(const QString& query) {
    pendingQuery_ = query.trimmed();
    searchDebounce_->start();
}

void VideoFeedModel::onSearchSubmitted(const QString& query) {
    const QString q = query.trimmed();

    if (submitThrottle_.isValid() && submitThrottle_.elapsed() < kSubmitThrottleMs && q == lastFiredQuery_) {
        return;
    }

    searchDebounce_->stop();
    pendingQuery_ = q;
    fireSearch(q);
}

void VideoFeedModel::fireSearch(const QString& query) {
    if (query == lastFiredQuery_) return;

    lastFiredQuery_ = query;
    submitThrottle_.restart();

    qDebug() << "[Search] fire:" << query;
    doFetch(query);
}

void VideoFeedModel::doFetch(const QString& query) {
    const quint32 seq = ++requestSeq_;
    activeQuery_ = query;

    setLoading(true);
    setErrorMessage({});

    api_->fetchVideos(
        query,
        [this, seq](const QJsonArray& arr) {
            if (seq != requestSeq_) return;

            beginResetModel();
            items_.clear();
            items_.reserve(arr.size());

            for (const auto& v : arr) {
                const auto o = v.toObject();
                // TODO(grnx): dude that's such a primitive logic
                items_.push_back(
                    VideoItem{
                        .id = o.value("id").toString(),
                        .title = o.value("title").toString(o.value("name").toString()),
                        .url = o.value("url").toString(),
                        .size = o.value("size").toVariant().toLongLong(),
                        .mime = o.value("mime").toString(o.value("content_type").toString()),
                        .author = o.value("author").toString(),
                        .createdAt = o.value("created_at").toString(),
                        .thumbnail = o.value("thumbnail").toString(),
                        .storyboard = o.value("storyboard").toString(),
                        // Try a couple of common field names — the backend
                        // contract says "description" but older drafts used
                        // "summary"; fall through so we get whichever is set.
                        .description = o.value("description").toString(o.value("summary").toString()),
                    }
                );
            }
            endResetModel();
            emit countChanged();
            setLoading(false);
            emit refreshed();
        },
        [this, seq](int code, const QString& error) {
            if (seq != requestSeq_) return;
            setErrorMessage(QStringLiteral("HTTP %1: %2").arg(code).arg(error));
            setLoading(false);
        }
    );
}

void VideoFeedModel::setCurrent(const QString& url, const QString& title) {
    if (currentUrl_ == url && currentTitle_ == title && currentVideo_.size() <= 2) return;
    currentUrl_ = url;
    currentTitle_ = title;
    // Minimal metadata only — wipe any leftover feed-row fields so the player
    // page doesn't end up rendering the *previous* video's author/thumbnail.
    currentVideo_ = QVariantMap{
        {QStringLiteral("url"), url},
        {QStringLiteral("title"), title},
    };
    emit currentChanged();
}

void VideoFeedModel::setCurrentVideo(const QVariantMap& video) {
    const auto url = video.value(QStringLiteral("url")).toString();
    const auto title = video.value(QStringLiteral("title")).toString();
    currentUrl_ = url;
    currentTitle_ = title;
    currentVideo_ = video;
    emit currentChanged();
}

// Turn a VideoItem into the same-shaped QVariantMap QML already sees via
// `currentVideo`. Kept local because it's the only place the model emits
// structured rows by value (data() returns them role-by-role).
static QVariantMap itemToVariant(const VideoFeedModel::VideoItem& v) {
    return QVariantMap{
        {QStringLiteral("id"), v.id},
        {QStringLiteral("title"), v.title},
        {QStringLiteral("url"), v.url},
        {QStringLiteral("size"), v.size},
        {QStringLiteral("mime"), v.mime},
        {QStringLiteral("author"), v.author},
        {QStringLiteral("createdAt"), v.createdAt},
        {QStringLiteral("thumbnail"), v.thumbnail},
        {QStringLiteral("storyboard"), v.storyboard},
        {QStringLiteral("description"), v.description},
    };
}

QVariantMap VideoFeedModel::nextVideo(const QString& currentId) const {
    if (currentId.isEmpty() || items_.empty()) return {};
    for (size_t i = 0; i + 1 < items_.size(); ++i) {
        if (items_[i].id == currentId) {
            return itemToVariant(items_[i + 1]);
        }
    }
    return {};
}

QVariantMap VideoFeedModel::previousVideo(const QString& currentId) const {
    if (currentId.isEmpty() || items_.empty()) return {};
    for (size_t i = 1; i < items_.size(); ++i) {
        if (items_[i].id == currentId) {
            return itemToVariant(items_[i - 1]);
        }
    }
    return {};
}

void VideoFeedModel::clearCurrent() {
    if (currentUrl_.isEmpty() && currentTitle_.isEmpty() && currentVideo_.isEmpty()) return;
    currentUrl_.clear();
    currentTitle_.clear();
    currentVideo_.clear();
    emit currentChanged();
}

void VideoFeedModel::setLoading(bool loading) {
    if (loading_ == loading) return;
    loading_ = loading;
    emit loadingChanged();
}

void VideoFeedModel::setErrorMessage(const QString& message) {
    if (errorMessage_ == message) return;
    errorMessage_ = message;
    emit errorMessageChanged();
}
