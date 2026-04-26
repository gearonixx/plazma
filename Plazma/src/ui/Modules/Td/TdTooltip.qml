import QtQuick
import Td 1.0

// TdTooltip — port of `Ui::Tooltip` (lib_ui/ui/widgets/tooltip.h).
// Attach to any Item by parenting it inside the target and binding
// `text`. Shows after `TdStyle.duration.tooltip` of hover.

Item {
    id: root

    property string text: ""
    property Item target: parent
    property int delay: TdStyle.duration.tooltip
    property int placement: TdTooltip.Below

    enum Placement { Above, Below }

    parent: target ? target : null
    anchors.fill: target

    HoverHandler {
        id: hover
        target: root.target
    }

    Timer {
        id: showTimer
        interval: root.delay
        running: hover.hovered && root.text !== ""
        onTriggered: bubble.opacity = 1
    }

    onTextChanged: bubble.opacity = 0
    Connections {
        target: hover
        function onHoveredChanged() { if (!hover.hovered) bubble.opacity = 0 }
    }

    Item {
        id: bubble
        opacity: 0
        z: TdStyle.z.tooltip
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: TdStyle.duration.fadeWrap } }

        x: hover.point ? hover.point.position.x + 12 : 0
        y: root.placement === TdTooltip.Below
           ? (hover.point ? hover.point.position.y + 18 : 0)
           : (hover.point ? hover.point.position.y - bg.height - 8 : 0)

        Rectangle {
            id: bg
            width: Math.min(label.implicitWidth + TdStyle.metrics.tooltipPadding * 2,
                            TdStyle.metrics.tooltipMaxWidth)
            height: label.implicitHeight + TdStyle.metrics.tooltipPadding
            radius: TdStyle.metrics.tooltipRadius
            color: TdPalette.c.tooltipBg
            border.color: TdPalette.c.tooltipBorderFg
            border.width: 1

            Text {
                id: label
                anchors.fill: parent
                anchors.margins: TdStyle.metrics.tooltipPadding / 2
                anchors.leftMargin: TdStyle.metrics.tooltipPadding
                anchors.rightMargin: TdStyle.metrics.tooltipPadding
                text: root.text
                color: TdPalette.c.tooltipFg
                font.family: TdStyle.font.family
                font.pixelSize: TdStyle.font.fsize - 1
                wrapMode: Text.WordWrap
                renderType: Text.NativeRendering
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
