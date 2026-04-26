import QtQuick
import Td 1.0

// TdBadge — port of `Dialogs::Ui::UnreadBadge` styling
// (lib_ui/dialogs/ui/dialogs_layout.cpp). Numeric pill badge or a small
// dot when `count <= 0`.

Item {
    id: root

    property int   count: 0
    property bool  muted: false
    property bool  dotMode: false       // small dot regardless of count
    property bool  showZero: false
    property color background: muted ? TdPalette.c.dialogsUnreadBgMuted
                                     : TdPalette.c.dialogsUnreadBg
    property color foreground: TdPalette.c.dialogsUnreadFg
    property string textOverride: ""

    visible: dotMode || count > 0 || (count === 0 && showZero) || textOverride !== ""
    implicitWidth: dotMode ? TdStyle.metrics.badgeDotSize : pill.width
    implicitHeight: dotMode ? TdStyle.metrics.badgeDotSize : TdStyle.metrics.badgeMinSize

    Rectangle {
        id: pill
        anchors.verticalCenter: parent.verticalCenter
        width: dotMode
            ? TdStyle.metrics.badgeDotSize
            : Math.max(TdStyle.metrics.badgeMinSize,
                       label.implicitWidth + TdStyle.metrics.badgePadding * 2)
        height: dotMode ? TdStyle.metrics.badgeDotSize : TdStyle.metrics.badgeMinSize
        radius: height / 2
        color: root.background

        Text {
            id: label
            anchors.centerIn: parent
            visible: !root.dotMode
            text: root.textOverride !== "" ? root.textOverride
                : (root.count > 99 ? "99+" : root.count.toString())
            color: root.foreground
            font.family: TdStyle.font.family
            font.pixelSize: TdStyle.metrics.badgeFontSize
            font.weight: TdStyle.font.weightSemibold
            renderType: Text.NativeRendering
        }
    }
}
