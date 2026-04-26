import QtQuick
import Td 1.0

// TdToggle — port of `Ui::Toggle` (lib_ui/ui/widgets/checkbox.h:Toggle).
// Sliding switch with optional right-side label.

Item {
    id: root

    property string text: ""
    property bool   checked: false
    property bool   enabledState: true

    signal toggled(bool checked)

    implicitHeight: Math.max(TdStyle.metrics.toggleHeight, 20)
    implicitWidth: track.width + (label.text ? label.implicitWidth + TdStyle.metrics.checkSpacing : 0)

    Rectangle {
        id: track
        width: TdStyle.metrics.toggleWidth
        height: TdStyle.metrics.toggleHeight
        radius: height / 2
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        color: root.checked ? TdPalette.c.toggleBgActive : TdPalette.c.toggleBg
        opacity: root.enabledState ? 1.0 : 0.55
        Behavior on color { ColorAnimation { duration: TdStyle.duration.universal } }

        Rectangle {
            id: handle
            width: TdStyle.metrics.toggleHandleSize
            height: width
            radius: width / 2
            color: TdPalette.c.toggleHandle
            border.color: TdPalette.c.toggleHandleShadow
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked
               ? track.width - width - TdStyle.metrics.togglePadding
               : TdStyle.metrics.togglePadding
            Behavior on x { NumberAnimation { duration: TdStyle.duration.universal; easing.type: TdStyle.easing.standard } }
        }
    }

    Text {
        id: label
        text: root.text
        anchors.left: track.right
        anchors.leftMargin: TdStyle.metrics.checkSpacing
        anchors.verticalCenter: parent.verticalCenter
        color: root.enabledState ? TdPalette.c.windowFg : TdPalette.c.menuFgDisabled
        font.family: TdStyle.font.family
        font.pixelSize: TdStyle.font.fsize + 1
        renderType: Text.NativeRendering
        visible: text !== ""
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabledState
        cursorShape: root.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            root.checked = !root.checked;
            root.toggled(root.checked);
        }
    }
}
