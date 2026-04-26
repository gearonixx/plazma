import QtQuick
import Td 1.0

// TdCheckbox — port of `Ui::Checkbox`
// (lib_ui/ui/widgets/checkbox.h). Animated check with optional label
// to the right.

Item {
    id: root

    property string text: ""
    property bool   checked: false
    property bool   enabledState: true

    signal toggled(bool checked)

    implicitHeight: Math.max(TdStyle.metrics.checkSize, 20)
    implicitWidth: box.width + (label.text ? label.implicitWidth + TdStyle.metrics.checkSpacing : 0)

    Rectangle {
        id: box
        width: TdStyle.metrics.checkSize
        height: width
        radius: TdStyle.metrics.checkRadius
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        color: root.checked ? TdPalette.c.checkboxFgActive : 'transparent'
        border.color: !root.enabledState ? TdPalette.c.checkboxFgDisabled
                    : root.checked      ? TdPalette.c.checkboxFgActive
                                        : TdPalette.c.checkboxFg
        border.width: TdStyle.metrics.checkBorderWidth
        Behavior on color { ColorAnimation { duration: TdStyle.duration.universal } }
        Behavior on border.color { ColorAnimation { duration: TdStyle.duration.universal } }

        // Check glyph drawn from two rotated rectangles forming a tick.
        Item {
            anchors.fill: parent
            opacity: root.checked ? 1 : 0
            scale: root.checked ? 1 : 0.6
            Behavior on opacity { NumberAnimation { duration: TdStyle.duration.universal } }
            Behavior on scale   { NumberAnimation { duration: TdStyle.duration.universal; easing.type: Easing.OutBack } }

            Rectangle {
                x: box.width * 0.18; y: box.height * 0.50
                width: box.width * 0.30; height: 2
                color: TdPalette.c.checkboxCheckFg
                radius: 1
                rotation: 45
                transformOrigin: Item.Left
            }
            Rectangle {
                x: box.width * 0.40; y: box.height * 0.65
                width: box.width * 0.45; height: 2
                color: TdPalette.c.checkboxCheckFg
                radius: 1
                rotation: -45
                transformOrigin: Item.Left
            }
        }
    }

    Text {
        id: label
        text: root.text
        anchors.left: box.right
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
