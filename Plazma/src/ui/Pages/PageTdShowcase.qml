import QtQuick
import QtQuick.Layouts

import Td 1.0
import Style 1.0

// Demo page exercising the Td framework end-to-end. Not part of the
// app's user flow — drop it into stackView while iterating on Td.

Item {
    id: page
    objectName: "qrc:/ui/Pages/PageTdShowcase.qml"

    Rectangle {
        anchors.fill: parent
        color: TdPalette.c.windowBg
    }

    TdScrollArea {
        anchors.fill: parent
        anchors.margins: 24

        content: [
            Column {
                width: page.width - 48
                spacing: 16

                TdFlatLabel {
                    text: "Td Framework — Showcase"
                    variant: TdFlatLabel.BoxTitle
                }
                TdFlatLabel {
                    text: "Tdesktop-style UI primitives running over QML. Click anything."
                    variant: TdFlatLabel.Sub
                    width: parent.width
                }

                TdSeparator {}

                TdFlatLabel { text: "Buttons"; variant: TdFlatLabel.Semibold }

                Row {
                    spacing: 12
                    TdRoundButton { text: "Active";    variant: TdRoundButton.Active;    onClicked: box.show() }
                    TdRoundButton { text: "Light";     variant: TdRoundButton.Light }
                    TdRoundButton { text: "Attention"; variant: TdRoundButton.Attention }
                    TdRoundButton { text: "Loading";   busy: true; enabledState: false }
                }

                TdSeparator {}

                TdFlatLabel { text: "Inputs"; variant: TdFlatLabel.Semibold }

                TdInputField {
                    width: 320
                    placeholder: "Phone number"
                }
                TdInputField {
                    width: 320
                    placeholder: "Verification code"
                    error: "Wrong code, try again"
                }

                TdSeparator {}

                TdFlatLabel { text: "Menu"; variant: TdFlatLabel.Semibold }

                Row {
                    spacing: 12
                    TdRoundButton {
                        text: "Open menu"
                        variant: TdRoundButton.Light
                        onClicked: menu.show(160, 320)
                    }
                    TdIconButton { iconColor: TdPalette.c.menuIconFg }
                }

                Item { width: 1; height: 80 }
            }
        ]
    }

    TdPopupMenu {
        id: menu
        TdMenuItem { text: "Open";         shortcut: "Enter";  onTriggered: menu.hide() }
        TdMenuItem { text: "Open in tab";  shortcut: "⌘T";     onTriggered: menu.hide() }
        TdMenuSeparator {}
        TdMenuItem { text: "Rename";       onTriggered: menu.hide() }
        TdMenuItem { text: "Delete";       destructive: true; onTriggered: menu.hide() }
    }

    TdBoxContent {
        id: box
        title: "Confirm action"

        Item {
            width: parent.width
            implicitHeight: 80
            TdFlatLabel {
                anchors.fill: parent
                anchors.margins: 24
                text: "This is a Td-styled modal box. It mirrors tdesktop's Ui::BoxContent: a dim background, a rounded card, a title row, content, and a right-aligned button row."
                wrapMode: Text.WordWrap
            }
        }

        buttons: [
            TdRoundButton { text: "OK";     variant: TdRoundButton.Active; onClicked: box.hide() },
            TdRoundButton { text: "Cancel"; variant: TdRoundButton.Light;  onClicked: box.hide() }
        ]
    }
}
