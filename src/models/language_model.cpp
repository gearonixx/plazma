#include "language_model.h"

using Lang = LanguageSettings::AvailablePageEnum;

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
        case Lang::English: emit updateTranslations(QLocale::English); break;
        case Lang::Russian: emit updateTranslations(QLocale::Russian); break;
        case Lang::China_cn: emit updateTranslations(QLocale::Chinese); break;
        default: emit updateTranslations(QLocale::English); break;
    }
}
