#pragma once

#include <qlocale.h>

#include <QObject>
#include <QSettings>
#include <QString>

#include <QDebug>

class Settings : public QObject {
    Q_OBJECT
public:
    explicit Settings(QObject* parent = nullptr);

    QLocale getAppLanguage() const {
        const QString localeStr = settings_.value("config/language", QLocale::system().name()).toString();

        qDebug() << "default locale name " << localeStr;

        return QLocale(localeStr);
    }

    void setAppLanguage(QLocale locale) { setValue("config/language", locale.name()); }

    // Downloads folder override. Empty string is the "use platform default"
    // sentinel — we resolve via QStandardPaths::MoviesLocation on read so the
    // resolved path tracks the user's OS even if XDG dirs change underneath
    // us. Persist only the user-chosen override; never freeze the default.
    QString getDownloadPath() const {
        return settings_.value(QStringLiteral("downloads/path")).toString();
    }

    void setDownloadPath(const QString& path) {
        if (path == getDownloadPath()) return;
        setValue(QStringLiteral("downloads/path"), path);
        emit downloadPathChanged();
    }

signals:
    void downloadPathChanged();

private:
    void setValue(const QString& name, const QVariant& value) { settings_.setValue(name, value); }

    mutable QSettings settings_;
};
