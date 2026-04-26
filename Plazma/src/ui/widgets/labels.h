#pragma once

#include "src/ui/style/style_widgets.h"
#include "src/ui/widgets/rp_widget.h"

#include <QString>

#include <optional>

namespace Ui {

// FlatLabel — single-or-multi-line text widget. Resizing by width re-flows
// the text and reports the natural height. Mirrors tdesktop's FlatLabel
// API surface (setText, resizeToWidth, textHeightFor) but stops short of
// the full rich text engine — we just use Qt's QStaticText for now.
class FlatLabel : public RpWidget {
    Q_OBJECT

public:
    FlatLabel(QWidget *parent,
              QString text,
              const style::FlatLabel &st = style::st::defaultFlatLabel());

    void setText(QString text);
    [[nodiscard]] const QString &text() const { return _text; }

    void setTextColorOverride(std::optional<QColor> color);

    int  resizeGetHeight(int newWidth) override;

protected:
    void paintEvent(QPaintEvent *e) override;

private:
    [[nodiscard]] int textHeightFor(int width) const;
    [[nodiscard]] Qt::Alignment qtAlign() const;

    const style::FlatLabel &_st;
    QString _text;
    std::optional<QColor> _textColorOverride;
};

} // namespace Ui
