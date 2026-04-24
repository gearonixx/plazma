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

    NavBar {
        id: nav
        activePage: PageEnum.PagePlaylists
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
    }

    // Sticky bar below the nav: title + sort hint + "New playlist" action.
    Rectangle {
        id: heading
        anchors.top: nav.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 52
        color: PlazmaStyle.color.warmWhite

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 16
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: qsTr("Playlists")
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    color: PlazmaStyle.color.textPrimary
                }
                Text {
                    text: qsTr("Sorted A to Z · %1 %2")
                            .arg(PlaylistsModel.count)
                            .arg(PlaylistsModel.count === 1 ? qsTr("playlist") : qsTr("playlists"))
                    font.pixelSize: 11
                    color: PlazmaStyle.color.textSecondary
                }
            }

            Rectangle {
                Layout.preferredWidth: newBtnText.implicitWidth + 30
                Layout.preferredHeight: 32
                radius: 16
                color: newMouse.containsMouse
                       ? PlazmaStyle.color.burntOrange
                       : PlazmaStyle.color.goldenApricot
                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "+"
                        color: "#FFFFFF"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }
                    Text {
                        id: newBtnText
                        text: qsTr("New playlist")
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }

                MouseArea {
                    id: newMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: renameDialog.openWith("", "")
                }
            }
        }
    }

    // ── Empty state ──────────────────────────────────────────────────
    ColumnLayout {
        visible: PlaylistsModel.count === 0
        anchors.centerIn: parent
        spacing: 14

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 96; height: 96; radius: 48
            color: PlazmaStyle.color.softAmber

            Text {
                anchors.centerIn: parent
                text: "♪"
                font.pixelSize: 44
                color: PlazmaStyle.color.warmGold
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("No playlists yet")
            font.pixelSize: 18
            font.weight: Font.DemiBold
            color: PlazmaStyle.color.textPrimary
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Save videos from the feed to keep them in one place")
            font.pixelSize: 12
            color: PlazmaStyle.color.textSecondary
        }
    }

    // ── Playlist grid (A-Z) ──────────────────────────────────────────
    GridView {
        id: grid
        anchors.top: heading.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 6
        anchors.bottomMargin: 16

        visible: PlaylistsModel.count > 0
        clip: true
        model: PlaylistsModel

        readonly property int columns: Math.max(1, Math.floor(width / 240))
        cellWidth: width / columns
        cellHeight: cellWidth * 9 / 16 + 66

        delegate: Item {
            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                id: card
                anchors.fill: parent
                anchors.margins: 8
                radius: 12
                color: cardMouse.containsMouse
                       ? PlazmaStyle.color.creamWhite
                       : PlazmaStyle.color.creamWhite
                border.color: cardMouse.containsMouse
                              ? PlazmaStyle.color.honeyYellow
                              : PlazmaStyle.color.inputBorder
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 120 } }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // 2×2 mosaic cover. If fewer than 4 thumbs, we stretch
                    // the first one to fill — same treatment YouTube uses
                    // for newly-created playlists.
                    Rectangle {
                        id: cover
                        Layout.fillWidth: true
                        Layout.preferredHeight: width * 9 / 16
                        radius: 12
                        color: "#1A1626"
                        clip: true

                        property var thumbs: model.thumbnails || []

                        // Single large thumb
                        Image {
                            anchors.fill: parent
                            source: cover.thumbs.length === 1 ? cover.thumbs[0] : ""
                            visible: cover.thumbs.length === 1
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }

                        // Mosaic when 2-4 thumbs available.
                        Grid {
                            anchors.fill: parent
                            visible: cover.thumbs.length >= 2
                            columns: 2
                            rows: 2
                            spacing: 2

                            Repeater {
                                model: Math.min(4, cover.thumbs.length)
                                delegate: Item {
                                    width: (cover.width - 2) / 2
                                    height: (cover.height - 2) / 2
                                    clip: true
                                    Image {
                                        anchors.fill: parent
                                        source: cover.thumbs[index]
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                    }
                                }
                            }
                        }

                        // Video count badge (bottom-right)
                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 8
                            width: countLabel.implicitWidth + 16
                            height: 22
                            radius: 4
                            color: Qt.rgba(0, 0, 0, 0.74)

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: "≡"
                                    color: "#FFFFFF"
                                    font.pixelSize: 11
                                }
                                Text {
                                    id: countLabel
                                    text: qsTr("%1 videos").arg(model.videoCount)
                                    color: "#FFFFFF"
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        // Big ▶ overlay on hover — click plays all from the
                        // first video in the playlist.
                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: Qt.rgba(0, 0, 0, 0.38)
                            opacity: cardMouse.containsMouse ? 1.0 : 0.0
                            visible: opacity > 0.01
                            Behavior on opacity { NumberAnimation { duration: 140 } }

                            Text {
                                anchors.centerIn: parent
                                text: "▶"
                                color: "#FFFFFF"
                                font.pixelSize: 28
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: cover.thumbs.length === 0
                            text: "♪"
                            color: Qt.rgba(1, 1, 1, 0.4)
                            font.pixelSize: 32
                        }
                    }

                    // Title + options button row
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56

                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.right: optionsBtn.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12
                            anchors.rightMargin: 4
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: model.name
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: PlazmaStyle.color.textPrimary
                                elide: Text.ElideRight
                            }
                            Text {
                                text: qsTr("Playlist")
                                font.pixelSize: 11
                                color: PlazmaStyle.color.textSecondary
                            }
                        }

                        Rectangle {
                            id: optionsBtn
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: 8
                            width: 28
                            height: 28
                            radius: 14
                            color: optionsMouse.containsMouse
                                   ? PlazmaStyle.color.softAmber
                                   : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "⋮"
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                color: PlazmaStyle.color.textSecondary
                            }

                            MouseArea {
                                id: optionsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton
                                onClicked: root.showPlaylistMenu(optionsBtn,
                                                                 optionsBtn.width / 2,
                                                                 optionsBtn.height,
                                                                 model.id, model.name)
                            }
                        }
                    }
                }

                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: (m) => {
                        if (m.button === Qt.RightButton) {
                            root.showPlaylistMenu(cardMouse, m.x, m.y, model.id, model.name)
                            return
                        }
                        PlaylistsModel.openPlaylist(model.id)
                        PageController.goToPage(PageEnum.PagePlaylistDetail)
                    }

                    // z-ordered below the optionsBtn so the button swallows
                    // its own clicks — QML hit-testing respects sibling order
                    // and the Rectangle with MouseArea is declared later.
                    z: -1
                }
            }
        }
    }

    // ── Per-card menu + dialogs ──────────────────────────────────────
    PlazmaPopupMenu {
        id: playlistMenu
        property string playlistId: ""
        property string playlistName: ""
        actions: [
            {
                text: qsTr("Open"),
                glyph: "▶",
                onTriggered: function() {
                    PlaylistsModel.openPlaylist(playlistMenu.playlistId)
                    PageController.goToPage(PageEnum.PagePlaylistDetail)
                }
            },
            {
                text: qsTr("Rename"),
                glyph: "✎",
                onTriggered: function() {
                    renameDialog.openWith(playlistMenu.playlistId, playlistMenu.playlistName)
                }
            },
            { separator: true },
            {
                text: qsTr("Delete playlist"),
                glyph: "🗑",
                danger: true,
                onTriggered: function() {
                    deleteConfirm.playlistId = playlistMenu.playlistId
                    deleteConfirm.playlistName = playlistMenu.playlistName
                    deleteConfirm.open()
                }
            }
        ]
    }

    function showPlaylistMenu(anchor, px, py, id, name) {
        playlistMenu.playlistId = id
        playlistMenu.playlistName = name
        playlistMenu.openAt(anchor, px, py)
    }

    RenamePlaylistDialog {
        id: renameDialog
        parent: Overlay.overlay
    }

    // Delete confirmation — small inline Popup, no need for another dialog file.
    Popup {
        id: deleteConfirm
        parent: Overlay.overlay
        modal: true
        dim: true
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property string playlistId: ""
        property string playlistName: ""

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
                text: qsTr("“%1” and all its entries will be removed. Videos themselves stay in your feed.").arg(deleteConfirm.playlistName)
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
                            PlaylistsModel.deletePlaylist(deleteConfirm.playlistId)
                            deleteConfirm.close()
                        }
                    }
                }
            }
        }
    }

    // Tiny toast — PlaylistsModel emits `notify` on saves/errors. Keeps
    // users aware of adds/removes without having to open the dialog again.
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

        Timer {
            id: toastTimer
            interval: 2200
            onTriggered: toast.opacity = 0.0
        }
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
