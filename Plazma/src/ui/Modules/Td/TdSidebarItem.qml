import QtQuick
import Td 1.0

// TdSidebarItem — port of `Dialogs::Ui::RowPainter` /
// `Dialogs::InnerWidget` rows (SourceFiles/dialogs/dialogs_inner_widget.cpp).
// Avatar + name + last message preview, badge, timestamp.

Item {
    id: root

    property string name: ""
    property string preview: ""
    property string time: ""
    property url    avatarSource
    property int    unreadCount: 0
    property bool   muted: false
    property bool   active: false
    property bool   pinned: false

    signal clicked()

    implicitHeight: TdStyle.metrics.sidebarItemHeight
    implicitWidth: 320

    TdAbstractButton {
        id: btn
        anchors.fill: parent
        rippleColor: root.active ? TdPalette.c.dialogsRippleBgActive : TdPalette.c.dialogsRippleBg
        onClicked: root.clicked()

        Rectangle {
            anchors.fill: parent
            color: root.active ? TdPalette.c.dialogsBgActive
                  : btn.hovered ? TdPalette.c.dialogsBgOver
                                : 'transparent'
            Behavior on color { ColorAnimation { duration: TdStyle.duration.universal } }
        }

        TdAvatar {
            id: avatarComp
            anchors.left: parent.left
            anchors.leftMargin: TdStyle.metrics.sidebarItemPadding
            anchors.verticalCenter: parent.verticalCenter
            size: TdStyle.metrics.sidebarAvatarSize
            name: root.name
            source: root.avatarSource
        }

        // Name (top row)
        Text {
            id: nameLabel
            anchors.left: avatarComp.right
            anchors.leftMargin: TdStyle.metrics.sidebarItemSpacing
            anchors.right: timeLabel.left
            anchors.rightMargin: 6
            anchors.top: avatarComp.top
            text: root.name
            color: root.active ? TdPalette.c.dialogsNameFgActive : TdPalette.c.dialogsNameFg
            font.family: TdStyle.font.family
            font.pixelSize: TdStyle.font.fsize + 2
            font.weight: TdStyle.font.weightSemibold
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        // Time (top right)
        Text {
            id: timeLabel
            anchors.right: parent.right
            anchors.rightMargin: TdStyle.metrics.sidebarItemPadding
            anchors.top: avatarComp.top
            text: root.time
            color: root.active ? TdPalette.c.dialogsDateFgActive : TdPalette.c.dialogsDateFg
            font.family: TdStyle.font.family
            font.pixelSize: TdStyle.font.fsize - 1
            renderType: Text.NativeRendering
        }

        // Preview (bottom)
        Text {
            id: previewLabel
            anchors.left: nameLabel.left
            anchors.right: badge.left
            anchors.rightMargin: 6
            anchors.bottom: avatarComp.bottom
            text: root.preview
            color: root.active ? TdPalette.c.dialogsTextFgActive : TdPalette.c.dialogsTextFg
            font.family: TdStyle.font.family
            font.pixelSize: TdStyle.font.fsize + 1
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        TdBadge {
            id: badge
            anchors.right: parent.right
            anchors.rightMargin: TdStyle.metrics.sidebarItemPadding
            anchors.bottom: avatarComp.bottom
            anchors.bottomMargin: 1
            count: root.unreadCount
            muted: root.muted
            background: root.active ? TdPalette.c.windowFgActive : (root.muted ? TdPalette.c.dialogsUnreadBgMuted : TdPalette.c.dialogsUnreadBg)
            foreground: root.active ? TdPalette.c.dialogsBgActive : TdPalette.c.dialogsUnreadFg
        }
    }
}
