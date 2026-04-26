import QtQuick
import Td 1.0

// TdScrollShadow — top + bottom edge fades that fade in/out based on a
// Flickable's scroll position. Mirrors the role of
// `Ui::ScrollArea`'s top/bottom shadows in tdesktop. Bind `target` to a
// Flickable (e.g. TdScrollArea) and place this Item over it.

Item {
    id: root

    property Flickable target: null
    property color shadowColor: TdPalette.c.shadowFg
    property int   depth: TdStyle.metrics.scrollEdgeShadow

    anchors.fill: parent

    readonly property bool _atTop: target ? target.contentY <= 0 : true
    readonly property bool _atBottom: target
        ? (target.contentY + target.height >= target.contentHeight - 0.5)
        : true

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.depth
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.shadowColor }
            GradientStop { position: 1.0; color: 'transparent' }
        }
        opacity: root._atTop ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: TdStyle.duration.fadeWrap } }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.depth
        gradient: Gradient {
            GradientStop { position: 0.0; color: 'transparent' }
            GradientStop { position: 1.0; color: root.shadowColor }
        }
        opacity: root._atBottom ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: TdStyle.duration.fadeWrap } }
    }
}
