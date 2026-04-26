import QtQuick
import Td 1.0

// TdTab — single tab item used inside TdTabBar.

Item {
    id: root

    property string text: ""
    property bool   active: false

    signal clicked()

    implicitHeight: TdStyle.metrics.tabHeight
    implicitWidth: label.implicitWidth + TdStyle.metrics.tabPadding * 2

    TdAbstractButton {
        anchors.fill: parent
        rippleColor: TdPalette.c.windowBgRipple
        onClicked: root.clicked()

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: root.active ? TdPalette.c.activeButtonBg : TdPalette.c.windowSubTextFg
            font.family: TdStyle.font.family
            font.pixelSize: TdStyle.font.fsize + 1
            font.weight: root.active ? TdStyle.font.weightSemibold : TdStyle.font.weightNormal
            renderType: Text.NativeRendering
            Behavior on color { ColorAnimation { duration: TdStyle.duration.universal } }
        }
    }
}
