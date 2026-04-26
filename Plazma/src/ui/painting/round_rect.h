#pragma once

#include "src/ui/painting/painter.h"
#include "src/ui/style/style_core.h"

#include <QRect>

namespace Ui {

// RoundRect — paints an antialiased filled rectangle with rounded corners.
// In tdesktop this caches per-corner pixmaps for cheap repaints; here we
// just use QPainter's built-in roundedRect path (good enough at 60fps for
// our small surfaces) and skip the cache.
class RoundRect {
public:
    RoundRect(int radius, const style::color &color)
    : _radius(radius), _color(color) {}

    void paint(QPainter &p, const QRect &rect) const {
        PainterHighQualityEnabler hq(p);
        p.setPen(Qt::NoPen);
        p.setBrush(_color.brush());
        p.drawRoundedRect(rect, _radius, _radius);
    }

    void paint(QPainter &p, const QRectF &rect) const {
        PainterHighQualityEnabler hq(p);
        p.setPen(Qt::NoPen);
        p.setBrush(_color.brush());
        p.drawRoundedRect(rect, _radius, _radius);
    }

    void setRadius(int radius) { _radius = radius; }
    [[nodiscard]] int radius() const { return _radius; }

private:
    int _radius;
    style::color _color;
};

} // namespace Ui
