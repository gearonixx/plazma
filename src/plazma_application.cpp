#include "plazma_application.h"

#include <QObject>
#include <QUrl>

#include <QQmlApplicationEngine>

#include <QtQuick/QQuickWindow>

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

void PlazmaApplication::onObjectCreated(QObject* qmlObject, const QUrl& objectUrl) {
    Q_ASSERT(!rootQmlFileUrl_.isEmpty());
    bool isMainFile = rootQmlFileUrl_ == objectUrl;

    if (!qmlObject && isMainFile) {
        QCoreApplication::exit(1);
        return;
    };

    if (auto win = qobject_cast<QQuickWindow*>(qmlObject)) {
        win->installEventFilter(this);
        win->show();
    };
};

void PlazmaApplication::forceQuit() { force_quit_ = true; };