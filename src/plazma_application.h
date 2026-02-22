#pragma once

#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
#include <QGuiApplication>
#else
#include <QApplication>
#endif

#include <QObject>
#include <QQmlApplicationEngine>

#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
#define PLAZMA_BASE_CLASS QGuiApplication
#else
#define PLAZMA_BASE_CLASS QApplication
#endif

class PlazmaApplication : public PLAZMA_BASE_CLASS {
    Q_OBJECT

    void onObjectCreated(const QObject* qmlObject, const QUrl& objectUrl);

public:
    PlazmaApplication(int& argc, char* argv[]);

    void init();

public slots:
    void forceQuit();

private:
    QQmlApplicationEngine* engine_{};

    QUrl rootQmlFileUrl_{};

    bool force_quit_ = false;
};
