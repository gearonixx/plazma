import QtQuick
import Td 1.0

// TdMenuSeparator — port of `Ui::Menu::Separator`. 1px hairline with
// menu padding above/below.

Item {
    width: parent ? parent.width : 0
    height: TdStyle.metrics.menuSeparatorHeight

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: TdStyle.metrics.menuItemPadding
        anchors.rightMargin: TdStyle.metrics.menuItemPadding
        height: TdStyle.metrics.lineWidth
        color: TdPalette.c.menuSeparatorFg
    }
}
