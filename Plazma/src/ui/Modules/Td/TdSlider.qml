import QtQuick
import Td 1.0

// TdSlider — port of `Ui::DiscreteSlider` / `Ui::ContinuousSlider`
// (lib_ui/ui/widgets/continuous_sliders.h). Drag a circular handle along
// a horizontal track.

Item {
    id: root

    property real min: 0
    property real max: 1
    property real value: 0
    property bool snap: false
    property int  steps: 10

    signal moved(real v)

    implicitHeight: TdStyle.metrics.sliderHeight
    implicitWidth: 200

    readonly property real _t: (max <= min) ? 0 : (value - min) / (max - min)

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: TdStyle.metrics.sliderTrackHeight
        radius: height / 2
        color: TdPalette.c.sliderBgInactive
    }

    Rectangle {
        anchors.left: track.left
        anchors.verticalCenter: track.verticalCenter
        height: track.height
        radius: track.radius
        width: track.width * root._t
        color: TdPalette.c.sliderBgActive
    }

    Rectangle {
        id: handle
        width: TdStyle.metrics.sliderHandleSize
        height: TdStyle.metrics.sliderHandleSize
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: track.x + track.width * root._t - width / 2
        color: TdPalette.c.sliderHandle
        border.color: TdPalette.c.sliderBgActive
        border.width: 2

        scale: drag.pressed ? 1.18 : (hover.hovered ? 1.08 : 1.0)
        Behavior on scale { NumberAnimation { duration: TdStyle.duration.universal } }
        HoverHandler { id: hover }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        hoverEnabled: false
        onPressed: function (m) { _set(m.x) }
        onPositionChanged: function (m) { if (drag.pressed) _set(m.x) }

        function _set(px) {
            const tx = Math.max(0, Math.min(track.width, px - track.x));
            let t = tx / track.width;
            if (root.snap && root.steps > 0) {
                t = Math.round(t * root.steps) / root.steps;
            }
            const newValue = root.min + (root.max - root.min) * t;
            if (Math.abs(newValue - root.value) > 1e-6) {
                root.value = newValue;
                root.moved(newValue);
            }
        }
    }
}
