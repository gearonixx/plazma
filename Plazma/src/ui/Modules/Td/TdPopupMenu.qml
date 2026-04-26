import QtQuick
import Td 1.0

// TdPopupMenu — port of `Ui::PopupMenu`
// (lib_ui/ui/widgets/popup_menu.h). Rounded panel with shadow, scale-in
// animation, click-outside to dismiss.

Item {
    id: root

    property bool open: false
    default property alias items: itemColumn.data

    signal closed()

    function show(px, py) {
        panel.x = px;
        panel.y = py;
        open = true;
    }

    function hide() {
        open = false;
        closed();
    }

    anchors.fill: parent
    visible: open
    z: 1000

    // Click-outside catcher
    MouseArea {
        anchors.fill: parent
        onPressed: root.hide()
    }

    Item {
        id: panel
        width: panelBg.width
        height: panelBg.height
        opacity: root.open ? 1.0 : 0.0
        scale: root.open ? 1.0 : 0.92
        transformOrigin: Item.TopLeft

        Behavior on opacity { NumberAnimation { duration: TdStyle.duration.universal; easing.type: TdStyle.easing.standard } }
        Behavior on scale   { NumberAnimation { duration: TdStyle.duration.universal; easing.type: TdStyle.easing.standard } }

        TdShadow {
            anchors.fill: panelBg
            cornerRadius: TdStyle.metrics.menuRadius
            extend: TdStyle.metrics.shadowDepthLarge
        }

        Rectangle {
            id: panelBg
            width: itemColumn.implicitWidth + TdStyle.metrics.menuPadding * 2
            height: itemColumn.implicitHeight + TdStyle.metrics.menuPadding * 2
            radius: TdStyle.metrics.menuRadius
            color: TdPalette.c.menuBg
            border.color: TdPalette.c.menuSeparatorFg
            border.width: 1

            Column {
                id: itemColumn
                x: TdStyle.metrics.menuPadding
                y: TdStyle.metrics.menuPadding
                width: 220
                spacing: 0
            }
        }

        // Stop click-through on the panel itself
        MouseArea {
            anchors.fill: panelBg
            onPressed: function (m) { m.accepted = true }
        }
    }
}
