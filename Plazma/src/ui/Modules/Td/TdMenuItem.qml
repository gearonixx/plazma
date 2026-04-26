import QtQuick
import Td 1.0

// TdMenuItem — port of `Ui::Menu::Action`
// (lib_ui/ui/widgets/menu/menu_action.h). Icon + label + optional
// shortcut / value / submenu. `checkable` toggles a leading checkmark
// instead of an icon. `hasSubmenu` shows a trailing chevron.

Item {
    id: root

    property string text: ""
    property string shortcut: ""
    property string trailingValue: ""
    property url    iconSource
    property bool   destructive: false
    property bool   enabledState: true
    property bool   checkable: false
    property bool   checked: false
    property bool   hasSubmenu: false

    signal triggered()

    implicitHeight: TdStyle.metrics.menuItemHeight
    implicitWidth: Math.max(TdStyle.metrics.menuMinWidth,
                            row.implicitWidth + TdStyle.metrics.menuItemPadding * 2)

    Rectangle {
        anchors.fill: parent
        color: button.hovered ? TdPalette.c.menuBgOver : 'transparent'
        Behavior on color { ColorAnimation { duration: TdStyle.duration.universal } }
    }

    TdAbstractButton {
        id: button
        anchors.fill: parent
        rippleColor: TdPalette.c.menuBgRipple
        enabledState: root.enabledState
        onClicked: {
            if (root.checkable) root.checked = !root.checked;
            root.triggered();
        }

        Row {
            id: row
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: TdStyle.metrics.menuItemPadding
            anchors.rightMargin: TdStyle.metrics.menuItemPadding
            spacing: 10

            // Leading slot: check mark, icon, or empty space for alignment
            Item {
                width: 18; height: 18
                anchors.verticalCenter: parent.verticalCenter

                // Check
                Item {
                    anchors.fill: parent
                    visible: root.checkable
                    opacity: root.checked ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: TdStyle.duration.universal } }
                    Rectangle {
                        x: parent.width * 0.18; y: parent.height * 0.50
                        width: parent.width * 0.30; height: 2
                        color: TdPalette.c.checkboxFgActive
                        radius: 1
                        rotation: 45
                        transformOrigin: Item.Left
                    }
                    Rectangle {
                        x: parent.width * 0.40; y: parent.height * 0.65
                        width: parent.width * 0.45; height: 2
                        color: TdPalette.c.checkboxFgActive
                        radius: 1
                        rotation: -45
                        transformOrigin: Item.Left
                    }
                }
                // Icon
                TdIcon {
                    anchors.fill: parent
                    visible: !root.checkable && root.iconSource != ""
                    source: root.iconSource
                    color: button.hovered ? TdPalette.c.menuIconFgOver : TdPalette.c.menuIconFg
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                color: !root.enabledState ? TdPalette.c.menuFgDisabled
                     : root.destructive   ? TdPalette.c.attentionButtonFg
                                          : TdPalette.c.windowFg
                font.family: TdStyle.font.family
                font.pixelSize: TdStyle.font.fsize + 1
                renderType: Text.NativeRendering
                width: row.width - 28 - rightAccessoryRow.implicitWidth - 10
                elide: Text.ElideRight
            }
        }

        Row {
            id: rightAccessoryRow
            anchors.right: parent.right
            anchors.rightMargin: TdStyle.metrics.menuItemPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.shortcut !== "" || root.trailingValue !== ""
                text: root.trailingValue !== "" ? root.trailingValue : root.shortcut
                color: TdPalette.c.windowSubTextFg
                font.family: TdStyle.font.family
                font.pixelSize: TdStyle.font.fsize - 1
                renderType: Text.NativeRendering
            }
            Item {
                visible: root.hasSubmenu
                anchors.verticalCenter: parent.verticalCenter
                width: 8; height: 12
                Rectangle {
                    x: 1; y: 2
                    width: 6; height: 1.4; rotation: 45; radius: 0.7
                    color: TdPalette.c.windowSubTextFg
                }
                Rectangle {
                    x: 1; y: 8
                    width: 6; height: 1.4; rotation: -45; radius: 0.7
                    color: TdPalette.c.windowSubTextFg
                }
            }
        }
    }
}
