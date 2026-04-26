#pragma once

#include "src/ui/style/style_core.h"

#include <QObject>
#include <QVariantAnimation>

namespace Ui::Animations {

// type — controls whether a state change snaps instantly or tweens.
enum class type {
    instant = 0,
    normal  = 1,
};

// Simple — a one-shot tween from a start value to an end value, paired with
// a per-frame callback. Mirrors tdesktop's `Animations::Simple` API:
//   _anim.start([this] { update(); }, 0., 1., 200, anim::easeOutCubic);
class Simple {
public:
    Simple() = default;
    Simple(const Simple &) = delete;
    Simple &operator=(const Simple &) = delete;
    ~Simple() { stop(); }

    using EasingHook = QEasingCurve::Type;

    void start(
            Fn<void()> callback,
            qreal from,
            qreal to,
            int duration,
            EasingHook easing = QEasingCurve::OutCubic) {
        stop();
        _from = from;
        _to = to;
        _current = from;
        _callback = std::move(callback);
        _animation = new QVariantAnimation();
        _animation->setStartValue(from);
        _animation->setEndValue(to);
        _animation->setDuration(duration);
        _animation->setEasingCurve(easing);
        QObject::connect(_animation, &QVariantAnimation::valueChanged,
                         [this](const QVariant &v) {
            _current = v.toReal();
            if (_callback) _callback();
        });
        QObject::connect(_animation, &QVariantAnimation::finished,
                         [this] {
            _current = _to;
            if (_callback) _callback();
        });
        _animation->start(QAbstractAnimation::DeleteWhenStopped);
    }

    void stop() {
        if (_animation) {
            QObject::disconnect(_animation, nullptr, nullptr, nullptr);
            _animation->stop();
            _animation = nullptr;
        }
    }

    [[nodiscard]] qreal value(qreal fallback) const {
        return _animation ? _current : fallback;
    }
    [[nodiscard]] qreal value() const { return _current; }
    [[nodiscard]] bool animating() const { return _animation != nullptr; }

private:
    QVariantAnimation *_animation = nullptr;
    qreal _from = 0.0;
    qreal _to = 0.0;
    qreal _current = 0.0;
    Fn<void()> _callback;
};

} // namespace Ui::Animations
