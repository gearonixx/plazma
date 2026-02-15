#pragma once

#include <QObject>

#include "../client.h"

class PhoneNumberModel : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool waitingForPhone READ waitingForPhone NOTIFY waitingForPhoneChanged)

public:
    PhoneNumberModel(TelegramClient* client_) : client_(client_) {
        Q_ASSERT(client_ != nullptr);

        QObject::connect(client_, &TelegramClient::phoneNumberRequired, this, &PhoneNumberModel::onPhoneNumberRequired);
        QObject::connect(this, &PhoneNumberModel::phoneNumberSent, client_, &TelegramClient::phoneNumberReceived);
    };

    explicit PhoneNumberModel(QObject* parent = nullptr);

    Q_INVOKABLE void submitPhoneNumber(const QString& phone_number);

    // getters
    bool waitingForPhone() const { return waitingForPhone_; }

signals:
    void waitingForPhoneChanged();
    void phoneNumberSent(const QString& phoneNumber);

private slots:
    void onPhoneNumberRequired() {
        waitingForPhone_ = true;
        emit waitingForPhoneChanged();
    };

private:
    TelegramClient* client_;
    bool waitingForPhone_ = false;
};