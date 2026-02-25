#pragma once

#include <QObject>
#include <QVariant>

class SystemsController: public QObject {
    Q_OBJECT

public:
    template <typename T>
    // A reference (&) can't be null, a pointer (*) can
    explicit SystemsController(const std::shared_ptr<T> &setting, const QObject* parent = nullptr);

private:
    QObject *m_qmlRoot;
};