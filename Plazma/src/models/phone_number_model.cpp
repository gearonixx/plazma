#include "phone_number_model.h"
#include <QDebug>

void PhoneNumberModel::submitPhoneNumber(const QString& phone_number) {
    if (!waitingForPhone_) {
        qWarning() << "[PHONE] submit while not waiting for phone — "
                      "likely a retry after a TDLib error";
    }

    emit phoneNumberSent(phone_number);

    if (waitingForPhone_) {
        waitingForPhone_ = false;
        emit waitingForPhoneChanged();
    }
};
