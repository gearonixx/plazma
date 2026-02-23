#include <QApplication>

#include "version.h"

#include <qcoreapplication.h>
#include <qguiapplication.h>
#include <QPushButton>

#include "client.h"

#include "core/osSignalHandler.h"

#include "plazma_application.h"

#include "../config.in.h"

Q_DECL_EXPORT int main(int argc, char* argv[]) {
    PlazmaApplication plazma(argc, argv);
    OsSignalHandler::setup();

    plazma.setApplicationName(APPLICATION_NAME);
    plazma.setApplicationDisplayName(APPLICATION_NAME);
    plazma.setApplicationVersion(PLAZMA_VERSION_STRING);

    plazma.init();

    qInfo().noquote() << QString("Started %1 version %2 %3").arg(APPLICATION_NAME, APP_VERSION, APPLICATION_ID);
    qInfo().noquote() << QString("%1 (%2)").arg(QSysInfo::prettyProductName(), QSysInfo::currentCpuArchitecture());

    plazma.exec();

    return 0;
}
