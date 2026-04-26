#pragma once

#include "src/ui/style/style_core.h"

#include <QWidget>

namespace Ui {

// RpWidget — "reactive paintable widget", a stripped-down adaptation of
// tdesktop's `Ui::RpWidget`. The original is built on the rpl reactive
// library; we use plain Qt signals here to stay dependency-free, but the
// API spirit is the same:
//
//   1. Subclass and override paintEvent for custom drawing.
//   2. Resize via resizeToWidth(int) — owners size by width and let the
//      widget compute its natural height.
//   3. Use sizeChanged()/resized() signals to wire up responsive layouts.
//
// The class is deliberately thin so widgets can also derive from QFrame /
// QScrollArea / etc. by inheriting from those directly when needed.
class RpWidget : public QWidget {
    Q_OBJECT

public:
    explicit RpWidget(QWidget *parent = nullptr);
    ~RpWidget() override = default;

    // Resize the widget so its computed natural height matches `newWidth`.
    void resizeToWidth(int newWidth);

    // Returns the natural (unconstrained) height the widget would prefer at
    // the given width. Default just preserves current height; override for
    // a real layout.
    virtual int resizeGetHeight(int /*newWidth*/) { return height(); }

    // Margins this widget reserves around itself (for shadows etc.).
    [[nodiscard]] virtual QMargins getMargins() const { return _margins; }
    void setMargins(QMargins m) { _margins = m; updateGeometry(); }

    [[nodiscard]] QRect rectNoMargins() const {
        return rect().marginsRemoved(getMargins());
    }
    [[nodiscard]] int widthNoMargins() const { return rectNoMargins().width(); }
    [[nodiscard]] int heightNoMargins() const { return rectNoMargins().height(); }

signals:
    void sizeChanged(QSize newSize);
    void resized();
    void shownChanged(bool shown);

protected:
    void resizeEvent(QResizeEvent *event) override;
    void showEvent(QShowEvent *event) override;
    void hideEvent(QHideEvent *event) override;

private:
    QMargins _margins;
};

} // namespace Ui
