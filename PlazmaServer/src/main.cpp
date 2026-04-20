#include <userver/clients/dns/component.hpp>
#include <userver/clients/http/component_list.hpp>
#include <userver/components/minimal_server_component_list.hpp>
#include <userver/storages/scylla/component.hpp>
#include <userver/utils/daemon_run.hpp>

#include "handlers/user/auth_login.hpp"
#include "handlers/videos/video_create.hpp"
#include "handlers/videos/video_list.hpp"
#include "handlers/videos/video_get.hpp"
#include "handlers/videos/video_delete.hpp"
#include "handlers/videos/video_view.hpp"
#include "handlers/videos/my_videos.hpp"
#include "s3/component.hpp"

int main(int argc, char* argv[]) {
    auto component_list = userver::components::MinimalServerComponentList()
        .AppendComponentList(userver::clients::http::ComponentList())
        .Append<userver::components::Scylla>("scylla")
        .Append<real_medium::handlers::users::auth_login::Handler>()
        .Append<real_medium::handlers::videos::create::Handler>()
        .Append<real_medium::handlers::videos::create::Handler>("handler-videos-create-v2")
        .Append<real_medium::handlers::videos::list::Handler>()
        .Append<real_medium::handlers::videos::get::Handler>()
        .Append<real_medium::handlers::videos::del::Handler>()
        .Append<real_medium::handlers::videos::view::Handler>()
        .Append<real_medium::handlers::videos::my::Handler>()
        .Append<real_medium::s3::S3Component>()
        .Append<userver::clients::dns::Component>();

    return userver::utils::DaemonMain(argc, argv, component_list);
}
