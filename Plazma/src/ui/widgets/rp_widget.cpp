#include "src/ui/widgets/rp_widget.h"

#include <QHideEvent>
#include <QResizeEvent>
#include <QShowEvent>

namespace Ui {

RpWidget::RpWidget(QWidget *parent) : QWidget(parent) {
    // Mirror tdesktop's RpWidget zero-geometry initialization — start with
    // a 0×0 box so layouts don't see a stale parent-default size before
    // the first explicit resize.
    setGeometry(0, 0, 0, 0);
}

void RpWidget::resizeToWidth(int newWidth) {
    const auto m = getMargins();
    const auto fullWidth = m.left() + newWidth + m.right();
    const auto fullHeight = m.top() + resizeGetHeight(newWidth) + m.bottom();
    if (size() != QSize(fullWidth, fullHeight)) {
        resize(fullWidth, fullHeight);
        update();
    }
}

void RpWidget::resizeEvent(QResizeEvent *event) {
    QWidget::resizeEvent(event);
    emit sizeChanged(event->size());
    emit resized();
}

void RpWidget::showEvent(QShowEvent *event) {
    QWidget::showEvent(event);
    emit shownChanged(true);
}

void RpWidget::hideEvent(QHideEvent *event) {
    QWidget::hideEvent(event);
    emit shownChanged(false);
}

} // namespace Ui
