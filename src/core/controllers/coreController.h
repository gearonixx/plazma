#pragma once

#include <QCoreApplication>
#include <QQmlApplicationEngine>

#include "src/controllers/pageController.h"
#include "src/controllers/systemController.h"

#include "src/models/auth_code_model.h"
#include "src/models/language_model.h"
#include "src/models/phone_number_model.h"

class CoreController : public QObject {
    Q_OBJECT;

public:
    explicit CoreController(QQmlApplicationEngine* engine_, TelegramClient* client, QObject* parent = nullptr);

    QSharedPointer<PageController> pageController() const;
    void setQmlRoot() const;

private:
    void initModels(TelegramClient* client);
    void initControllers();

    void initTranslationsBindings();
    void updateTranslator(const QLocale &locale);


    QQmlApplicationEngine* qmlEngine_{};

    QSharedPointer<QTranslator> translator_;

    QSharedPointer<PageController> pageController_;

    QScopedPointer<SystemsController> systemsController_;

    QSharedPointer<LanguageModel> language_model_;

    QSharedPointer<PhoneNumberModel> phoneNumberModel_;
    QSharedPointer<AuthorizationCodeModel> authCodeModel_;
};