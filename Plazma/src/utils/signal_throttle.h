#pragma once

#include <QObject>
#include <QTimer>
#include <functional>

// SignalThrottle
// ──────────────
// Coalesces a high-frequency stream of "something changed, please refresh"
// pings into at most one emission per `intervalMs`. The first ping fires
// immediately so the UI feels responsive on the leading edge; subsequent
// pings within the window are folded into a single trailing emission once
// the timer expires.
//
// Used by DownloadsModel to keep readyRead() callbacks (which can fire
// dozens of times per second on a fast connection) from saturating QML
// property bindings on the latest* scalars. The model still emits
// dataChanged() on the row directly — that's the authoritative bytes-on-disk
// signal — but the chrome (download bar, percentage label) only needs ~60
// Hz to look smooth.
class SignalThrottle : public QObject {
    Q_OBJECT
public:
    explicit SignalThrottle(int intervalMs, QObject* parent, std::function<void()> sink)
        : QObject(parent), sink_(std::move(sink)), intervalMs_(intervalMs) {
        timer_.setSingleShot(true);
        QObject::connect(&timer_, &QTimer::timeout, this, [this] {
            // Trailing emission — fire only if at least one request landed
            // during the cooldown, then re-arm the window so the *next*
            // leading-edge emission waits its turn too. If nothing came in,
            // the throttle goes quiet until the next request.
            if (!pending_) return;
            pending_ = false;
            if (sink_) sink_();
            timer_.start(intervalMs_);
        });
    }

    // Request that the sink be fired soon. Coalesces multiple calls within
    // a single window into one emission. The first call after a quiet
    // period fires immediately (leading edge); subsequent calls within the
    // window are folded into a single trailing emission at window-close.
    void request() {
        if (timer_.isActive()) {
            pending_ = true;
            return;
        }
        if (sink_) sink_();
        pending_ = false;
        timer_.start(intervalMs_);
    }

    // Cancel any pending trailing emission. Used when the underlying object
    // becomes irrelevant (e.g., the entry the throttle was tracking was
    // removed) so we don't fire on stale state.
    void cancel() {
        pending_ = false;
        timer_.stop();
    }

    // Force the trailing emission immediately, regardless of cooldown. Used
    // at terminal transitions (Completed / Failed) so the final state isn't
    // hidden behind the throttle window.
    void flush() {
        timer_.stop();
        pending_ = false;
        if (sink_) sink_();
    }

private:
    std::function<void()> sink_;
    QTimer timer_;
    int intervalMs_;
    bool pending_ = false;
};
