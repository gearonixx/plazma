import QtQuick
import Td 1.0

// TdAbstractButton — analogue of `Ui::AbstractButton`
// (lib_ui/ui/abstract_button.h). All Td-styled buttons inherit its
// hover/press/disabled state machine plus an integrated ripple and
// keyboard activation.

Item {
    id: root

    signal clicked()
    signal pressed()
    signal released()

    property bool hovered: mouseArea.containsMouse
    property bool pressed_: mouseArea.pressed
    property bool enabledState: true
    property bool keyboardFocused: activeFocus
    property color rippleColor: '#33000000'
    property bool ripplesEnabled: true
    property bool focusRingEnabled: true

    default property alias content: contentHolder.data

    activeFocusOnTab: true

    Keys.onPressed: function (e) {
        if (!enabledState) return;
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
            root.pressed();
            ripple.start(width / 2, height / 2);
            e.accepted = true;
        }
    }
    Keys.onReleased: function (e) {
        if (!enabledState) return;
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
            ripple.release();
            root.released();
            root.clicked();
            e.accepted = true;
        }
    }

    Item {
        id: contentHolder
        anchors.fill: parent
    }

    TdRipple {
        id: ripple
        anchors.fill: parent
        rippleColor: root.rippleColor
        visible: root.ripplesEnabled
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.enabledState
        cursorShape: root.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
        hoverEnabled: true
        onPressed: function (mouse) {
            if (root.ripplesEnabled) ripple.start(mouse.x, mouse.y);
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.pressed();
        }
        onReleased: {
            if (root.ripplesEnabled) ripple.release();
            root.released();
        }
        onClicked: root.clicked()
    }

    // Keyboard focus ring — only visible when activated by Tab, not click.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -TdStyle.metrics.focusRingInset
        color: 'transparent'
        radius: TdStyle.metrics.buttonRadius + TdStyle.metrics.focusRingInset
        border.color: TdPalette.c.focusRingFg
        border.width: TdStyle.metrics.focusRingWidth
        visible: root.focusRingEnabled
                 && root.activeFocus
                 && root.focusReason !== Qt.MouseFocusReason
        opacity: 0.7
    }
}
