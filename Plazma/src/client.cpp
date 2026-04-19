#include <QDebug>

#include <qdebug.h>
#include <qobject.h>
#include <qthread.h>
#include <td/telegram/Client.h>
#include <td/telegram/td_api.h>
#include <concepts>
#include <td/telegram/td_api.hpp>

#include "version.h"

#include "detail.h"

#include "client.h"

RequestPtr TelegramRequestBuilder::setTdLibParameters() {
    auto request = td_api::make_object<td::td_api::setTdlibParameters>();
    request->database_directory_ = "tdlib";
    request->use_message_database_ = true;
    request->use_secret_chats_ = true;
    request->api_id_ = 94575;
    request->api_hash_ = "a3406de8d171bb422bb6ddf3bbd800e2";
    request->system_language_code_ = "en";
    request->device_model_ = APPLICATION_ID;
    request->application_version_ = APP_VERSION;

    return request;
}

RequestPtr TelegramRequestBuilder::getVersion() { return td_api::make_object<td_api::getOption>("version"); };

RequestPtr TelegramRequestBuilder::setPhoneNumber(const lcString& phone_number) {
    return td_api::make_object<td::td_api::setAuthenticationPhoneNumber>(phone_number, nullptr);
}

RequestPtr TelegramRequestBuilder::checkAuthCode(const lcString& code) {
    return td_api::make_object<td::td_api::checkAuthenticationCode>(code);
}

RequestPtr TelegramRequestBuilder::getMe() { return td_api::make_object<td::td_api::getMe>(); }

// - - - -

TelegramClient::TelegramClient() { createInstance(); }

TelegramClient::~TelegramClient() {
    if (polling_thread_) {
        polling_thread_->requestInterruption();
        polling_thread_->wait();
    }
}

void TelegramClient::createInstance() {
    td::ClientManager::execute(td_api::make_object<td_api::setLogVerbosityLevel>(LOG_LEVEL));

    client_manager_ = std::make_unique<td::ClientManager>();
    client_id_ = client_manager_->create_client_id();

    send(request_builder_->getVersion());
}

template <std::derived_from<td_api::Object> T, typename... Fs>
void dispatch(td_api::object_ptr<T>& obj, Fs&&... handlers) {
    td_api::downcast_call(*obj, detail::overloaded(std::forward<Fs>(handlers)..., [](auto&) {}));
}

void TelegramClient::process_update(td_api::object_ptr<td_api::Object> update) {
    dispatch(update, [this](td_api::updateAuthorizationState& update_authorization_state) {
        td_api::downcast_call(*update_authorization_state.authorization_state_, detail::overloaded(
            [this](td_api::authorizationStateWaitTdlibParameters&) {
                qDebug() << "[AUTH] WaitTdlibParameters";
                send(request_builder_->setTdLibParameters());
            },
            [this](td_api::authorizationStateWaitPhoneNumber&) {
                qDebug() << "[AUTH] WaitPhoneNumber";
                emit phoneNumberRequired();
            },
            [this](td_api::authorizationStateWaitCode&) {
                qDebug() << "[AUTH] WaitCode";
                emit authCodeRequired();
            },
            [](td_api::authorizationStateWaitRegistration&) {
                qWarning() << "[AUTH] WaitRegistration — account has no name yet; "
                              "app does not handle this state. "
                              "Register via an official Telegram client first, then retry.";
            },
            [](td_api::authorizationStateWaitPassword& s) {
                qWarning() << "[AUTH] WaitPassword — 2FA required. "
                              "App does not handle this state yet. Hint:"
                              << QString::fromStdString(s.password_hint_);
            },
            [](td_api::authorizationStateWaitEmailAddress&) {
                qWarning() << "[AUTH] WaitEmailAddress — app does not handle this state.";
            },
            [](td_api::authorizationStateWaitEmailCode&) {
                qWarning() << "[AUTH] WaitEmailCode — app does not handle this state.";
            },
            [](td_api::authorizationStateLoggingOut&) {
                qDebug() << "[AUTH] LoggingOut";
            },
            [](td_api::authorizationStateClosing&) {
                qDebug() << "[AUTH] Closing";
            },
            [](td_api::authorizationStateClosed&) {
                qDebug() << "[AUTH] Closed";
            },
            [this](td_api::authorizationStateReady&) {
                qDebug() << "[AUTH] Ready";
                is_authorized_ = true;
                send(request_builder_->getMe(), [this](ResponsePtr response) {
                    auto raw = td::td_api::move_object_as<td_api::user>(response);

                    qDebug() << raw->first_name_ << " " << raw->last_name_;

                    me_ = std::shared_ptr<td_api::user>(raw.release());

                    emit userLoaded(me_);
                });
            },
            [](auto& other) {
                qWarning() << "[AUTH] Unhandled auth state:"
                           << QString::fromStdString(td_api::to_string(other));
            }
        ));
    });
}

void TelegramClient::pollForUpdates() {
    while (!QThread::currentThread()->isInterruptionRequested()) {
        td::ClientManager::Response response = client_manager_->receive(RECEIVE_TIMEOUT);

        if (!response.object) { continue; }

        if (isUnsolicitedUpdate(response)) {
            process_update(std::move(response.object));
        } else {
            qDebug() << "Response for request" << response.request_id << ":" << td_api::to_string(response.object);

            auto match = response_handlers_.find(response.request_id);

            if (match != response_handlers_.end()) {
                match->second(std::move(response.object));
                response_handlers_.erase(match);
            }
        }
    }
}

void TelegramClient::startPolling() {
    polling_thread_.reset(QThread::create([this]() { pollForUpdates(); }));

    polling_thread_->start();
};

bool TelegramClient::isUnsolicitedUpdate(const td::ClientManager::Response& response) const {
    return response.request_id == 0;
}

RequestId TelegramClient::update_request_id() { return ++current_request_id_; }

bool TelegramClient::IsAuthorized() const { return is_authorized_; }

void TelegramClient::phoneNumberReceived(const QString& phone_number) {
    send(request_builder_->setPhoneNumber(phone_number.toStdString()));
}

void TelegramClient::authCodeReceived(const QString& code) {
    send(request_builder_->checkAuthCode(code.toStdString()));
}
