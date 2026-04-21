#include "json_guards.h"

#include <QDebug>
#include <QLatin1String>

namespace validators {

// ─── Log tagging ──────────────────────────────────────────────────────────

void logMalformed(const QString& context, const QString& key, const char* expectedType) {
    qWarning().noquote() << "[validators]" << context << "=> malformed response, expected"
                         << expectedType << "at" << key;
}

void logSkippedArrayElements(const QString& context, const char* expectedType, qsizetype skipped) {
    qWarning().noquote() << "[validators]" << context << "=> skipped" << skipped
                         << "array element(s) that failed to unwrap as" << expectedType;
}

// ─── Error formatters ─────────────────────────────────────────────────────
//
// Centralized so the wording is consistent across every validator in the
// project. Matches the `[response] <field>: <reason>` shape already used
// by ensureLoginResponse.

QString formatMissingFieldError(const QString& key, const char* expectedType) {
    return QStringLiteral("[response] %1: expected %2, missing or wrong type")
        .arg(key, QLatin1String(expectedType));
}

QString formatEmptyStringError(const QString& key) {
    return QStringLiteral("[response] %1: field is missing or empty").arg(key);
}

QString formatNonPositiveError(const QString& key) {
    return QStringLiteral("[response] %1: invalid or missing (must be > 0)").arg(key);
}

// ─── Presence / required-field helpers ────────────────────────────────────

bool hasAll(const QJsonObject& json, std::initializer_list<QString> keys) {
    for (const auto& key : keys) {
        if (!json.contains(key)) return false;
    }
    return true;
}

std::optional<QString>
extractNonEmptyString(const QJsonObject& json, const QString& key, QString& error) {
    auto value = extract<QString>(json, key);
    if (!value || value->isEmpty()) {
        error = formatEmptyStringError(key);
        return std::nullopt;
    }
    return value;
}

std::optional<qint64>
extractPositiveInteger(const QJsonObject& json, const QString& key, QString& error) {
    auto value = extract<qint64>(json, key);
    if (!value || *value <= 0) {
        error = formatNonPositiveError(key);
        return std::nullopt;
    }
    return value;
}

// ─── requireFields ────────────────────────────────────────────────────────

namespace {

bool kindMatches(const QJsonValue& v, JsonKind kind) {
    switch (kind) {
        case JsonKind::Array:   return v.isArray();
        case JsonKind::Object:  return v.isObject();
        case JsonKind::String:  return v.isString();
        case JsonKind::Number:
        case JsonKind::Integer: return v.isDouble();
        case JsonKind::Bool:    return v.isBool();
    }
    return false;
}

const char* kindName(JsonKind kind) {
    switch (kind) {
        case JsonKind::Array:   return "array";
        case JsonKind::Object:  return "object";
        case JsonKind::String:  return "string";
        case JsonKind::Number:  return "number";
        case JsonKind::Integer: return "integer";
        case JsonKind::Bool:    return "bool";
    }
    return "unknown";
}

}  // namespace

bool requireFields(
    const QJsonObject& json, std::initializer_list<FieldRequirement> fields, QString& error
) {
    for (const auto& f : fields) {
        const auto it = json.constFind(f.key);
        if (it == json.constEnd()) {
            error = QStringLiteral("[response] %1: field is missing").arg(f.key);
            return false;
        }
        if (!kindMatches(it.value(), f.kind)) {
            error = QStringLiteral("[response] %1: expected %2")
                        .arg(f.key, QLatin1String(kindName(f.kind)));
            return false;
        }
    }
    return true;
}

}  // namespace validators
