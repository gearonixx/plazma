#include "profile_model.h"

#include <QDebug>
#include <QJsonArray>
#include <QJsonObject>
#include <algorithm>

#include "src/api.h"
#include "src/session.h"

ProfileModel::ProfileModel(Session* session, Api* api, QObject* parent)
    : QAbstractListModel(parent), session_(session), api_(api) {
    Q_ASSERT(session_ != nullptr);
    Q_ASSERT(api_ != nullptr);

    // Keep the page header reactive to auth state. Session emits sessionChanged
    // on login/logout; the profile headline and avatar glyph both derive from
    // it so we need to re-notify QML whenever session state moves.
    connect(session_, &Session::sessionChanged, this, [this] {
        emit profileChanged();
        // A fresh session means a different "me" — our cached list is stale.
        if (session_->valid()) {
            refresh();
        } else {
            beginResetModel();
            items_.clear();
            endResetModel();
            emit countChanged();
        }
    });
}

int ProfileModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) return 0;
    return static_cast<int>(items_.size());
}

QVariant ProfileModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= static_cast<int>(items_.size())) {
        return {};
    }
    const auto& item = items_[index.row()];
    switch (role) {
        case Roles::IdRole:         return item.id;
        case Roles::TitleRole:      return item.title;
        case Roles::UrlRole:        return item.url;
        case Roles::SizeRole:       return item.size;
        case Roles::MimeRole:       return item.mime;
        case Roles::AuthorRole:     return item.author;
        case Roles::CreatedAtRole:  return item.createdAt;
        case Roles::ThumbnailRole:  return item.thumbnail;
        case Roles::StoryboardRole: return item.storyboard;
        case Roles::DescriptionRole: return item.description;
        default:                    return {};
    }
}

QHash<int, QByteArray> ProfileModel::roleNames() const {
    return {
        {Roles::IdRole, "id"},
        {Roles::TitleRole, "title"},
        {Roles::UrlRole, "url"},
        {Roles::SizeRole, "size"},
        {Roles::MimeRole, "mime"},
        {Roles::AuthorRole, "author"},
        {Roles::CreatedAtRole, "createdAt"},
        {Roles::ThumbnailRole, "thumbnail"},
        {Roles::StoryboardRole, "storyboard"},
        {Roles::DescriptionRole, "description"},
    };
}

qint64 ProfileModel::userId() const { return session_->valid() ? session_->userId() : 0; }

QString ProfileModel::username() const { return session_->valid() ? session_->username() : QString{}; }

QString ProfileModel::displayName() const {
    if (!session_->valid()) return tr("Signed out");
    const auto u = session_->username();
    if (!u.isEmpty()) return QStringLiteral("@") + u;
    // Requirement: when there's no username, the page must display "just a
    // user_id and that's it". We prefix with "User #" for readability — the
    // raw number alone reads like a timestamp.
    return tr("User #%1").arg(session_->userId());
}

QString ProfileModel::handle() const {
    if (!session_->valid()) return {};
    return QStringLiteral("ID %1").arg(session_->userId());
}

QString ProfileModel::avatarInitial() const {
    if (!session_->valid()) return QStringLiteral("?");
    const auto u = session_->username();
    if (!u.isEmpty()) {
        // Skip an @ if the username happened to carry one.
        int i = 0;
        while (i < u.size() && (u[i] == QLatin1Char('@') || u[i].isSpace())) ++i;
        if (i < u.size()) return u.mid(i, 1).toUpper();
    }
    // No username — the glyph should read as "numeric id" without being a
    // random digit (digits fight the circular avatar visually).
    return QStringLiteral("#");
}

int ProfileModel::avatarPaletteIndex() const {
    // Seven Telegram-ish accent buckets, picked deterministically off the
    // user id so each user is always the same color across sessions.
    if (!session_->valid()) return 0;
    const auto id = session_->userId();
    return static_cast<int>(std::llabs(id) % 7);
}

qint64 ProfileModel::totalSize() const {
    qint64 sum = 0;
    for (const auto& v : items_) sum += v.size;
    return sum;
}

void ProfileModel::refresh() {
    if (!session_->valid()) return;
    if (loading_) return;

    const quint32 seq = ++requestSeq_;
    setLoading(true);
    setErrorMessage({});

    api_->fetchVideos(
        {},
        [this, seq](const QJsonArray& arr) {
            if (seq != requestSeq_) return;

            std::vector<VideoFeedModel::VideoItem> all;
            all.reserve(arr.size());
            for (const auto& v : arr) {
                const auto o = v.toObject();
                all.push_back(VideoFeedModel::VideoItem{
                    .id        = o.value("id").toString(),
                    .title     = o.value("title").toString(o.value("name").toString()),
                    .url       = o.value("url").toString(),
                    .size      = o.value("size").toVariant().toLongLong(),
                    .mime      = o.value("mime").toString(o.value("content_type").toString()),
                    .author    = o.value("author").toString(),
                    .createdAt = o.value("created_at").toString(),
                    .thumbnail = o.value("thumbnail").toString(),
                    .storyboard = o.value("storyboard").toString(),
                    .description = o.value("description").toString(o.value("summary").toString()),
                });
            }
            applyVideos(all);
            setLoading(false);
        },
        [this, seq](int code, const QString& error) {
            if (seq != requestSeq_) return;
            setErrorMessage(QStringLiteral("HTTP %1: %2").arg(code).arg(error));
            setLoading(false);
        }
    );
}

void ProfileModel::applyVideos(const std::vector<VideoFeedModel::VideoItem>& all) {
    std::vector<VideoFeedModel::VideoItem> mine;
    mine.reserve(all.size());
    for (const auto& v : all) {
        if (isMine(v)) mine.push_back(v);
    }

    beginResetModel();
    items_ = std::move(mine);
    endResetModel();
    emit countChanged();
}

bool ProfileModel::isMine(const VideoFeedModel::VideoItem& v) const {
    // The server writes `author` as whatever was supplied at upload. Our
    // login payload sends username + firstName + lastName; match liberally
    // against any of them (trimmed, case-insensitive) so reconnecting from
    // a different client doesn't orphan the channel.
    const auto author = v.author.trimmed();
    if (author.isEmpty()) return false;

    const auto un = session_->username().trimmed();
    const auto fn = session_->firstName().trimmed();
    const auto ln = session_->lastName().trimmed();

    const Qt::CaseSensitivity ci = Qt::CaseInsensitive;
    if (!un.isEmpty() && author.compare(un, ci) == 0) return true;
    if (!fn.isEmpty() && author.compare(fn, ci) == 0) return true;
    if (!ln.isEmpty() && author.compare(ln, ci) == 0) return true;
    // Some servers prefix the handle with '@' in the payload.
    if (!un.isEmpty() && author.compare(QStringLiteral("@") + un, ci) == 0) return true;
    return false;
}

void ProfileModel::deleteVideo(const QString& id) {
    if (id.isEmpty()) return;

    // Optimistic removal: find the row, drop it, remember enough to restore
    // on failure. Keeps the UI responsive without burning a full refresh.
    const auto it = std::find_if(
        items_.begin(), items_.end(),
        [&](const VideoFeedModel::VideoItem& v) { return v.id == id; }
    );
    if (it == items_.end()) return;

    const int row = static_cast<int>(std::distance(items_.begin(), it));
    const auto snapshot = *it;

    beginRemoveRows({}, row, row);
    items_.erase(it);
    endRemoveRows();
    emit countChanged();

    api_->deleteVideo(
        id,
        [this, id] {
            emit videoDeleted(id);
        },
        [this, row, snapshot, id](int code, const QString& error) {
            // Roll back the optimistic remove.
            const int clamped = std::min(row, static_cast<int>(items_.size()));
            beginInsertRows({}, clamped, clamped);
            items_.insert(items_.begin() + clamped, snapshot);
            endInsertRows();
            emit countChanged();

            const auto msg = QStringLiteral("HTTP %1: %2").arg(code).arg(error);
            setErrorMessage(msg);
            emit actionFailed(tr("delete"), msg);
            qWarning() << "[Profile] delete failed:" << id << code << error;
        }
    );
}

void ProfileModel::renameVideo(const QString& id, const QString& newTitle) {
    if (id.isEmpty()) return;
    const auto trimmed = newTitle.trimmed();
    if (trimmed.isEmpty()) return;

    const auto it = std::find_if(
        items_.begin(), items_.end(),
        [&](const VideoFeedModel::VideoItem& v) { return v.id == id; }
    );
    if (it == items_.end()) return;

    const int row = static_cast<int>(std::distance(items_.begin(), it));
    const auto oldTitle = it->title;

    // Optimistic title swap — let the UI reflect the new value while the
    // PATCH is in flight.
    it->title = trimmed;
    const auto idx = index(row);
    emit dataChanged(idx, idx, {Roles::TitleRole});

    api_->renameVideo(
        id, trimmed,
        [this, id, trimmed] {
            emit videoRenamed(id, trimmed);
        },
        [this, id, oldTitle, row](int code, const QString& error) {
            if (row >= 0 && row < static_cast<int>(items_.size()) && items_[row].id == id) {
                items_[row].title = oldTitle;
                const auto idx = index(row);
                emit dataChanged(idx, idx, {Roles::TitleRole});
            }
            const auto msg = QStringLiteral("HTTP %1: %2").arg(code).arg(error);
            setErrorMessage(msg);
            emit actionFailed(tr("rename"), msg);
            qWarning() << "[Profile] rename failed:" << id << code << error;
        }
    );
}

void ProfileModel::setLoading(bool loading) {
    if (loading_ == loading) return;
    loading_ = loading;
    emit loadingChanged();
}

void ProfileModel::setErrorMessage(const QString& message) {
    if (errorMessage_ == message) return;
    errorMessage_ = message;
    emit errorMessageChanged();
}
