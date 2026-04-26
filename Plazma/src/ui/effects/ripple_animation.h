#pragma once

#include "src/ui/style/style_core.h"
#include "src/ui/style/style_widgets.h"

#include <QImage>
#include <QPainter>
#include <QPoint>
#include <QSize>

#include <vector>

namespace Ui {

// RippleAnimation — a Material-style expanding circle with optional fade-out.
// Modeled on tdesktop's `Ui::RippleAnimation`. We keep it simple: each ripple
// is a center point + a start time. Active ripples are advanced when paint()
// is called and dropped when fully transparent.
class RippleAnimation {
public:
    RippleAnimation(
        const style::RippleAnimation &st,
        QImage mask,
        Fn<void()> updateCallback);

    // Begin a new ripple at the given local coordinate.
    void add(QPoint origin);
    // Begin to fade out the most recent ripple.
    void lastStop();
    // Cancel everything.
    void clearCache();
    // Are there any visible ripples right now?
    [[nodiscard]] bool empty() const;

    // Paint all live ripples clipped to the mask, at (x, y) inside the
    // painter target. `colorOverride` lets a hovered button switch tints.
    void paint(QPainter &p, int x, int y, int outerWidth,
               const QColor *colorOverride = nullptr);

    // Default mask helpers — these are what most call-sites want.
    [[nodiscard]] static QImage maskByDrawer(QSize size,
                                             bool filled,
                                             const Fn<void(QPainter&)> &drawer);
    [[nodiscard]] static QImage rectMask(QSize size);
    [[nodiscard]] static QImage roundRectMask(QSize size, int radius);
    [[nodiscard]] static QImage ellipseMask(QSize size);

private:
    struct Ripple {
        QPoint origin;
        qint64 startedAt;
        qint64 stoppingAt = 0;     // 0 == still expanding
        bool   stopped = false;
    };

    [[nodiscard]] qint64 now() const;
    [[nodiscard]] qreal expandRadius(QSize) const;

    const style::RippleAnimation &_st;
    QImage _mask;                  // alpha channel: 1 inside the button shape
    Fn<void()> _update;
    std::vector<Ripple> _ripples;
};

} // namespace Ui
