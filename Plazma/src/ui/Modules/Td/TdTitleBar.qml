import QtQuick
import Td 1.0

// TdTitleBar — visual port of `Ui::Platform::TitleWidget`
// (lib_ui/ui/platform/ui_platform_window_title.h). Renders a custom
// frameless title bar with title text + min/max/close buttons. Window
// chrome integration (drag/move) is left to the host ApplicationWindow.

Item {
    id: root

    property string title: ""
    property bool   active: true
    property bool   minimizeEnabled: true
    property bool   maximizeEnabled: true
    property bool   closeEnabled: true

    signal minimizeClicked()
    signal maximizeClicked()
    signal closeClicked()

    implicitHeight: TdStyle.metrics.titleBarHeight
    implicitWidth: 600

    Rectangle {
        anchors.fill: parent
        color: root.active ? TdPalette.c.titleBgActive : TdPalette.c.titleBg

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: root.active ? TdPalette.c.titleFgActive : TdPalette.c.titleFg
            font.family: TdStyle.font.family
            font.pixelSize: TdStyle.font.fsize
            font.weight: TdStyle.font.weightMedium
            renderType: Text.NativeRendering
        }
    }

    Row {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: 0

        TdIconButton {
            visible: root.minimizeEnabled
            width: TdStyle.metrics.titleBarButtonWidth
            height: parent.height
            radius: 0
            onClicked: root.minimizeClicked()
            Item {
                anchors.centerIn: parent
                width: 12; height: 12
                Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1.2; color: TdPalette.c.titleFgActive }
            }
        }
        TdIconButton {
            visible: root.maximizeEnabled
            width: TdStyle.metrics.titleBarButtonWidth
            height: parent.height
            radius: 0
            onClicked: root.maximizeClicked()
            Rectangle {
                anchors.centerIn: parent
                width: 10; height: 10
                color: 'transparent'
                border.color: TdPalette.c.titleFgActive
                border.width: 1.2
            }
        }
        Item {
            visible: root.closeEnabled
            width: TdStyle.metrics.titleBarButtonWidth
            height: parent.height

            Rectangle {
                id: closeBg
                anchors.fill: parent
                color: closeArea.containsMouse ? TdPalette.c.titleButtonCloseBgOver : 'transparent'
                Behavior on color { ColorAnimation { duration: TdStyle.duration.universal } }
            }

            Item {
                anchors.centerIn: parent
                width: 10; height: 10
                Rectangle {
                    anchors.centerIn: parent; width: parent.width; height: 1.3; rotation: 45
                    color: closeArea.containsMouse ? TdPalette.c.titleButtonCloseFgOver : TdPalette.c.titleFgActive
                }
                Rectangle {
                    anchors.centerIn: parent; width: parent.width; height: 1.3; rotation: -45
                    color: closeArea.containsMouse ? TdPalette.c.titleButtonCloseFgOver : TdPalette.c.titleFgActive
                }
            }
            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeClicked()
            }
        }
    }

    // Bottom hairline shadow
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: TdStyle.metrics.lineWidth
        color: TdPalette.c.dividerFg
    }
}
