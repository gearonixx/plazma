#pragma once

#include <QObject>

#include "../client.h"

class AuthorizationCodeModel : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool waitingForAuthCode READ waitingForAuthCode NOTIFY waitingForCodeChanged)

public:
    AuthorizationCodeModel(TelegramClient* client_) : client_(client_) {
        Q_ASSERT(client_ != nullptr);

        QObject::connect(client_, &TelegramClient::authCodeRequired, this, &AuthorizationCodeModel::onAuthCodeRequired);
        QObject::connect(this, &AuthorizationCodeModel::authCodeSent, client_, &TelegramClient::authCodeReceived);
    };

    explicit AuthorizationCodeModel(QObject* parent = nullptr);

    Q_INVOKABLE void submitAuthCode(const QString& code);

    // getters
    bool waitingForAuthCode() const { return waitingForAuthCode_; }

signals:
    void waitingForCodeChanged();
    void authCodeSent(const QString& code);

private slots:
    void onAuthCodeRequired() {
        waitingForAuthCode_ = true;
        emit waitingForCodeChanged();
    };

private:
    TelegramClient* client_;
    bool waitingForAuthCode_ = false;
};