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

    Component.onCompleted: VideoFeedModel.refresh()

    NavBar {
        id: nav
        activePage: PageEnum.PageFeed
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
    }

    // Status strip (loading / error)
    Rectangle {
        id: statusStrip
        anchors.top: nav.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: visible ? 28 : 0
        visible: VideoFeedModel.loading || VideoFeedModel.errorMessage.length > 0
        color: VideoFeedModel.errorMessage.length > 0
               ? "#F8D7DA"
               : PlazmaStyle.color.softAmber
        z: 5

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

            BusyIndicator {
                visible: VideoFeedModel.loading
                running: visible
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
            }

            Text {
                Layout.fillWidth: true
                text: VideoFeedModel.errorMessage.length > 0
                      ? qsTr("Failed to load videos: %1").arg(VideoFeedModel.errorMessage)
                      : qsTr("Loading feed…")
                font.pixelSize: 11
                color: VideoFeedModel.errorMessage.length > 0
                       ? "#842029"
                       : PlazmaStyle.color.textPrimary
                elide: Text.ElideRight
            }

            Text {
                visible: VideoFeedModel.errorMessage.length > 0
                text: qsTr("Retry")
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: PlazmaStyle.color.burntOrange

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: VideoFeedModel.refresh()
                }
            }
        }
    }

    // Empty state
    ColumnLayout {
        visible: !VideoFeedModel.loading
                 && VideoFeedModel.count === 0
                 && VideoFeedModel.errorMessage.length === 0
        anchors.centerIn: parent
        spacing: 14

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 96; height: 96; radius: 48
            color: PlazmaStyle.color.softAmber

            Text {
                anchors.centerIn: parent
                text: "\uD83C\uDFAC"
                font.pixelSize: 40
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("No videos yet")
            font.pixelSize: 18
            font.weight: Font.DemiBold
            color: PlazmaStyle.color.textPrimary
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Upload one to get the feed started")
            font.pixelSize: 13
            color: PlazmaStyle.color.textSecondary
        }

        BasicButtonType {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 160
            Layout.preferredHeight: 44

            defaultColor: PlazmaStyle.color.goldenApricot
            hoveredColor: PlazmaStyle.color.warmGold
            pressedColor: PlazmaStyle.color.burntOrange
            textColor: "#FFFFFF"

            text: qsTr("Upload video")
            font.pixelSize: 13
            font.weight: Font.DemiBold

            clickedFunc: function() { PageController.replacePage(PageEnum.PageUpload) }
        }
    }

    // Grid of videos
    GridView {
        id: grid
        anchors.top: statusStrip.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 12
        visible: VideoFeedModel.count > 0

        readonly property int cardMinWidth: 240
        readonly property int columns: Math.max(1, Math.floor(width / cardMinWidth))

        cellWidth: width / columns
        cellHeight: cellWidth * 9 / 16 + 64

        clip: true
        model: VideoFeedModel

        delegate: Item {
            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                radius: 10
                color: PlazmaStyle.color.creamWhite
                border.color: PlazmaStyle.color.inputBorder
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Thumbnail
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: width * 9 / 16
                        color: "#000000"
                        radius: 10
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: model.thumbnail
                            visible: model.thumbnail && model.thumbnail.length > 0
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !model.thumbnail || model.thumbnail.length === 0
                            text: "\u25B6"
                            color: "#FFFFFF"
                            font.pixelSize: 40
                            opacity: 0.7
                        }

                        Rectangle {
                            visible: model.size > 0
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 8
                            height: 18
                            width: sizeText.implicitWidth + 12
                            radius: 9
                            color: PlazmaStyle.color.translucentMidnightBlack

                            Text {
                                id: sizeText
                                anchors.centerIn: parent
                                text: root.formatSize(model.size)
                                color: "#FFFFFF"
                                font.pixelSize: 10
                            }
                        }
                    }

                    // Title + author
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        Layout.topMargin: 8
                        Layout.bottomMargin: 10
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: model.title && model.title.length > 0
                                  ? model.title
                                  : qsTr("Untitled")
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: PlazmaStyle.color.textPrimary
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: model.author && model.author.length > 0
                                  ? model.author
                                  : (model.createdAt || "")
                            font.pixelSize: 11
                            color: PlazmaStyle.color.textSecondary
                            elide: Text.ElideRight
                            visible: text.length > 0
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!model.url || model.url.length === 0) return
                        VideoFeedModel.setCurrent(model.url, model.title || "")
                        PageController.replacePage(PageEnum.PagePlayer)
                    }
                }
            }
        }
    }

    function formatSize(bytes) {
        if (!bytes || bytes <= 0) return ""
        const kb = bytes / 1024
        if (kb < 1024) return kb.toFixed(0) + " KB"
        const mb = kb / 1024
        if (mb < 1024) return mb.toFixed(1) + " MB"
        return (mb / 1024).toFixed(2) + " GB"
    }
}
