#include "src/ui/widgets/buttons.h"

#include "src/ui/painting/painter.h"

#include <QPaintEvent>
#include <QPainterPath>
#include <QPointer>

namespace Ui {

namespace {

constexpr int kHoverDurationMs = 160;

} // namespace

// ─────────────────────────── RippleButton ────────────────────────────────

RippleButton::RippleButton(QWidget *parent, const style::RippleAnimation &st)
: AbstractButton(parent)
, _st(st) {
}

RippleButton::~RippleButton() = default;

void RippleButton::ensureRipple() {
    if (_ripple) return;
    _ripple = std::make_unique<RippleAnimation>(
        _st,
        prepareRippleMask(),
        [weak = QPointer<RippleButton>(this)] {
            if (weak) weak->update();
        });
}

void RippleButton::onStateChanged(State was, StateChangeSource source) {
    AbstractButton::onStateChanged(was, source);

    const bool wasDown = was.testFlag(StateFlag::Down);
    const bool nowDown = isDown();
    if (wasDown == nowDown) return;

    ensureRipple();
    if (nowDown) {
        // Origin: center of the widget. We'd normally use the press point,
        // but mousePressEvent doesn't pass it through to onStateChanged.
        // Centered ripples still look good and match tdesktop's icon
        // buttons (which also default to center).
        _ripple->add(QPoint(width() / 2, height() / 2));
    } else {
        _ripple->lastStop();
    }
}

void RippleButton::paintRipple(QPainter &p, int x, int y, const QColor *override) {
    if (_ripple && !_ripple->empty()) {
        _ripple->paint(p, x, y, width(), override);
    }
}

// ─────────────────────────── RoundButton ─────────────────────────────────

RoundButton::RoundButton(
    QWidget *parent,
    QString text,
    const style::RoundButton &st)
: RippleButton(parent, st.ripple)
, _st(st)
, _text(std::move(text)) {
    setPointerCursor(true);
    resizeToText();
}

void RoundButton::setText(QString text) {
    _text = std::move(text);
    resizeToText();
    update();
}

void RoundButton::setFullWidth(int width) {
    _fullWidthOverride = width;
    resizeToText();
}

void RoundButton::resizeToText() {
    _textWidth = _st.textFont.width(_text);
    const auto width = _fullWidthOverride > 0
        ? _fullWidthOverride
        : (_textWidth + _st.padding.left() + _st.padding.right());
    resize(width, _st.height);
}

int RoundButton::resizeGetHeight(int /*newWidth*/) {
    return _st.height;
}

QImage RoundButton::prepareRippleMask() const {
    const auto radius = _st.radius < 0 ? height() / 2 : _st.radius;
    return RippleAnimation::roundRectMask(size(), radius);
}

void RoundButton::paintEvent(QPaintEvent *) {
    Painter p(this);
    PainterHighQualityEnabler hq(p);

    const auto over = isOver();
    const auto disabled = isDisabled();

    // Background — round-rect filled with the active or idle color.
    const auto &bg = (over && !disabled) ? _st.textBgOver : _st.textBg;
    const auto radius = _st.radius < 0 ? height() / 2 : _st.radius;
    p.setPen(Qt::NoPen);
    p.setBrush(bg.brush());
    p.drawRoundedRect(rect(), radius, radius);

    // Ripple goes on top of the background but under the text.
    paintRipple(p, 0, 0);

    // Foreground text.
    const auto &fg = (over && !disabled) ? _st.textFgOver : _st.textFg;
    if (disabled) {
        p.setOpacity(0.5);
    }
    p.setPen(fg.pen());
    p.setFont(*_st.textFont);
    const auto textRect = rect().marginsRemoved(_st.padding)
        .adjusted(0, _st.textTop, 0, _st.textTop);
    p.drawText(textRect,
               Qt::AlignCenter | Qt::TextSingleLine,
               _text);
}

// ─────────────────────────── IconButton ──────────────────────────────────

IconButton::IconButton(QWidget *parent, const style::IconButton &st)
: RippleButton(parent, st.ripple)
, _st(st)
, _iconText(st.iconText) {
    resize(_st.width, _st.height);
    setPointerCursor(true);
}

void IconButton::setIconText(QString text) {
    _iconText = std::move(text);
    update();
}

QImage IconButton::prepareRippleMask() const {
    return RippleAnimation::ellipseMask(size());
}

void IconButton::onStateChanged(State was, StateChangeSource source) {
    RippleButton::onStateChanged(was, source);

    const bool wasOver = was.testFlag(StateFlag::Over);
    if (wasOver != isOver()) {
        _overAnimation.start(
            [weak = QPointer<IconButton>(this)] {
                if (weak) weak->update();
            },
            wasOver ? 1.0 : 0.0,
            wasOver ? 0.0 : 1.0,
            kHoverDurationMs);
    }
}

void IconButton::paintEvent(QPaintEvent *) {
    Painter p(this);
    PainterHighQualityEnabler hq(p);

    // Hover halo — soft circle under the icon, faded in by _overAnimation.
    const auto overT = _overAnimation.value(isOver() ? 1.0 : 0.0);
    if (overT > 0.0) {
        QColor halo = *style::palette().tintedBg;
        halo.setAlphaF(halo.alphaF() * overT);
        p.setPen(Qt::NoPen);
        p.setBrush(halo);
        p.drawEllipse(rect());
    }

    paintRipple(p, 0, 0);

    // Icon — interpolate color from idle → hover.
    QColor c = *_st.iconColor;
    if (overT > 0.0) {
        const auto &target = *_st.iconColorOver;
        c = QColor::fromRgbF(
            c.redF()   + (target.redF()   - c.redF())   * overT,
            c.greenF() + (target.greenF() - c.greenF()) * overT,
            c.blueF()  + (target.blueF()  - c.blueF())  * overT,
            c.alphaF() + (target.alphaF() - c.alphaF()) * overT);
    }
    p.setPen(c);
    p.setFont(*_st.iconFont);
    p.drawText(rect(), Qt::AlignCenter, _iconText);
}

// ─────────────────────────── LinkButton ──────────────────────────────────

LinkButton::LinkButton(
    QWidget *parent,
    QString text,
    const style::LinkButton &st)
: AbstractButton(parent)
, _st(st)
, _text(std::move(text)) {
    setPointerCursor(true);
    resizeToText();
}

void LinkButton::setText(QString text) {
    _text = std::move(text);
    resizeToText();
    update();
}

void LinkButton::resizeToText() {
    _textWidth = _st.textFont.width(_text);
    resize(_textWidth + _st.padding.left() + _st.padding.right(),
           _st.textFont.height() + _st.padding.top() + _st.padding.bottom());
}

int LinkButton::resizeGetHeight(int /*newWidth*/) {
    return _st.textFont.height() + _st.padding.top() + _st.padding.bottom();
}

void LinkButton::paintEvent(QPaintEvent *) {
    Painter p(this);
    const auto &fg = isOver() ? _st.textFgOver : _st.textFg;
    p.setPen(fg.pen());
    p.setFont(*_st.textFont);
    p.drawText(rect().marginsRemoved(_st.padding),
               Qt::AlignLeft | Qt::AlignVCenter,
               _text);
}

} // namespace Ui
