import QtQuick
import Td 1.0

// TdNavigationDrawer — port of `Window::SidebarManager` shell layout
// from tdesktop. Three-stack: optional narrow icon rail on the far
// left, the dialogs/sidebar list, and a content area filling the rest.
// Slots:
//   - rail        : children parented into the icon rail (TdIconButton, TdAvatar…)
//   - sidebar     : children parented into the wider list column
//   - content     : children filling the right-hand pane

Item {
    id: root

    property int  railWidth: 64
    property int  sidebarWidth: 320
    property bool railVisible: true

    default property alias content: contentHolder.data
    property alias rail: railHolder.data
    property alias sidebar: sidebarHolder.data

    Rectangle {
        anchors.fill: parent
        color: TdPalette.c.windowBg
    }

    Item {
        id: railHolder
        width: root.railVisible ? root.railWidth : 0
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        Rectangle {
            anchors.fill: parent
            color: TdPalette.c.sideBarBg
            visible: root.railVisible
        }
    }

    Item {
        id: sidebarHolder
        width: root.sidebarWidth
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: railHolder.right
        Rectangle {
            anchors.fill: parent
            color: TdPalette.c.dialogsBg
        }
    }

    Rectangle {
        anchors.left: sidebarHolder.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: TdStyle.metrics.lineWidth
        color: TdPalette.c.dividerFg
    }

    Item {
        id: contentHolder
        anchors.left: sidebarHolder.right
        anchors.leftMargin: TdStyle.metrics.lineWidth
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }
}
