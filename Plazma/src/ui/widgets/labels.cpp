#include "src/ui/widgets/labels.h"

#include "src/ui/painting/painter.h"

#include <QPaintEvent>
#include <QTextOption>

namespace Ui {

FlatLabel::FlatLabel(QWidget *parent, QString text, const style::FlatLabel &st)
: RpWidget(parent)
, _st(st)
, _text(std::move(text)) {
    resize(_st.textFont.width(_text) + _st.padding.left() + _st.padding.right(),
           _st.textFont.height()     + _st.padding.top()  + _st.padding.bottom());
}

void FlatLabel::setText(QString text) {
    _text = std::move(text);
    resizeToWidth(width() ? width() : _st.textFont.width(_text));
    update();
}

void FlatLabel::setTextColorOverride(std::optional<QColor> color) {
    _textColorOverride = color;
    update();
}

Qt::Alignment FlatLabel::qtAlign() const {
    // Already a Qt::Alignment in our descriptor — just pass through.
    return _st.align;
}

int FlatLabel::textHeightFor(int width) const {
    if (width <= 0) {
        return _st.textFont.height();
    }
    const auto innerWidth =
        std::max(width - _st.padding.left() - _st.padding.right(), 1);

    // Use QFontMetrics::boundingRect to wrap and measure.
    QFontMetrics m(*_st.textFont);
    QRect r = m.boundingRect(
        QRect(0, 0, innerWidth, 1 << 20),
        Qt::TextWordWrap | int(qtAlign()),
        _text);
    int h = r.height();
    if (_st.lineHeight > 0) {
        const auto lines = std::max(1, h / m.height());
        h = lines * _st.lineHeight;
    }
    return h + _st.padding.top() + _st.padding.bottom();
}

int FlatLabel::resizeGetHeight(int newWidth) {
    return textHeightFor(newWidth);
}

void FlatLabel::paintEvent(QPaintEvent *) {
    Painter p(this);
    p.setFont(*_st.textFont);
    QColor textColor = _textColorOverride.value_or(*_st.textFg);
    p.setPen(textColor);

    QTextOption opt;
    opt.setAlignment(qtAlign());
    opt.setWrapMode(QTextOption::WordWrap);

    p.drawText(rect().marginsRemoved(_st.padding), _text, opt);
}

} // namespace Ui
