#include "video_list.hpp"

#include <algorithm>
#include <cstdint>
#include <optional>
#include <stdexcept>
#include <string>

#include <userver/formats/common/type.hpp>
#include <userver/formats/json/serialize.hpp>
#include <userver/formats/json/value_builder.hpp>
#include <userver/logging/log.hpp>
#include <userver/storages/scylla/operations.hpp>
#include <userver/storages/scylla/row.hpp>

#include "search/es_component.hpp"
#include "utils/auth.hpp"
#include "utils/video.hpp"

namespace real_medium::handlers::videos::list {

// ── cursor helpers ────────────────────────────────────────────────────────────

namespace {

// Minimal base64url (no padding) encode/decode — used only for pagination cursors.
std::string Base64UrlEncode(const std::string& in) {
    static const char kAlpha[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
    std::string out;
    out.reserve(((in.size() + 2) / 3) * 4);
    for (size_t i = 0; i < in.size(); i += 3) {
        const uint32_t b = (static_cast<uint8_t>(in[i]) << 16) |
                           (i + 1 < in.size() ? static_cast<uint8_t>(in[i + 1]) << 8 : 0u) |
                           (i + 2 < in.size() ? static_cast<uint8_t>(in[i + 2]) : 0u);
        out.push_back(kAlpha[(b >> 18) & 0x3F]);
        out.push_back(kAlpha[(b >> 12) & 0x3F]);
        if (i + 1 < in.size()) out.push_back(kAlpha[(b >> 6) & 0x3F]);
        if (i + 2 < in.size()) out.push_back(kAlpha[b & 0x3F]);
    }
    return out;
}

std::string Base64UrlDecode(const std::string& in) {
    // Build reverse table on first call.
    static const auto kRev = [] {
        std::array<int8_t, 256> t{};
        t.fill(-1);
        const char alpha[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
        for (int i = 0; alpha[i]; ++i) t[static_cast<uint8_t>(alpha[i])] = static_cast<int8_t>(i);
        return t;
    }();

    std::string out;
    out.reserve((in.size() * 3) / 4);
    uint32_t buf = 0;
    int bits = 0;
    for (const char c : in) {
        const int8_t v = kRev[static_cast<uint8_t>(c)];
        if (v < 0) throw std::invalid_argument("bad base64url char");
        buf = (buf << 6) | static_cast<uint32_t>(v);
        bits += 6;
        if (bits >= 8) {
            bits -= 8;
            out.push_back(static_cast<char>((buf >> bits) & 0xFF));
        }
    }
    return out;
}

// Opaque pagination cursor, base64url({ "v":1, "k":<sort_values JSON>, "q":"...", "s":"...", "a":<int|null> })
struct Cursor {
    std::string sort_values_json;
    std::string q_normalized;
    std::string sort;
    std::optional<int64_t> author_id;
};

std::string EncodeCursor(const Cursor& c) {
    userver::formats::json::ValueBuilder vb;
    vb["v"] = 1;
    vb["k"] = userver::formats::json::FromString(c.sort_values_json);
    vb["q"] = c.q_normalized;
    vb["s"] = c.sort;
    if (c.author_id.has_value()) {
        vb["a"] = *c.author_id;
    } else {
        vb["a"] = userver::formats::json::ValueBuilder{userver::formats::common::Type::kNull}.ExtractValue();
    }
    return Base64UrlEncode(userver::formats::json::ToString(vb.ExtractValue()));
}

std::optional<Cursor> DecodeCursor(const std::string& encoded) {
    try {
        const auto json = userver::formats::json::FromString(Base64UrlDecode(encoded));
        if (json["v"].As<int>(0) != 1) return std::nullopt;
        Cursor c;
        c.sort_values_json = userver::formats::json::ToString(json["k"]);
        c.q_normalized = json["q"].As<std::string>("");
        c.sort = json["s"].As<std::string>("");
        const auto a = json["a"];
        if (!a.IsMissing() && !a.IsNull()) c.author_id = a.As<int64_t>(0);
        return c;
    } catch (...) {
        return std::nullopt;
    }
}

std::string SortStr(search::SortMode m) {
    switch (m) {
        case search::SortMode::kRelevance: return "relevance";
        case search::SortMode::kPopular: return "popular";
        case search::SortMode::kRecent: return "recent";
    }
    return "relevance";
}

search::SortMode ParseSort(const std::string& s, bool has_query) {
    if (s == "relevance") return search::SortMode::kRelevance;
    if (s == "popular") return search::SortMode::kPopular;
    if (s == "recent") return search::SortMode::kRecent;
    return has_query ? search::SortMode::kRelevance : search::SortMode::kRecent;
}

userver::formats::json::Value NullJson() {
    return userver::formats::json::ValueBuilder{userver::formats::common::Type::kNull}.ExtractValue();
}

// Build a video JSON object from an ES hit, including the BM25 score field.
userver::formats::json::Value BuildEsVideoJson(const search::EsHit& h) {
    userver::formats::json::ValueBuilder vb;
    vb["id"] = h.video_id;
    vb["user_id"] = h.user_id;
    vb["title"] = h.title;
    vb["url"] = utils::video::StorageUrlToHttp(h.storage_url);
    vb["mime"] = h.mime;
    vb["size"] = h.size_bytes;
    vb["visibility"] = h.visibility;
    vb["created_at"] = utils::video::FormatTimestampMs(h.created_at_ms);
    vb["author"] = h.author;
    vb["score"] = h.score;
    if (h.duration_ms.has_value()) {
        vb["duration_ms"] = *h.duration_ms;
    } else {
        vb["duration_ms"] = NullJson();
    }
    vb["thumbnail"] = h.thumbnail_url.empty() ? NullJson()
                                               : userver::formats::json::ValueBuilder{
                                                     utils::video::StorageUrlToHttp(h.thumbnail_url)
                                                 }.ExtractValue();
    vb["storyboard"] = h.storyboard_url.empty() ? NullJson()
                                                 : userver::formats::json::ValueBuilder{
                                                       utils::video::StorageUrlToHttp(h.storyboard_url)
                                                   }.ExtractValue();
    return vb.ExtractValue();
}

}  // namespace

// ── Handler ───────────────────────────────────────────────────────────────────

Handler::Handler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& context
)
    : HttpHandlerBase(config, context),
      session_(context.FindComponent<userver::components::Scylla>("scylla").GetSession()),
      es_(context.FindComponent<search::EsComponent>()) {}

std::string Handler::HandleRequest(
    userver::server::http::HttpRequest& request,
    userver::server::request::RequestContext& /*context*/
) const {
    request.GetHttpResponse().SetContentType("application/json");

    const auto auth = utils::ExtractAuth(request);
    if (auth.result == utils::AuthResult::kInvalid) {
        request.SetResponseStatus(userver::server::http::HttpStatus::kUnauthorized);
        return R"({"error": "invalid or expired token"})";
    }

    // ── ?limit ────────────────────────────────────────────────────────────
    int limit = 20;
    const auto limit_str = request.GetArg("limit");
    if (!limit_str.empty()) {
        try {
            limit = std::clamp(std::stoi(limit_str), 1, 100);
        } catch (const std::exception&) {
            request.SetResponseStatus(userver::server::http::HttpStatus::kBadRequest);
            return R"({"error": "limit must be an integer in [1, 100]"})";
        }
    }

    // ── ?q ────────────────────────────────────────────────────────────────
    std::string q = request.GetArg("q");
    if (q.find('\0') != std::string::npos || q.size() > 1024) {
        request.SetResponseStatus(userver::server::http::HttpStatus::kBadRequest);
        return R"({"error": "invalid query"})";
    }
    // Trim ASCII control/whitespace
    {
        size_t s = 0, e = q.size();
        while (s < e && static_cast<unsigned char>(q[s]) <= 0x20) ++s;
        while (e > s && static_cast<unsigned char>(q[e - 1]) <= 0x20) --e;
        q = q.substr(s, e - s);
    }
    const bool has_query = !q.empty();

    // ── ?sort ─────────────────────────────────────────────────────────────
    const auto sort_str = request.GetArg("sort");
    if (!sort_str.empty() && sort_str != "relevance" && sort_str != "recent" && sort_str != "popular") {
        request.SetResponseStatus(userver::server::http::HttpStatus::kBadRequest);
        return R"({"error": "sort must be one of: relevance, recent, popular"})";
    }
    const search::SortMode sort_mode = ParseSort(sort_str, has_query);

    // ── ?author ───────────────────────────────────────────────────────────
    const auto author_str = request.GetArg("author");
    const bool has_author = !author_str.empty();
    int64_t author_id = 0;
    if (has_author) {
        try {
            author_id = std::stoll(author_str);
        } catch (const std::exception&) {
            request.SetResponseStatus(userver::server::http::HttpStatus::kBadRequest);
            return R"({"error": "author must be a valid user_id integer"})";
        }
        if (author_id <= 0) {
            request.SetResponseStatus(userver::server::http::HttpStatus::kBadRequest);
            return R"({"error": "author must be a positive user_id"})";
        }
    }

    // ── ?cursor ───────────────────────────────────────────────────────────
    const auto cursor_str = request.GetArg("cursor");
    std::optional<Cursor> cursor;
    if (!cursor_str.empty()) {
        cursor = DecodeCursor(cursor_str);
        if (!cursor.has_value()) {
            request.SetResponseStatus(userver::server::http::HttpStatus::kBadRequest);
            return R"({"error": "invalid cursor"})";
        }
        const std::optional<int64_t> expected_author = has_author ? std::optional<int64_t>{author_id} : std::nullopt;
        if (cursor->q_normalized != q || cursor->sort != SortStr(sort_mode) || cursor->author_id != expected_author) {
            request.SetResponseStatus(userver::server::http::HttpStatus::kBadRequest);
            return R"({"error": "cursor/query mismatch"})";
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SEARCH PATH  (q non-empty) — ElasticSearch with Scylla fallback
    // ═══════════════════════════════════════════════════════════════════════
    if (has_query) {
        const bool owner_ctx =
            auth.result == utils::AuthResult::kAuthenticated && has_author && auth.user_id == author_id;

        auto es_result = es_.Search(
            q,
            limit,
            sort_mode,
            has_author ? std::optional<int64_t>{author_id} : std::nullopt,
            owner_ctx,
            cursor.has_value() ? std::optional<std::string>{cursor->sort_values_json} : std::nullopt
        );

        if (es_result.has_value()) {
            // ── ES success ────────────────────────────────────────────────
            userver::formats::json::ValueBuilder videos_arr{userver::formats::common::Type::kArray};
            for (const auto& hit : es_result->hits) {
                videos_arr.PushBack(BuildEsVideoJson(hit));
            }

            // next_cursor: only when we returned a full page (more may exist)
            userver::formats::json::Value next_cursor_val = NullJson();
            if (!es_result->hits.empty() && static_cast<int>(es_result->hits.size()) == limit) {
                const auto& last = es_result->hits.back();
                if (!last.sort_values_json.empty()) {
                    Cursor nc;
                    nc.sort_values_json = last.sort_values_json;
                    nc.q_normalized = q;
                    nc.sort = SortStr(sort_mode);
                    nc.author_id = has_author ? std::optional<int64_t>{author_id} : std::nullopt;
                    next_cursor_val = userver::formats::json::ValueBuilder{EncodeCursor(nc)}.ExtractValue();
                }
            }

            userver::formats::json::ValueBuilder response;
            response["videos"] = videos_arr.ExtractValue();
            response["next_cursor"] = next_cursor_val;
            response["total_estimate"] = es_result->total_estimate;
            response["query_time_ms"] = es_result->query_time_ms;
            return userver::formats::json::ToString(response.ExtractValue());
        }

        // ── ES unavailable — Scylla substring fallback ────────────────────
        request.GetHttpResponse().SetHeader(std::string{"X-Search-Degraded"}, std::string{"1"});
        std::string q_lower = q;
        std::transform(q_lower.begin(), q_lower.end(), q_lower.begin(), ::tolower);

        userver::formats::json::ValueBuilder videos_arr{userver::formats::common::Type::kArray};
        try {
            if (has_author) {
                const bool is_owner =
                    auth.result == utils::AuthResult::kAuthenticated && auth.user_id == author_id;
                auto table = session_->GetTable("videos");
                userver::storages::scylla::operations::SelectMany select;
                select.AddAllColumns();
                select.WhereInt64("user_id", author_id);
                int collected = 0;
                for (const auto& row : table.Execute(select)) {
                    if (collected >= limit) break;
                    const auto vis =
                        row.IsNull("visibility") ? std::string{"public"} : row.Get<std::string>("visibility");
                    if (!is_owner && vis != "public") continue;
                    const auto title = row.Get<std::string>("title");
                    std::string t = title;
                    std::transform(t.begin(), t.end(), t.begin(), ::tolower);
                    if (t.find(q_lower) == std::string::npos) continue;
                    const int64_t ca = row.IsNull("created_at_ms") ? 0LL : row.Get<int64_t>("created_at_ms");
                    videos_arr.PushBack(utils::video::BuildVideoJson(
                        row.Get<std::string>("video_id"), author_id, title,
                        row.Get<std::string>("storage_url"),
                        row.IsNull("mime") ? std::string{} : row.Get<std::string>("mime"),
                        row.IsNull("size_bytes") ? 0LL : row.Get<int64_t>("size_bytes"),
                        std::nullopt,
                        row.IsNull("thumbnail_url") ? std::string{} : row.Get<std::string>("thumbnail_url"),
                        vis, ca,
                        row.IsNull("storyboard_url") ? std::string{} : row.Get<std::string>("storyboard_url")
                    ));
                    ++collected;
                }
            } else {
                const int64_t now_ms = utils::video::NowMs();
                auto table = session_->GetTable("videos_by_day");
                int collected = 0;
                for (int day = 0; day < 30 && collected < limit; ++day) {
                    const auto day_str = utils::video::DayString(now_ms - static_cast<int64_t>(day) * 86'400'000LL);
                    userver::storages::scylla::operations::SelectMany sel;
                    sel.AddAllColumns();
                    sel.WhereString("day", day_str);
                    sel.SetLimit(static_cast<uint32_t>((limit - collected) * 4));
                    for (const auto& row : table.Execute(sel)) {
                        if (collected >= limit) break;
                        const auto title = row.Get<std::string>("title");
                        std::string t = title;
                        std::transform(t.begin(), t.end(), t.begin(), ::tolower);
                        if (t.find(q_lower) == std::string::npos) continue;
                        videos_arr.PushBack(utils::video::BuildVideoJson(
                            row.Get<std::string>("video_id"),
                            row.Get<int64_t>("user_id"), title,
                            row.Get<std::string>("storage_url"),
                            row.IsNull("mime") ? std::string{} : row.Get<std::string>("mime"),
                            row.IsNull("size_bytes") ? 0LL : row.Get<int64_t>("size_bytes"),
                            std::nullopt,
                            row.IsNull("thumbnail_url") ? std::string{} : row.Get<std::string>("thumbnail_url"),
                            "public",
                            row.IsNull("created_at") ? 0LL : row.Get<int64_t>("created_at"),
                            row.IsNull("storyboard_url") ? std::string{} : row.Get<std::string>("storyboard_url")
                        ));
                        ++collected;
                    }
                }
            }
        } catch (const std::exception& ex) {
            LOG_ERROR() << "GET /v1/videos Scylla fallback failed: " << ex.what();
            request.SetResponseStatus(userver::server::http::HttpStatus::kInternalServerError);
            userver::formats::json::ValueBuilder err;
            err["error"] = std::string{ex.what()};
            return userver::formats::json::ToString(err.ExtractValue());
        }

        userver::formats::json::ValueBuilder response;
        response["videos"] = videos_arr.ExtractValue();
        response["next_cursor"] = NullJson();
        response["total_estimate"] = -1;
        response["query_time_ms"] = 0;
        return userver::formats::json::ToString(response.ExtractValue());
    }

    // ═══════════════════════════════════════════════════════════════════════
    // FEED PATH  (q empty) — Scylla only, unchanged from original
    // ═══════════════════════════════════════════════════════════════════════
    userver::formats::json::ValueBuilder videos_arr{userver::formats::common::Type::kArray};

    try {
        if (has_author) {
            const bool is_owner =
                auth.result == utils::AuthResult::kAuthenticated && auth.user_id == author_id;
            auto table = session_->GetTable("videos");
            userver::storages::scylla::operations::SelectMany select;
            select.AddAllColumns();
            select.WhereInt64("user_id", author_id);
            int collected = 0;
            for (const auto& row : table.Execute(select)) {
                if (collected >= limit) break;
                const auto vis =
                    row.IsNull("visibility") ? std::string{"public"} : row.Get<std::string>("visibility");
                if (!is_owner && vis != "public") continue;
                const int64_t ca = row.IsNull("created_at_ms") ? 0LL : row.Get<int64_t>("created_at_ms");
                videos_arr.PushBack(utils::video::BuildVideoJson(
                    row.Get<std::string>("video_id"), author_id,
                    row.Get<std::string>("title"),
                    row.Get<std::string>("storage_url"),
                    row.IsNull("mime") ? std::string{} : row.Get<std::string>("mime"),
                    row.IsNull("size_bytes") ? 0LL : row.Get<int64_t>("size_bytes"),
                    std::nullopt,
                    row.IsNull("thumbnail_url") ? std::string{} : row.Get<std::string>("thumbnail_url"),
                    vis, ca,
                    row.IsNull("storyboard_url") ? std::string{} : row.Get<std::string>("storyboard_url")
                ));
                ++collected;
            }
        } else {
            const int64_t now_ms = utils::video::NowMs();
            auto table = session_->GetTable("videos_by_day");
            int collected = 0;
            for (int day = 0; day < 30 && collected < limit; ++day) {
                const auto day_str = utils::video::DayString(now_ms - static_cast<int64_t>(day) * 86'400'000LL);
                userver::storages::scylla::operations::SelectMany sel;
                sel.AddAllColumns();
                sel.WhereString("day", day_str);
                sel.SetLimit(static_cast<uint32_t>((limit - collected) * 4));
                for (const auto& row : table.Execute(sel)) {
                    if (collected >= limit) break;
                    videos_arr.PushBack(utils::video::BuildVideoJson(
                        row.Get<std::string>("video_id"),
                        row.Get<int64_t>("user_id"),
                        row.Get<std::string>("title"),
                        row.Get<std::string>("storage_url"),
                        row.IsNull("mime") ? std::string{} : row.Get<std::string>("mime"),
                        row.IsNull("size_bytes") ? 0LL : row.Get<int64_t>("size_bytes"),
                        std::nullopt,
                        row.IsNull("thumbnail_url") ? std::string{} : row.Get<std::string>("thumbnail_url"),
                        "public",
                        row.IsNull("created_at") ? 0LL : row.Get<int64_t>("created_at"),
                        row.IsNull("storyboard_url") ? std::string{} : row.Get<std::string>("storyboard_url")
                    ));
                    ++collected;
                }
            }
        }
    } catch (const std::exception& ex) {
        LOG_ERROR() << "GET /v1/videos failed: " << ex.what();
        request.SetResponseStatus(userver::server::http::HttpStatus::kInternalServerError);
        userver::formats::json::ValueBuilder err;
        err["error"] = std::string{ex.what()};
        return userver::formats::json::ToString(err.ExtractValue());
    }

    userver::formats::json::ValueBuilder response;
    response["videos"] = videos_arr.ExtractValue();
    response["next_cursor"] = NullJson();
    response["total_estimate"] = -1;
    response["query_time_ms"] = 0;
    return userver::formats::json::ToString(response.ExtractValue());
}

}  // namespace real_medium::handlers::videos::list
