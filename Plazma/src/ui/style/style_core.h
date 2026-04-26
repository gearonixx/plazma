#pragma once

#include <QBrush>
#include <QColor>
#include <QFont>
#include <QFontMetrics>
#include <QMargins>
#include <QPen>
#include <QPoint>
#include <QSize>
#include <QString>

#include <functional>

namespace style {

// Color wrapper. Holds a QColor by value but is referred to by const-ref so
// future palette swaps (theming) can mutate the underlying value in-place.
class color {
public:
    color() = default;
    explicit color(QColor c) : _value(c) {}
    color(const QString &hex) : _value(hex) {}
    color(int r, int g, int b, int a = 255) : _value(r, g, b, a) {}

    [[nodiscard]] const QColor &operator*() const { return _value; }
    [[nodiscard]] const QColor *operator->() const { return &_value; }

    [[nodiscard]] QBrush brush() const { return QBrush(_value); }
    [[nodiscard]] QPen pen() const { return QPen(_value); }
    [[nodiscard]] operator QColor() const { return _value; }

    void set(const QColor &c) { _value = c; }

private:
    QColor _value;
};

// Font wrapper. Holds a QFont and exposes metrics.
class font {
public:
    font() = default;
    font(int sizePx, int weight = QFont::Normal, const QString &family = QString())
    : _font(family.isEmpty() ? QFont() : QFont(family)) {
        _font.setPixelSize(sizePx);
        _font.setWeight(QFont::Weight(weight));
        _metrics = QFontMetrics(_font);
    }

    [[nodiscard]] const QFont &operator*() const { return _font; }
    [[nodiscard]] operator QFont() const { return _font; }

    [[nodiscard]] int height() const { return _metrics.height(); }
    [[nodiscard]] int ascent() const { return _metrics.ascent(); }
    [[nodiscard]] int width(const QString &text) const {
        return _metrics.horizontalAdvance(text);
    }
    [[nodiscard]] QString elided(const QString &text, int width,
                                 Qt::TextElideMode mode = Qt::ElideRight) const {
        return _metrics.elidedText(text, mode, width);
    }

private:
    QFont _font;
    QFontMetrics _metrics{ _font };
};

// Margin / point / size aliases — match tdesktop spelling so usage reads alike.
using margins = QMargins;
using point   = QPoint;
using size    = QSize;

enum class align {
    left   = 0x01,
    right  = 0x02,
    center = 0x04,
    top    = 0x08,
    bottom = 0x10,
};

[[nodiscard]] inline bool RightToLeft() { return false; }
[[nodiscard]] inline QRect rtlrect(int x, int y, int w, int h, int) { return { x, y, w, h }; }
[[nodiscard]] inline QRect rtlrect(QRect r, int) { return r; }
[[nodiscard]] inline QPoint rtlpoint(int x, int y, int) { return { x, y }; }
[[nodiscard]] inline QPoint rtlpoint(QPoint p, int) { return p; }

} // namespace style

// Convenience global alias mirroring tdesktop, where every callable bag of
// widget data is `Fn<...>`.
template <typename T>
using Fn = std::function<T>;
