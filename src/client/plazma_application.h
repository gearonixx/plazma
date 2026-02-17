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

private:
    PlazmaApplication(int& argc, char* argv[]);

public:
    void init();

private:
    QQmlApplicationEngine* engine_{};
}
