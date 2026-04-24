#pragma once

#include <QAbstractListModel>
#include <QString>
#include <vector>

#include "src/models/video_feed_model.h"

class Api;
class Session;

// ProfileModel — "my channel" page data source.
//
// Reads the identity half of its state (userId / username / avatar glyph) off
// Session, and the content half (my uploaded videos) off the same feed endpoint
// VideoFeedModel uses, filtered client-side to rows authored by the current
// user. Exposes video rows with the *same role names* as VideoFeedModel so the
// PageProfile card delegate stays identical to PageFeed's.
//
// Why client-side filter: the server only exposes GET /v1/videos and
// GET /v1/videos?q=...; there is no /v1/users/{id}/videos yet. When the
// backend grows one we can swap the refresh() implementation without
// touching QML or the roles.
class ProfileModel : public QAbstractListModel {
    Q_OBJECT

    // Identity
    Q_PROPERTY(qint64 userId READ userId NOTIFY profileChanged)
    Q_PROPERTY(QString username READ username NOTIFY profileChanged)
    Q_PROPERTY(QString displayName READ displayName NOTIFY profileChanged)
    Q_PROPERTY(QString handle READ handle NOTIFY profileChanged)
    Q_PROPERTY(bool hasUsername READ hasUsername NOTIFY profileChanged)
    Q_PROPERTY(QString avatarInitial READ avatarInitial NOTIFY profileChanged)
    Q_PROPERTY(int avatarPaletteIndex READ avatarPaletteIndex NOTIFY profileChanged)

    // Content
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(qint64 totalSize READ totalSize NOTIFY countChanged)

public:
    // Reuse VideoFeedModel's role ids verbatim so the card delegate in QML
    // can be shared between pages without two parallel role dictionaries.
    using Roles = VideoFeedModel::Roles;

    explicit ProfileModel(Session* session, Api* api, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // ── Identity ────────────────────────────────────────────────────────
    [[nodiscard]] qint64 userId() const;
    [[nodiscard]] QString username() const;
    [[nodiscard]] bool hasUsername() const { return !username().isEmpty(); }
    // What the page headline shows. @username if set, otherwise "User #<id>".
    [[nodiscard]] QString displayName() const;
    // Subline: handle-style identifier — always includes the numeric user id
    // so the page can show it even when a username exists.
    [[nodiscard]] QString handle() const;
    // Single glyph for the avatar. First letter of username, uppercased; if
    // no username, a '#' — it pairs visually with the numeric id subline.
    [[nodiscard]] QString avatarInitial() const;
    // 0..6 — deterministic per user. QML picks a gradient from its palette.
    [[nodiscard]] int avatarPaletteIndex() const;

    // ── Content ─────────────────────────────────────────────────────────
    [[nodiscard]] bool loading() const { return loading_; }
    [[nodiscard]] QString errorMessage() const { return errorMessage_; }
    [[nodiscard]] int count() const { return static_cast<int>(items_.size()); }
    [[nodiscard]] qint64 totalSize() const;

public slots:
    // Re-pull the feed and re-filter. Idempotent while a request is in flight.
    void refresh();

    // Optimistic delete: row is removed locally on the callback, with
    // rollback + errorMessage set if the server rejects. Emits videoDeleted
    // on success so other models (VideoFeedModel) can refresh too.
    void deleteVideo(const QString& id);

    // PATCH the title. The row is updated in place on success; on failure the
    // original title is restored and errorMessage is set.
    void renameVideo(const QString& id, const QString& newTitle);

signals:
    void profileChanged();
    void loadingChanged();
    void errorMessageChanged();
    void countChanged();

    // Fired after the server confirms a destructive/mutating op — lets
    // VideoFeedModel refresh so the Feed page stays in sync.
    void videoDeleted(QString id);
    void videoRenamed(QString id, QString newTitle);

    // Surfaces a short human-readable line for transient toast banners,
    // separate from errorMessage which is the "current error state" flag.
    void actionFailed(QString action, QString message);

private:
    void setLoading(bool loading);
    void setErrorMessage(const QString& message);
    void applyVideos(const std::vector<VideoFeedModel::VideoItem>& all);

    // Does a videoItem belong to the current user? Match on author equality
    // against the session username or firstName — whichever the server used
    // as author at upload time. Case-insensitive, trimmed.
    [[nodiscard]] bool isMine(const VideoFeedModel::VideoItem& v) const;

    Session* session_ = nullptr;
    Api* api_ = nullptr;

    std::vector<VideoFeedModel::VideoItem> items_;
    bool loading_ = false;
    QString errorMessage_;
    quint32 requestSeq_ = 0;
};
