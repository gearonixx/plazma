import QtQuick

import dev.gearonixx.plazma 1.0
import Td 1.0

// Settings layer. Shown via TdLayerManager.show(...) from the gear icon in
// NavBar. Mirrors tdesktop's box-style settings flows (see Settings::Chat
// in settings_chat.cpp): a titled box with grouped rows, each row a
// self-contained "set and forget" affordance.
//
// Currently houses a single group ("Downloads") — the box is sized to its
// content so adding rows later doesn't require a layout pass.
TdBoxContent {
    id: root

    title: qsTr("Settings")
    boxWidth: 440

    // Esc to dismiss — matches every modal in the app + standard expectation.
    Keys.onEscapePressed: function (event) {
        root.hide();
        event.accepted = true;
    }
    Component.onCompleted: forceActiveFocus()

    // Surface validation errors raised by SettingsModel (folder doesn't
    // exist / not writable). Cleared whenever the user picks again or
    // toggles back to default, so a stale error never lingers.
    property string errorMessage: ""

    Connections {
        target: SettingsModel
        function onDownloadPathError(reason) { root.errorMessage = reason }
        function onDownloadPathChanged() { root.errorMessage = "" }
    }

    body: [
        Column {
            id: bodyCol
            width: parent ? parent.width : root.boxWidth
            spacing: 0
            topPadding: 4
            bottomPadding: 8

            TdSectionHeader {
                width: parent.width
                text: qsTr("Downloads")
                uppercase: true
            }

            // Primary action: change the download folder. The whole row is
            // clickable — the path appears as the subtitle so the user can
            // verify at a glance where their videos go without opening
            // anything.
            TdSettingsRow {
                width: parent.width
                title: qsTr("Save videos to")
                subtitle: SettingsModel.effectiveDownloadPath
                chevron: true
                onClicked: SettingsModel.chooseDownloadFolder()
            }

            // Reveal in system file manager. Same affordance Telegram and
            // OBS expose right next to the path so users can confirm where
            // files land before kicking off a big download.
            TdSettingsRow {
                width: parent.width
                title: qsTr("Open in file manager")
                onClicked: SettingsModel.revealDownloadFolder()
            }

            // Only visible once the user has chosen a custom folder, so
            // first-run users aren't tempted to "reset" something they
            // never changed.
            TdSettingsRow {
                width: parent.width
                visible: !SettingsModel.usingDefaultDownloadPath
                title: qsTr("Reset to default location")
                subtitle: SettingsModel.defaultDownloadPath
                destructive: true
                onClicked: SettingsModel.resetDownloadPath()
            }

            // Inline error surface — only paints when there's something to
            // say. Sits below the rows so it's adjacent to whatever just
            // failed.
            Item {
                width: parent.width
                visible: root.errorMessage.length > 0
                height: visible ? errorLabel.implicitHeight + 20 : 0

                Text {
                    id: errorLabel
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: TdStyle.metrics.rowPadding
                    anchors.rightMargin: TdStyle.metrics.rowPadding
                    text: root.errorMessage
                    color: TdPalette.c.attentionButtonFg
                    wrapMode: Text.WordWrap
                    font.family: TdStyle.font.family
                    font.pixelSize: TdStyle.font.fsize
                    renderType: Text.NativeRendering
                }
            }
        }
    ]

    buttons: [
        TdRoundButton {
            text: qsTr("Done")
            variant: TdRoundButton.Active
            onClicked: root.hide()
        }
    ]
}
