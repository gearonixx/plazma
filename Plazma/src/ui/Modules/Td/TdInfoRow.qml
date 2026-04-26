import QtQuick
import Td 1.0

// TdInfoRow — value/label row used in profile / about panes
// (SourceFiles/info/profile/info_profile_values.cpp). Label below,
// value above, optional copy action.

Item {
    id: root

    property string label: ""
    property string value: ""
    property bool   copyable: false
    signal copyRequested()

    implicitHeight: TdStyle.metrics.rowHeight
    implicitWidth: 320

    Column {
        anchors.fill: parent
        anchors.leftMargin: TdStyle.metrics.rowPadding
        anchors.rightMargin: TdStyle.metrics.rowPadding
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 2

        Text {
            text: root.value
            color: TdPalette.c.windowFg
            font.family: TdStyle.font.family
            font.pixelSize: TdStyle.font.fsize + 1
            renderType: Text.NativeRendering
            width: parent.width
            elide: Text.ElideRight
        }
        Text {
            text: root.label
            color: TdPalette.c.windowSubTextFg
            font.family: TdStyle.font.family
            font.pixelSize: TdStyle.font.fsize
            renderType: Text.NativeRendering
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.copyable
        cursorShape: root.copyable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.copyRequested()
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: TdStyle.metrics.lineWidth
        color: TdPalette.c.dividerFg
    }
}
