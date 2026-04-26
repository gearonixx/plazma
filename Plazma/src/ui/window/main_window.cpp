#include "src/ui/window/main_window.h"

#include "src/ui/painting/painter.h"
#include "src/ui/style/style_palette.h"

#include <QPaintEvent>
#include <QResizeEvent>
#include <QVBoxLayout>

namespace Ui {

MainWindow::MainWindow(QWidget *parent) : RpWidget(parent) {
    auto *layout = new QVBoxLayout(this);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(0);

    _stack = new QStackedWidget(this);
    layout->addWidget(_stack);

    // Match the QML default window size so dock-style placement isn't
    // surprising for users coming from the old build.
    resize(780, 540);
    setMinimumSize(780, 540);
    setWindowTitle(QStringLiteral("Plazma"));

    // Force palette background — without this, Qt's default palette for
    // QWidget bleeds through where children don't fully cover the canvas.
    QPalette pal = palette();
    pal.setColor(QPalette::Window, *style::palette().windowBg);
    setPalette(pal);
    setAutoFillBackground(true);
}

void MainWindow::showSection(QWidget *section) {
    if (!section) return;
    if (_stack->indexOf(section) < 0) {
        _stack->addWidget(section);
    }
    _stack->setCurrentWidget(section);
}

QWidget *MainWindow::currentSection() const {
    return _stack ? _stack->currentWidget() : nullptr;
}

void MainWindow::paintEvent(QPaintEvent *) {
    Painter p(this);
    p.fillRect(rect(), style::palette().windowBg);
}

void MainWindow::resizeEvent(QResizeEvent *e) {
    RpWidget::resizeEvent(e);
}

} // namespace Ui
