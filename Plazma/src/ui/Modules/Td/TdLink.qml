import QtQuick
import Td 1.0

// TdLink — clickable link text. Mirrors `Ui::FlatLabel` with a
// link-style palette + hover underline. Use for in-text actions.

Text {
    id: root

    property bool active: false
    signal clicked()

    color: hover.hovered ? TdPalette.c.linkFgOver : TdPalette.c.linkFg
    font.family: TdStyle.font.family
    font.pixelSize: TdStyle.font.fsize + 1
    font.underline: hover.hovered
    renderType: Text.NativeRendering

    HoverHandler { id: hover }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Behavior on color { ColorAnimation { duration: TdStyle.duration.universal } }
}
