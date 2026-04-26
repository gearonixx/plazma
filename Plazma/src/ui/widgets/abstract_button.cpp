#include "src/ui/widgets/abstract_button.h"

#include <QEnterEvent>
#include <QKeyEvent>
#include <QMouseEvent>
#include <QSinglePointEvent>

namespace Ui {

AbstractButton::AbstractButton(QWidget *parent) : RpWidget(parent) {
    setMouseTracking(true);
    setFocusPolicy(Qt::StrongFocus);
    setAttribute(Qt::WA_OpaquePaintEvent, false);
}

void AbstractButton::setDisabled(bool disabled) {
    auto was = _state;
    if (disabled) _state |= StateFlag::Disabled;
    else _state &= ~State(StateFlag::Disabled);
    if (_state != was) {
        updateCursor();
        update();
        onStateChanged(was, StateChangeSource::ByUser);
    }
}

void AbstractButton::setPointerCursor(bool enable) {
    _pointerCursorEnabled = enable;
    updateCursor();
}

void AbstractButton::clicked(Qt::KeyboardModifiers modifiers, Qt::MouseButton button) {
    if (isDisabled()) return;
    _modifiers = modifiers;
    if (_clickedCallback) _clickedCallback();
    emit clickedSignal(button);
}

void AbstractButton::setOver(bool over, StateChangeSource source) {
    auto was = _state;
    if (over) _state |= StateFlag::Over;
    else _state &= ~State(StateFlag::Over);
    if (_state != was) {
        updateCursor();
        update();
        onStateChanged(was, source);
    }
}

bool AbstractButton::setDown(bool down,
                             StateChangeSource source,
                             Qt::KeyboardModifiers modifiers,
                             Qt::MouseButton button) {
    auto was = _state;
    if (down) _state |= StateFlag::Down;
    else _state &= ~State(StateFlag::Down);
    if (_state == was) return false;

    update();
    onStateChanged(was, source);

    // Mouse-up over a pressed button == click. Match tdesktop semantics:
    // the click fires when transitioning OUT of Down while still Over.
    if (was.testFlag(StateFlag::Down) && !down && isOver() && !isDisabled()) {
        clicked(modifiers, button);
    }
    return true;
}

void AbstractButton::enterEvent(QEnterEvent *e) {
    setOver(true, StateChangeSource::ByHover);
    RpWidget::enterEvent(e);
}

void AbstractButton::leaveEvent(QEvent *e) {
    setOver(false, StateChangeSource::ByHover);
    RpWidget::leaveEvent(e);
}

void AbstractButton::mousePressEvent(QMouseEvent *e) {
    if (e->button() == Qt::LeftButton) {
        checkIfOver(e->position().toPoint());
        setDown(true, StateChangeSource::ByPress, e->modifiers(), e->button());
    }
}

void AbstractButton::mouseReleaseEvent(QMouseEvent *e) {
    if (e->button() == Qt::LeftButton) {
        checkIfOver(e->position().toPoint());
        setDown(false, StateChangeSource::ByPress, e->modifiers(), e->button());
    }
}

void AbstractButton::mouseMoveEvent(QMouseEvent *e) {
    checkIfOver(e->position().toPoint());
}

void AbstractButton::keyPressEvent(QKeyEvent *e) {
    if (e->key() == Qt::Key_Return
        || e->key() == Qt::Key_Enter
        || e->key() == Qt::Key_Space) {
        clicked(e->modifiers(), Qt::LeftButton);
        e->accept();
        return;
    }
    RpWidget::keyPressEvent(e);
}

void AbstractButton::checkIfOver(QPoint localPos) {
    setOver(rect().contains(localPos), StateChangeSource::ByHover);
}

void AbstractButton::updateCursor() {
    const bool wantPointer = _pointerCursorEnabled && isOver() && !isDisabled();
    if (wantPointer == _pointerCursorActive) return;
    _pointerCursorActive = wantPointer;
    setCursor(wantPointer ? Qt::PointingHandCursor : Qt::ArrowCursor);
}

} // namespace Ui
