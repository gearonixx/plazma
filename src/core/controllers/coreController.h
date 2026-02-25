#pragma once

#include <QQmlApplicationEngine>

#include "src/controllers/systemController.h"
#include "src/controllers/pageController.h"

#include "src/models/auth_code_model.h"
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

    QQmlApplicationEngine* qmlEngine_ {};

    QSharedPointer<PageController> pageController_;

    QScopedPointer<SystemsController> systemsController_;

    QSharedPointer<PhoneNumberModel> phoneNumberModel_;
    QSharedPointer<AuthorizationCodeModel> authCodeModel_;
};