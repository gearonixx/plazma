#include "video_list.hpp"

#include <algorithm>
#include <string>
#include <string_view>

#include <userver/formats/json/serialize.hpp>
#include <userver/formats/json/value_builder.hpp>
#include <userver/http/common_headers.hpp>
#include <userver/http/content_type.hpp>
#include <userver/logging/log.hpp>
#include <userver/s3api/clients/s3api.hpp>

namespace real_medium::handlers::videos::list {

namespace {

constexpr std::string_view kPrefix = "videos/";
constexpr std::string_view kPublicBase = "http://localhost:9000/plazma-videos/";

std::string_view MimeFromExt(std::string_view filename) {
    const auto dot = filename.find_last_of('.');
    if (dot == std::string_view::npos) return "application/octet-stream";
    auto ext = filename.substr(dot + 1);
    std::string lower(ext);
    std::transform(lower.begin(), lower.end(), lower.begin(),
                   [](unsigned char c) { return std::tolower(c); });
    if (lower == "mp4" || lower == "m4v") return "video/mp4";
    if (lower == "webm") return "video/webm";
    if (lower == "mkv") return "video/x-matroska";
    if (lower == "mov") return "video/quicktime";
    if (lower == "avi") return "video/x-msvideo";
    if (lower == "ogv") return "video/ogg";
    return "application/octet-stream";
}

struct ParsedKey {
    std::string id;
    std::string title;
    bool ok{false};
};

ParsedKey ParseKey(std::string_view key) {
    if (key.substr(0, kPrefix.size()) != kPrefix) return {};
    auto rest = key.substr(kPrefix.size());
    auto slash = rest.find('/');
    if (slash == std::string_view::npos || slash == 0 || slash + 1 >= rest.size()) return {};
    return {std::string{rest.substr(0, slash)}, std::string{rest.substr(slash + 1)}, true};
}

}  // namespace

Handler::Handler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& context
) : HttpHandlerBase(config, context),
    s3_(context.FindComponent<s3::S3Component>()) {
}

std::string Handler::HandleRequest(
    userver::server::http::HttpRequest& request,
    userver::server::request::RequestContext& /*context*/
) const {
    request.GetHttpResponse().SetContentType(userver::http::content_type::kApplicationJson);

    userver::formats::json::ValueBuilder response;
    userver::formats::json::ValueBuilder videos{userver::formats::common::Type::kArray};

    try {
        auto client = s3_.GetClient();
        const auto objects = client->ListBucketContentsParsed(kPrefix);

        for (const auto& obj : objects) {
            const auto parsed = ParseKey(obj.key);
            if (!parsed.ok) continue;

            userver::formats::json::ValueBuilder item;
            item["id"] = parsed.id;
            item["title"] = parsed.title;
            item["url"] = std::string{kPublicBase} + obj.key;
            item["size"] = static_cast<std::int64_t>(obj.size);
            item["mime"] = std::string{MimeFromExt(parsed.title)};
            item["author"] = std::string{};
            item["created_at"] = obj.last_modified;
            item["thumbnail"] = std::string{};
            videos.PushBack(item.ExtractValue());
        }
    } catch (const std::exception& ex) {
        LOG_ERROR() << "Failed to list videos from S3: " << ex.what();
        request.SetResponseStatus(userver::server::http::HttpStatus::kInternalServerError);
        userver::formats::json::ValueBuilder err;
        err["error"] = std::string{ex.what()};
        return userver::formats::json::ToString(err.ExtractValue());
    }

    response["videos"] = videos.ExtractValue();
    return userver::formats::json::ToString(response.ExtractValue());
}

}
