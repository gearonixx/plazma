import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import dev.gearonixx.plazma 1.0

import Style 1.0

// Modal "Save video to…" dialog — the YouTube flow, more ergonomic than a
// nested context submenu. Accepts a video QVariantMap at openWith() time
// and stays open while the user toggles membership in one or more playlists
// and/or creates a new one.
//
// Every toggle mutates PlaylistsModel immediately (no bulk "Save" button);
// the dialog is purely a control surface. `Done` just closes it. This
// mirrors YouTube's 2024 redesign where adding/removing is instant.
Popup {
    id: root

    property var video: ({})        // QVariantMap-shaped: id, title, url, ...
    readonly property string _videoId: video && video.id ? String(video.id) : ""

    modal: true
    dim: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape

    implicitWidth: 360
    implicitHeight: Math.min(460, contentCol.implicitHeight + 40)

    signal newPlaylistRequested()

    function openWith(v) {
        video = v || ({})
        _summaries = PlaylistsModel.summariesForVideo(_videoId)
        // Center in the window that owns `parent` (set by caller).
        const p = parent
        if (p) {
            x = (p.width - width) / 2
            y = (p.height - height) / 2
        }
        creatingNew = false
        newNameField.text = ""
        newNameError = ""
        open()
    }

    // ── Reactive list of {id, name, videoCount, contains} — rebuilt on
    // every mutation so the checkmarks stay in sync with reality.
    property var _summaries: []
    property bool creatingNew: false
    property string newNameError: ""

    Connections {
        target: PlaylistsModel
        function onCountChanged() { root._summaries = PlaylistsModel.summariesForVideo(root._videoId) }
        function onCurrentChanged() { /* no-op */ }
        function onLastCreatedChanged() {
            // New playlist just popped — refresh list + auto-add the video.
            root._summaries = PlaylistsModel.summariesForVideo(root._videoId)
        }
    }

    background: Item {
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            radius: 14
            color: Qt.rgba(0, 0, 0, 0.14)
            opacity: 0.6
        }
        Rectangle {
            anchors.fill: parent
            radius: 14
            color: PlazmaStyle.color.creamWhite
            border.color: PlazmaStyle.color.inputBorder
            border.width: 1
        }
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 180; easing.type: Easing.OutCubic }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 }
            NumberAnimation { property: "scale"; from: 1; to: 0.98; duration: 120 }
        }
    }

    contentItem: ColumnLayout {
        id: contentCol
        spacing: 0

        // Header
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 52

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Save video to…")
                font.pixelSize: 15
                font.weight: Font.DemiBold
                color: PlazmaStyle.color.textPrimary
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 12
                width: 28; height: 28; radius: 14
                color: closeMouse.containsMouse ? PlazmaStyle.color.softAmber : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 13
                    color: PlazmaStyle.color.textSecondary
                }
                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: PlazmaStyle.color.inputBorder
            }
        }

        // Video title hint — so the user knows which video they're saving.
        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: 10
            text: root.video && root.video.title ? root.video.title : qsTr("Untitled")
            font.pixelSize: 12
            color: PlazmaStyle.color.textSecondary
            elide: Text.ElideRight
            maximumLineCount: 1
            wrapMode: Text.NoWrap
        }

        // Playlist rows (scrollable).
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(240, Math.max(52, listView.contentHeight + 8))
            Layout.topMargin: 8

            // Empty state: no playlists yet. Nudge them straight to the
            // create-new UI — otherwise they're staring at a blank panel.
            Text {
                anchors.centerIn: parent
                visible: root._summaries.length === 0
                text: qsTr("No playlists yet. Create your first below.")
                font.pixelSize: 12
                color: PlazmaStyle.color.textHint
            }

            ListView {
                id: listView
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                clip: true
                model: root._summaries
                spacing: 2
                visible: root._summaries.length > 0

                delegate: Rectangle {
                    width: listView.width
                    height: 38
                    radius: 8

                    property var entry: modelData
                    readonly property bool contains: entry && entry.contains === true

                    color: rowMouse.containsMouse
                           ? PlazmaStyle.color.softAmber
                           : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        // Checkbox-ish square. Filled when the video is in
                        // that playlist.
                        Rectangle {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            radius: 4
                            color: contains ? PlazmaStyle.color.goldenApricot : "transparent"
                            border.color: contains
                                          ? PlazmaStyle.color.goldenApricot
                                          : PlazmaStyle.color.inputBorder
                            border.width: 1.5

                            Text {
                                anchors.centerIn: parent
                                visible: contains
                                text: "✓"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: "#FFFFFF"
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: entry ? entry.name : ""
                            font.pixelSize: 13
                            color: PlazmaStyle.color.textPrimary
                            elide: Text.ElideRight
                        }

                        Text {
                            text: entry ? qsTr("%1 videos").arg(entry.videoCount) : ""
                            font.pixelSize: 11
                            color: PlazmaStyle.color.textHint
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!entry) return
                            if (contains) {
                                PlaylistsModel.removeVideoFromPlaylist(entry.id, root._videoId)
                            } else {
                                PlaylistsModel.addVideoToPlaylist(entry.id, root.video)
                            }
                            root._summaries = PlaylistsModel.summariesForVideo(root._videoId)
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 8
            color: PlazmaStyle.color.inputBorder
        }

        // Create-new-playlist row. Collapsed by default: a single button
        // that expands into a text field when tapped.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.creatingNew ? 96 : 48

            Behavior on Layout.preferredHeight { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            // Collapsed state
            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: 6
                anchors.bottomMargin: 6
                radius: 8
                color: newMouse.containsMouse ? PlazmaStyle.color.softAmber : "transparent"
                visible: !root.creatingNew
                Behavior on color { ColorAnimation { duration: 100 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        radius: 9
                        color: PlazmaStyle.color.warmGold
                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            color: "#FFFFFF"
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("New playlist")
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: PlazmaStyle.color.textPrimary
                    }
                }

                MouseArea {
                    id: newMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.creatingNew = true
                        newNameField.forceActiveFocus()
                        newNameField.selectAll()
                    }
                }
            }

            // Expanded state
            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 6
                spacing: 6
                visible: root.creatingNew

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 8
                    color: PlazmaStyle.color.inputBackground
                    border.color: newNameField.activeFocus
                                  ? PlazmaStyle.color.inputBorderFocused
                                  : PlazmaStyle.color.inputBorder
                    border.width: 1

                    TextField {
                        id: newNameField
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
                        onAccepted: root._tryCreate()
                        onTextChanged: if (root.newNameError.length > 0) root.newNameError = ""
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: root.newNameError
                        font.pixelSize: 11
                        color: PlazmaStyle.color.errorRed
                        visible: text.length > 0
                    }

                    Rectangle {
                        Layout.preferredWidth: 70
                        Layout.preferredHeight: 30
                        radius: 15
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
                            onClicked: {
                                root.creatingNew = false
                                root.newNameError = ""
                                newNameField.text = ""
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 82
                        Layout.preferredHeight: 30
                        radius: 15
                        color: createMouse.containsMouse
                               ? PlazmaStyle.color.burntOrange
                               : PlazmaStyle.color.goldenApricot
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Create")
                            color: "#FFFFFF"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            id: createMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._tryCreate()
                        }
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 8 }
    }

    function _tryCreate() {
        const name = newNameField.text.trim()
        if (!PlaylistsModel.isValidName(name)) {
            root.newNameError = qsTr("Enter a name")
            return
        }
        if (PlaylistsModel.isNameTaken(name)) {
            root.newNameError = qsTr("A playlist with that name already exists")
            return
        }
        const id = PlaylistsModel.createPlaylist(name)
        if (id.length === 0) {
            root.newNameError = qsTr("Couldn’t create the playlist")
            return
        }
        PlaylistsModel.addVideoToPlaylist(id, root.video)
        root._summaries = PlaylistsModel.summariesForVideo(root._videoId)
        root.creatingNew = false
        newNameField.text = ""
        root.newNameError = ""
    }
}
