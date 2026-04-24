import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Style 1.0

// Single row of a PlazmaPopupMenu. Modeled after tdesktop's
// Menu::Action (itemPadding 17/8/17/7, ripple-on-press). Supports a
// leading glyph slot, a checkmark, a trailing submenu arrow, and a
// "danger" variant for destructive actions.
Rectangle {
    id: root

    property alias text: label.text
    property string glyph: ""               // leading icon glyph (optional)
    property string shortcut: ""            // right-aligned secondary text
    property bool hasSubmenu: false
    property bool checked: false
    property bool danger: false
    property bool enabled_: true
    property bool active: false             // focused by keyboard navigation

    signal triggered()
    signal hovered()

    implicitHeight: 34
    implicitWidth: Math.max(180, row.implicitWidth + 34)
    Layout.fillWidth: true

    readonly property bool showHover: (hover.containsMouse || root.active) && root.enabled_

    color: showHover ? PlazmaStyle.color.softAmber : "transparent"
    Behavior on color { ColorAnimation { duration: 90 } }

    radius: 6
    // Inset the hover chip a little from the menu's outer radius so the
    // corners don't fight when multiple items are lit up (they won't
    // actually stack, but visually the 2-4px inset reads cleaner).
    anchors.leftMargin: 4
    anchors.rightMargin: 4

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 10
        spacing: 10

        Item {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            visible: root.glyph.length > 0 || root.checked

            Text {
                anchors.centerIn: parent
                text: root.checked ? "✓" : root.glyph
                font.pixelSize: root.checked ? 13 : 14
                font.weight: Font.DemiBold
                color: root.danger
                       ? PlazmaStyle.color.errorRed
                       : (root.showHover ? PlazmaStyle.color.warmGold : PlazmaStyle.color.textSecondary)
            }
        }

        Text {
            id: label
            Layout.fillWidth: true
            font.pixelSize: 13
            color: !root.enabled_
                   ? PlazmaStyle.color.textHint
                   : (root.danger ? PlazmaStyle.color.errorRed : PlazmaStyle.color.textPrimary)
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            visible: root.shortcut.length > 0 && !root.hasSubmenu
            text: root.shortcut
            font.pixelSize: 11
            font.letterSpacing: 0.3
            color: PlazmaStyle.color.textHint
        }

        Text {
            visible: root.hasSubmenu
            text: "›"
            font.pixelSize: 16
            color: root.showHover ? PlazmaStyle.color.warmGold : PlazmaStyle.color.textSecondary
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled_ ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled_
        onEntered: root.hovered()
        onClicked: root.triggered()
    }
}
