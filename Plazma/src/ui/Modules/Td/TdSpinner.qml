import QtQuick
import Td 1.0

// TdSpinner — port of `Ui::InfiniteRadialAnimation` and the simpler
// loading spinners in tdesktop. An arc that revolves and grows.

Item {
    id: root

    property color color: TdPalette.c.activeButtonBg
    property int   thickness: TdStyle.metrics.progressRadialLine
    property int   size: TdStyle.metrics.progressRadialSize
    property bool  running: true

    implicitWidth:  size
    implicitHeight: size

    Canvas {
        id: arc
        anchors.fill: parent
        antialiasing: true

        property real rot: 0
        property real arcLen: Math.PI * 0.7

        onPaint: {
            const ctx = getContext('2d');
            ctx.reset();
            const cx = width / 2;
            const cy = height / 2;
            const r = (Math.min(width, height) - root.thickness) / 2;
            ctx.lineWidth = root.thickness;
            ctx.lineCap = 'round';
            ctx.strokeStyle = root.color;
            ctx.beginPath();
            ctx.arc(cx, cy, r, rot, rot + arcLen);
            ctx.stroke();
        }
    }

    NumberAnimation {
        id: spin
        target: arc
        property: "rot"
        from: 0
        to: 2 * Math.PI
        duration: TdStyle.duration.spinnerCycle
        loops: Animation.Infinite
        running: root.running
        onRunningChanged: if (!running) arc.rot = 0
    }

    Timer {
        interval: 16
        repeat: true
        running: root.running
        onTriggered: arc.requestPaint()
    }
}
