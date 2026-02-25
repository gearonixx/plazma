#include "coreController.h"
#include "../../utils.h"
#include "../config.in.h"

#include <QCoreApplication>
#include <QQmlContext>

// TODO: make a system controller possible

// TODO: provide telegramClient_ as a qml context
CoreController::CoreController(QQmlApplicationEngine* engine, TelegramClient* client, QObject* parent)
    : QObject(parent), qmlEngine_(engine) {
    initModels(client);
    initControllers();

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

void CoreController::initControllers() {
    // TODO
    auto tmp_ptr = std::shared_ptr<QVariant>();
    systemsController_.reset(new SystemsController(tmp_ptr, this));
    qmlEngine_->rootContext()->setContextProperty("systemsController", systemsController_.data());

    pageController_.reset(new PageController());
    qmlEngine_->rootContext()->setContextProperty("PageController", pageController_.data());
}

void CoreController::setQmlRoot() const {
    if (qmlEngine_->rootObjects().isEmpty()) {
        qDebug() << "No rootObjects loaded";
        QCoreApplication::exit(0);
        return;
    }

    systemsController_->setQmlRoot(qmlEngine_->rootObjects().at(0));
}


QSharedPointer<PageController> CoreController::pageController() const {
   return pageController_;
}