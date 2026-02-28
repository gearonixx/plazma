#include "coreController.h"
#include "../../utils.h"

#include <QCoreApplication>
#include <QDebug>
#include <QQmlContext>

#include <QDirIterator>

#include <QTranslator>

#include "version.h"

// TODO: make a system controller possible

// TODO: provide telegramClient_ as a qml context

// TODO: init server, make the telegram auth logic
// + add the user to the server
CoreController::CoreController(
    QQmlApplicationEngine* engine,
    std::shared_ptr<Settings> settings,
    TelegramClient* client,
    QObject* parent
)
    : QObject(parent), settings_(settings), qmlEngine_(engine) {
    initModels(client);
    initControllers();

    initSignalHandlers();

    translator_.reset(new QTranslator());
    updateTranslator(settings_->getAppLanguage());

    new Utils(engine);
};

void CoreController::initModels(TelegramClient* client) {
    phoneNumberModel_.reset(new PhoneNumberModel(client));
    qmlRegisterSingletonInstance<PhoneNumberModel>(APPLICATION_ID, 1, 0, "PhoneNumberModel", phoneNumberModel_.data());

    authCodeModel_.reset(new AuthorizationCodeModel(client));
    qmlRegisterSingletonInstance<AuthorizationCodeModel>(
        APPLICATION_ID, 1, 0, "AuthorizationCodeModel", authCodeModel_.data()
    );

    language_model_.reset(new LanguageModel(settings_));
    qmlRegisterSingletonInstance<LanguageModel>(APPLICATION_ID, 1, 0, "LanguageModel", language_model_.data());
};

void CoreController::initControllers() {
    // TODO
    auto tmp_ptr = std::shared_ptr<QVariant>();
    systemsController_.reset(new SystemsController(tmp_ptr, this));
    qmlEngine_->rootContext()->setContextProperty("SystemsController", systemsController_.data());

    pageController_.reset(new PageController());
    qmlEngine_->rootContext()->setContextProperty("PageController", pageController_.data());
}

void CoreController::initSignalHandlers() { initTranslationsBindings(); }

void CoreController::setQmlRoot() const {
    if (qmlEngine_->rootObjects().isEmpty()) {
        qDebug() << "No rootObjects loaded";
        QCoreApplication::exit(0);
        return;
    }

    systemsController_->setQmlRoot(qmlEngine_->rootObjects().at(0));
}

QSharedPointer<PageController> CoreController::pageController() const { return pageController_; }

void CoreController::initTranslationsBindings() {
    connect(language_model_.get(), &LanguageModel::updateTranslations, this, &CoreController::updateTranslator);
    connect(this, &CoreController::translationsUpdated, language_model_.get(), &LanguageModel::translationsUpdated);
};

void CoreController::updateTranslator(const QLocale& locale) const {
    if (!translator_->isEmpty()) {
        QCoreApplication::removeTranslator(translator_.data());
    }

    QList<QString> availableTranslations;
    const QList<QString> nameFilters = {"*.qm"};

    QDirIterator it(QString(":/locales"), nameFilters, QDir::Filter::Files, QDirIterator::NoIteratorFlags);

    while (it.hasNext()) {
        availableTranslations << it.next();
    }

    if (availableTranslations.isEmpty()) {
        qDebug() << "No translations found";
        return;
    }

    for (const QString& translation : availableTranslations) {
        qDebug() << translation;
    }

    // ru
    const QString lang = locale.name().split("_").first();
    const QString strFileName = QString(":/locales/%1.qm").arg(lang);

    if (translator_->load(locale, strFileName)) {
        if (QCoreApplication::installTranslator(translator_.data())) {
            settings_->setAppLanguage(locale);
        } else {
            qWarning() << "Failed to load translation file:" << strFileName;
            settings_->setAppLanguage(QLocale::English);
        }
    }

    qmlEngine_->retranslate();

    emit translationsUpdated();
};