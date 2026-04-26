#pragma once

#include "src/ui/widgets/rp_widget.h"

#include <QPointer>
#include <QStackedWidget>

namespace Ui {

// MainWindow — top-level shell. Holds a QStackedWidget that swaps between
// "section" widgets (login, feed, player, etc.). The shell paints the
// canvas color and hands input to the active section.
class MainWindow : public RpWidget {
    Q_OBJECT

public:
    explicit MainWindow(QWidget *parent = nullptr);

    // Show a top-level section. Ownership transfers to the stacked widget.
    void showSection(QWidget *section);
    [[nodiscard]] QWidget *currentSection() const;

protected:
    void paintEvent(QPaintEvent *e) override;
    void resizeEvent(QResizeEvent *e) override;

private:
    QStackedWidget *_stack = nullptr;
};

} // namespace Ui
