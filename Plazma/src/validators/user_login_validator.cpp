#include "../session.h"

#include "json_guards.h"

#include <QJsonObject>
#include <optional>

namespace validators {

std::optional<UserLogin> ensureLoginResponse(const QJsonObject& json, QString& error) {
    auto user = extract<QJsonObject>(json, QStringLiteral("user"));
    if (!user) {
        error = formatMissingFieldError(QStringLiteral("user"), "object");
        return std::nullopt;
    }

    auto userId = extractPositiveInteger(*user, QStringLiteral("user_id"), error);
    if (!userId) return std::nullopt;

    auto phone = extractNonEmptyString(*user, QStringLiteral("phone_number"), error);
    if (!phone) return std::nullopt;

    auto firstName = extractNonEmptyString(*user, QStringLiteral("first_name"), error);
    if (!firstName) return std::nullopt;

    return UserLogin{
        .userId = *userId,
        .username = extractOr<QString>(*user, QStringLiteral("username"), {}),
        .firstName = *firstName,
        .lastName = extractOr<QString>(*user, QStringLiteral("last_name"), {}),
        .phoneNumber = *phone,
        .isPremium = extractOr<bool>(*user, QStringLiteral("is_premium"), false),
    };
}

}  // namespace validators
