#pragma once

#include "src/ui/style/style_core.h"

#include <QPainter>

namespace Ui {

// Painter — a thin QPainter subclass that adds a few tdesktop-style helpers.
// In tdesktop, this exists primarily so paint code can read like
// `p.setBrush(st::myColor)` directly with a `style::color`.
class Painter : public QPainter {
public:
    using QPainter::QPainter;

    void setPenColor(const style::color &c) { setPen(c.pen()); }
    void setBrushColor(const style::color &c) { setBrush(c.brush()); }
    void fillRect(const QRect &r, const style::color &c) {
        QPainter::fillRect(r, *c);
    }
    void fillRect(const QRectF &r, const style::color &c) {
        QPainter::fillRect(r, *c);
    }

    // Convenience: enable best-quality antialiased painting in one call.
    void setSmoothTransform() {
        setRenderHint(QPainter::Antialiasing, true);
        setRenderHint(QPainter::SmoothPixmapTransform, true);
        setRenderHint(QPainter::TextAntialiasing, true);
    }
};

// PainterHighQualityEnabler — RAII helper that flips on antialiasing for the
// duration of a painting block, restoring the previous flags on destruction.
class PainterHighQualityEnabler {
public:
    explicit PainterHighQualityEnabler(QPainter &p)
    : _p(p), _hints(p.renderHints()) {
        _p.setRenderHints(QPainter::Antialiasing
            | QPainter::SmoothPixmapTransform
            | QPainter::TextAntialiasing);
    }
    ~PainterHighQualityEnabler() {
        _p.setRenderHints(_hints);
    }

private:
    QPainter &_p;
    QPainter::RenderHints _hints;
};

} // namespace Ui
