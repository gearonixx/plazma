#pragma once

#include <QQmlApplicationEngine>

#include "src/models/auth_code_model.h"
#include "src/models/phone_number_model.h"

class CoreController : public QObject {
    Q_OBJECT;

public:
    explicit CoreController(QQmlApplicationEngine* engine_, TelegramClient* client, QObject* parent = nullptr);

private:
    void initModels(TelegramClient* client);

    QQmlApplicationEngine engine_{};

    QSharedPointer<PhoneNumberModel> phoneNumberModel_;
    QSharedPointer<AuthorizationCodeModel> authCodeModel_;
};