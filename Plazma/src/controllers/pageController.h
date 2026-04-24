#pragma once

#include <qqml.h>

#include <QObject>

namespace PageLoader {
Q_NAMESPACE

enum class PageEnum {
    PageStart = 0,
    PageLogin,
    PageFeed,
    PageUpload,
    PagePlayer,
    PageProfile,
    PagePlaylists,
    PagePlaylistDetail,
};

Q_ENUM_NS(PageEnum);

static void declareQmlEnum() {
    qmlRegisterUncreatableMetaObject(staticMetaObject, "PageEnum", 1, 0, "PageEnum", "Error: only enums");
}
}  // namespace PageLoader

class PageController : public QObject {
    Q_OBJECT

public:
    explicit PageController(QObject* parent = nullptr);

public slots:
    [[nodiscard]] Q_INVOKABLE QString getPagePath(PageLoader::PageEnum page);

    Q_INVOKABLE void goToPage(PageLoader::PageEnum page) { emit goToPageRequested(page); }
    Q_INVOKABLE void replacePage(PageLoader::PageEnum page) { emit replacePageRequested(page); }

    void showOnStartup();

    void closeWindow();
    void hideWindow();
    void closeApplication();

    void keyPressEvent(Qt::Key key);

    void setDrawerDepth(int depth);
    [[nodiscard]] int getDrawerDepth() const;
    // increment/decrement return the new depth — the return is optional info,
    // callers often just invoke for the side effect, so don't mark nodiscard.
    int incrementDrawerDepth();
    int decrementDrawerDepth();

signals:
    void goToPageRequested(PageLoader::PageEnum page);
    void replacePageRequested(PageLoader::PageEnum page);

    void closePage();
    void escapePressed();
    void closeTopDrawer();

    void hideMainWindow();
    void raiseMainWindow();

    void showErrorMessage(const QString& errorMessage);
    void showNotificationMessage(const QString& message);

    void showBusyIndicator(bool visible);
    void disableControls(bool disabled);

private:
    int m_drawerDepth = 0;
};
