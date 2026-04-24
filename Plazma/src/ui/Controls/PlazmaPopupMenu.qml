import QtQuick
import QtQuick.Controls

import Style 1.0

// PlazmaPopupMenu — context menu modeled on tdesktop's Ui::PopupMenu
// (ui/widgets/popup_menu.cpp). White rounded card, soft drop shadow,
// row hover = soft lavender tint, scale+fade enter animation.
//
// Usage:
//   PlazmaPopupMenu {
//       id: menu
//       actions: [
//           { text: qsTr("Play"),             glyph: "▶", onTriggered: () => { ... } },
//           { text: qsTr("Save to playlist"), glyph: "+", onTriggered: () => { ... } },
//           { separator: true },
//           { text: qsTr("Copy link"),        glyph: "⧉", onTriggered: () => { ... } },
//           { text: qsTr("Delete"),           danger: true, onTriggered: () => { ... } },
//       ]
//   }
//   menu.openAt(someMouseArea, mouse.x, mouse.y)   // context click
//   menu.openAtItem(someButton)                    // anchored dropdown
//
// `actions` entries accept: text, glyph (string), shortcut, separator (bool),
// checked (bool), danger (bool), enabled (bool), onTriggered (callable).
// Arrow-key navigation is handled automatically; separators are skipped.
Popup {
    id: root

    property var actions: []
    property real minWidth: 208
    property real maxWidth: 320

    modal: false
    dim: false
    focus: true
    padding: 0

    closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

    contentItem: Item {
        implicitWidth: Math.max(root.minWidth,
                                Math.min(root.maxWidth, column.implicitWidth + 8))
        implicitHeight: column.implicitHeight + 12

        Column {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 6
            spacing: 0

            Repeater {
                model: root.actions

                delegate: Item {
                    width: column.width
                    height: isSeparator ? sep.implicitHeight : row.implicitHeight

                    property var entry: root.actions[index]
                    property int entryIndex: index
                    readonly property bool isSeparator: entry && entry.separator === true

                    // Separator variant
                    PlazmaMenuSeparator {
                        id: sep
                        anchors.left: parent.left
                        anchors.right: parent.right
                        visible: isSeparator
                    }

                    // Row variant
                    PlazmaMenuItem {
                        id: row
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 8
                        visible: !isSeparator

                        text: entry ? (entry.text || "") : ""
                        glyph: entry && entry.glyph ? entry.glyph : ""
                        shortcut: entry && entry.shortcut ? entry.shortcut : ""
                        checked: entry && entry.checked === true
                        danger: entry && entry.danger === true
                        enabled_: !entry || entry.enabled !== false
                        active: root._activeIndex === entryIndex

                        onHovered: root._activeIndex = entryIndex
                        onTriggered: root._invoke(entryIndex)
                    }
                }
            }
        }
    }

    // ── Visual chrome — card + stacked soft shadow ────────────────────
    background: Item {
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            radius: 10
            color: Qt.rgba(0, 0, 0, 0.10)
            opacity: 0.55
        }
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 2
            radius: 10
            color: Qt.rgba(0, 0, 0, 0.06)
            opacity: 0.9
        }
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: PlazmaStyle.color.creamWhite
            border.color: PlazmaStyle.color.inputBorder
            border.width: 1
        }
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.94; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 120; easing.type: Easing.InCubic }
            NumberAnimation { property: "scale"; from: 1.0; to: 0.97; duration: 120; easing.type: Easing.InCubic }
        }
    }

    // ── Public openers ────────────────────────────────────────────────
    function openAt(anchor, px, py) {
        const win = anchor.Window.window
        if (!win) return
        parent = win.contentItem
        const p = anchor.mapToItem(parent, px, py)
        _placeAt(p.x, p.y)
    }
    function openAtItem(item) {
        const win = item.Window.window
        if (!win) return
        parent = win.contentItem
        const p = item.mapToItem(parent, 0, item.height + 4)
        _placeAt(p.x, p.y)
    }
    function _placeAt(px, py) {
        // Nudge into bounds, then pick the appropriate scale pivot so the
        // animation looks like it's expanding *away* from the cursor.
        const maxX = (parent ? parent.width : 0) - width - 8
        const maxY = (parent ? parent.height : 0) - height - 8
        const nx = Math.max(8, Math.min(px, maxX))
        const ny = Math.max(8, Math.min(py, maxY))
        transformOrigin = (nx < px) ? Popup.TopRight : Popup.TopLeft
        x = nx
        y = ny
        open()
    }

    // ── Keyboard navigation ───────────────────────────────────────────
    property int _activeIndex: -1

    onOpened: _activeIndex = -1

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Down)      { _moveActive(1);  e.accepted = true }
        else if (e.key === Qt.Key_Up)   { _moveActive(-1); e.accepted = true }
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            _invoke(_activeIndex); e.accepted = true
        }
    }

    function _moveActive(dir) {
        if (!actions || actions.length === 0) return
        var i = _activeIndex
        for (var step = 0; step < actions.length; ++step) {
            i = (i + dir + actions.length) % actions.length
            const a = actions[i]
            if (a && !a.separator && a.enabled !== false) {
                _activeIndex = i
                return
            }
        }
    }
    function _invoke(idx) {
        const a = actions[idx]
        if (!a || a.separator || a.enabled === false) return
        if (a.onTriggered) a.onTriggered()
        close()
    }
}
