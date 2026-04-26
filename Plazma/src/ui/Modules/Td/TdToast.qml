import QtQuick
import Td 1.0

// TdToast — single transient toast view. Used by TdNotifications;
// usually you don't instantiate this directly. Mirrors the look of
// `Ui::Toast::Manager` (lib_ui/ui/toast/toast_manager.cpp).

Item {
    id: root

    property string text: ""
    property int    duration: TdStyle.duration.toast
    property int    state_: 0   // 0 = info, 1 = success, 2 = error

    signal closed()

    width: parent ? Math.min(parent.width - 32, TdStyle.metrics.toastMaxWidth) : TdStyle.metrics.toastMaxWidth
    height: TdStyle.metrics.toastHeight
    opacity: 0
    z: TdStyle.z.toast

    readonly property color _bg: state_ === 1 ? TdPalette.c.successFg
                              : state_ === 2 ? TdPalette.c.errorFg
                                              : TdPalette.c.tooltipBg
    readonly property color _fg: state_ === 0 ? TdPalette.c.tooltipFg : 'white'

    TdShadow {
        anchors.fill: bg
        cornerRadius: TdStyle.metrics.toastRadius
        extend: TdStyle.metrics.shadowDepthMedium
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: TdStyle.metrics.toastRadius
        color: root._bg
        border.color: TdPalette.c.tooltipBorderFg
        border.width: root.state_ === 0 ? 1 : 0

        Text {
            anchors.fill: parent
            anchors.margins: TdStyle.metrics.toastPadding
            text: root.text
            color: root._fg
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            font.family: TdStyle.font.family
            font.pixelSize: TdStyle.font.fsize + 1
            renderType: Text.NativeRendering
        }
    }

    SequentialAnimation on opacity {
        id: lifecycle
        running: false
        NumberAnimation { from: 0; to: 1; duration: TdStyle.duration.fadeWrap }
        PauseAnimation  { duration: root.duration }
        NumberAnimation { from: 1; to: 0; duration: TdStyle.duration.fadeWrap }
        ScriptAction { script: root.closed() }
    }

    Component.onCompleted: lifecycle.running = true
}
