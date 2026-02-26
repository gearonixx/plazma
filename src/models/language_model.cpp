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