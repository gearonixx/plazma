import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import dev.gearonixx.plazma 1.0

import Style 1.0

// DownloadBar — compact single-row progress strip anchored to the bottom of
// the app window. Bound to DownloadsModel's latest* scalars, it collapses
// automatically a few seconds after a download finishes.
//
// Modeled on tdesktop's Ui::DownloadBar (ui/controls/download_bar.cpp): a
// thin rectangle sitting above the main content, a radial-style progress
// line, the filename on the left, an action on the right. The difference
// is that ours is a QML slide-in rather than a widget that owns its own
// paint event — fits the rest of the Plazma UI more naturally.
Rectangle {
    id: root

    // DownloadsModel statuses — kept in sync with DownloadsModel::Status
    // (see downloads_model.h). Copied here rather than bound to the enum
    // because Q_ENUM exposure through QML is annoying and this never changes.
    readonly property int statusQueued:      0
    readonly property int statusDownloading: 1
    readonly property int statusCompleted:   2
    readonly property int statusFailed:      3
    readonly property int statusCanceled:    4

    readonly property int currentStatus: DownloadsModel.latestStatus
    readonly property bool hasLatest: DownloadsModel.latestId.length > 0
    readonly property bool shouldShow: hasLatest && DownloadsModel.latestVisible

    // Slide-up animation: the bar lives outside the screen vertically when
    // hidden so it never steals hit-tests on the page below.
    readonly property int barHeight: 56
    height: shouldShow ? barHeight : 0
    visible: height > 0.5
    clip: true

    Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    color: currentStatus === statusFailed
           ? "#FDECEC"
           : (currentStatus === statusCompleted
              ? "#E9F7EF"
              : PlazmaStyle.color.creamWhite)
    Behavior on color { ColorAnimation { duration: 160 } }

    // Top hairline — same trick NavBar uses to separate from page content.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: PlazmaStyle.color.inputBorder
    }

    // Progress line — spans the full bar, sits underneath the text. For a
    // completed download the bar reads full; for a failure it's still painted
    // (useful debug cue) but muted.
    Rectangle {
        id: progressLine
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        height: 3
        width: parent.width * Math.max(0, Math.min(1, DownloadsModel.latestProgress))
        color: currentStatus === statusFailed
               ? PlazmaStyle.color.errorRed
               : (currentStatus === statusCompleted
                  ? "#0F9D58"
                  : PlazmaStyle.color.burntOrange)
        Behavior on width { NumberAnimation { duration: 140 } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 10
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        spacing: 12

        // Glyph slot: arrow while downloading, check when done, ! on fail.
        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 16
            color: root.currentStatus === root.statusFailed
                   ? Qt.rgba(1, 0.3, 0.3, 0.14)
                   : (root.currentStatus === root.statusCompleted
                      ? Qt.rgba(0.2, 0.7, 0.4, 0.18)
                      : PlazmaStyle.color.softAmber)

            Text {
                anchors.centerIn: parent
                text: {
                    if (root.currentStatus === root.statusFailed)    return "!"
                    if (root.currentStatus === root.statusCompleted) return "✓"
                    if (root.currentStatus === root.statusCanceled)  return "—"
                    return "↓"
                }
                font.pixelSize: 16
                font.weight: Font.DemiBold
                color: root.currentStatus === root.statusFailed
                       ? PlazmaStyle.color.errorRed
                       : (root.currentStatus === root.statusCompleted
                          ? "#0F9D58"
                          : PlazmaStyle.color.warmGold)
            }
        }

        // Title + status line. Kept to two small rows so the bar doesn't
        // balloon on mobile-sized windows (we cap width at 780 in main.qml).
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: {
                    const t = DownloadsModel.latestTitle
                    return (t && t.length > 0) ? t : qsTr("Video")
                }
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: PlazmaStyle.color.textPrimary
                elide: Text.ElideMiddle
                maximumLineCount: 1
            }

            Text {
                Layout.fillWidth: true
                text: {
                    if (root.currentStatus === root.statusFailed) {
                        const err = DownloadsModel.latestError
                        return err && err.length > 0
                               ? qsTr("Failed — %1").arg(err)
                               : qsTr("Download failed")
                    }
                    if (root.currentStatus === root.statusCompleted) {
                        return qsTr("Saved to %1 · %2")
                               .arg(DownloadsModel.downloadsFolder)
                               .arg(root.formatSize(DownloadsModel.latestTotal))
                    }
                    if (root.currentStatus === root.statusCanceled) {
                        return qsTr("Canceled")
                    }
                    // Active: "12.3 MB of 128 MB · 34%" style
                    const total = DownloadsModel.latestTotal
                    const recv  = DownloadsModel.latestReceived
                    if (total > 0) {
                        const pct = Math.round(DownloadsModel.latestProgress * 100)
                        return qsTr("%1 of %2 · %3%")
                               .arg(root.formatSize(recv))
                               .arg(root.formatSize(total))
                               .arg(pct)
                    }
                    return qsTr("%1 downloaded").arg(root.formatSize(recv))
                }
                font.pixelSize: 11
                color: root.currentStatus === root.statusFailed
                       ? PlazmaStyle.color.errorRed
                       : PlazmaStyle.color.textSecondary
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // Contextual action on the right — switches between "Cancel" while
        // active and "Open" after completion. Follows the YouTube download
        // panel convention: the primary inline action matches the state.
        Rectangle {
            id: actionBtn
            Layout.preferredHeight: 30
            Layout.preferredWidth: actionLabel.implicitWidth + 24
            radius: 15
            color: actionMouse.containsMouse
                   ? PlazmaStyle.color.warmGold
                   : PlazmaStyle.color.softAmber
            Behavior on color { ColorAnimation { duration: 120 } }
            visible: root.currentStatus !== root.statusCanceled

            Text {
                id: actionLabel
                anchors.centerIn: parent
                text: {
                    if (root.currentStatus === root.statusCompleted) return qsTr("Open")
                    if (root.currentStatus === root.statusFailed)    return qsTr("Retry")
                    return qsTr("Cancel")
                }
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: actionMouse.containsMouse
                       ? "#FFFFFF"
                       : PlazmaStyle.color.warmGold
            }

            MouseArea {
                id: actionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const id = DownloadsModel.latestId
                    if (id.length === 0) return

                    if (root.currentStatus === root.statusCompleted) {
                        DownloadsModel.openFile(id)
                        DownloadsModel.dismissLatest()
                        return
                    }
                    if (root.currentStatus === root.statusFailed) {
                        // retry() re-uses the cached URL/mime on the entry so
                        // we don't have to stash the video payload in QML.
                        DownloadsModel.retry(id)
                        return
                    }
                    // Active → cancel.
                    DownloadsModel.cancel(id)
                }
            }
        }

        // "Show in folder" — only useful post-completion but also handy on
        // failure to inspect whatever was written.
        Rectangle {
            Layout.preferredHeight: 30
            Layout.preferredWidth: 30
            radius: 15
            color: folderMouse.containsMouse ? PlazmaStyle.color.softAmber : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
            visible: root.currentStatus === root.statusCompleted
                     || root.currentStatus === root.statusFailed

            Text {
                anchors.centerIn: parent
                text: "📁"
                font.pixelSize: 14
            }

            MouseArea {
                id: folderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: DownloadsModel.openFolder(DownloadsModel.latestId)
                ToolTip.visible: folderMouse.containsMouse
                ToolTip.text: qsTr("Show in folder")
                ToolTip.delay: 350
            }
        }

        // Dismiss chip. Hides the bar without cancelling the transfer.
        Rectangle {
            Layout.preferredHeight: 30
            Layout.preferredWidth: 30
            radius: 15
            color: closeMouse.containsMouse ? PlazmaStyle.color.softAmber : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "×"
                font.pixelSize: 18
                color: PlazmaStyle.color.textSecondary
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: DownloadsModel.dismissLatest()
            }
        }
    }

    function formatSize(bytes) {
        if (!bytes || bytes <= 0) return "0 B"
        if (bytes < 1024) return bytes + " B"
        var kb = bytes / 1024
        if (kb < 1024) return kb.toFixed(0) + " KB"
        var mb = kb / 1024
        if (mb < 1024) return mb.toFixed(1) + " MB"
        return (mb / 1024).toFixed(2) + " GB"
    }
}
