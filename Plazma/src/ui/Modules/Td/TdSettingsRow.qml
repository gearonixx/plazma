import QtQuick
import Td 1.0

// TdSettingsRow — port of `Settings::Button` and the rows in the
// settings panes (SourceFiles/settings/settings_*.cpp). Icon + title +
// optional subtitle on the left, optional trailing widget on the right
// (chevron, toggle, value text). Hover ripple matches dialogsBgOver.

Item {
    id: root

    property url    iconSource
    property color  iconColor: TdPalette.c.menuIconFg
    property string title: ""
    property string subtitle: ""
    property string value: ""
    property bool   chevron: false
    property bool   destructive: false
    property bool   enabledState: true

    default property alias trailing: trailingHolder.data

    signal clicked()

    implicitHeight: subtitle !== "" ? TdStyle.metrics.rowHeight + 8 : TdStyle.metrics.rowHeight
    implicitWidth: 320

    TdAbstractButton {
        anchors.fill: parent
        rippleColor: TdPalette.c.dialogsRippleBg
        enabledState: root.enabledState
        onClicked: root.clicked()

        Rectangle {
            anchors.fill: parent
            color: parent.hovered ? TdPalette.c.dialogsBgOver : 'transparent'
            Behavior on color { ColorAnimation { duration: TdStyle.duration.universal } }
        }

        Item {
            id: iconHolder
            width: root.iconSource != "" ? TdStyle.metrics.rowIconSize + TdStyle.metrics.rowIconSpacing : 0
            height: parent.height
            anchors.left: parent.left
            anchors.leftMargin: TdStyle.metrics.rowPadding
            TdIcon {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                source: root.iconSource
                color: root.destructive ? TdPalette.c.attentionButtonFg : root.iconColor
                size: TdStyle.metrics.rowIconSize
                visible: root.iconSource != ""
            }
        }

        Column {
            anchors.left: iconHolder.right
            anchors.right: trailingHolder.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 8
            spacing: 2

            Text {
                text: root.title
                color: !root.enabledState ? TdPalette.c.menuFgDisabled
                    : root.destructive ? TdPalette.c.attentionButtonFg
                                       : TdPalette.c.windowFg
                font.family: TdStyle.font.family
                font.pixelSize: TdStyle.font.fsize + 1
                font.weight: TdStyle.font.weightMedium
                renderType: Text.NativeRendering
                width: parent.width
                elide: Text.ElideRight
            }
            Text {
                visible: root.subtitle !== ""
                text: root.subtitle
                color: TdPalette.c.windowSubTextFg
                font.family: TdStyle.font.family
                font.pixelSize: TdStyle.font.fsize
                renderType: Text.NativeRendering
                width: parent.width
                elide: Text.ElideRight
            }
        }

        Item {
            id: trailingHolder
            anchors.right: parent.right
            anchors.rightMargin: TdStyle.metrics.rowPadding
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: parent.height
        }

        // Default trailing: value text + chevron
        Row {
            visible: trailingHolder.children.length === 0
            anchors.right: parent.right
            anchors.rightMargin: TdStyle.metrics.rowPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Text {
                visible: root.value !== ""
                text: root.value
                color: TdPalette.c.windowSubTextFg
                font.family: TdStyle.font.family
                font.pixelSize: TdStyle.font.fsize
                renderType: Text.NativeRendering
                anchors.verticalCenter: parent.verticalCenter
            }
            Item {
                visible: root.chevron
                width: TdStyle.metrics.rowChevronSize
                height: width
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    width: 6; height: 1.5; rotation: 45; radius: 1
                    color: TdPalette.c.windowSubTextFg
                    x: parent.width / 2 - 3; y: parent.height / 2 - 3
                }
                Rectangle {
                    width: 6; height: 1.5; rotation: -45; radius: 1
                    color: TdPalette.c.windowSubTextFg
                    x: parent.width / 2 - 3; y: parent.height / 2 + 1.5
                }
            }
        }
    }

    // Bottom divider (1px, indented to align with title)
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: TdStyle.metrics.rowPadding + (root.iconSource != "" ? TdStyle.metrics.rowIconSize + TdStyle.metrics.rowIconSpacing : 0)
        height: TdStyle.metrics.lineWidth
        color: TdPalette.c.dividerFg
    }
}
