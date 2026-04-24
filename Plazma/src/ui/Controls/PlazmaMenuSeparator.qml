import QtQuick

import Style 1.0

// Thin divider line between groups of menu items — matches tdesktop's
// defaultMenuSeparator (1px on the windowBgRipple color, with an 8px
// top/bottom buffer so the line doesn't crowd neighbouring text).
Item {
    implicitHeight: 9
    implicitWidth: 100

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        height: 1
        color: PlazmaStyle.color.inputBorder
    }
}
