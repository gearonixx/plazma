# `GET /v1/videos` — full endpoint spec

Authoritative contract for the video feed + search endpoint. Frontend is already
wired to this shape (`Plazma/src/api.cpp :: Api::fetchVideos`,
`Plazma/src/models/video_feed_model.cpp`); this doc is the server-side work
item.

Status: current handler
(`PlazmaServer/src/handlers/videos/video_list.cpp`) implements the feed and a
naive case-insensitive `title.find(q)` filter. This spec describes the target
state — a real search engine (ElasticSearch / OpenSearch) behind the same URL.

---

## 1. Identity

| Attribute | Value |
| --- | --- |
| Method | `GET` |
| Path | `/v1/videos` |
| Auth | Optional bearer (see §3) |
| Content-Type (response) | `application/json; charset=utf-8` |
| Idempotent | Yes |
| Cacheable | Yes, see §8 |

---

## 2. Query parameters

| Name | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| `q` | string | no | — | Search query. UTF-8, URL-encoded, trimmed client-side, max 256 chars. Treat missing and empty identically. |
| `limit` | integer | no | `20` | Clamped to `[1, 100]`. |
| `cursor` | opaque string | no | — | Pagination cursor returned by a previous response. See §5. |
| `author` | int64 | no | — | Restricts to one user's videos. Mutually compatible with `q`. |
| `sort` | enum | no | auto | `relevance`, `recent`, `popular`. Default: `relevance` if `q` non-empty, else `recent`. |

Validation rules:

- `q`: reject with `400` if byte length > 1024 (safety limit past the client cap).
  Strip ASCII control chars before indexing the query string. Do not reject on
  empty — treat as "no search".
- `limit`: non-integer or out-of-range → `400 {"error":"limit must be an
  integer in [1, 100]"}`.
- `cursor`: must decode to the schema in §5; if not, `400
  {"error":"invalid cursor"}`.
- `author`: must be a positive int64; otherwise `400`.
- `sort`: unknown values → `400`.

---

## 3. Authentication

- Bearer token in `Authorization: Bearer <token>`.
- Missing header → treat as anonymous (public videos only).
- Present but invalid/expired → `401 {"error":"invalid or expired token"}`.
- Authenticated caller's own `author=<me>` query returns the caller's private +
  unlisted videos in addition to public. All other combinations return only
  `visibility = "public"`.

---

## 4. Success response

`200 OK`, body:

```json
{
  "videos": [
    {
      "id":          "v_01HX…",
      "user_id":     42,
      "title":       "My holiday clip",
      "url":         "http://localhost:9000/plazma-videos/videos/…",
      "mime":        "video/mp4",
      "size":        184203213,
      "duration_ms": 91230,
      "thumbnail":   "http://localhost:9000/plazma-videos/thumbs/…",
      "storyboard":  "http://localhost:9000/plazma-videos/sprites/…",
      "author":      "alex",
      "created_at":  "2026-04-01T12:31:08Z",
      "visibility":  "public",
      "score":       8.4213
    }
  ],
  "next_cursor": "eyJrIjoi…",
  "total_estimate": 1732,
  "query_time_ms": 17
}
```

Field semantics — keep them stable, the QML delegate binds to them:

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `id` | string | yes | Stable video id. |
| `user_id` | int64 | yes | Author's id. |
| `title` | string | yes | Display title. May be empty string; never `null`. |
| `url` | string | yes | Absolute HTTP URL to the media file. |
| `mime` | string | yes | e.g. `video/mp4`. Empty string if unknown. |
| `size` | int64 | yes | Bytes. `0` if unknown. |
| `duration_ms` | int64 \| null | yes | Present when probed; `null` otherwise. |
| `thumbnail` | string \| null | yes | Absolute HTTP URL or `null`. |
| `storyboard` | string \| null | yes | Absolute HTTP URL to 10×10 sprite sheet, or `null`. |
| `author` | string | yes | Username. Empty string if unknown. |
| `created_at` | ISO-8601 string | yes | UTC, seconds precision, `Z` suffix. |
| `visibility` | enum | yes | `public`, `unlisted`, `private`. Only `public` appears for anonymous callers. |
| `score` | number | when `q` present | BM25 score from the search backend. Omit when `q` empty. |
| `next_cursor` | string \| null | yes | Opaque cursor or `null` when no more pages. |
| `total_estimate` | int | yes | Approximate total hits. Backend may return `-1` when unknown. |
| `query_time_ms` | int | yes | Server-side elapsed time for the search call only (excludes network). |

Do **not** emit `null` for `title`, `mime`, `size`, `url`, `user_id` — these are
declared as non-nullable to keep the QML role binding trivial.

---

## 5. Pagination

Cursor-based, seek-style. Encode as URL-safe base64 of a compact JSON object
that **must** be treated as opaque by clients:

```json
{
  "v": 1,
  "k": "<sort key tuple>",
  "q": "<normalized query, for cursor-to-query binding>",
  "s": "<sort mode>",
  "a": <author user_id or null>
}
```

Rules:

- A cursor is only valid for the identical `(q_normalized, sort, author)`
  triple it was minted against. Mismatch → `400 {"error":"cursor/query
  mismatch"}`. This prevents clients from "paging into" a different query.
- When `sort=recent`, the sort key is `(created_at DESC, video_id DESC)`.
- When `sort=relevance`, the sort key is `(score DESC, created_at DESC,
  video_id DESC)` — the created_at + id tie-breakers are what make the cursor
  stable under concurrent writes.
- The last page MUST set `next_cursor: null`.
- Cursors expire after 10 minutes; expired → `410 {"error":"cursor expired"}`.

---

## 6. Ordering semantics

| Mode | Active when | Primary key | Tie-breakers |
| --- | --- | --- | --- |
| `relevance` | `q` non-empty AND (`sort` unset or `relevance`) | BM25 score desc | `created_at` desc, `video_id` desc |
| `recent` | `q` empty AND (`sort` unset or `recent`) | `created_at` desc | `video_id` desc |
| `popular` | `sort=popular` | `video_stats.views` desc over last 7d | `created_at` desc |

---

## 7. Error responses

All errors are JSON `{"error":"<message>"}` with the statuses below.

| Status | Condition |
| --- | --- |
| `400` | Malformed parameter per §2. |
| `401` | Token present but invalid / expired. |
| `410` | Expired cursor. |
| `429` | Rate limit exceeded (§10). |
| `500` | Internal error (ES unavailable AND fallback also failed). |
| `503` | Dependency degradation — ES circuit breaker open, and we chose to fail rather than fall back. |

Clients surface the message verbatim — keep it short and human-readable.

---

## 8. Caching

- `Cache-Control: public, max-age=15, stale-while-revalidate=60` when `q`
  empty (feed).
- `Cache-Control: private, max-age=5` when `q` non-empty (search results are
  personal enough given visibility filtering that public caching is wrong).
- `Vary: Authorization` always.
- `ETag` derived from `(sort, q, limit, cursor, author, auth.user_id or
  "anon")` + index generation. Client support is optional; server must honour
  `If-None-Match` → `304`.

---

## 9. Search backend — ElasticSearch / OpenSearch

### 9.1 Index

One index: `videos_v1`. Write through `videos` alias so we can rebuild under
`videos_v2` and swap atomically.

```json
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1,
    "analysis": {
      "analyzer": {
        "plazma_text": {
          "type": "custom",
          "tokenizer": "standard",
          "filter": ["lowercase", "asciifolding", "stop_en_ru", "icu_normalizer"]
        }
      },
      "filter": {
        "stop_en_ru": { "type": "stop", "stopwords": ["_english_", "_russian_"] }
      }
    }
  },
  "mappings": {
    "dynamic": "strict",
    "properties": {
      "video_id":     { "type": "keyword" },
      "user_id":      { "type": "long" },
      "author":       { "type": "text", "analyzer": "plazma_text",
                         "fields": { "raw": { "type": "keyword" } } },
      "title":        { "type": "text", "analyzer": "plazma_text",
                         "fields": { "raw": { "type": "keyword" } } },
      "description":  { "type": "text", "analyzer": "plazma_text" },
      "tags":         { "type": "keyword" },
      "mime":         { "type": "keyword" },
      "size_bytes":   { "type": "long" },
      "duration_ms":  { "type": "long" },
      "visibility":   { "type": "keyword" },
      "created_at":   { "type": "date", "format": "epoch_millis" },
      "thumbnail_url":{ "type": "keyword", "index": false },
      "storyboard_url":{ "type": "keyword", "index": false },
      "storage_url":  { "type": "keyword", "index": false },
      "views_7d":     { "type": "long" },
      "indexed_at":   { "type": "date", "format": "epoch_millis" }
    }
  }
}
```

Notes:

- `asciifolding` + ICU normalization means `é` → `e`, Cyrillic folding works.
  Keep this aligned between index-time and query-time analyzers.
- `title.raw` / `author.raw` keep an exact-match handle for sort / filter /
  exact-phrase boost.
- `dynamic: strict` — reject unknown fields rather than silently expanding
  the mapping.

### 9.2 Query DSL

For `q` non-empty:

```json
{
  "size": <limit>,
  "query": {
    "function_score": {
      "query": {
        "bool": {
          "must": [{
            "multi_match": {
              "query":  "<q>",
              "type":   "best_fields",
              "fields": ["title^3", "author^2", "description^1", "tags^1.5"],
              "operator": "and",
              "fuzziness": "AUTO:4,7",
              "prefix_length": 1
            }
          }],
          "should": [
            { "match_phrase": { "title":  { "query": "<q>", "boost": 4 } } },
            { "match_phrase": { "author": { "query": "<q>", "boost": 2 } } }
          ],
          "filter": [ <visibility filter>, <author filter if any> ]
        }
      },
      "functions": [
        { "gauss": { "created_at": { "origin": "now", "scale": "14d",
                                      "offset": "1d", "decay": 0.5 } } },
        { "field_value_factor": { "field": "views_7d",
                                   "modifier": "log1p", "missing": 0 } }
      ],
      "score_mode": "sum",
      "boost_mode": "multiply"
    }
  },
  "sort": [ "_score",
            { "created_at": "desc" },
            { "video_id": "desc" } ],
  "track_total_hits": 10000
}
```

For `q` empty: skip ES entirely, serve from Scylla `videos_by_day` (the
existing code path). Keeps the feed independent of ES availability.

Visibility filter:

- Anonymous or non-matching user: `{"term": {"visibility": "public"}}`.
- Authenticated `u` on `author=u`: omit the filter (owner sees all own).
- Authenticated `u` on any other query: `{"term": {"visibility": "public"}}`.

### 9.3 Indexing pipeline

Write path for every create / update / delete:

1. Primary write — existing Scylla transaction
   (`video_create`, `video_delete`) stays authoritative.
2. On commit, enqueue an indexing event `{op, video_id, generation_ts}` onto
   an outbox table `plazma.search_outbox`.
3. A background component drains the outbox in FIFO order with at-least-once
   semantics and issues `index` / `delete` to ES. Tolerates ES being down —
   rows stay in the outbox.
4. ES document uses `video_id` as `_id` so retries are idempotent. Every doc
   carries `indexed_at = NowMs()`; the search handler ignores hits with an
   `indexed_at` older than the cursor mint time to prevent rank flapping
   mid-page.

Counters (`views_7d`) are refreshed out-of-band by a 5-minute scheduled task
that upserts partial docs via `_update` with the latest window.

### 9.4 Backfill

One-off Scylla-to-ES walker at deployment:

- Scan `plazma.video_by_id`, project to the ES doc shape, bulk-index into
  `videos_v1` with `refresh=wait_for` off, then `POST _aliases` to point
  `videos` at `videos_v1`.
- Resumable — record the last `video_id` in a `plazma.backfill_state` row.

---

## 10. Performance, limits, safety

- **Target latency** p50 < 40 ms, p95 < 200 ms end-to-end inside the server.
  Frontend debounces typing and does not cancel in-flight requests on the wire
  — it drops stale responses client-side — so sub-200ms is the budget that
  keeps the feed pleasant under fast typing.
- **Per-caller rate limit**: 20 rps averaged over 10 s, burst 40. Keyed by
  `user_id` when authenticated, else by client IP. Over limit → `429` with
  `Retry-After`.
- **Per-query cost cap**: ES request timeout 500 ms. On timeout, return `503`
  **or** the Scylla fallback result set (see §11) depending on the circuit
  breaker state.
- **Response cap**: absolute `limit` ceiling = 100. Never page beyond 10 000
  total hits (ES deep-pagination limit); surface `next_cursor: null` there.

---

## 11. Fallback behaviour

The feed must survive ES being down.

- When `q` empty: already independent of ES. No fallback needed.
- When `q` non-empty:
  - Circuit-breaker opens after 5 consecutive failures or >50% 30 s error
    rate. While open, short-circuit to the legacy Scylla substring path from
    the current `video_list.cpp`, but:
    - Mark the response with header `X-Search-Degraded: 1`.
    - Omit `score` and `total_estimate`.
    - Keep `visibility` filtering identical to the ES path.
  - Breaker half-opens after 30 s and probes with a single canary query.

---

## 12. Observability

Emit these per request (structured log + metrics):

- `search.requests_total{sort, auth, degraded}`
- `search.latency_ms{phase=<parse|es|scylla|serialize>}` histogram
- `search.results_count` histogram
- `search.errors_total{kind=<timeout|parse|es_5xx|…>}`
- `search.outbox_lag_ms` gauge (for indexing freshness)

Tracing: propagate `X-Request-Id`; span names `video_search.handle`,
`video_search.es_query`, `video_search.scylla_fallback`.

---

## 13. Security

- Reject `q` containing raw null bytes (`\x00`) — `400`.
- The query string is passed to ES via the JSON body, never concatenated into
  a URL or Lucene query string, so no injection surface there. Do not enable
  `query_string` syntax.
- Visibility filter is enforced server-side; never trust a client-provided
  visibility hint.
- Response `url` / `thumbnail` / `storyboard` are rewritten by
  `StorageUrlToHttp()`; do not leak raw `s3://` URLs.

---

## 14. Test matrix

Minimum acceptance tests before shipping:

1. `q` empty, anonymous → 20 recent public videos, newest first.
2. `q` empty, authenticated → same as (1) plus their private/unlisted are
   still **hidden** (feed is public-only).
3. `q` empty, `author=<self>`, authenticated → own private/unlisted appear.
4. `q` empty, `author=<other>`, anonymous → only public.
5. `q="holiday"` matches `title="My holiday clip"` and
   `title="Holiday plans"`; ordering reflects BM25.
6. `q="HOLiday"` matches the same set (case-insensitive via analyzer).
7. `q="holday"` matches `holiday` via fuzziness (Levenshtein 1).
8. `q="олег"` / `q="Oleg"` both match `author="Олег"` via ICU folding.
9. Cursor round-trip: page 1 → page 2 returns disjoint rows, stable under a
   concurrent insert at time `between(p1, p2)`.
10. Cursor minted for `q="a"` rejected with `400` on `q="b"`.
11. `limit=0`, `limit=101`, `limit="abc"` all → `400`.
12. ES down → feed (`q` empty) still serves; search (`q` non-empty) either
    returns degraded Scylla results with `X-Search-Degraded: 1` or `503`
    depending on breaker state.
13. Rate limit: 41st request within 1 s → `429` with `Retry-After`.

---

## 15. Rollout plan

1. Ship `search_outbox` table + outbox-writing code behind a feature flag
   (`search.outbox.enabled`). No reader change. Verify outbox drains cleanly
   in staging.
2. Deploy ES cluster, run the backfill, point the `videos` alias at
   `videos_v1`. Still no reader change.
3. Flip `search.reader=es` for 10% of traffic via header-based routing. Watch
   `search.latency_ms` and `search.errors_total`. Revert by flipping the flag.
4. Ramp to 100%.
5. Delete the legacy substring match from `video_list.cpp` once the ES reader
   has been at 100% for two weeks without a rollback.
