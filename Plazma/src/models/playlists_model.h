#pragma once

#include <QAbstractListModel>
#include <QHash>
#include <QJsonObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <vector>

// PlaylistsModel
// ──────────────
// Single-source-of-truth for YouTube-style playlists, persisted to QSettings
// under the "playlists" group. The model acts as the A-Z list of playlists
// (exposed via QAbstractListModel) *and* publishes the contents of a single
// "opened" playlist through the currentVideos property, which the detail page
// binds to. Mutations bump `updatedAt` and re-sort alphabetically.
//
// Ordering: case-insensitive lexicographic on `name`, ties broken by `id` so
// repeated names (which the validator prevents, but defensively) stay stable.
class PlaylistsModel : public QAbstractListModel {
    Q_OBJECT

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QString currentPlaylistId READ currentPlaylistId NOTIFY currentChanged)
    Q_PROPERTY(QString currentPlaylistName READ currentPlaylistName NOTIFY currentChanged)
    Q_PROPERTY(QVariantList currentVideos READ currentVideos NOTIFY currentChanged)
    Q_PROPERTY(QString lastCreatedId READ lastCreatedId NOTIFY lastCreatedChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        NameRole,
        VideoCountRole,
        ThumbnailsRole,   // QStringList, up to 4 thumbnails — the cover mosaic
        FirstThumbRole,   // convenience: first non-empty thumbnail or ""
        UpdatedAtRole,
    };

    struct Video {
        QString id;
        QString title;
        QString url;
        qint64 size = 0;
        QString mime;
        QString author;
        QString createdAt;
        QString thumbnail;
        QString storyboard;
        QString description;  // preserved so the watch page keeps the description when replayed from a playlist entry
        QString addedAt;      // ISO-8601 UTC
    };

    struct Playlist {
        QString id;
        QString name;
        QString createdAt;
        QString updatedAt;
        std::vector<Video> videos;
    };

    explicit PlaylistsModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    [[nodiscard]] int count() const { return static_cast<int>(playlists_.size()); }
    [[nodiscard]] QString currentPlaylistId() const { return currentId_; }
    [[nodiscard]] QString currentPlaylistName() const;
    [[nodiscard]] QVariantList currentVideos() const;
    [[nodiscard]] QString lastCreatedId() const { return lastCreatedId_; }

public slots:
    // Returns the new playlist's id on success, or an empty string if the name
    // is invalid or already taken (case-insensitive).
    Q_INVOKABLE QString createPlaylist(const QString& name);
    Q_INVOKABLE bool renamePlaylist(const QString& id, const QString& newName);
    Q_INVOKABLE bool deletePlaylist(const QString& id);

    // Adds video to playlist. Idempotent — returns false if the video was
    // already present (so the UI can surface "Already in this playlist").
    Q_INVOKABLE bool addVideoToPlaylist(const QString& playlistId, const QVariantMap& video);
    Q_INVOKABLE bool removeVideoFromPlaylist(const QString& playlistId, const QString& videoId);

    Q_INVOKABLE bool playlistContains(const QString& playlistId, const QString& videoId) const;
    Q_INVOKABLE QString playlistName(const QString& id) const;
    Q_INVOKABLE QStringList playlistsContaining(const QString& videoId) const;

    // Returns a lightweight summary list {id, name, contains} for every
    // playlist — used by the "Save to playlist" submenu, which needs to know
    // which playlists already have the video.
    Q_INVOKABLE QVariantList summariesForVideo(const QString& videoId) const;

    // Validation — "Untitled" is reserved, empty/whitespace is rejected.
    Q_INVOKABLE bool isValidName(const QString& name) const;
    Q_INVOKABLE bool isNameTaken(const QString& name, const QString& exceptId = QString()) const;

    // Select a playlist as "open". The detail page binds to currentVideos.
    Q_INVOKABLE void openPlaylist(const QString& id);
    Q_INVOKABLE void closeCurrent();

signals:
    void countChanged();
    void currentChanged();
    void lastCreatedChanged();
    void notify(QString message);

private:
    void load();
    void save() const;
    void sortByName();
    int indexOf(const QString& id) const;
    Playlist* find(const QString& id);
    const Playlist* find(const QString& id) const;
    void touch(Playlist& p);
    void refreshCurrent();
    QStringList previewThumbnails(const Playlist& p) const;
    QString firstThumbnail(const Playlist& p) const;

    static QJsonObject toJson(const Playlist& p);
    static Playlist fromJson(const QJsonObject& o);
    static QJsonObject videoToJson(const Video& v);
    static Video videoFromJson(const QJsonObject& o);
    static Video videoFromVariant(const QVariantMap& m);
    static QVariantMap videoToVariant(const Video& v);
    static QString makeId();
    static QString isoNowUtc();

    std::vector<Playlist> playlists_;
    QString currentId_;
    QString lastCreatedId_;
};
