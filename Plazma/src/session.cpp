#include "session.h"
#include "api.h"

#include <QDebug>

Session::Session(QObject* parent) : QObject(parent), api_(std::make_unique<Api>(this)) {}

void Session::start(const UserLogin& user) {
    userId_ = user.userId;
    username_ = user.username;
    firstName_ = user.firstName;
    lastName_ = user.lastName;
    phoneNumber_ = user.phoneNumber;
    premium_ = user.isPremium;
    valid_ = true;

    if (!errorMessage_.isEmpty()) {
        errorMessage_.clear();
        emit errorChanged();
    }

    qDebug() << "[SESSION] Started for user" << userId_ << firstName_ << lastName_;

    emit sessionChanged();
}

void Session::reportError(int statusCode, const QString& message) {
    errorMessage_ = statusCode > 0
        ? QStringLiteral("HTTP %1: %2").arg(statusCode).arg(message)
        : message;

    qWarning() << "[SESSION] login failed:" << errorMessage_;

    emit errorChanged();
}
