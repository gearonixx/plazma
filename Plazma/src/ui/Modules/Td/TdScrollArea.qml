import QtQuick
import Td 1.0

// TdScrollArea — port of `Ui::ScrollArea`
// (lib_ui/ui/widgets/scroll_area.h). Slim auto-fading vertical scroll bar
// over a Flickable. Use `contentItem` for the scrolled content.

Flickable {
    id: flick

    property alias content: contentHolder.children

    // tdesktop scroll bar widens on hover; we mirror that.
    property bool _scrollHovered: scrollHover.hovered

    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    clip: true

    contentWidth: width
    contentHeight: contentHolder.childrenRect.height

    Item {
        id: contentHolder
        width: flick.width
        height: childrenRect.height
    }

    HoverHandler {
        id: scrollHover
        target: scrollBar
    }

    // Track
    Rectangle {
        id: scrollTrack
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: scrollBar.width + 2
        color: 'transparent'
    }

    // Bar
    Rectangle {
        id: scrollBar
        anchors.right: parent.right
        anchors.rightMargin: 2
        width: flick._scrollHovered ? TdStyle.metrics.scrollWidthOver
                                    : TdStyle.metrics.scrollWidth
        radius: width / 2
        color: flick._scrollHovered ? TdPalette.c.scrollBarBgOver
                                    : TdPalette.c.scrollBarBg
        opacity: flick.contentHeight > flick.height ? 1.0 : 0.0

        y: flick.contentY * (flick.height / Math.max(flick.contentHeight, 1))
        height: Math.max(
            TdStyle.metrics.scrollMinHeight,
            flick.height * (flick.height / Math.max(flick.contentHeight, 1))
        )

        Behavior on opacity { NumberAnimation { duration: TdStyle.duration.fadeWrap } }
        Behavior on width   { NumberAnimation { duration: TdStyle.duration.universal } }
        Behavior on color   { ColorAnimation  { duration: TdStyle.duration.universal } }

        MouseArea {
            id: barDrag
            anchors.fill: parent
            cursorShape: Qt.ArrowCursor
            preventStealing: true
            property real grabY: 0
            onPressed: function (mouse) { grabY = mouse.y }
            onPositionChanged: function (mouse) {
                if (!pressed) return;
                const dy = mouse.y - grabY;
                const trackH = flick.height - scrollBar.height;
                if (trackH <= 0) return;
                const newY = Math.max(0, Math.min(trackH, scrollBar.y + dy));
                flick.contentY = newY * (flick.contentHeight - flick.height) / trackH;
            }
        }
    }
}
