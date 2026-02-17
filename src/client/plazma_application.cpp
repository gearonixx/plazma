#include "plazma_application.h"

#include <QObject>
#include <QUrl>

#include <QQmlApplicationEngine>

static constexpr const char* kRootQmlFileUrl = "qrc://main.qml";

PlazmaApplication::init() {
    engine_ = new QQmlApplicationEngine;

    const QUrl url(QStringLiteral(kRootQmlFileUrl));

    QObject::connect(engine_, &QQmlApplicationEngine::objectCreated, this, [this, url]() {

    });
};
