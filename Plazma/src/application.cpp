#include "application.h"

#include <QObject>
#include <QProcessEnvironment>
#include <QUrl>

#include <QQmlApplicationEngine>

#include <QtQuick/QQuickWindow>

#include "version.h"

#include "controllers/pageController.h"
#include "models/language_model.h"
#include "ui/window/main_window.h"
#include "ui/window/page_start.h"

static constexpr const char* kRootQmlFileUrl = "qrc:/ui/main.qml";
static constexpr const char* kQmlModulesUrl = "qrc:/ui/Modules/";

bool PlazmaApplication::forceQuit_ = false;

PlazmaApplication::PlazmaApplication(int& argc, char* argv[]) : PLAZMA_BASE_CLASS(argc, argv) {
    setDesktopFileName(APPLICATION_NAME);

    setQuitOnLastWindowClosed(false);

    settings_ = std::shared_ptr<Settings>(new Settings);
}

void PlazmaApplication::init() {
    qmlEngine_ = new QQmlApplicationEngine;

    rootQmlFileUrl_ = QString::fromUtf8(kRootQmlFileUrl);

    connect(
        qmlEngine_,
        &QQmlApplicationEngine::objectCreated,
        this,
        &PlazmaApplication::onObjectCreated,

        Qt::QueuedConnection
    );

    telegramClient_.reset(new TelegramClient);

    coreController_.reset(new CoreController(qmlEngine_, settings_, telegramClient_.data()));

    telegramClient_->startPolling();

    qmlEngine_->addImportPath(kQmlModulesUrl);
    qmlEngine_->load(rootQmlFileUrl_);

    if (qmlEngine_->rootObjects().isEmpty()) {
        exit(0);
        return;
    }

    coreController_->setQmlRoot();

    coreController_->pageController()->showOnStartup();

    initNativeShell();
};

void PlazmaApplication::initNativeShell() {
    // Off by default — the new framework only handles a subset of pages.
    // Launch with `PLAZMA_NATIVE_UI=1` to preview the C++ widget shell.
    const auto env = QProcessEnvironment::systemEnvironment();
    if (env.value(QStringLiteral("PLAZMA_NATIVE_UI")) != QStringLiteral("1")) {
        return;
    }

    nativeWindow_.reset(new Ui::MainWindow());
    auto *startPage = new Ui::PageStart(
        nullptr,
        coreController_->session(),
        coreController_->languageModel(),
        coreController_->phoneModel(),
        coreController_->pageController().data());
    nativeWindow_->showSection(startPage);
    nativeWindow_->setWindowTitle(QStringLiteral("Plazma — Native UI Preview"));
    nativeWindow_->show();
}

void PlazmaApplication::onObjectCreated(QObject* qmlObject, const QUrl& objectUrl) {
    Q_ASSERT(!rootQmlFileUrl_.isEmpty());
    bool isMainFile = rootQmlFileUrl_ == objectUrl;

    if (isMainFile && !qmlObject) {
        exit(1);
        return;
    };

    if (auto win = qobject_cast<QQuickWindow*>(qmlObject)) {
        win->installEventFilter(this);
        win->show();
    };
};

void PlazmaApplication::registerTypes() {
    LanguageSettings::declareQmlAvailableLanguageEnum();
    PageLoader::declareQmlEnum();
};

void PlazmaApplication::forceQuit() { forceQuit_ = true; };

QQmlApplicationEngine* PlazmaApplication::qmlEngine() const { return qmlEngine_; };
