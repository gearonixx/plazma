#pragma once

#include <qlocale.h>

#include <QObject>
#include <QSettings>

class Settings : public QObject {
public:
    QLocale getAppLanguage() const {
        const QString localeStr = settings_.value("config/language", QLocale::system().name()).toString();

        return QLocale(localeStr);
    }

private:
    mutable QSettings settings_;
};