import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import dev.gearonixx.plazma 1.0

import Style 1.0

// Dual-purpose "name a playlist" dialog — used for both renaming an
// existing playlist and creating a new one. When `playlistId` is empty
// the Save button creates a brand-new playlist; otherwise it renames.
//
// Signal `playlistCreated(id, name)` lets callers hook into new creates
// (the A-Z grid updates automatically, but other pages may want it).
Popup {
    id: root

    property string playlistId: ""
    property string initialName: ""
    property string errorMessage: ""
    readonly property bool isRename: playlistId.length > 0

    signal playlistCreated(string id, string name)

    modal: true
    dim: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape

    implicitWidth: 340
    implicitHeight: 190

    function openWith(id, name) {
        playlistId = id
        initialName = name
        nameField.text = name
        errorMessage = ""
        if (parent) {
            x = (parent.width - width) / 2
            y = (parent.height - height) / 2
        }
        open()
        Qt.callLater(() => {
            nameField.forceActiveFocus()
            nameField.selectAll()
        })
    }

    background: Rectangle {
        radius: 14
        color: PlazmaStyle.color.creamWhite
        border.color: PlazmaStyle.color.inputBorder
        border.width: 1
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
            NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 170; easing.type: Easing.OutCubic }
        }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 110 }
    }

    contentItem: ColumnLayout {
        spacing: 12
        anchors.margins: 18

        Text {
            Layout.fillWidth: true
            text: root.isRename ? qsTr("Rename playlist") : qsTr("New playlist")
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: PlazmaStyle.color.textPrimary
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 8
            color: PlazmaStyle.color.inputBackground
            border.color: nameField.activeFocus
                          ? PlazmaStyle.color.inputBorderFocused
                          : PlazmaStyle.color.inputBorder
            border.width: 1

            TextField {
                id: nameField
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                placeholderText: qsTr("Playlist name")
                placeholderTextColor: PlazmaStyle.color.textHint
                font.pixelSize: 13
                color: PlazmaStyle.color.textPrimary
                background: null
                verticalAlignment: TextInput.AlignVCenter
                leftPadding: 0; rightPadding: 0; topPadding: 0; bottomPadding: 0
                onAccepted: root._submit()
                onTextChanged: if (root.errorMessage.length > 0) root.errorMessage = ""
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.errorMessage
            font.pixelSize: 11
            color: PlazmaStyle.color.errorRed
            visible: text.length > 0
            wrapMode: Text.WordWrap
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 32
                radius: 16
                color: cancelMouse.containsMouse ? PlazmaStyle.color.softAmber : "transparent"
                border.color: PlazmaStyle.color.inputBorder
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Cancel")
                    font.pixelSize: 12
                    color: PlazmaStyle.color.textPrimary
                }
                MouseArea {
                    id: cancelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }

            Rectangle {
                Layout.preferredWidth: 92
                Layout.preferredHeight: 32
                radius: 16
                color: saveMouse.containsMouse
                       ? PlazmaStyle.color.burntOrange
                       : PlazmaStyle.color.goldenApricot
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: root.isRename ? qsTr("Save") : qsTr("Create")
                    color: "#FFFFFF"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    id: saveMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._submit()
                }
            }
        }
    }

    function _submit() {
        const n = nameField.text.trim()
        if (!PlaylistsModel.isValidName(n)) { errorMessage = qsTr("Enter a name"); return }
        if (PlaylistsModel.isNameTaken(n, playlistId)) {
            errorMessage = qsTr("Another playlist already uses this name")
            return
        }
        if (isRename) {
            PlaylistsModel.renamePlaylist(playlistId, n)
        } else {
            const newId = PlaylistsModel.createPlaylist(n)
            if (newId.length > 0) playlistCreated(newId, n)
        }
        close()
    }
}
