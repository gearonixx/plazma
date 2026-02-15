#include <QApplication>

#include "version.h"

#include <qcoreapplication.h>
#include <qguiapplication.h>
#include <qobject.h>
#include <QPushButton>
#include <QQmlApplicationEngine>

#include "utils.h"

#include "models/auth_code_model.h"
#include "models/phone_number_model.h"

#include "client.h"

constexpr const char APPLICATION_ID[] = "dev.gearonixx.plazma";
constexpr const char APPLICATION_NAME[] = "plazma";
constexpr const char APPLICATION_DISPLAY_NAME[] = "Plazma";  

Q_DECL_EXPORT int main(int argc, char* argv[]) {
    QApplication app(argc, argv);

    QCoreApplication::setApplicationName(APPLICATION_NAME);
    QGuiApplication::setApplicationDisplayName(APPLICATION_DISPLAY_NAME);
    QCoreApplication::setApplicationVersion(PLAZMA_VERSION_STRING);

    QPushButton button;

    QQmlApplicationEngine qmlEngine;

    TelegramClient client;

    PhoneNumberModel phoneNumberModel(&client);
    AuthorizationCodeModel authCodeModel(&client);

    qmlRegisterSingletonInstance<PhoneNumberModel>(APPLICATION_ID, 1, 0, "PhoneNumberModel", &phoneNumberModel);
    qmlRegisterSingletonInstance<AuthorizationCodeModel>(
        APPLICATION_ID, 1, 0, "AuthorizationCodeModel", &authCodeModel
    );

    QUrl url = QUrl("qrc:///main.qml");

    qmlEngine.load(url);

    client.startPolling();

    if (qmlEngine.rootObjects().isEmpty()) {
        return -1;
    }

    new Utils(&qmlEngine);

    return app.exec();
}
