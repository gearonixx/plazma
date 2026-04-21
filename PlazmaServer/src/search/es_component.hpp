#pragma once

#include <atomic>
#include <cstdint>
#include <optional>
#include <string>
#include <vector>

#include <userver/clients/http/client.hpp>
#include <userver/components/loggable_component_base.hpp>
#include <userver/components/component_context.hpp>
#include <userver/yaml_config/schema.hpp>

namespace real_medium::search {

enum class SortMode { kRelevance, kRecent, kPopular };

struct EsHit {
    std::string video_id;
    int64_t user_id = 0;
    std::string author;
    std::string title;
    std::string storage_url;
    std::string mime;
    int64_t size_bytes = 0;
    std::optional<int64_t> duration_ms;
    std::string thumbnail_url;
    std::string storyboard_url;
    std::string visibility;
    int64_t created_at_ms = 0;
    double score = 0.0;
    std::string sort_values_json;  // raw JSON array of ES sort values for search_after cursor
};

struct EsSearchResult {
    std::vector<EsHit> hits;
    int64_t total_estimate = 0;
    int64_t query_time_ms = 0;
};

class EsComponent final : public userver::components::LoggableComponentBase {
public:
    static constexpr std::string_view kName = "es-search";

    EsComponent(
        const userver::components::ComponentConfig& config,
        const userver::components::ComponentContext& context
    );

    static userver::yaml_config::Schema GetStaticConfigSchema();

    // Returns nullopt when the circuit breaker is open — caller should fall back to Scylla.
    std::optional<EsSearchResult> Search(
        const std::string& query,
        int limit,
        SortMode sort,
        std::optional<int64_t> author_filter,
        bool owner_context,
        std::optional<std::string> search_after_json
    ) const;

private:
    userver::clients::http::Client& http_;
    std::string url_;
    std::string index_;

    mutable std::atomic<int> consecutive_failures_{0};
    // Epoch ms at which the breaker opened, 0 = closed.
    mutable std::atomic<int64_t> open_since_ms_{0};

    static constexpr int kBreakerThreshold = 5;
    static constexpr int64_t kHalfOpenDelayMs = 30'000;

    bool IsBreakerOpen() const;
    void RecordSuccess() const;
    void RecordFailure() const;

    std::string BuildQueryJson(
        const std::string& q,
        int limit,
        SortMode sort,
        std::optional<int64_t> author_filter,
        bool owner_context,
        std::optional<std::string> search_after_json
    ) const;
};

}  // namespace real_medium::search
