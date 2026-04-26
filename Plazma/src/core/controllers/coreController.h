#pragma once

#include <QCoreApplication>
#include <QQmlApplicationEngine>

#include "src/api.h"
#include "src/controllers/pageController.h"
#include "src/controllers/systemController.h"
#include "src/settings.h"

#include "src/models/auth_code_model.h"
#include "src/models/downloads_model.h"
#include "src/models/file_dialog_model.h"
#include "src/models/language_model.h"
#include "src/models/phone_number_model.h"
#include "src/models/playlists_model.h"
#include "src/models/profile_model.h"
#include "src/models/settings_model.h"
#include "src/models/user_model.h"
#include "src/models/video_feed_model.h"
#include "src/platform/file_dialog.h"
#include "src/session.h"

class CoreController : public QObject {
    Q_OBJECT;

public:
    explicit CoreController(
        QQmlApplicationEngine* engine_,
        std::shared_ptr<Settings> settings,
        TelegramClient* client,
        QObject* parent = nullptr
    );

    QSharedPointer<PageController> pageController() const;
    void setQmlRoot() const;

    // Accessors so non-QML widgets (the new C++ shell) can also bind to the
    // same singleton model instances.
    [[nodiscard]] Session              *session()        const { return session_.data(); }
    [[nodiscard]] LanguageModel        *languageModel()  const { return language_model_.data(); }
    [[nodiscard]] PhoneNumberModel     *phoneModel()     const { return phoneNumberModel_.data(); }
    [[nodiscard]] AuthorizationCodeModel *authCodeModel() const { return authCodeModel_.data(); }
    [[nodiscard]] UserModel            *userModel()      const { return userModel_.data(); }
    [[nodiscard]] VideoFeedModel       *videoFeedModel() const { return videoFeedModel_.data(); }
    [[nodiscard]] ProfileModel         *profileModel()   const { return profileModel_.data(); }
    [[nodiscard]] PlaylistsModel       *playlistsModel() const { return playlistsModel_.data(); }
    [[nodiscard]] DownloadsModel       *downloadsModel() const { return downloadsModel_.data(); }
    [[nodiscard]] SettingsModel        *settingsModel()  const { return settingsModel_.data(); }

signals:
    void translationsUpdated() const;

private:
    void initModels(TelegramClient* client);
    void initControllers();

    void initSignalHandlers();

    void initTranslationsBindings();
    void initAuthBindings();
    void initTdlibErrorBindings(TelegramClient* client);
    void updateTranslator(const QLocale& locale) const;

    QQmlApplicationEngine* qmlEngine_{};

    std::shared_ptr<Settings> settings_{};

    QSharedPointer<QTranslator> translator_;

    QSharedPointer<PageController> pageController_;

    QScopedPointer<SystemsController> systemsController_;

    QSharedPointer<LanguageModel> language_model_;
    QSharedPointer<SettingsModel> settingsModel_;

    QSharedPointer<PhoneNumberModel> phoneNumberModel_;
    QSharedPointer<AuthorizationCodeModel> authCodeModel_;

    QSharedPointer<UserModel> userModel_;
    QSharedPointer<Session> session_;

    QScopedPointer<platform::FileDialog> fileDialog_;
    QSharedPointer<FileDialogModel> fileDialogModel_;

    QSharedPointer<VideoFeedModel> videoFeedModel_;
    QSharedPointer<ProfileModel> profileModel_;
    QSharedPointer<PlaylistsModel> playlistsModel_;
    QSharedPointer<DownloadsModel> downloadsModel_;
};