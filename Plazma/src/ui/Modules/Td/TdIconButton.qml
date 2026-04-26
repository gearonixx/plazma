import QtQuick
import Td 1.0

// TdIconButton — port of `Ui::IconButton` (lib_ui/ui/widgets/buttons.h).
// Square hover-tinted button with an icon (image source) at its center.

Item {
    id: root

    property url    iconSource: ""
    property string text: ""           // optional tooltip text (unused for now)
    property color  iconColor: TdPalette.c.menuIconFg
    property color  iconColorOver: TdPalette.c.menuIconFgOver
    property int    iconSize: 20
    property real   radius: TdStyle.metrics.iconButtonRadius
    property bool   enabledState: true
    property bool   active: false      // toggled-on state

    signal clicked()

    implicitWidth:  TdStyle.metrics.iconButtonSize
    implicitHeight: TdStyle.metrics.iconButtonSize

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: button.hovered ? TdPalette.c.windowBgOver
                              : (root.active ? TdPalette.c.windowBgOver : 'transparent')
        Behavior on color { ColorAnimation { duration: TdStyle.duration.universal } }
    }

    TdAbstractButton {
        id: button
        anchors.fill: parent
        rippleColor: TdPalette.c.windowBgRipple
        enabledState: root.enabledState
        onClicked: root.clicked()

        Image {
            anchors.centerIn: parent
            source: root.iconSource
            sourceSize.width: root.iconSize
            sourceSize.height: root.iconSize
            width: root.iconSize
            height: root.iconSize
            opacity: root.enabledState ? 1.0 : 0.4
            visible: root.iconSource !== ""
        }
    }
}
