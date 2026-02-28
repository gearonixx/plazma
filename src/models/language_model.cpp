#include "language_model.h"

#include <QDebug>
#include <QMetaEnum>

using Lang = LanguageSettings::AvailablePageEnum;

LanguageModel::LanguageModel(QObject* parent) : QAbstractListModel(parent) {
    QMetaEnum metaEnum = QMetaEnum::fromType<LanguageSettings::AvailablePageEnum>();

    for (int key = 0; key < metaEnum.keyCount(); key++) {
        auto language = static_cast<Lang>(key);
        availableLanguages_.push_back(ModelLanguageData{getLanguageName(language), language});
    }
}

QString LanguageModel::getLanguageName(const Lang language) {
    QString languageName;

    switch (language) {
        case Lang::English:
            languageName = "English";
            break;
        case Lang::Russian:
            languageName = "Русский";
            break;
        case Lang::China_cn:
            languageName = "\347\256\200\344\275\223\344\270\255\346\226\207";
            break;
        default:
            break;
    };

    return languageName;
}

void LanguageModel::changeLanguage(const Lang language) {
    switch (language) {
        case Lang::English:
            emit updateTranslations(QLocale::English);
            break;
        case Lang::Russian:
            emit updateTranslations(QLocale::Russian);
            break;
        case Lang::China_cn:
            emit updateTranslations(QLocale::Chinese);
            break;
        default:
            emit updateTranslations(QLocale::English);
            break;
    }
}

int LanguageModel::rowCount(const QModelIndex& parent) const { Q_UNUSED(parent); }

QVariant LanguageModel::data(const QModelIndex& index, int role) const {}
