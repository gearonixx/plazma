#include "video_create.hpp"

#include <algorithm>
#include <cctype>

#include <userver/formats/json/serialize.hpp>
#include <userver/formats/json/value_builder.hpp>
#include <userver/http/common_headers.hpp>
#include <userver/logging/log.hpp>
#include <userver/storages/scylla/operations.hpp>
#include <userver/utils/uuid7.hpp>

#include "utils/auth.hpp"
#include "utils/video.hpp"

namespace real_medium::handlers::videos::create {

namespace {

struct MultipartPart {
    std::string name;
    std::string filename;
    std::string content_type;
    std::string data;
};

std::string ExtractBoundary(const std::string& ct) {
    auto pos = ct.find("boundary=");
    if (pos == std::string::npos) return {};
    pos += 9;
    if (pos < ct.size() && ct[pos] == '"') {
        ++pos;
        const auto end = ct.find('"', pos);
        return (end == std::string::npos) ? std::string{} : ct.substr(pos, end - pos);
    }
    const auto end = ct.find_first_of("; \t\r\n", pos);
    return ct.substr(pos, end - pos);
}

// Case-insensitive search for a header name within a MIME part headers block.
// Returns the position of the colon (or npos if not found).
size_t FindHeader(const std::string& headers, std::string_view name) {
    std::string lh = headers;
    std::transform(lh.begin(), lh.end(), lh.begin(), ::tolower);
    std::string ln(name);
    std::transform(ln.begin(), ln.end(), ln.begin(), ::tolower);
    ln += ':';
    return lh.find(ln);
}

// Extract a named parameter from a Content-Disposition header value, e.g. name="foo".
// header_value is the full value string starting after "Content-Disposition:".
std::string ExtractDispositionParam(const std::string& headers, const std::string& param) {
    const auto hpos = FindHeader(headers, "Content-Disposition");
    if (hpos == std::string::npos) return {};
    const auto line_end = headers.find("\r\n", hpos);
    const auto line_len = (line_end == std::string::npos) ? std::string::npos : line_end - hpos;
    const auto line = headers.substr(hpos, line_len);

    // Case-insensitive search for param="
    std::string lline = line, lparam = param + "=\"";
    std::transform(lline.begin(), lline.end(), lline.begin(), ::tolower);
    std::transform(lparam.begin(), lparam.end(), lparam.begin(), ::tolower);
    const auto ppos = lline.find(lparam);
    if (ppos == std::string::npos) return {};
    const auto val_start = ppos + lparam.size();
    const auto val_end = line.find('"', val_start);
    return (val_end == std::string::npos) ? std::string{} : line.substr(val_start, val_end - val_start);
}

// Extract Content-Type value from a MIME part header block, stripping parameters.
std::string ExtractPartContentType(const std::string& headers) {
    const auto hpos = FindHeader(headers, "Content-Type");
    if (hpos == std::string::npos) return {};
    // Advance past the header name and colon
    auto pos = headers.find(':', hpos);
    if (pos == std::string::npos) return {};
    ++pos;
    while (pos < headers.size() && headers[pos] == ' ') ++pos;
    auto end = headers.find("\r\n", pos);
    auto ct = headers.substr(pos, (end == std::string::npos) ? std::string::npos : end - pos);
    // Strip parameters after ';' (e.g. "; charset=utf-8")
    const auto semi = ct.find(';');
    if (semi != std::string::npos) ct.resize(semi);
    while (!ct.empty() && ct.back() == ' ') ct.pop_back();
    return ct;
}

std::vector<MultipartPart> ParseMultipart(const std::string& body, const std::string& boundary) {
    std::vector<MultipartPart> parts;
    const auto delim = "--" + boundary;

    size_t pos = body.find(delim);
    while (pos != std::string::npos) {
        pos += delim.size();

        // Check for terminal boundary "--" or part separator "\r\n"
        if (pos + 1 < body.size() && body[pos] == '-' && body[pos + 1] == '-') break;
        if (pos + 1 < body.size() && body[pos] == '\r' && body[pos + 1] == '\n') {
            pos += 2;
        } else {
            break;  // malformed boundary line
        }

        const auto headers_end = body.find("\r\n\r\n", pos);
        if (headers_end == std::string::npos) break;
        const auto headers = body.substr(pos, headers_end - pos);
        const auto data_start = headers_end + 4;

        const auto next_delim = body.find("\r\n" + delim, data_start);
        if (next_delim == std::string::npos) break;

        MultipartPart part;
        part.name         = ExtractDispositionParam(headers, "name");
        part.filename     = ExtractDispositionParam(headers, "filename");
        part.content_type = ExtractPartContentType(headers);
        part.data         = body.substr(data_start, next_delim - data_start);
        parts.push_back(std::move(part));

        pos = next_delim + 2;  // skip the \r\n before the next delimiter
        pos = body.find(delim, pos);
    }
    return parts;
}

}  // namespace

Handler::Handler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& context
) : HttpHandlerBase(config, context),
    s3_(context.FindComponent<s3::S3Component>()),
    session_(context.FindComponent<userver::components::Scylla>("scylla").GetSession()) {
}

std::string Handler::HandleRequest(
    userver::server::http::HttpRequest& request,
    userver::server::request::RequestContext& /*context*/
) const {
    request.GetHttpResponse().SetContentType("application/json");

    // Auth is required; no anonymous uploads
    const auto auth = utils::ExtractAuth(request);
    if (auth.result == utils::AuthResult::kInvalid) {
        request.SetResponseStatus(userver::server::http::HttpStatus::kUnauthorized);
        return R"({"error": "invalid or expired token"})";
    }
    if (auth.result == utils::AuthResult::kAnonymous) {
        request.SetResponseStatus(userver::server::http::HttpStatus::kUnauthorized);
        return R"({"error": "authentication required"})";
    }
    const int64_t user_id = auth.user_id;

    const auto content_type_hdr = request.GetHeader("Content-Type");
    const auto boundary = ExtractBoundary(content_type_hdr);
    if (boundary.empty()) {
        request.SetResponseStatus(userver::server::http::HttpStatus::kBadRequest);
        return R"({"error": "expected multipart/form-data with boundary"})";
    }

    const auto parts = ParseMultipart(request.RequestBody(), boundary);
    if (parts.empty()) {
        request.SetResponseStatus(userver::server::http::HttpStatus::kBadRequest);
        return R"({"error": "no parts found in multipart body"})";
    }

    // Locate file part and optional form fields
    const MultipartPart* file_part = nullptr;
    std::string title_field;
    std::string visibility_field = "public";

    for (const auto& part : parts) {
        if (!part.filename.empty() && file_part == nullptr) {
            file_part = &part;
        } else if (part.name == "title") {
            title_field = part.data;
        } else if (part.name == "visibility") {
            const auto& v = part.data;
            if (v == "public" || v == "unlisted" || v == "private") visibility_field = v;
        }
    }

    if (!file_part) {
        request.SetResponseStatus(userver::server::http::HttpStatus::kBadRequest);
        return R"({"error": "no file part found in request"})";
    }

    // Resolve MIME: prefer part Content-Type, fall back to extension inference
    std::string mime = file_part->content_type;
    if (mime.empty()) {
        mime = utils::video::MimeFromFilename(file_part->filename);
    }
    if (!utils::video::IsAllowedMime(mime)) {
        request.SetResponseStatus(userver::server::http::HttpStatus::kUnsupportedMediaType);
        return R"({"error": "unsupported video format; allowed: mp4, webm, mkv, mov, avi, ogv"})";
    }

    if (file_part->data.empty()) {
        request.SetResponseStatus(userver::server::http::HttpStatus::kBadRequest);
        return R"({"error": "file part is empty"})";
    }

    const auto video_id      = userver::utils::generators::GenerateUuidV7();
    const auto safe_filename = utils::video::SanitizeFilename(file_part->filename);
    const auto s3_key        = "videos/" + video_id + "/" + safe_filename;
    const auto storage_url   = "s3://plazma-videos/" + s3_key;
    const auto size_bytes    = static_cast<int64_t>(file_part->data.size());
    const auto created_at_ms = utils::video::NowMs();
    const auto day           = utils::video::DayString(created_at_ms);

    // Derive/normalize title
    std::string title = utils::video::NormalizeTitle(
        title_field.empty() ? [&] {
            std::string t = safe_filename;
            const auto dot = t.rfind('.');
            if (dot != std::string::npos) t.resize(dot);
            return t;
        }() : title_field
    );
    if (title.empty()) title = video_id;  // last-resort fallback

    // Upload to S3 first; if this fails don't write metadata
    try {
        userver::s3api::Client::Meta meta;
        meta[userver::http::headers::kContentType] = mime;
        s3_.GetClient()->PutObject(s3_key, file_part->data, meta);
    } catch (const std::exception& ex) {
        LOG_ERROR() << "S3 upload failed for video_id=" << video_id << ": " << ex.what();
        request.SetResponseStatus(userver::server::http::HttpStatus::kBadGateway);
        return R"({"error": "storage upload failed"})";
    }

    // Write metadata to all three tables (application-level "batch")
    try {
        {
            auto table = session_->GetTable("videos");
            userver::storages::scylla::operations::InsertOne ins;
            ins.BindInt64("user_id",      user_id);
            ins.BindString("video_id",    video_id);
            ins.BindString("title",       title);
            ins.BindString("storage_url", storage_url);
            ins.BindString("thumbnail_url", "");
            ins.BindString("mime",        mime);
            ins.BindInt64("size_bytes",   size_bytes);
            ins.BindString("visibility",  visibility_field);
            ins.BindInt64("created_at_ms", created_at_ms);
            table.Execute(ins);
        }
        {
            auto table = session_->GetTable("video_by_id");
            userver::storages::scylla::operations::InsertOne ins;
            ins.BindString("video_id",    video_id);
            ins.BindInt64("user_id",      user_id);
            ins.BindString("title",       title);
            ins.BindString("storage_url", storage_url);
            ins.BindString("mime",        mime);
            ins.BindInt64("size_bytes",   size_bytes);
            ins.BindString("thumbnail_url", "");
            ins.BindString("visibility",  visibility_field);
            ins.BindInt64("created_at",   created_at_ms);
            ins.BindString("day",         day);
            table.Execute(ins);
        }
        // Only public videos go into the global feed table;
        // private/unlisted are accessible only via direct lookup or the owner's library.
        if (visibility_field == "public") {
            auto table = session_->GetTable("videos_by_day");
            userver::storages::scylla::operations::InsertOne ins;
            ins.BindString("day",         day);
            ins.BindInt64("created_at",   created_at_ms);
            ins.BindString("video_id",    video_id);
            ins.BindInt64("user_id",      user_id);
            ins.BindString("title",       title);
            ins.BindString("storage_url", storage_url);
            ins.BindString("thumbnail_url", "");
            ins.BindString("mime",        mime);
            ins.BindInt64("size_bytes",   size_bytes);
            ins.BindString("visibility",  visibility_field);
            table.Execute(ins);
        }
    } catch (const std::exception& ex) {
        LOG_ERROR() << "Scylla write failed for video_id=" << video_id
                    << " user_id=" << user_id << ": " << ex.what();
        // S3 object is already uploaded; orphaned until a future cleanup job runs.
        request.SetResponseStatus(userver::server::http::HttpStatus::kInternalServerError);
        return R"({"error": "metadata write failed"})";
    }

    LOG_INFO() << "POST /v1/videos video_id=" << video_id
               << " user_id=" << user_id
               << " size=" << size_bytes
               << " mime=" << mime
               << " visibility=" << visibility_field;

    userver::formats::json::ValueBuilder response;
    response["video"] = utils::video::BuildVideoJson(
        video_id, user_id, title, storage_url, mime, size_bytes,
        std::nullopt, "", visibility_field, created_at_ms
    );
    request.SetResponseStatus(userver::server::http::HttpStatus::kCreated);
    return userver::formats::json::ToString(response.ExtractValue());
}

}  // namespace real_medium::handlers::videos::create
