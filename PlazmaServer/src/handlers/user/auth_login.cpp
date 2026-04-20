#include "auth_login.hpp"

#include <docs/api.hpp>
#include <userver/components/component_config.hpp>
#include <userver/storages/scylla/operations.hpp>
#include <userver/storages/scylla/row.hpp>
#include <userver/logging/log.hpp>

#include "validators/login_validator.hpp"
#include "utils/errors.hpp"
#include "utils/jwt.hpp"
#include "utils/video.hpp"

namespace real_medium::handlers::users::auth_login {

Handler::Handler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& context
) : HttpHandlerJsonBase(config, context),
    session_(context.FindComponent<userver::components::Scylla>("scylla").GetSession()) {}


userver::formats::json::Value Handler::HandleRequestJsonThrow(
    const userver::server::http::HttpRequest& request,
    const userver::formats::json::Value& request_json,
    userver::server::request::RequestContext& /*context*/
) const {
    const auto dto = request_json.As<::handlers::TelegramLoginDTO>();
    try {
        validator::validate(dto);
    } catch (const utils::error::ValidationException& err) {
        request.SetResponseStatus(userver::server::http::HttpStatus::kUnprocessableEntity);
        return err.GetDetails();
    }

    auto users_by_phone = session_->GetTable("users_by_phone");

    userver::storages::scylla::operations::SelectOne select_user;
    select_user.AddAllColumns();
    select_user.WhereString("phone_number", dto.phone_number);

    auto user_row = users_by_phone.Execute(select_user);
    if (user_row.Empty()) {
        userver::storages::scylla::operations::InsertOne insert_user;
        insert_user.BindInt64("user_id",       dto.user_id);
        insert_user.BindString("username",     dto.username.value_or(""));
        insert_user.BindString("first_name",   dto.first_name);
        insert_user.BindString("last_name",    dto.last_name.value_or(""));
        insert_user.BindString("phone_number", dto.phone_number);
        insert_user.BindBool("is_premium",     dto.is_premium);

        users_by_phone.Execute(insert_user);

        // Re-read to get the canonical row (avoids trusting insert echo)
        user_row = users_by_phone.Execute(select_user);
        if (user_row.Empty()) {
            LOG_ERROR() << "POST /v1/auth/login: user row missing after insert, phone="
                        << dto.phone_number;
            request.SetResponseStatus(userver::server::http::HttpStatus::kInternalServerError);
            userver::formats::json::ValueBuilder err;
            err["error"] = "failed to persist user";
            return err.ExtractValue();
        }
    }

    const auto user_id = user_row.Get<int64_t>("user_id");
    const auto phone   = user_row.Get<std::string>("phone_number");

    const auto token         = utils::jwt::Mint(user_id, phone);
    const auto expires_at_ms = utils::video::NowMs() + 30LL * 24LL * 3600LL * 1000LL;

    LOG_INFO() << "POST /v1/auth/login user_id=" << user_id;

    userver::formats::json::ValueBuilder response;
    response["token"]      = token;
    response["expires_at"] = utils::video::FormatTimestampMs(expires_at_ms);
    response["user"]["user_id"]      = user_id;
    response["user"]["username"]     = user_row.IsNull("username")
        ? std::string{} : user_row.Get<std::string>("username");
    response["user"]["first_name"]   = user_row.IsNull("first_name")
        ? std::string{} : user_row.Get<std::string>("first_name");
    response["user"]["phone_number"] = phone;
    response["user"]["is_premium"]   = user_row.IsNull("is_premium")
        ? false : user_row.Get<bool>("is_premium");
    return response.ExtractValue();
}

}  // namespace real_medium::handlers::users::auth_login
