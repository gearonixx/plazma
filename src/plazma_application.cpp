#include "plazma_application.h"

#include <QObject>
#include <QUrl>

#include <QQmlApplicationEngine>

static constexpr const char* kRootQmlFileUrl = "qrc://main.qml";

void PlazmaApplication::init() {
    engine_ = new QQmlApplicationEngine;

    rootQmlFileUrl_ = QString::fromUtf8(kRootQmlFileUrl);

    QObject::connect(
        engine_,
        &QQmlApplicationEngine::objectCreated,
        this,
        &PlazmaApplication::onObjectCreated,

        Qt::QueuedConnection
    );
};

void PlazmaApplication::onObjectCreated(const QObject* qmlObject, const QUrl& objectUrl) {
    Q_ASSERT(!rootQmlFileUrl_.isEmpty());
    bool isMainFile = rootQmlFileUrl_ == objectUrl;

    if (!qmlObject && isMainFile) {
        QCoreApplication::exit(1);
        return;
    };
};

void PlazmaApplication::forceQuit() { force_quit_ = true; };