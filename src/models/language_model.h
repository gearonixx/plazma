#pragma once

#include <qqml.h>

#include <QObject>
#include <QString>

#include <QAbstractListModel>

namespace LanguageSettings {
Q_NAMESPACE
enum class AvailablePageEnum { English = 0, Russian, China_cn };

Q_ENUM_NS(AvailablePageEnum);

static void declareQmlAvailableLanguageEnum() {
    qmlRegisterUncreatableMetaObject(staticMetaObject, "AvailablePageEnum", 1, 0, "AvailablePageEnum", QString());
}
}  // namespace LanguageSettings

struct ModelLanguageData {
    QString name;
    LanguageSettings::AvailablePageEnum page;
};

class LanguageModel : public QAbstractListModel {
    Q_OBJECT
public:
    explicit LanguageModel(QObject* parent = nullptr);

    QString getLanguageName(const LanguageSettings::AvailablePageEnum language);

    int rowCount(const QModelIndex& parent) const override;
    QVariant data(const QModelIndex& index, int role) const override;

public slots:
    void changeLanguage(const LanguageSettings::AvailablePageEnum language);

signals:
    void updateTranslations(const QLocale);

private:
    QVector<ModelLanguageData> availableLanguages_;
};
