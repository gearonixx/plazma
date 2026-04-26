#pragma once

#include "src/ui/effects/animations.h"
#include "src/ui/effects/ripple_animation.h"
#include "src/ui/style/style_widgets.h"
#include "src/ui/widgets/abstract_button.h"

#include <memory>

namespace Ui {

// RippleButton — abstract intermediate that wires a ripple animation onto
// any AbstractButton subclass. Concrete buttons specialize the mask shape.
class RippleButton : public AbstractButton {
    Q_OBJECT

public:
    RippleButton(QWidget *parent, const style::RippleAnimation &st);
    ~RippleButton() override;

protected:
    void onStateChanged(State was, StateChangeSource source) override;

    void paintRipple(QPainter &p, int x, int y, const QColor *override = nullptr);

    [[nodiscard]] virtual QImage prepareRippleMask() const = 0;

private:
    void ensureRipple();

    const style::RippleAnimation &_st;
    std::unique_ptr<RippleAnimation> _ripple;
};

// RoundButton — primary action button with rounded corners + tween between
// idle/over background colors + a ripple from the press point.
class RoundButton : public RippleButton {
    Q_OBJECT

public:
    RoundButton(QWidget *parent, QString text, const style::RoundButton &st);

    void setText(QString text);
    void setFullWidth(int width);

    [[nodiscard]] const style::RoundButton &st() const { return _st; }

protected:
    void paintEvent(QPaintEvent *e) override;
    int  resizeGetHeight(int newWidth) override;

    QImage prepareRippleMask() const override;

private:
    void resizeToText();

    const style::RoundButton &_st;
    QString _text;
    int _textWidth = 0;
    int _fullWidthOverride = 0;
};

// IconButton — square chrome around a single glyph (emoji or icon font).
// On hover the icon color tweens; on press it ripples.
class IconButton : public RippleButton {
    Q_OBJECT

public:
    IconButton(QWidget *parent, const style::IconButton &st);

    void setIconText(QString text);

    [[nodiscard]] const style::IconButton &st() const { return _st; }

protected:
    void paintEvent(QPaintEvent *e) override;
    void onStateChanged(State was, StateChangeSource source) override;

    QImage prepareRippleMask() const override;

private:
    const style::IconButton &_st;
    QString _iconText;

    Animations::Simple _overAnimation;
};

// LinkButton — inline tappable text. No background, hover only changes text
// color. No ripple.
class LinkButton : public AbstractButton {
    Q_OBJECT

public:
    LinkButton(QWidget *parent, QString text, const style::LinkButton &st);

    void setText(QString text);

protected:
    void paintEvent(QPaintEvent *e) override;
    int  resizeGetHeight(int newWidth) override;

private:
    void resizeToText();

    const style::LinkButton &_st;
    QString _text;
    int _textWidth = 0;
};

} // namespace Ui
