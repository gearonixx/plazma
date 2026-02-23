#include "plazma_application.h"

#include <QObject>
#include <QUrl>

#include <QQmlApplicationEngine>

#include <QtQuick/QQuickWindow>

#include "config.in.h"

static constexpr const char* kRootQmlFileUrl = "qrc:///main.qml";

bool PlazmaApplication::forceQuit_ = false;

PlazmaApplication::PlazmaApplication(int& argc, char* argv[]) : PLAZMA_BASE_CLASS(argc, argv) {
    setDesktopFileName(APPLICATION_NAME);

    setQuitOnLastWindowClosed(false);
}

void PlazmaApplication::init() {
    qmlEngine_ = new QQmlApplicationEngine;

    rootQmlFileUrl_ = QString::fromUtf8(kRootQmlFileUrl);

    QObject::connect(
        qmlEngine_,
        &QQmlApplicationEngine::objectCreated,
        this,
        &PlazmaApplication::onObjectCreated,

        Qt::QueuedConnection
    );

    telegramClient_.reset(new TelegramClient);
    coreController_.reset(new CoreController(qmlEngine_, telegramClient_.data()));

    qmlEngine_->load(rootQmlFileUrl_);

    if (qmlEngine_->rootObjects().isEmpty()) {
        QCoreApplication::exit(0);
        return;
    }

    telegramClient_->startPolling();
};

void PlazmaApplication::onObjectCreated(QObject* qmlObject, const QUrl& objectUrl) {
    Q_ASSERT(!rootQmlFileUrl_.isEmpty());
    bool isMainFile = rootQmlFileUrl_ == objectUrl;

    if (isMainFile && !qmlObject) {
        QCoreApplication::exit(1);
        return;
    };

    if (auto win = qobject_cast<QQuickWindow*>(qmlObject)) {
        win->installEventFilter(this);
        win->show();
    };
};

void PlazmaApplication::forceQuit() { forceQuit_ = true; };

QQmlApplicationEngine* PlazmaApplication::qmlEngine() const { return qmlEngine_; };