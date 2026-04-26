import QtQuick
import Td 1.0

// TdRadioButton — port of `Ui::RadioButton`. Supports a string `group`
// so radios with the same group auto-deselect siblings inside the same
// parent.

Item {
    id: root

    property string text: ""
    property bool   checked: false
    property bool   enabledState: true
    property string group: ""

    signal toggled(bool checked)

    implicitHeight: Math.max(TdStyle.metrics.radioSize, 20)
    implicitWidth: ring.width + (label.text ? label.implicitWidth + TdStyle.metrics.checkSpacing : 0)

    Rectangle {
        id: ring
        width: TdStyle.metrics.radioSize
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        color: root.checked ? TdPalette.c.radioBgOver : TdPalette.c.radioBg
        border.color: !root.enabledState ? TdPalette.c.checkboxFgDisabled
                    : root.checked      ? TdPalette.c.radioBorderActive
                                        : TdPalette.c.radioBorder
        border.width: TdStyle.metrics.radioBorderWidth

        Rectangle {
            anchors.centerIn: parent
            width: TdStyle.metrics.radioInnerSize
            height: width
            radius: width / 2
            color: TdPalette.c.radioFg
            opacity: root.checked ? 1 : 0
            scale: root.checked ? 1 : 0.4
            Behavior on opacity { NumberAnimation { duration: TdStyle.duration.universal } }
            Behavior on scale   { NumberAnimation { duration: TdStyle.duration.universal; easing.type: Easing.OutBack } }
        }
    }

    Text {
        id: label
        text: root.text
        anchors.left: ring.right
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
            if (root.group !== "" && root.parent) {
                for (let i = 0; i < root.parent.children.length; ++i) {
                    const sib = root.parent.children[i];
                    if (sib !== root && sib.group === root.group && sib.checked !== undefined) {
                        sib.checked = false;
                    }
                }
            }
            root.checked = true;
            root.toggled(true);
        }
    }
}
