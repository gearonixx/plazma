import QtQuick
import Td 1.0

// TdSearchInput — port of `Dialogs::SearchInputField` styling
// (lib_ui/dialogs/dialogs_widget.cpp). Pill-shaped field with a leading
// search glyph and a trailing clear button when the field is non-empty.

Item {
    id: root

    property alias text: input.text
    property alias placeholder: placeholderLabel.text
    property url   leadingIconSource

    signal accepted(string text)
    signal textChanged_(string text)
    signal cleared()

    implicitHeight: TdStyle.metrics.searchInputHeight
    implicitWidth: 240

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: TdStyle.metrics.searchInputRadius
        color: input.activeFocus ? TdPalette.c.filterInputActiveBg
                                 : TdPalette.c.filterInputInactiveBg
        border.color: input.activeFocus ? TdPalette.c.filterInputBorderFg : 'transparent'
        border.width: 1
        Behavior on color { ColorAnimation { duration: TdStyle.duration.universal } }
        Behavior on border.color { ColorAnimation { duration: TdStyle.duration.universal } }
    }

    // Leading icon (uses TdIcon when source is provided; falls back to a
    // tiny drawn lens otherwise).
    Item {
        id: leadingSlot
        width: TdStyle.metrics.inputFieldIconSize
        height: TdStyle.metrics.inputFieldIconSize
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: TdStyle.metrics.searchInputPadding

        TdIcon {
            anchors.fill: parent
            source: root.leadingIconSource
            color: TdPalette.c.placeholderFg
            visible: root.leadingIconSource != ""
        }

        // Drawn fallback magnifier (when no source supplied).
        Item {
            anchors.fill: parent
            visible: root.leadingIconSource == ""
            Rectangle {
                width: parent.width * 0.65
                height: width
                radius: width / 2
                color: 'transparent'
                border.color: TdPalette.c.placeholderFg
                border.width: 1.5
                anchors.left: parent.left
                anchors.top: parent.top
            }
            Rectangle {
                width: parent.width * 0.30
                height: 1.5
                color: TdPalette.c.placeholderFg
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 1
                anchors.bottomMargin: 2
                rotation: 45
                transformOrigin: Item.Center
            }
        }
    }

    TextInput {
        id: input
        anchors.left: leadingSlot.right
        anchors.right: clearBtn.visible ? clearBtn.left : parent.right
        anchors.leftMargin: 8
        anchors.rightMargin: TdStyle.metrics.searchInputPadding
        anchors.verticalCenter: parent.verticalCenter
        color: TdPalette.c.windowFg
        selectionColor: TdPalette.c.activeButtonBg
        selectedTextColor: TdPalette.c.activeButtonFg
        font.family: TdStyle.font.family
        font.pixelSize: TdStyle.font.fsize + 1
        clip: true
        renderType: Text.NativeRendering
        onAccepted: root.accepted(text)
        onTextChanged: root.textChanged_(text)
    }

    Text {
        id: placeholderLabel
        anchors.left: input.left
        anchors.verticalCenter: input.verticalCenter
        text: ""
        color: TdPalette.c.placeholderFg
        font: input.font
        renderType: Text.NativeRendering
        visible: input.text.length === 0
    }

    TdIconButton {
        id: clearBtn
        iconSize: 14
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 24; height: 24
        visible: input.text.length > 0
        onClicked: { input.text = ""; root.cleared(); input.forceActiveFocus() }

        // Inline X glyph since we don't ship an icon set.
        Item {
            anchors.centerIn: parent
            width: 10; height: 10
            Rectangle { anchors.centerIn: parent; width: parent.width; height: 1.5; rotation: 45; color: TdPalette.c.placeholderFg; radius: 1 }
            Rectangle { anchors.centerIn: parent; width: parent.width; height: 1.5; rotation: -45; color: TdPalette.c.placeholderFg; radius: 1 }
        }
    }
}
