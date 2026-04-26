import QtQuick
import Td 1.0

// TdSectionHeader — port of the section labels used between groups of
// rows in tdesktop settings panes (`PeerListBox::peerListSetTitle` /
// `Settings::AddSubsectionTitle`). Small uppercase text in the accent
// color.

Item {
    id: root

    property string text: ""
    property bool   uppercase: false

    implicitHeight: TdStyle.metrics.sectionHeaderHeight
    implicitWidth: 200

    Text {
        anchors.left: parent.left
        anchors.leftMargin: TdStyle.metrics.rowPadding
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        text: root.uppercase ? root.text.toUpperCase() : root.text
        color: TdPalette.c.activeButtonBg
        font.family: TdStyle.font.family
        font.pixelSize: TdStyle.font.fsize - 1
        font.weight: TdStyle.font.weightSemibold
        font.letterSpacing: root.uppercase ? 0.6 : 0
        renderType: Text.NativeRendering
    }
}
