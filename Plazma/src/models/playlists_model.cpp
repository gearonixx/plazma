#include "playlists_model.h"

#include <QDateTime>
#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#include <QUuid>

#include <algorithm>

namespace {
constexpr auto kStoreKey = "playlists/data";
constexpr int kPreviewThumbs = 4;
}  // namespace

PlaylistsModel::PlaylistsModel(QObject* parent) : QAbstractListModel(parent) {
    load();
}

int PlaylistsModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) return 0;
    return static_cast<int>(playlists_.size());
}

QVariant PlaylistsModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= static_cast<int>(playlists_.size())) {
        return {};
    }
    const auto& p = playlists_[index.row()];
    switch (role) {
        case IdRole:
            return p.id;
        case NameRole:
            return p.name;
        case VideoCountRole:
            return static_cast<int>(p.videos.size());
        case ThumbnailsRole:
            return previewThumbnails(p);
        case FirstThumbRole:
            return firstThumbnail(p);
        case UpdatedAtRole:
            return p.updatedAt;
        default:
            return {};
    }
}

QHash<int, QByteArray> PlaylistsModel::roleNames() const {
    return {
        {IdRole, "id"},
        {NameRole, "name"},
        {VideoCountRole, "videoCount"},
        {ThumbnailsRole, "thumbnails"},
        {FirstThumbRole, "coverThumbnail"},
        {UpdatedAtRole, "updatedAt"},
    };
}

QString PlaylistsModel::currentPlaylistName() const {
    const auto* p = find(currentId_);
    return p ? p->name : QString();
}

QVariantList PlaylistsModel::currentVideos() const {
    const auto* p = find(currentId_);
    if (!p) return {};
    QVariantList out;
    out.reserve(static_cast<int>(p->videos.size()));
    for (const auto& v : p->videos) out.push_back(videoToVariant(v));
    return out;
}

QString PlaylistsModel::createPlaylist(const QString& name) {
    const QString trimmed = name.trimmed();
    if (!isValidName(trimmed) || isNameTaken(trimmed)) {
        emit notify(tr("Choose a different name"));
        return {};
    }

    Playlist p;
    p.id = makeId();
    p.name = trimmed;
    p.createdAt = isoNowUtc();
    p.updatedAt = p.createdAt;
    const QString newId = p.id;

    playlists_.push_back(std::move(p));
    sortByName();

    beginResetModel();
    endResetModel();
    emit countChanged();

    lastCreatedId_ = newId;
    emit lastCreatedChanged();

    save();
    return newId;
}

bool PlaylistsModel::renamePlaylist(const QString& id, const QString& newName) {
    const QString trimmed = newName.trimmed();
    if (!isValidName(trimmed) || isNameTaken(trimmed, id)) return false;

    auto* p = find(id);
    if (!p) return false;
    if (p->name == trimmed) return true;

    p->name = trimmed;
    touch(*p);

    sortByName();
    beginResetModel();
    endResetModel();

    if (id == currentId_) emit currentChanged();
    save();
    return true;
}

bool PlaylistsModel::deletePlaylist(const QString& id) {
    const int row = indexOf(id);
    if (row < 0) return false;

    beginRemoveRows({}, row, row);
    playlists_.erase(playlists_.begin() + row);
    endRemoveRows();
    emit countChanged();

    if (currentId_ == id) {
        currentId_.clear();
        emit currentChanged();
    }

    save();
    return true;
}

bool PlaylistsModel::addVideoToPlaylist(const QString& playlistId, const QVariantMap& videoMap) {
    auto* p = find(playlistId);
    if (!p) return false;

    Video v = videoFromVariant(videoMap);
    if (v.id.isEmpty() && v.url.isEmpty()) return false;

    // Dedup by id (preferred) or url fallback.
    const auto dupe = [&](const Video& x) {
        if (!v.id.isEmpty()) return x.id == v.id;
        return !x.url.isEmpty() && x.url == v.url;
    };
    if (std::any_of(p->videos.begin(), p->videos.end(), dupe)) {
        emit notify(tr("Already in “%1”").arg(p->name));
        return false;
    }

    if (v.addedAt.isEmpty()) v.addedAt = isoNowUtc();
    p->videos.push_back(std::move(v));
    touch(*p);

    const int row = indexOf(playlistId);
    if (row >= 0) {
        const QModelIndex mi = index(row);
        emit dataChanged(mi, mi, {VideoCountRole, ThumbnailsRole, FirstThumbRole, UpdatedAtRole});
    }
    if (playlistId == currentId_) emit currentChanged();

    emit notify(tr("Saved to “%1”").arg(p->name));
    save();
    return true;
}

bool PlaylistsModel::removeVideoFromPlaylist(const QString& playlistId, const QString& videoId) {
    auto* p = find(playlistId);
    if (!p) return false;

    const auto before = p->videos.size();
    p->videos.erase(
        std::remove_if(p->videos.begin(), p->videos.end(), [&](const Video& v) { return v.id == videoId; }),
        p->videos.end()
    );
    if (p->videos.size() == before) return false;

    touch(*p);
    const int row = indexOf(playlistId);
    if (row >= 0) {
        const QModelIndex mi = index(row);
        emit dataChanged(mi, mi, {VideoCountRole, ThumbnailsRole, FirstThumbRole, UpdatedAtRole});
    }
    if (playlistId == currentId_) emit currentChanged();

    save();
    return true;
}

bool PlaylistsModel::playlistContains(const QString& playlistId, const QString& videoId) const {
    const auto* p = find(playlistId);
    if (!p || videoId.isEmpty()) return false;
    return std::any_of(p->videos.begin(), p->videos.end(), [&](const Video& v) { return v.id == videoId; });
}

QString PlaylistsModel::playlistName(const QString& id) const {
    const auto* p = find(id);
    return p ? p->name : QString();
}

QStringList PlaylistsModel::playlistsContaining(const QString& videoId) const {
    QStringList ids;
    if (videoId.isEmpty()) return ids;
    for (const auto& p : playlists_) {
        if (std::any_of(p.videos.begin(), p.videos.end(), [&](const Video& v) { return v.id == videoId; })) {
            ids.push_back(p.id);
        }
    }
    return ids;
}

QVariantList PlaylistsModel::summariesForVideo(const QString& videoId) const {
    QVariantList out;
    out.reserve(static_cast<int>(playlists_.size()));
    for (const auto& p : playlists_) {
        QVariantMap m;
        m.insert("id", p.id);
        m.insert("name", p.name);
        m.insert("videoCount", static_cast<int>(p.videos.size()));
        m.insert("contains", videoId.isEmpty()
                                ? false
                                : std::any_of(p.videos.begin(), p.videos.end(),
                                              [&](const Video& v) { return v.id == videoId; }));
        out.push_back(m);
    }
    return out;
}

bool PlaylistsModel::isValidName(const QString& name) const {
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty()) return false;
    if (trimmed.length() > 100) return false;
    return true;
}

bool PlaylistsModel::isNameTaken(const QString& name, const QString& exceptId) const {
    const QString trimmed = name.trimmed();
    for (const auto& p : playlists_) {
        if (p.id == exceptId) continue;
        if (p.name.compare(trimmed, Qt::CaseInsensitive) == 0) return true;
    }
    return false;
}

void PlaylistsModel::openPlaylist(const QString& id) {
    if (currentId_ == id) return;
    const auto* p = find(id);
    if (!p) return;
    currentId_ = id;
    emit currentChanged();
}

void PlaylistsModel::closeCurrent() {
    if (currentId_.isEmpty()) return;
    currentId_.clear();
    emit currentChanged();
}

void PlaylistsModel::load() {
    QSettings s;
    const QByteArray blob = s.value(kStoreKey).toByteArray();
    if (blob.isEmpty()) return;

    QJsonParseError err{};
    const auto doc = QJsonDocument::fromJson(blob, &err);
    if (err.error != QJsonParseError::NoError || !doc.isArray()) {
        qWarning() << "[Playlists] corrupt store blob — dropping:" << err.errorString();
        return;
    }

    playlists_.clear();
    const auto arr = doc.array();
    playlists_.reserve(arr.size());
    for (const auto& v : arr) {
        if (!v.isObject()) continue;
        playlists_.push_back(fromJson(v.toObject()));
    }
    sortByName();
}

void PlaylistsModel::save() const {
    QJsonArray arr;
    for (const auto& p : playlists_) arr.push_back(toJson(p));
    QSettings s;
    s.setValue(kStoreKey, QJsonDocument(arr).toJson(QJsonDocument::Compact));
}

void PlaylistsModel::sortByName() {
    std::sort(playlists_.begin(), playlists_.end(), [](const Playlist& a, const Playlist& b) {
        const int cmp = a.name.localeAwareCompare(b.name);
        if (cmp != 0) return cmp < 0;
        return a.id < b.id;
    });
}

int PlaylistsModel::indexOf(const QString& id) const {
    for (int i = 0; i < static_cast<int>(playlists_.size()); ++i) {
        if (playlists_[i].id == id) return i;
    }
    return -1;
}

PlaylistsModel::Playlist* PlaylistsModel::find(const QString& id) {
    const int i = indexOf(id);
    return i >= 0 ? &playlists_[i] : nullptr;
}

const PlaylistsModel::Playlist* PlaylistsModel::find(const QString& id) const {
    const int i = indexOf(id);
    return i >= 0 ? &playlists_[i] : nullptr;
}

void PlaylistsModel::touch(Playlist& p) {
    p.updatedAt = isoNowUtc();
}

QStringList PlaylistsModel::previewThumbnails(const Playlist& p) const {
    QStringList out;
    for (const auto& v : p.videos) {
        if (!v.thumbnail.isEmpty()) {
            out.push_back(v.thumbnail);
            if (out.size() >= kPreviewThumbs) break;
        }
    }
    return out;
}

QString PlaylistsModel::firstThumbnail(const Playlist& p) const {
    for (const auto& v : p.videos) {
        if (!v.thumbnail.isEmpty()) return v.thumbnail;
    }
    return {};
}

QJsonObject PlaylistsModel::toJson(const Playlist& p) {
    QJsonArray videos;
    for (const auto& v : p.videos) videos.push_back(videoToJson(v));
    return QJsonObject{
        {"id", p.id},
        {"name", p.name},
        {"createdAt", p.createdAt},
        {"updatedAt", p.updatedAt},
        {"videos", videos},
    };
}

PlaylistsModel::Playlist PlaylistsModel::fromJson(const QJsonObject& o) {
    Playlist p;
    p.id = o.value("id").toString();
    p.name = o.value("name").toString();
    p.createdAt = o.value("createdAt").toString();
    p.updatedAt = o.value("updatedAt").toString();
    const auto arr = o.value("videos").toArray();
    p.videos.reserve(arr.size());
    for (const auto& v : arr) {
        if (!v.isObject()) continue;
        p.videos.push_back(videoFromJson(v.toObject()));
    }
    if (p.id.isEmpty()) p.id = makeId();  // migrate any pre-id entries
    return p;
}

QJsonObject PlaylistsModel::videoToJson(const Video& v) {
    return QJsonObject{
        {"id", v.id},
        {"title", v.title},
        {"url", v.url},
        {"size", static_cast<qint64>(v.size)},
        {"mime", v.mime},
        {"author", v.author},
        {"createdAt", v.createdAt},
        {"thumbnail", v.thumbnail},
        {"storyboard", v.storyboard},
        {"description", v.description},
        {"addedAt", v.addedAt},
    };
}

PlaylistsModel::Video PlaylistsModel::videoFromJson(const QJsonObject& o) {
    Video v;
    v.id = o.value("id").toString();
    v.title = o.value("title").toString();
    v.url = o.value("url").toString();
    v.size = o.value("size").toVariant().toLongLong();
    v.mime = o.value("mime").toString();
    v.author = o.value("author").toString();
    v.createdAt = o.value("createdAt").toString();
    v.thumbnail = o.value("thumbnail").toString();
    v.storyboard = o.value("storyboard").toString();
    v.description = o.value("description").toString();
    v.addedAt = o.value("addedAt").toString();
    return v;
}

PlaylistsModel::Video PlaylistsModel::videoFromVariant(const QVariantMap& m) {
    Video v;
    v.id = m.value("id").toString();
    v.title = m.value("title").toString();
    v.url = m.value("url").toString();
    v.size = m.value("size").toLongLong();
    v.mime = m.value("mime").toString();
    v.author = m.value("author").toString();
    v.createdAt = m.value("createdAt").toString();
    v.thumbnail = m.value("thumbnail").toString();
    v.storyboard = m.value("storyboard").toString();
    v.description = m.value("description").toString();
    v.addedAt = m.value("addedAt").toString();
    return v;
}

QVariantMap PlaylistsModel::videoToVariant(const Video& v) {
    QVariantMap m;
    m.insert("id", v.id);
    m.insert("title", v.title);
    m.insert("url", v.url);
    m.insert("size", v.size);
    m.insert("mime", v.mime);
    m.insert("author", v.author);
    m.insert("createdAt", v.createdAt);
    m.insert("thumbnail", v.thumbnail);
    m.insert("storyboard", v.storyboard);
    m.insert("description", v.description);
    m.insert("addedAt", v.addedAt);
    return m;
}

QString PlaylistsModel::makeId() {
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

QString PlaylistsModel::isoNowUtc() {
    return QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
}
