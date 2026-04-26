import QtQuick
import Td 1.0

// TdBoxContent — port of `Ui::BoxContent` /
// `Window::Layer` (lib_ui/ui/layers/box_content.h). Modal layer with a
// dim background, centered rounded box, title, content slot and a
// bottom button row.
//
// Slots:
//   - `title`             plain text title
//   - `content`           default-property children fill the body
//   - `buttons`           Item children for the bottom-aligned button row

Item {
    id: root

    property string title: ""
    property bool   open: false
    property int    boxWidth: 380
    property int    contentMargins: TdStyle.metrics.boxPadding

    default property alias body: bodyHolder.data
    property alias buttons: buttonRow.data

    signal closed()

    function show()  { open = true }
    function hide()  { open = false; closed() }

    anchors.fill: parent
    visible: open || dim.opacity > 0
    z: 900

    // Dim layer
    Rectangle {
        id: dim
        anchors.fill: parent
        color: TdPalette.c.layerBg
        opacity: root.open ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: TdStyle.duration.fadeWrap } }

        MouseArea {
            anchors.fill: parent
            onPressed: root.hide()
        }
    }

    Item {
        id: boxFrame
        width: root.boxWidth
        height: contentLayout.implicitHeight
        anchors.centerIn: parent
        opacity: root.open ? 1.0 : 0.0
        scale: root.open ? 1.0 : 0.96
        Behavior on opacity { NumberAnimation { duration: TdStyle.duration.universal; easing.type: TdStyle.easing.standard } }
        Behavior on scale   { NumberAnimation { duration: TdStyle.duration.universal; easing.type: TdStyle.easing.standard } }

        TdShadow {
            anchors.fill: boxBg
            cornerRadius: TdStyle.metrics.boxRadius
            extend: TdStyle.metrics.shadowDepthLarge
        }

        Rectangle {
            id: boxBg
            anchors.fill: parent
            color: TdPalette.c.boxBg
            radius: TdStyle.metrics.boxRadius

            // Eat clicks so the dim catcher behind us doesn't dismiss
            MouseArea { anchors.fill: parent; onPressed: function(m){ m.accepted = true } }
        }

        Column {
            id: contentLayout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 0

            // Title bar
            Item {
                width: parent.width
                height: 56
                visible: root.title.length > 0

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: root.contentMargins
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.title
                    color: TdPalette.c.windowBoldFg
                    font.family: TdStyle.font.family
                    font.pixelSize: TdStyle.metrics.boxTitleSize
                    font.weight: TdStyle.font.weightSemibold
                    renderType: Text.NativeRendering
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: TdStyle.metrics.lineWidth
                    color: TdPalette.c.boxDivider
                }
            }

            // Body
            Item {
                id: bodyHolder
                width: parent.width
                implicitHeight: childrenRect.height
                height: childrenRect.height
            }

            // Button row
            Item {
                id: buttonRowFrame
                width: parent.width
                height: buttonRow.children.length > 0
                        ? TdStyle.metrics.boxButtonHeight + root.contentMargins
                        : 0

                Row {
                    id: buttonRow
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: root.contentMargins
                    anchors.bottomMargin: root.contentMargins / 2
                    spacing: TdStyle.metrics.boxButtonSpacing
                    layoutDirection: Qt.RightToLeft
                }
            }
        }
    }
}
