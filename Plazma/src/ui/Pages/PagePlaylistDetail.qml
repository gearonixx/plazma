import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import dev.gearonixx.plazma 1.0

import "../Controls"

import PageEnum 1.0
import Style 1.0

Page {
    id: root

    background: Rectangle { color: PlazmaStyle.color.warmWhite }

    readonly property var videos: PlaylistsModel.currentVideos
    readonly property int videoCount: videos.length
    readonly property string playlistId: PlaylistsModel.currentPlaylistId
    readonly property string playlistName: PlaylistsModel.currentPlaylistName

    // If the user lands here without an open playlist (e.g. the model was
    // reset), bounce back to the library. Avoids a blank page and keeps
    // the navigation model coherent.
    Component.onCompleted: {
        if (playlistId.length === 0) {
            PageController.replacePage(PageEnum.PagePlaylists)
        }
    }

    NavBar {
        id: nav
        activePage: PageEnum.PagePlaylistDetail
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
    }

    // Header strip: back arrow + playlist name + video count + actions.
    Rectangle {
        id: header
        anchors.top: nav.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 96
        color: PlazmaStyle.color.creamWhite

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: PlazmaStyle.color.inputBorder
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: backMouse.containsMouse ? PlazmaStyle.color.softAmber : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "‹"
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    color: PlazmaStyle.color.textPrimary
                }
                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PageController.replacePage(PageEnum.PagePlaylists)
                }
            }

            // Mini cover — first thumbnail or placeholder.
            Rectangle {
                Layout.preferredWidth: 72
                Layout.preferredHeight: 72 * 9 / 16
                radius: 8
                color: "#1A1626"
                clip: true

                Image {
                    anchors.fill: parent
                    source: root.videos.length > 0 && root.videos[0].thumbnail
                            ? root.videos[0].thumbnail : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: source !== ""
                    asynchronous: true
                }
                Text {
                    anchors.centerIn: parent
                    visible: root.videos.length === 0 || !root.videos[0].thumbnail
                    text: "♪"
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font.pixelSize: 22
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    text: root.playlistName
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    color: PlazmaStyle.color.textPrimary
                    elide: Text.ElideRight
                }
                Text {
                    text: qsTr("%1 %2 · Playlist").arg(root.videoCount)
                          .arg(root.videoCount === 1 ? qsTr("video") : qsTr("videos"))
                    font.pixelSize: 11
                    color: PlazmaStyle.color.textSecondary
                }
            }

            Rectangle {
                Layout.preferredWidth: playAllText.implicitWidth + 30
                Layout.preferredHeight: 32
                radius: 16
                color: playAllMouse.containsMouse
                       ? PlazmaStyle.color.burntOrange
                       : PlazmaStyle.color.goldenApricot
                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "▶"; color: "#FFFFFF"; font.pixelSize: 11 }
                    Text {
                        id: playAllText
                        text: qsTr("Play all")
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: playAllMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.videoCount > 0
                    onClicked: {
                        const v = root.videos[0]
                        if (!v || !v.url) return
                        VideoFeedModel.setCurrentVideo(v)
                        PageController.goToPage(PageEnum.PagePlayer)
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                color: menuMouse.containsMouse ? PlazmaStyle.color.softAmber : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "⋮"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    color: PlazmaStyle.color.textSecondary
                }
                MouseArea {
                    id: menuMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: headerMenu.openAt(parent, parent.width / 2, parent.height)
                }
            }
        }
    }

    // Empty state
    ColumnLayout {
        visible: root.videoCount === 0
        anchors.centerIn: parent
        spacing: 10

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "♪"
            font.pixelSize: 52
            color: PlazmaStyle.color.textHint
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("This playlist is empty")
            font.pixelSize: 16
            font.weight: Font.DemiBold
            color: PlazmaStyle.color.textPrimary
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Right-click a video in the feed to add it here")
            font.pixelSize: 12
            color: PlazmaStyle.color.textSecondary
        }
    }

    // Video list. YouTube puts an index column on the left; we mirror that —
    // it makes the list feel ordered even though playlists default to
    // insertion-order (same as YouTube's default "Manual" sort).
    ListView {
        id: list
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        clip: true
        model: root.videos
        spacing: 4
        visible: root.videoCount > 0

        delegate: Rectangle {
            width: list.width
            height: 76
            radius: 10
            color: rowMouse.containsMouse ? PlazmaStyle.color.creamWhite : "transparent"
            border.color: rowMouse.containsMouse ? PlazmaStyle.color.inputBorder : "transparent"
            border.width: 1
            Behavior on color { ColorAnimation { duration: 100 } }

            property var entry: modelData

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 12

                Text {
                    Layout.preferredWidth: 22
                    horizontalAlignment: Text.AlignRight
                    text: (index + 1).toString()
                    font.pixelSize: 12
                    color: PlazmaStyle.color.textHint
                }

                // Thumbnail (16:9, ~80x45).
                Rectangle {
                    Layout.preferredWidth: 92
                    Layout.preferredHeight: 52
                    radius: 6
                    color: "#1A1626"
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: entry && entry.thumbnail ? entry.thumbnail : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: source !== ""
                        asynchronous: true
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !entry || !entry.thumbnail
                        text: "▶"
                        color: Qt.rgba(1, 1, 1, 0.5)
                        font.pixelSize: 18
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: entry && entry.title && entry.title.length > 0
                              ? entry.title : qsTr("Untitled")
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: PlazmaStyle.color.textPrimary
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: entry && entry.author ? entry.author : ""
                        font.pixelSize: 11
                        color: PlazmaStyle.color.textSecondary
                        elide: Text.ElideRight
                        visible: text.length > 0
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 14
                    color: rowMenuMouse.containsMouse ? PlazmaStyle.color.softAmber : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "⋮"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: PlazmaStyle.color.textSecondary
                    }
                    MouseArea {
                        id: rowMenuMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openRowMenu(parent, parent.width / 2, parent.height, entry)
                    }
                }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                z: -1

                onClicked: (m) => {
                    if (m.button === Qt.RightButton) {
                        root.openRowMenu(rowMouse, m.x, m.y, entry)
                        return
                    }
                    if (!entry || !entry.url) return
                    VideoFeedModel.setCurrentVideo(entry)
                    PageController.goToPage(PageEnum.PagePlayer)
                }
            }
        }
    }

    // ── Menus & dialogs ──────────────────────────────────────────────
    PlazmaPopupMenu {
        id: headerMenu
        actions: [
            { text: qsTr("Rename"), glyph: "✎", onTriggered: function() {
                renameDialog.openWith(root.playlistId, root.playlistName)
            }},
            { separator: true },
            { text: qsTr("Delete playlist"), glyph: "🗑", danger: true, onTriggered: function() {
                deleteConfirm.open()
            }}
        ]
    }

    PlazmaPopupMenu {
        id: rowMenu
        property var video: ({})
        property int downloadStatus: -1

        readonly property bool dlActive:    rowMenu.downloadStatus === 0
                                            || rowMenu.downloadStatus === 1
        readonly property bool dlCompleted: rowMenu.downloadStatus === 2
        readonly property bool dlFailed:    rowMenu.downloadStatus === 3

        actions: [
            { text: qsTr("Play"), glyph: "▶", onTriggered: function() {
                if (!rowMenu.video || !rowMenu.video.url) return
                VideoFeedModel.setCurrentVideo(rowMenu.video)
                PageController.goToPage(PageEnum.PagePlayer)
            }},
            { text: qsTr("Save to another playlist"), glyph: "+", onTriggered: function() {
                savePicker.openWith(rowMenu.video)
            }},
            {
                text: rowMenu.dlActive
                      ? qsTr("Downloading…")
                      : (rowMenu.dlCompleted
                         ? qsTr("Open downloaded video")
                         : (rowMenu.dlFailed
                            ? qsTr("Download video · retry")
                            : qsTr("Download video"))),
                glyph: rowMenu.dlCompleted ? "✓" : "↓",
                enabled: !rowMenu.dlActive,
                onTriggered: function() {
                    if (!rowMenu.video || !rowMenu.video.id) return
                    if (rowMenu.dlCompleted) {
                        DownloadsModel.openFile(rowMenu.video.id)
                        return
                    }
                    DownloadsModel.start(rowMenu.video)
                }
            },
            { separator: true },
            { text: qsTr("Remove from playlist"), glyph: "−", danger: true, onTriggered: function() {
                if (rowMenu.video && rowMenu.video.id) {
                    PlaylistsModel.removeVideoFromPlaylist(root.playlistId, rowMenu.video.id)
                }
            }}
        ]
    }

    function openRowMenu(anchor, px, py, video) {
        rowMenu.video = video || ({})
        const vid = video && video.id ? String(video.id) : ""
        rowMenu.downloadStatus = vid.length > 0 ? DownloadsModel.statusOf(vid) : -1
        rowMenu.openAt(anchor, px, py)
    }

    RenamePlaylistDialog {
        id: renameDialog
        parent: Overlay.overlay
    }

    SaveToPlaylistDialog {
        id: savePicker
        parent: Overlay.overlay
    }

    // Delete confirmation for the playlist itself.
    Popup {
        id: deleteConfirm
        parent: Overlay.overlay
        modal: true
        dim: true
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        implicitWidth: 340
        implicitHeight: 170

        onAboutToShow: {
            if (parent) {
                x = (parent.width - width) / 2
                y = (parent.height - height) / 2
            }
        }

        background: Rectangle {
            radius: 14
            color: PlazmaStyle.color.creamWhite
            border.color: PlazmaStyle.color.inputBorder
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 10
            anchors.margins: 18

            Text {
                Layout.fillWidth: true
                text: qsTr("Delete this playlist?")
                font.pixelSize: 15
                font.weight: Font.DemiBold
                color: PlazmaStyle.color.textPrimary
            }
            Text {
                Layout.fillWidth: true
                text: qsTr("“%1” and all its entries will be removed. Videos themselves stay in your feed.").arg(root.playlistName)
                font.pixelSize: 12
                color: PlazmaStyle.color.textSecondary
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
                    color: delCancelMouse.containsMouse ? PlazmaStyle.color.softAmber : "transparent"
                    border.color: PlazmaStyle.color.inputBorder
                    border.width: 1
                    Text { anchors.centerIn: parent; text: qsTr("Cancel"); font.pixelSize: 12; color: PlazmaStyle.color.textPrimary }
                    MouseArea { id: delCancelMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deleteConfirm.close() }
                }
                Rectangle {
                    Layout.preferredWidth: 92
                    Layout.preferredHeight: 32
                    radius: 16
                    color: delMouse.containsMouse ? "#B83131" : PlazmaStyle.color.errorRed
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text { anchors.centerIn: parent; text: qsTr("Delete"); color: "#FFFFFF"; font.pixelSize: 12; font.weight: Font.DemiBold }
                    MouseArea {
                        id: delMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            PlaylistsModel.deletePlaylist(root.playlistId)
                            deleteConfirm.close()
                            PageController.replacePage(PageEnum.PagePlaylists)
                        }
                    }
                }
            }
        }
    }

    // Toast (reuses the same pattern as the feed)
    Rectangle {
        id: toast
        property string message: ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        height: 36
        width: toastLabel.implicitWidth + 28
        radius: 18
        color: PlazmaStyle.color.darkCharcoal
        visible: opacity > 0.01
        opacity: 0.0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Text {
            id: toastLabel
            anchors.centerIn: parent
            text: toast.message
            color: "#FFFFFF"
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Timer { id: toastTimer; interval: 2200; onTriggered: toast.opacity = 0.0 }
    }

    Connections {
        target: PlaylistsModel
        function onNotify(message) {
            toast.message = message
            toast.opacity = 1.0
            toastTimer.restart()
        }
    }
}
