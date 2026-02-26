#pragma once

#include <qqml.h>

#include <QObject>
#include <QString>

namespace LanguageSettings {
Q_NAMESPACE
enum class AvailablePageEnum { English, Russian, China_cn };

Q_ENUM_NS(AvailablePageEnum);

static void declareQmlAvailableLanguageEnum() {
    qmlRegisterUncreatableMetaObject(
        LanguageSettings::staticMetaObject, "AvailablePageEnum", 1, 0, "AvailablePageEnum", QString()
    );
}
}  // namespace LanguageSettings

class LanguageModel : public QObject {
    Q_OBJECT
public:
    explicit LanguageModel(QObject* parent = nullptr);

    QString getLanguageName(const LanguageSettings::AvailablePageEnum language);
};