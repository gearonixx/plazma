#include "auth_code_model.h"
#include <QDebug>

void AuthorizationCodeModel::submitAuthCode(const QString& code) {
    if (!waitingForAuthCode_) {
        qWarning() << "[AUTH] submitAuthCode ignored — not waiting for code "
                      "(duplicate submit or state already advanced)";
        return;
    }

    waitingForAuthCode_ = false;
    emit waitingForCodeChanged();
    emit authCodeSent(code);
};
