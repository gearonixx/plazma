#pragma once

#include <QQmlApplicationEngine>
#include <QObject>

class Utils : public QObject {
    Q_OBJECT

private:
public:
    static Utils* instance();

    explicit Utils(QQmlApplicationEngine* engine);

private:
    static inline Utils* s_instance = nullptr;
    QQmlApplicationEngine* m_engine;
};