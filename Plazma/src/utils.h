#pragma once

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QObject>
#include <QQmlApplicationEngine>
#include <QString>

#include <exception>

class Utils : public QObject {
    Q_OBJECT

public:
    static Utils* instance();

    explicit Utils(QQmlApplicationEngine* engine);

    Q_INVOKABLE static QString getRandomString(int len);

    Q_INVOKABLE static QString safeBase64Decode(QString string);

    Q_INVOKABLE static QString verifyJsonString(const QString& source);
    Q_INVOKABLE static QJsonObject jsonFromString(const QString& string);

    static QString jsonToString(const QJsonObject& json, QJsonDocument::JsonFormat format = QJsonDocument::Indented);
    static QString jsonToString(const QJsonArray& array, QJsonDocument::JsonFormat format = QJsonDocument::Indented);

    Q_INVOKABLE static bool initializePath(const QString& path);
    Q_INVOKABLE static bool createEmptyFile(const QString& path);

    static void logException(const std::exception& e);
    static void logException(const std::exception_ptr& eptr = std::current_exception());

private:
    static inline Utils* s_instance = nullptr;
    QQmlApplicationEngine* m_engine;
};
