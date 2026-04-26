import QtQuick

// TdRipple — pointer-driven ink ripple analogue of
// `Ui::RippleAnimation` from lib_ui/ui/effects/ripple_animation.cpp.
//
// Drop into the contentItem you want rippled. Call `start(x, y)` from a
// MouseArea press and `release()` on release; the overlay handles its
// own fade-out animation.

Item {
    id: root
    anchors.fill: parent
    clip: true

    property color rippleColor: '#33000000'

    function start(px, py) {
        ripple.cx = px;
        ripple.cy = py;
        ripple.opacity = 1.0;
        ripple.scale = 0.0;
        const w = root.width, h = root.height;
        const dx = Math.max(px, w - px);
        const dy = Math.max(py, h - py);
        ripple.targetSize = 2 * Math.sqrt(dx * dx + dy * dy);
        ripple.scale = 1.0;
    }

    function release() {
        fade.start();
    }

    Rectangle {
        id: ripple
        property real cx: 0
        property real cy: 0
        property real targetSize: 0
        width: targetSize
        height: targetSize
        radius: targetSize / 2
        x: cx - width / 2
        y: cy - height / 2
        scale: 0
        opacity: 0
        color: root.rippleColor

        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
    }

    NumberAnimation {
        id: fade
        target: ripple
        property: "opacity"
        from: ripple.opacity
        to: 0
        duration: 250
        easing.type: Easing.OutCubic
    }
}
