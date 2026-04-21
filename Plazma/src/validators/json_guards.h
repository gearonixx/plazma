#pragma once

#include "../basic_types.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QJsonValue>
#include <QString>

#include <concepts>
#include <initializer_list>
#include <optional>
#include <utility>
#include <vector>

namespace validators {

// ─── Traits ───────────────────────────────────────────────────────────────
//
// For each JSON-representable C++ type we specialize JsonTraits<T> with:
//   - matches(const QJsonValue&)  — is the value of type T?
//   - extract(const QJsonValue&)  — unwrap it (undefined if !matches).
//   - typeName()                  — short label used in error logs.
//
// Unspecialized types leave JsonTraits<T> incomplete, which fails the
// JsonExtractable<T> concept below — so every templated helper produces
// a readable diagnostic instead of a mile of error output.

template <typename T>
struct JsonTraits;

template <>
struct JsonTraits<QJsonArray> {
    static bool matches(const QJsonValue& v) { return v.isArray(); }
    static QJsonArray extract(const QJsonValue& v) { return v.toArray(); }
    static constexpr const char* typeName() { return "array"; }
};

template <>
struct JsonTraits<QJsonObject> {
    static bool matches(const QJsonValue& v) { return v.isObject(); }
    static QJsonObject extract(const QJsonValue& v) { return v.toObject(); }
    static constexpr const char* typeName() { return "object"; }
};

template <>
struct JsonTraits<QString> {
    static bool matches(const QJsonValue& v) { return v.isString(); }
    static QString extract(const QJsonValue& v) { return v.toString(); }
    static constexpr const char* typeName() { return "string"; }
};

template <>
struct JsonTraits<double> {
    static bool matches(const QJsonValue& v) { return v.isDouble(); }
    static double extract(const QJsonValue& v) { return v.toDouble(); }
    static constexpr const char* typeName() { return "number"; }
};

template <>
struct JsonTraits<qint64> {
    // JSON has no integer type — matches() still keys off isDouble(),
    // extract() rounds via toInteger() for callers who want integer semantics.
    static bool matches(const QJsonValue& v) { return v.isDouble(); }
    static qint64 extract(const QJsonValue& v) { return v.toInteger(); }
    static constexpr const char* typeName() { return "integer"; }
};

template <>
struct JsonTraits<bool> {
    static bool matches(const QJsonValue& v) { return v.isBool(); }
    static bool extract(const QJsonValue& v) { return v.toBool(); }
    static constexpr const char* typeName() { return "bool"; }
};

template <typename T>
concept JsonExtractable = requires(const QJsonValue& v) {
    { JsonTraits<T>::matches(v) } -> std::same_as<bool>;
    { JsonTraits<T>::extract(v) } -> std::convertible_to<T>;
    { JsonTraits<T>::typeName() } -> std::convertible_to<const char*>;
};

// ─── Predicates ───────────────────────────────────────────────────────────

template <JsonExtractable T>
[[nodiscard]] bool has(const QJsonObject& json, const QString& key) {
    const auto it = json.constFind(key);
    return it != json.constEnd() && JsonTraits<T>::matches(it.value());
}

[[nodiscard]] inline bool hasJsonArray(const QJsonObject& json, const QString& key) {
    return has<QJsonArray>(json, key);
}
[[nodiscard]] inline bool hasJsonObject(const QJsonObject& json, const QString& key) {
    return has<QJsonObject>(json, key);
}
[[nodiscard]] inline bool hasJsonString(const QJsonObject& json, const QString& key) {
    return has<QString>(json, key);
}
[[nodiscard]] inline bool hasJsonNumber(const QJsonObject& json, const QString& key) {
    return has<double>(json, key);
}
[[nodiscard]] inline bool hasJsonInteger(const QJsonObject& json, const QString& key) {
    return has<qint64>(json, key);
}
[[nodiscard]] inline bool hasJsonBool(const QJsonObject& json, const QString& key) {
    return has<bool>(json, key);
}

// Presence-only check across multiple keys. Doesn't care about types —
// useful when you just want to know the response isn't a truncated fragment
// before running per-field extraction.
[[nodiscard]] bool hasAll(const QJsonObject& json, std::initializer_list<QString> keys);

// ─── Extractors (quiet) ───────────────────────────────────────────────────
//
// No logging, no side effects. Return nullopt or the fallback on
// missing/wrong-type. Higher-level callbacks compose on these.

template <JsonExtractable T>
[[nodiscard]] std::optional<T> extract(const QJsonObject& json, const QString& key) {
    const auto it = json.constFind(key);
    if (it == json.constEnd() || !JsonTraits<T>::matches(it.value())) return std::nullopt;
    return JsonTraits<T>::extract(it.value());
}

template <JsonExtractable T>
[[nodiscard]] T extractOr(const QJsonObject& json, const QString& key, T fallback) {
    auto opt = extract<T>(json, key);
    return opt ? std::move(*opt) : std::move(fallback);
}

// ─── Extractors with diagnostics ──────────────────────────────────────────
//
// Write a standardized reason to `error` on failure. Return nullopt so
// callers can early-out with `if (!value) return std::nullopt;`. Meant
// for hand-rolled validators that build up a structured result — the
// pattern the existing ensureLoginResponse uses by hand, templatized.

QString formatMissingFieldError(const QString& key, const char* expectedType);
QString formatEmptyStringError(const QString& key);
QString formatNonPositiveError(const QString& key);

template <JsonExtractable T>
[[nodiscard]] std::optional<T>
extractRequired(const QJsonObject& json, const QString& key, QString& error) {
    auto value = extract<T>(json, key);
    if (!value) error = formatMissingFieldError(key, JsonTraits<T>::typeName());
    return value;
}

// Non-empty string — the pattern `.toString().isEmpty()` in user_login_validator.cpp.
[[nodiscard]] std::optional<QString>
extractNonEmptyString(const QJsonObject& json, const QString& key, QString& error);

// Strictly positive integer — the `.toInteger() <= 0` pattern for user_id.
[[nodiscard]] std::optional<qint64>
extractPositiveInteger(const QJsonObject& json, const QString& key, QString& error);

// ─── Array transforms ─────────────────────────────────────────────────────
//
// mapArray<T>(arr) returns a vector of every element that unwraps cleanly
// as T; malformed elements are silently dropped. Use forEachTyped when
// you also want a count of what was skipped.
//
// The Fn concept constraint on forEachTyped ensures the callable actually
// accepts const T& — otherwise you get a "constraint not satisfied" error
// at the callsite instead of a pages-long template instantiation trace.

template <JsonExtractable T>
[[nodiscard]] std::vector<T> mapArray(const QJsonArray& arr) {
    std::vector<T> out;
    out.reserve(static_cast<size_t>(arr.size()));
    for (const auto& v : arr) {
        if (JsonTraits<T>::matches(v)) out.push_back(JsonTraits<T>::extract(v));
    }
    return out;
}

void logSkippedArrayElements(const QString& context, const char* expectedType, qsizetype skipped);

template <JsonExtractable T, typename F>
    requires std::invocable<F, const T&>
void forEachTyped(const QJsonArray& arr, QString context, F&& fn) {
    qsizetype skipped = 0;
    for (const auto& v : arr) {
        if (!JsonTraits<T>::matches(v)) {
            ++skipped;
            continue;
        }
        fn(JsonTraits<T>::extract(v));
    }
    if (skipped > 0) logSkippedArrayElements(context, JsonTraits<T>::typeName(), skipped);
}

// ─── Callback builders ────────────────────────────────────────────────────
//
// resolveField<T> — .done() lambda that unwraps `key` as T, forwards to
// `resolve`, or logs a malformed-response warning and drops.
// resolveOptionalField<T> — same but field may be absent; resolve receives
// std::optional<T>. Only wrong-type triggers the warning.

void logMalformed(const QString& context, const QString& key, const char* expectedType);

template <JsonExtractable T>
[[nodiscard]] Fn<void(QJsonObject)>
resolveField(QString key, QString context, Fn<void(T)> resolve) {
    return [key = std::move(key), context = std::move(context), resolve = std::move(resolve)](
               const QJsonObject& json
           ) mutable {
        auto value = extract<T>(json, key);
        if (!value) {
            logMalformed(context, key, JsonTraits<T>::typeName());
            return;
        }
        if (resolve) resolve(std::move(*value));
    };
}

template <JsonExtractable T>
[[nodiscard]] Fn<void(QJsonObject)> resolveOptionalField(
    QString key, QString context, Fn<void(std::optional<T>)> resolve
) {
    return [key = std::move(key), context = std::move(context), resolve = std::move(resolve)](
               const QJsonObject& json
           ) mutable {
        const auto it = json.constFind(key);
        if (it == json.constEnd()) {
            if (resolve) resolve(std::nullopt);
            return;
        }
        if (!JsonTraits<T>::matches(it.value())) {
            logMalformed(context, key, JsonTraits<T>::typeName());
            return;
        }
        if (resolve) resolve(JsonTraits<T>::extract(it.value()));
    };
}

[[nodiscard]] inline Fn<void(QJsonObject)>
resolveArrayField(QString key, QString context, Fn<void(QJsonArray)> resolve) {
    return resolveField<QJsonArray>(std::move(key), std::move(context), std::move(resolve));
}

[[nodiscard]] inline Fn<void(QJsonObject)>
resolveObjectField(QString key, QString context, Fn<void(QJsonObject)> resolve) {
    return resolveField<QJsonObject>(std::move(key), std::move(context), std::move(resolve));
}

// ─── Struct deserialization (customization point) ────────────────────────
//
// A type T opts in to being "deserializable from JSON" by providing:
//
//     static std::optional<T> fromJson(const QJsonObject& json, QString& error);
//
// Anything matching that shape satisfies JsonDeserializable<T>. The
// generic deserialize<T> and resolveDeserializedField<T> then work for
// it without the struct needing to inherit from anything or register
// with a central registry — the concept is the interface.
//
// Example:
//     struct Video {
//         QString id;
//         QString url;
//         static std::optional<Video> fromJson(const QJsonObject& j, QString& err) {
//             auto id  = extractNonEmptyString(j, "id", err);  if (!id)  return {};
//             auto url = extractNonEmptyString(j, "url", err); if (!url) return {};
//             return Video{*id, *url};
//         }
//     };
//
// Then: resolveDeserializedField<Video>("video", "fetchVideo", onVideo)
// produces a .done() callback that parses into Video for you.

template <typename T>
concept JsonDeserializable = requires(const QJsonObject& json, QString& error) {
    { T::fromJson(json, error) } -> std::same_as<std::optional<T>>;
};

template <JsonDeserializable T>
[[nodiscard]] std::optional<T> deserialize(const QJsonObject& json, QString& error) {
    return T::fromJson(json, error);
}

// Deserialize every element of `arr` that parses cleanly; skipped elements
// are logged under `context`. Returns the surviving Ts in order.
template <JsonDeserializable T>
[[nodiscard]] std::vector<T> deserializeArray(const QJsonArray& arr, const QString& context) {
    std::vector<T> out;
    out.reserve(static_cast<size_t>(arr.size()));
    qsizetype skipped = 0;
    for (const auto& v : arr) {
        if (!v.isObject()) {
            ++skipped;
            continue;
        }
        QString err;
        auto parsed = T::fromJson(v.toObject(), err);
        if (!parsed) {
            ++skipped;
            continue;
        }
        out.push_back(std::move(*parsed));
    }
    if (skipped > 0) logSkippedArrayElements(context, "object", skipped);
    return out;
}

// .done() callback that expects `key` to be an object, parses it into T
// via T::fromJson, and forwards. On missing/malformed/parse-failure it
// logs with `context` and drops.
template <JsonDeserializable T>
[[nodiscard]] Fn<void(QJsonObject)> resolveDeserializedField(
    QString key, QString context, Fn<void(T)> resolve
) {
    return [key = std::move(key), context = std::move(context), resolve = std::move(resolve)](
               const QJsonObject& json
           ) mutable {
        auto obj = extract<QJsonObject>(json, key);
        if (!obj) {
            logMalformed(context, key, "object");
            return;
        }
        QString err;
        auto parsed = T::fromJson(*obj, err);
        if (!parsed) {
            logMalformed(context, key, err.isEmpty() ? "valid T" : qUtf8Printable(err));
            return;
        }
        if (resolve) resolve(std::move(*parsed));
    };
}

// Same but for `key` resolving to an array — produces a vector<T>.
template <JsonDeserializable T>
[[nodiscard]] Fn<void(QJsonObject)> resolveDeserializedArrayField(
    QString key, QString context, Fn<void(std::vector<T>)> resolve
) {
    return [key = std::move(key), context = std::move(context), resolve = std::move(resolve)](
               const QJsonObject& json
           ) mutable {
        auto arr = extract<QJsonArray>(json, key);
        if (!arr) {
            logMalformed(context, key, "array");
            return;
        }
        auto items = deserializeArray<T>(*arr, context);
        if (resolve) resolve(std::move(items));
    };
}

// ─── Multi-field validation ───────────────────────────────────────────────
//
// requireFields(json, {{"user", JsonKind::Object}, {"token", JsonKind::String}}, err)
// returns true iff every field is present and of the right kind. On the
// first failure writes a message into `err` and returns false.

enum class JsonKind { Array, Object, String, Number, Integer, Bool };

struct FieldRequirement {
    QString key;
    JsonKind kind;
};

[[nodiscard]] bool requireFields(
    const QJsonObject& json, std::initializer_list<FieldRequirement> fields, QString& error
);

}  // namespace validators
