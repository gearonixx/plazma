import QtQuick
import Td 1.0

// TdProgressBar — linear progress bar matching tdesktop's
// `Ui::FilledSlider` / progress filling style. Determinate when
// `indeterminate = false`, sweeping animation otherwise.

Item {
    id: root

    enum State { Normal, Success, Error }

    property real value: 0.0          // 0..1
    property bool indeterminate: false
    property int  state_: TdProgressBar.Normal
    property int  thickness: TdStyle.metrics.progressHeight

    implicitHeight: thickness
    implicitWidth: 200

    readonly property color _fg: state_ === TdProgressBar.Success ? TdPalette.c.progressFgSuccess
                               : state_ === TdProgressBar.Error   ? TdPalette.c.progressFgError
                                                                  : TdPalette.c.progressFg

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: TdPalette.c.progressBg
    }

    Rectangle {
        id: fill
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        radius: height / 2
        color: root._fg
        width: root.indeterminate ? indWidth : Math.max(0, Math.min(1, root.value)) * parent.width
        Behavior on width { enabled: !root.indeterminate; NumberAnimation { duration: TdStyle.duration.universal } }

        property real indWidth: parent.width * 0.35
        SequentialAnimation on x {
            running: root.indeterminate
            loops: Animation.Infinite
            NumberAnimation { from: -fill.indWidth; to: root.width; duration: 1300; easing.type: Easing.InOutQuad }
        }
    }
}
