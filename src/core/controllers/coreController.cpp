#include "coreController.h"
#include "../../utils.h"
#include "../config.in.h"

#include <QCoreApplication>

// TODO: make a system controller possible

// TODO: provide telegramClient_ as a qml context
CoreController::CoreController(QQmlApplicationEngine* engine, TelegramClient* client, QObject* parent)
    : QObject(parent), qmlEngine_(engine), systemsController_(std::shared_ptr<QVariant>(), this) {
    initModels(client);

    new Utils(engine);
};

void CoreController::initModels(TelegramClient* client) {
    phoneNumberModel_.reset(new PhoneNumberModel(client));
    qmlRegisterSingletonInstance<PhoneNumberModel>(APPLICATION_ID, 1, 0, "PhoneNumberModel", phoneNumberModel_.data());

    authCodeModel_.reset(new AuthorizationCodeModel(client));
    qmlRegisterSingletonInstance<AuthorizationCodeModel>(
        APPLICATION_ID, 1, 0, "AuthorizationCodeModel", authCodeModel_.data()
    );
};

void CoreController::setQmlRoot() {
    if (qmlEngine_.rootObjects().isEmpty()) {
        qDebug() << "No rootObjects loaded";

        QCoreApplication::exit(0);
        return;
    }

    systemsController_.setQmlRoot(qmlEngine_.rootObjects().at(0));
}