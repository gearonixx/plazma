import QtQuick
import Td 1.0

// TdShadow — a soft drop shadow rendered with stacked semi-transparent
// rectangles, mirroring the look of `Ui::Shadow` from
// lib_ui/ui/widgets/shadow.h. Pure-QML so it works without the Qt5Compat
// graphical-effects package.
//
// Usage: place inside a parent and bind `extend` for depth.

Item {
    id: root

    property color shadowColor: TdPalette.c.shadowFg
    property int   extend: TdStyle.metrics.shadowDepthSmall
    property real  cornerRadius: 0

    anchors.fill: parent
    anchors.margins: -extend
    z: -1

    // Layered fades. Cheaper than a real GaussianBlur and looks close enough
    // for the small radii tdesktop uses for popups.
    Repeater {
        model: root.extend
        delegate: Rectangle {
            anchors.fill: parent
            anchors.margins: root.extend - index
            color: 'transparent'
            border.color: root.shadowColor
            border.width: 1
            radius: root.cornerRadius + (root.extend - index)
            opacity: (1.0 - (index / root.extend)) * 0.6
        }
    }
}
