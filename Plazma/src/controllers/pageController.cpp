#include "pageController.h"

#include <QCoreApplication>
#include <QMetaEnum>

PageController::PageController(QObject* parent) : QObject(parent) {}

QString PageController::getPagePath(PageLoader::PageEnum page) {
    QMetaEnum metaEnum = QMetaEnum::fromType<PageLoader::PageEnum>();
    QString pageName = metaEnum.valueToKey(static_cast<int>(page));

    return "qrc:/ui/Pages/" + pageName + ".qml";
}

void PageController::showOnStartup() { emit raiseMainWindow(); }

void PageController::closeWindow() {
#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
    qApp->quit();
#else
    emit hideMainWindow();
#endif
}

void PageController::hideWindow() { emit hideMainWindow(); }

void PageController::closeApplication() { qApp->quit(); }

void PageController::keyPressEvent(Qt::Key key) {
    switch (key) {
        case Qt::Key_Back:
        case Qt::Key_Escape: {
            if (m_drawerDepth) {
                emit closeTopDrawer();
                decrementDrawerDepth();
            } else {
                emit escapePressed();
            }
            break;
        }
        default:
            return;
    }
}

void PageController::setDrawerDepth(int depth) {
    if (depth >= 0) {
        m_drawerDepth = depth;
    }
}

int PageController::getDrawerDepth() const { return m_drawerDepth; }

int PageController::incrementDrawerDepth() { return ++m_drawerDepth; }

int PageController::decrementDrawerDepth() {
    if (m_drawerDepth == 0) {
        return m_drawerDepth;
    }
    return --m_drawerDepth;
}
