#include "src/ui/effects/ripple_animation.h"

#include <QDateTime>
#include <QPainter>

#include <algorithm>
#include <cmath>

namespace Ui {

namespace {

constexpr int kRippleExpandMs = 280;
constexpr int kRippleFadeMs   = 220;

} // namespace

RippleAnimation::RippleAnimation(
    const style::RippleAnimation &st,
    QImage mask,
    Fn<void()> updateCallback)
: _st(st)
, _mask(std::move(mask))
, _update(std::move(updateCallback)) {
}

qint64 RippleAnimation::now() const {
    return QDateTime::currentMSecsSinceEpoch();
}

qreal RippleAnimation::expandRadius(QSize size) const {
    // Cover the entire mask from the press point — pythagoras of the
    // half-diagonal does the trick.
    const auto w = qreal(size.width());
    const auto h = qreal(size.height());
    return std::sqrt(w * w + h * h);
}

void RippleAnimation::add(QPoint origin) {
    _ripples.push_back({ origin, now() });
    if (_update) _update();
}

void RippleAnimation::lastStop() {
    if (_ripples.empty()) return;
    auto &r = _ripples.back();
    if (r.stopped) return;
    r.stoppingAt = now();
    r.stopped = true;
}

void RippleAnimation::clearCache() {
    _ripples.clear();
}

bool RippleAnimation::empty() const {
    return _ripples.empty();
}

void RippleAnimation::paint(
    QPainter &p,
    int x,
    int y,
    int /*outerWidth*/,
    const QColor *colorOverride) {

    if (_ripples.empty() || _mask.isNull()) return;

    const auto color = colorOverride ? *colorOverride : *_st.rippleColor;
    const auto t = now();
    const auto maxRadius = expandRadius(_mask.size());

    // Composite each ripple into a buffer, then blit through the mask so
    // ripples that spill past the button's rounded corners are clipped.
    QImage layer(_mask.size(), QImage::Format_ARGB32_Premultiplied);
    layer.fill(Qt::transparent);

    {
        QPainter lp(&layer);
        lp.setRenderHint(QPainter::Antialiasing);
        lp.setPen(Qt::NoPen);

        for (auto &ripple : _ripples) {
            const auto elapsed = qreal(t - ripple.startedAt);
            const auto expandT = std::clamp(elapsed / kRippleExpandMs, 0.0, 1.0);
            // ease out cubic
            const auto eased = 1.0 - std::pow(1.0 - expandT, 3.0);
            const auto radius = eased * maxRadius;

            qreal alpha = 1.0;
            if (ripple.stopped) {
                const auto fadeElapsed = qreal(t - ripple.stoppingAt);
                alpha = std::clamp(1.0 - (fadeElapsed / kRippleFadeMs), 0.0, 1.0);
            }

            QColor tint = color;
            tint.setAlphaF(tint.alphaF() * alpha);
            lp.setBrush(tint);
            lp.drawEllipse(QPointF(ripple.origin), radius, radius);
        }
    }

    // Mask out: anywhere the button shape isn't, kill the ripple pixels.
    {
        QPainter mp(&layer);
        mp.setCompositionMode(QPainter::CompositionMode_DestinationIn);
        mp.drawImage(0, 0, _mask);
    }

    p.drawImage(x, y, layer);

    // Drop fully-faded ripples.
    _ripples.erase(
        std::remove_if(_ripples.begin(), _ripples.end(),
            [&](const Ripple &r) {
                if (!r.stopped) return false;
                return (t - r.stoppingAt) >= kRippleFadeMs;
            }),
        _ripples.end());

    // Schedule a repaint if any ripple is still alive.
    if (!_ripples.empty() && _update) {
        _update();
    }
}

QImage RippleAnimation::maskByDrawer(QSize size, bool filled,
                                     const Fn<void(QPainter&)> &drawer) {
    QImage mask(size, QImage::Format_ARGB32_Premultiplied);
    mask.fill(Qt::transparent);
    QPainter p(&mask);
    p.setRenderHint(QPainter::Antialiasing);
    p.setPen(Qt::NoPen);
    if (filled) {
        p.setBrush(Qt::white);
        p.drawRect(QRect(QPoint(), size));
    }
    if (drawer) drawer(p);
    return mask;
}

QImage RippleAnimation::rectMask(QSize size) {
    return maskByDrawer(size, true, nullptr);
}

QImage RippleAnimation::roundRectMask(QSize size, int radius) {
    return maskByDrawer(size, false, [&](QPainter &p) {
        p.setBrush(Qt::white);
        p.drawRoundedRect(QRect(QPoint(), size), radius, radius);
    });
}

QImage RippleAnimation::ellipseMask(QSize size) {
    return maskByDrawer(size, false, [&](QPainter &p) {
        p.setBrush(Qt::white);
        p.drawEllipse(QRect(QPoint(), size));
    });
}

} // namespace Ui
