#pragma once

#include "src/ui/widgets/rp_widget.h"

#include <QFlags>
#include <QtGlobal>

namespace Ui {

// AbstractButton — owns the over/down/disabled state machine plus a
// click-callback registration system. Concrete buttons subclass this and
// override paintEvent + onStateChanged to render their look.
class AbstractButton : public RpWidget {
    Q_OBJECT

public:
    enum class StateFlag {
        None     = 0,
        Over     = 0x01,
        Down     = 0x02,
        Disabled = 0x04,
    };
    Q_DECLARE_FLAGS(State, StateFlag)

    enum class StateChangeSource {
        ByUser  = 0x00,
        ByPress = 0x01,
        ByHover = 0x02,
    };

    explicit AbstractButton(QWidget *parent);
    ~AbstractButton() override = default;

    [[nodiscard]] bool isOver() const { return _state.testFlag(StateFlag::Over); }
    [[nodiscard]] bool isDown() const { return _state.testFlag(StateFlag::Down); }
    [[nodiscard]] bool isDisabled() const { return _state.testFlag(StateFlag::Disabled); }

    void setDisabled(bool disabled = true);
    void setPointerCursor(bool enable);

    void setClickedCallback(Fn<void()> callback) {
        _clickedCallback = std::move(callback);
    }

    // Programmatically trigger a click (also fires the clicked signal).
    void clicked(Qt::KeyboardModifiers modifiers, Qt::MouseButton button);

signals:
    void clickedSignal(Qt::MouseButton button);

protected:
    [[nodiscard]] State state() const { return _state; }

    void setOver(bool over, StateChangeSource source = StateChangeSource::ByUser);
    bool setDown(bool down,
                 StateChangeSource source,
                 Qt::KeyboardModifiers modifiers,
                 Qt::MouseButton button);

    // Override hooks — invoked any time the state changes.
    virtual void onStateChanged(State /*was*/, StateChangeSource /*source*/) {}

    void enterEvent(QEnterEvent *e) override;
    void leaveEvent(QEvent *e) override;
    void mousePressEvent(QMouseEvent *e) override;
    void mouseReleaseEvent(QMouseEvent *e) override;
    void mouseMoveEvent(QMouseEvent *e) override;
    void keyPressEvent(QKeyEvent *e) override;

private:
    void updateCursor();
    void checkIfOver(QPoint localPos);

    State _state{ StateFlag::None };
    Qt::KeyboardModifiers _modifiers{};
    bool _pointerCursorEnabled = true;
    bool _pointerCursorActive  = false;

    Fn<void()> _clickedCallback;
};

} // namespace Ui
