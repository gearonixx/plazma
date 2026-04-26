import QtQuick
import Td 1.0

// TdEmptyState — port of the empty-state placeholders used in tdesktop
// (e.g. PeerListBox empty hint, dialogs empty list). Centered icon,
// title and subtitle; optional action button slot.

Item {
    id: root

    property url    iconSource
    property string title: ""
    property string subtitle: ""

    default property alias action: actionHolder.data

    Column {
        anchors.centerIn: parent
        spacing: 12
        width: Math.min(parent.width - TdStyle.metrics.emptyStatePadding * 2, 360)

        TdIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            source: root.iconSource
            color: TdPalette.c.windowSubTextFg
            size: TdStyle.metrics.emptyStateIcon
            visible: root.iconSource != ""
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.title
            color: TdPalette.c.windowBoldFg
            font.family: TdStyle.font.family
            font.pixelSize: TdStyle.font.largeFontSize
            font.weight: TdStyle.font.weightSemibold
            renderType: Text.NativeRendering
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            text: root.subtitle
            color: TdPalette.c.windowSubTextFg
            font.family: TdStyle.font.family
            font.pixelSize: TdStyle.font.fsize + 1
            renderType: Text.NativeRendering
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            anchors.left: parent.left
            anchors.right: parent.right
            visible: text !== ""
        }
        Item {
            id: actionHolder
            anchors.horizontalCenter: parent.horizontalCenter
            implicitHeight: childrenRect.height
            implicitWidth: childrenRect.width
            visible: actionHolder.children.length > 0
        }
    }
}
