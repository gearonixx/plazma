import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import dev.gearonixx.plazma 1.0

import "../Controls"

import PageEnum 1.0
import Style 1.0

Page {
    id: root

    property string statusText: ""
    property bool statusIsError: false

    background: Rectangle { color: PlazmaStyle.color.warmWhite }

    Connections {
        target: FileDialogModel
        function onFileSelected(path) {
            root.statusIsError = false
            root.statusText = qsTr("Uploading %1…").arg(path.split("/").pop())
        }
    }

    Connections {
        target: VideoFeedModel
        function onUploadFinished(filename) {
            root.statusIsError = false
            root.statusText = qsTr("Uploaded %1 — opening feed…").arg(filename)
            goToFeed.start()
        }
        function onUploadFailed(statusCode, error) {
            root.statusIsError = true
            root.statusText = qsTr("Upload failed (%1): %2").arg(statusCode).arg(error)
        }
    }

    Timer {
        id: goToFeed
        interval: 600
        repeat: false
        onTriggered: PageController.replacePage(PageEnum.PageFeed)
    }

    NavBar {
        id: nav
        activePage: PageEnum.PageUpload
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
    }

    // Drag-and-drop
    DropArea {
        anchors.top: nav.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        onDropped: function(drop) {
            if (drop.hasUrls && drop.urls.length > 0) {
                // Mirror the existing picker flow by prompting the user.
                FileDialogModel.openFilePicker()
                drop.accept()
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: parent.containsDrag
            color: Qt.rgba(0, 0, 0, 0.55)
            z: 100

            Text {
                anchors.centerIn: parent
                text: qsTr("Drop video to upload")
                color: "#FFFFFF"
                font.pixelSize: 24
                font.weight: Font.Bold
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 440)
            spacing: 16

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 140; height: 140; radius: 70
                color: PlazmaStyle.color.softAmber

                Text {
                    anchors.centerIn: parent
                    text: "\u2B06"
                    font.pixelSize: 60
                    color: PlazmaStyle.color.warmGold
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Upload a video")
                font.pixelSize: 22
                font.weight: Font.Bold
                color: PlazmaStyle.color.textPrimary
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                text: qsTr("Click below to pick a file, or drop one here.\nWe'll push it to the server and add it to the feed.")
                font.pixelSize: 13
                color: PlazmaStyle.color.textSecondary
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                lineHeight: 1.4
            }

            BasicButtonType {
                Layout.fillWidth: true
                Layout.preferredHeight: 50

                defaultColor: PlazmaStyle.color.goldenApricot
                hoveredColor: PlazmaStyle.color.warmGold
                pressedColor: PlazmaStyle.color.burntOrange
                textColor: "#FFFFFF"

                text: qsTr("Pick a file…")
                font.pixelSize: 16
                font.weight: Font.DemiBold

                clickedFunc: function() { FileDialogModel.openFilePicker() }
            }

            BasicButtonType {
                Layout.fillWidth: true
                Layout.preferredHeight: 44

                defaultColor: "transparent"
                hoveredColor: PlazmaStyle.color.softAmber
                pressedColor: PlazmaStyle.color.warmGold
                textColor: PlazmaStyle.color.textSecondary

                text: qsTr("Back to feed")
                font.pixelSize: 14
                font.weight: Font.Medium

                clickedFunc: function() { PageController.replacePage(PageEnum.PageFeed) }
            }

            Rectangle {
                visible: root.statusText.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: statusLabel.implicitHeight + 20
                radius: 8
                color: root.statusIsError ? "#F8D7DA" : PlazmaStyle.color.softAmber
                border.color: root.statusIsError ? "#F5C2C7" : PlazmaStyle.color.warmGold
                border.width: 1

                Text {
                    id: statusLabel
                    anchors.fill: parent
                    anchors.margins: 10
                    text: root.statusText
                    color: root.statusIsError ? "#842029" : PlazmaStyle.color.textPrimary
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
