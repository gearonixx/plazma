#include "osSignalHandler.h"

#include <QCoreApplication>

#ifdef Q_OS_WIN
#  include <windows.h>
#else
#  include <csignal>
#endif

namespace {

static bool initialized = false;

#ifdef Q_OS_WIN
static BOOL WINAPI winCtrlHandler(DWORD ctrl) {
    if (ctrl == CTRL_C_EVENT || ctrl == CTRL_BREAK_EVENT) {
        QCoreApplication::quit();
        return TRUE;
    }
    return FALSE;
}
#else
static void posixSignalHandler(int) {
    QCoreApplication::quit();
}
#endif

}  // namespace

OsSignalHandler::OsSignalHandler(QObject* parent) : QObject(parent) {}

void OsSignalHandler::setup() {
    if (initialized) return;
    initialized = true;

#ifdef Q_OS_WIN
    SetConsoleCtrlHandler(winCtrlHandler, TRUE);
#else
    std::signal(SIGTERM, posixSignalHandler);
    std::signal(SIGINT,  posixSignalHandler);
#endif
}

void OsSignalHandler::handleSignal(int) {}
