#pragma once

#include <string_view>

namespace plazma::fatal {

using Callback = void (*)(int verbosity, std::string_view message);

void set_callback(Callback callback) noexcept;
Callback get_callback() noexcept;

void set_max_verbosity(int level) noexcept;
int get_max_verbosity() noexcept;

// Route all fatal signals (qFatal, std::terminate, uncaught exceptions)
// through process_fatal_error. Installs a default callback that writes
// timestamped messages to stderr and to <AppDataLocation>/crash.log.
// Idempotent; call once from main().
void install() noexcept;

// The TdLib analog. Always aborts.
[[noreturn]] void process_fatal_error(std::string_view message) noexcept;

}  // namespace plazma::fatal
