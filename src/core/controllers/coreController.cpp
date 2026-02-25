#include "coreController.h"
#include "../../utils.h"
#include "../config.in.h"

// TODO: make a system controller possible

// TODO: provide telegramClient_ as a qml context
CoreController::CoreController(QQmlApplicationEngine* engine, TelegramClient* client, QObject* parent)
    : QObject(parent), engine_(engine) {
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
