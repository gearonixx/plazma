import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qt.labs.settings

import dev.gearonixx.plazma 1.0

import "../Controls"

import PageEnum 1.0
import Style 1.0

Page {
    id: root

    property bool hasVideo: player.hasMedia
    property string currentTitle: VideoFeedModel.currentTitle
    property string lastError: ""
    property bool mouseIdle: false
    property string lastToast: ""
    property bool chromeVisible: !root.hasVideo
                                 || player.paused
                                 || stageMouse.containsMouse
                                 || topChromeHover.containsMouse
                                 || bottomChromeHover.containsMouse
                                 || controlsTimer.running

    background: Rectangle { color: "#050608" }

    Settings {
        id: persisted
        category: "player"
        property real volume: 100
        property bool muted: false
        property real speed: 1.0
        property bool loop: false
        property string hwdec: "auto-safe"
    }

    readonly property var hwdecModes: [
        { id: "auto-safe", label: qsTr("Automatic") },
        { id: "vaapi",     label: "VA-API" },
        { id: "nvdec",     label: "NVDEC" },
        { id: "no",        label: qsTr("Software (CPU)") }
    ]

    function hwdecLabel(id) {
        for (let i = 0; i < hwdecModes.length; ++i)
            if (hwdecModes[i].id === id) return hwdecModes[i].label
        return id
    }

    Component.onCompleted: {
        player.volume = persisted.volume
        player.muted = persisted.muted
        player.speed = persisted.speed
        player.loop = persisted.loop
        player.hwdec = persisted.hwdec

        if (VideoFeedModel.currentUrl.length > 0) {
            root.lastError = ""
            player.source = VideoFeedModel.currentUrl
        }
    }

    Connections {
        target: VideoFeedModel
        function onCurrentChanged() {
            if (VideoFeedModel.currentUrl.length > 0) {
                root.lastError = ""
                player.source = VideoFeedModel.currentUrl
            }
        }
    }

    Connections {
        target: FileDialogModel
        function onFileSelected(path) {
            root.lastError = ""
            const raw = path.startsWith("file://") ? path.slice(7) : path
            root.currentTitle = raw.split("/").pop()
            player.source = "file://" + raw
        }
    }

    Connections {
        target: player
        function onVolumeChanged() { persisted.volume = player.volume }
        function onMutedChanged()  { persisted.muted = player.muted }
        function onSpeedChanged()  { persisted.speed = player.speed; root.showToast(player.speed.toFixed(2) + "×") }
        function onLoopChanged()   { persisted.loop = player.loop }
        function onHwdecChanged()  { persisted.hwdec = player.hwdec }
        function onScreenshotSaved(path) { root.showToast(qsTr("Saved: %1").arg(path.split("/").pop())) }
        function onPlaybackError(msg)    { root.lastError = msg; root.showToast(qsTr("Error: %1").arg(msg)) }
        function onEndReached() { if (!player.loop) root.showToast(qsTr("End of video")) }
        function onFileLoaded() {
            const want = player.hwdec
            const got  = player.hwdecCurrent
            if (want !== "auto-safe" && want !== "no" && (got === "no" || got.length === 0)) {
                root.showToast(qsTr("HW %1 unavailable — using CPU").arg(root.hwdecLabel(want)))
            }
        }
    }

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0) return "0:00"
        const s = Math.floor(seconds)
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        const sec = s % 60
        const pad = function(n) { return n < 10 ? "0" + n : "" + n }
        return h > 0 ? h + ":" + pad(m) + ":" + pad(sec) : m + ":" + pad(sec)
    }

    function toggleFullscreen() {
        const win = root.Window.window
        if (!win) return
        win.visibility = (win.visibility === Window.FullScreen) ? Window.Windowed : Window.FullScreen
    }

    function showToast(text) {
        root.lastToast = text
        toastTimer.restart()
    }

    function goBack() {
        player.stop()
        VideoFeedModel.clearCurrent()
        PageController.replacePage(PageEnum.PageFeed)
    }

    Shortcut { sequence: "Space"; enabled: root.hasVideo; onActivated: player.playPause() }
    Shortcut { sequence: "K";     enabled: root.hasVideo; onActivated: player.playPause() }
    Shortcut { sequence: "Right"; enabled: root.hasVideo; onActivated: { player.seekRelative(5);  skipRight.pulse() } }
    Shortcut { sequence: "Left";  enabled: root.hasVideo; onActivated: { player.seekRelative(-5); skipLeft.pulse()  } }
    Shortcut { sequence: "L";     enabled: root.hasVideo; onActivated: { player.seekRelative(10); skipRight.pulse() } }
    Shortcut { sequence: "J";     enabled: root.hasVideo; onActivated: { player.seekRelative(-10); skipLeft.pulse() } }
    Shortcut { sequence: "Up";    enabled: root.hasVideo; onActivated: { player.volume = Math.min(100, player.volume + 5); root.showToast(qsTr("Volume %1%").arg(Math.round(player.volume))) } }
    Shortcut { sequence: "Down";  enabled: root.hasVideo; onActivated: { player.volume = Math.max(0, player.volume - 5); root.showToast(qsTr("Volume %1%").arg(Math.round(player.volume))) } }
    Shortcut { sequence: "M";     enabled: root.hasVideo; onActivated: { player.toggleMute(); root.showToast(player.muted ? qsTr("Muted") : qsTr("Unmuted")) } }
    Shortcut { sequence: "F";     enabled: root.hasVideo; onActivated: root.toggleFullscreen() }
    Shortcut { sequence: "Escape"; onActivated: {
        const win = root.Window.window
        if (win && win.visibility === Window.FullScreen) { win.visibility = Window.Windowed; return }
        root.goBack()
    } }
    Shortcut { sequence: ","; enabled: root.hasVideo; onActivated: player.frameBackStep() }
    Shortcut { sequence: "."; enabled: root.hasVideo; onActivated: player.frameStep() }
    Shortcut { sequence: "["; enabled: root.hasVideo; onActivated: player.speed = Math.max(0.25, player.speed - 0.25) }
    Shortcut { sequence: "]"; enabled: root.hasVideo; onActivated: player.speed = Math.min(4.0,  player.speed + 0.25) }
    Shortcut { sequence: "S"; enabled: root.hasVideo; onActivated: player.takeScreenshot() }
    Shortcut { sequence: "R"; enabled: root.hasVideo; onActivated: { player.toggleLoop(); root.showToast(player.loop ? qsTr("Loop on") : qsTr("Loop off")) } }
    Shortcut { sequence: "0"; enabled: root.hasVideo; onActivated: player.seekPercent(0) }
    Shortcut { sequence: "1"; enabled: root.hasVideo; onActivated: player.seekPercent(10) }
    Shortcut { sequence: "2"; enabled: root.hasVideo; onActivated: player.seekPercent(20) }
    Shortcut { sequence: "3"; enabled: root.hasVideo; onActivated: player.seekPercent(30) }
    Shortcut { sequence: "4"; enabled: root.hasVideo; onActivated: player.seekPercent(40) }
    Shortcut { sequence: "5"; enabled: root.hasVideo; onActivated: player.seekPercent(50) }
    Shortcut { sequence: "6"; enabled: root.hasVideo; onActivated: player.seekPercent(60) }
    Shortcut { sequence: "7"; enabled: root.hasVideo; onActivated: player.seekPercent(70) }
    Shortcut { sequence: "8"; enabled: root.hasVideo; onActivated: player.seekPercent(80) }
    Shortcut { sequence: "9"; enabled: root.hasVideo; onActivated: player.seekPercent(90) }

    Rectangle {
        id: stage
        anchors.fill: parent
        color: "#050608"
        clip: true

        MpvObject {
            id: player
            anchors.fill: parent
        }

        DropArea {
            anchors.fill: parent
            onDropped: function(drop) {
                if (drop.hasUrls && drop.urls.length > 0) {
                    const url = drop.urls[0].toString()
                    const p = url.startsWith("file://") ? url.slice(7) : url
                    root.currentTitle = p.split("/").pop()
                    root.lastError = ""
                    player.source = "file://" + p
                    drop.accept()
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: parent.containsDrag
                color: Qt.rgba(0.98, 0.70, 0.42, 0.15)
                border.color: PlazmaStyle.color.goldenApricot
                border.width: 3
                z: 200

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "\u2B07"
                        color: PlazmaStyle.color.goldenApricot
                        font.pixelSize: 56
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Drop to play")
                        color: "#FFFFFF"
                        font.pixelSize: 22
                        font.weight: Font.Bold
                    }
                }
            }
        }

        MouseArea {
            id: stageMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.hasVideo
            acceptedButtons: Qt.LeftButton
            cursorShape: root.mouseIdle ? Qt.BlankCursor : Qt.ArrowCursor

            onClicked: function(m) { player.playPause() }
            onDoubleClicked: function(m) {
                const third = width / 3
                if (m.x < third) {
                    player.seekRelative(-10); skipLeft.pulse()
                } else if (m.x > 2 * third) {
                    player.seekRelative(10); skipRight.pulse()
                } else {
                    root.toggleFullscreen()
                }
            }
            onPositionChanged: { controlsTimer.restart(); idleTimer.restart(); root.mouseIdle = false }
            onWheel: function(w) {
                const step = w.angleDelta.y > 0 ? 5 : -5
                if (player.muted && step > 0) player.muted = false
                player.volume = Math.max(0, Math.min(100, player.volume + step))
                root.showToast(qsTr("Volume %1%").arg(Math.round(player.volume)))
            }
        }

        Timer { id: controlsTimer; interval: 2800; repeat: false; running: root.hasVideo && !player.paused }
        Timer { id: idleTimer; interval: 3500; repeat: false; onTriggered: if (root.hasVideo && !player.paused) root.mouseIdle = true }

        SkipIndicator { id: skipLeft;  direction: -1; anchors.left:  parent.left;  anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 60  }
        SkipIndicator { id: skipRight; direction:  1; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: 60 }

        // ========================================================= Empty state
        Item {
            anchors.fill: parent
            visible: !root.hasVideo && !player.loading && root.lastError.length === 0

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 64, 460)
                height: emptyCol.implicitHeight + 56
                radius: 20
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                ColumnLayout {
                    id: emptyCol
                    anchors.fill: parent
                    anchors.margins: 28
                    spacing: 14

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 72; height: 72; radius: 36
                        color: PlazmaStyle.color.softGoldenApricot

                        Text {
                            anchors.centerIn: parent
                            text: "\u25B6"
                            font.pixelSize: 32
                            color: PlazmaStyle.color.goldenApricot
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Nothing playing")
                        color: "#FFFFFF"
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        text: qsTr("Pick a video from the feed, drop a file here, or open one from disk.")
                        color: PlazmaStyle.color.cloudyGray
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        lineHeight: 1.45
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 6
                        spacing: 10

                        PillButton {
                            label: qsTr("Back to feed")
                            primary: false
                            onTriggered: root.goBack()
                        }

                        PillButton {
                            label: qsTr("Open local file")
                            primary: true
                            onTriggered: FileDialogModel.openFilePicker()
                        }
                    }
                }
            }
        }

        // ========================================================= Error state
        Item {
            anchors.fill: parent
            visible: root.lastError.length > 0 && !player.loading

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 64, 460)
                height: errCol.implicitHeight + 48
                radius: 20
                color: Qt.rgba(0.85, 0.25, 0.25, 0.10)
                border.color: Qt.rgba(0.85, 0.25, 0.25, 0.45)
                border.width: 1

                ColumnLayout {
                    id: errCol
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 12

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "\u26A0"
                        color: "#FF8E8E"
                        font.pixelSize: 38
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Couldn't play this video")
                        color: "#FFFFFF"
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        text: root.lastError
                        color: PlazmaStyle.color.cloudyGray
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 4
                        spacing: 10

                        PillButton {
                            label: qsTr("Back to feed")
                            primary: false
                            onTriggered: root.goBack()
                        }

                        PillButton {
                            label: qsTr("Retry")
                            primary: true
                            onTriggered: {
                                const url = VideoFeedModel.currentUrl.length > 0
                                            ? VideoFeedModel.currentUrl
                                            : player.source
                                root.lastError = ""
                                if (url && url.length > 0) {
                                    player.source = ""
                                    player.source = url
                                }
                            }
                        }
                    }
                }
            }
        }

        BusyIndicator {
            anchors.centerIn: parent
            running: player.loading
            visible: running
            width: 56; height: 56
        }

        // ========================================================= Toast
        Rectangle {
            visible: toastTimer.running
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 96
            width: Math.min(toastText.implicitWidth + 32, stage.width - 40)
            height: 38
            radius: 19
            color: PlazmaStyle.color.translucentMidnightBlack
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            opacity: toastTimer.running ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Text {
                id: toastText
                anchors.centerIn: parent
                text: root.lastToast
                color: "#FFFFFF"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Timer { id: toastTimer; interval: 1500; repeat: false }
        }

        // ========================================================= Top chrome (floating)
        Item {
            id: topChrome
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 84

            opacity: root.chromeVisible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.65) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            MouseArea {
                id: topChromeHover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                propagateComposedEvents: true
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 14
                anchors.bottomMargin: 14
                spacing: 14

                // Pretty back button — pill, chevron + label, subtle shadow
                Rectangle {
                    id: backBtn
                    Layout.preferredHeight: 40
                    Layout.preferredWidth: backRow.implicitWidth + 24
                    radius: 20

                    color: backMouse.pressed
                           ? Qt.rgba(1, 1, 1, 0.26)
                           : (backMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.10))
                    border.color: Qt.rgba(1, 1, 1, 0.14)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on scale { NumberAnimation { duration: 140 } }
                    scale: backMouse.pressed ? 0.96 : 1.0

                    RowLayout {
                        id: backRow
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "\u2039"
                            color: "#FFFFFF"
                            font.pixelSize: 22
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: qsTr("Back")
                            color: "#FFFFFF"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                    }

                    ToolTip.visible: backMouse.containsMouse
                    ToolTip.text: qsTr("Back to feed  (Esc)")
                    ToolTip.delay: 500

                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.goBack()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: root.currentTitle.length > 0 ? root.currentTitle : qsTr("Player")
                        color: "#FFFFFF"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: player.videoWidth > 0
                        text: {
                            const res = player.videoWidth + " × " + player.videoHeight
                            const codec = player.videoCodec.length > 0 ? "  ·  " + player.videoCodec : ""
                            const hw = player.hwdecCurrent.length > 0 && player.hwdecCurrent !== "no"
                                       ? "  ·  " + player.hwdecCurrent.toUpperCase() : ""
                            return res + codec + hw
                        }
                        color: PlazmaStyle.color.cloudyGray
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }

                GhostIcon {
                    glyph: "\u2B06"
                    tip: qsTr("Open local file")
                    onTriggered: FileDialogModel.openFilePicker()
                }

                GhostIcon {
                    glyph: "\u26F6"
                    tip: qsTr("Fullscreen  (F)")
                    onTriggered: root.toggleFullscreen()
                }
            }
        }

        // ========================================================= Bottom chrome
        Item {
            id: overlay
            visible: root.hasVideo
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 132

            opacity: root.chromeVisible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.85) }
                }
            }

            MouseArea {
                id: bottomChromeHover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                propagateComposedEvents: true
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                anchors.bottomMargin: 14
                spacing: 2

                Slider {
                    id: seekBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    from: 0
                    to: player.duration > 0 ? player.duration : 1
                    value: player.position
                    onMoved: player.seek(value)

                    background: Rectangle {
                        x: seekBar.leftPadding
                        y: seekBar.topPadding + seekBar.availableHeight / 2 - height / 2
                        width: seekBar.availableWidth
                        height: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.18)

                        Rectangle {
                            visible: player.bufferedPosition > 0 && player.duration > 0
                            width: parent.width * Math.min(1, player.bufferedPosition / player.duration)
                            height: parent.height
                            radius: parent.radius
                            color: Qt.rgba(1, 1, 1, 0.35)
                        }

                        Rectangle {
                            width: seekBar.visualPosition * parent.width
                            height: parent.height
                            radius: parent.radius
                            color: PlazmaStyle.color.goldenApricot
                        }
                    }

                    handle: Rectangle {
                        x: seekBar.leftPadding + seekBar.visualPosition * (seekBar.availableWidth - width)
                        y: seekBar.topPadding + seekBar.availableHeight / 2 - height / 2
                        width: seekBar.pressed ? 16 : 13
                        height: width
                        radius: width / 2
                        color: PlazmaStyle.color.warmGold
                        border.color: "#FFFFFF"
                        border.width: 2
                        Behavior on width { NumberAnimation { duration: 120 } }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    CircleButton {
                        diameter: 42
                        glyph: player.paused ? "\u25B6" : "\u275A\u275A"
                        bg: PlazmaStyle.color.goldenApricot
                        bgHover: PlazmaStyle.color.warmGold
                        bgPressed: PlazmaStyle.color.burntOrange
                        onClicked: player.playPause()
                    }

                    CircleButton {
                        visible: player.paused
                        diameter: 28
                        glyph: "\u23EA"
                        bg: "transparent"; bgHover: Qt.rgba(1, 1, 1, 0.16)
                        onClicked: player.frameBackStep()
                    }
                    CircleButton {
                        visible: player.paused
                        diameter: 28
                        glyph: "\u23E9"
                        bg: "transparent"; bgHover: Qt.rgba(1, 1, 1, 0.16)
                        onClicked: player.frameStep()
                    }

                    Text {
                        text: root.formatTime(player.position) + "  /  " + root.formatTime(player.duration)
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        Layout.minimumWidth: 108
                        Layout.leftMargin: 4
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredHeight: 30
                        Layout.preferredWidth: speedText.implicitWidth + 22
                        radius: 15
                        color: speedMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                        border.color: Qt.rgba(1, 1, 1, 0.14)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            id: speedText
                            anchors.centerIn: parent
                            text: player.speed.toFixed(player.speed % 1 === 0 ? 0 : 2) + "×"
                            color: "#FFFFFF"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: speedMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: speedMenu.open()
                        }

                        Menu {
                            id: speedMenu
                            y: -implicitHeight - 4
                            Repeater {
                                model: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
                                MenuItem {
                                    text: modelData.toFixed(modelData % 1 === 0 ? 0 : 2) + "×" +
                                          (Math.abs(modelData - player.speed) < 0.01 ? "  \u2713" : "")
                                    onTriggered: player.speed = modelData
                                }
                            }
                        }
                    }

                    CircleButton {
                        diameter: 32
                        glyph: "\u21BB"
                        bg: player.loop ? PlazmaStyle.color.goldenApricot : "transparent"
                        bgHover: player.loop ? PlazmaStyle.color.warmGold : Qt.rgba(1, 1, 1, 0.16)
                        onClicked: { player.toggleLoop(); root.showToast(player.loop ? qsTr("Loop on") : qsTr("Loop off")) }
                    }

                    CircleButton {
                        diameter: 32
                        glyph: (player.muted || player.volume === 0) ? "\uD83D\uDD07" : "\uD83D\uDD0A"
                        bg: "transparent"; bgHover: Qt.rgba(1, 1, 1, 0.16)
                        onClicked: player.toggleMute()
                    }

                    Slider {
                        id: volumeSlider
                        Layout.preferredWidth: 90
                        from: 0; to: 100
                        value: player.muted ? 0 : player.volume
                        onMoved: {
                            if (player.muted && value > 0) player.muted = false
                            player.volume = value
                        }

                        background: Rectangle {
                            x: volumeSlider.leftPadding
                            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                            width: volumeSlider.availableWidth
                            height: 3; radius: 2
                            color: Qt.rgba(1, 1, 1, 0.18)

                            Rectangle {
                                width: volumeSlider.visualPosition * parent.width
                                height: parent.height; radius: parent.radius
                                color: "#FFFFFF"
                            }
                        }

                        handle: Rectangle {
                            x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                            width: 10; height: 10; radius: 5
                            color: "#FFFFFF"
                        }
                    }

                    CircleButton {
                        diameter: 32
                        glyph: "\u22EE"
                        bg: "transparent"; bgHover: Qt.rgba(1, 1, 1, 0.16)
                        onClicked: moreMenu.open()

                        Menu {
                            id: moreMenu
                            y: -implicitHeight - 4

                            MenuItem {
                                enabled: false
                                text: {
                                    const hw = player.hwdecCurrent
                                    const hwLabel = (!hw || hw === "no") ? qsTr("CPU") : hw.toUpperCase()
                                    const codec = player.videoCodec.length > 0 ? player.videoCodec : "—"
                                    return qsTr("Decoder: %1  ·  %2").arg(hwLabel).arg(codec)
                                }
                            }

                            MenuSeparator {}

                            MenuItem {
                                text: qsTr("Open local file")
                                onTriggered: FileDialogModel.openFilePicker()
                            }

                            MenuItem {
                                text: qsTr("Take screenshot")
                                onTriggered: player.takeScreenshot()
                            }

                            MenuSeparator {}

                            Menu {
                                title: qsTr("Audio track")
                                enabled: player.audioTracks.length > 0
                                Repeater {
                                    model: player.audioTracks
                                    MenuItem {
                                        text: (modelData.title || qsTr("Track %1").arg(modelData.id))
                                              + (modelData.selected ? "  \u2713" : "")
                                        onTriggered: player.setAudioTrack(modelData.id)
                                    }
                                }
                            }

                            Menu {
                                title: qsTr("Subtitles")
                                MenuItem {
                                    text: qsTr("Off")
                                    onTriggered: player.setSubtitleTrack(0)
                                }
                                Repeater {
                                    model: player.subtitleTracks
                                    MenuItem {
                                        text: (modelData.title || qsTr("Track %1").arg(modelData.id))
                                              + (modelData.selected ? "  \u2713" : "")
                                        onTriggered: player.setSubtitleTrack(modelData.id)
                                    }
                                }
                            }

                            Menu {
                                title: qsTr("Hardware acceleration")
                                Repeater {
                                    model: root.hwdecModes
                                    MenuItem {
                                        text: modelData.label +
                                              (modelData.id === player.hwdec ? "  \u2713" : "")
                                        onTriggered: player.hwdec = modelData.id
                                    }
                                }
                            }
                        }
                    }

                    CircleButton {
                        diameter: 32
                        glyph: "\u26F6"
                        bg: "transparent"; bgHover: Qt.rgba(1, 1, 1, 0.16)
                        onClicked: root.toggleFullscreen()
                    }
                }
            }
        }
    }

    // ==================================================== Reusable components
    component CircleButton : Rectangle {
        id: btn
        property int diameter: 32
        property string glyph: ""
        property color bg: "transparent"
        property color bgHover: Qt.rgba(1, 1, 1, 0.16)
        property color bgPressed: Qt.rgba(1, 1, 1, 0.28)
        signal clicked()

        Layout.preferredWidth: diameter
        Layout.preferredHeight: diameter
        width: diameter; height: diameter
        radius: diameter / 2
        color: mouse.pressed ? bgPressed : (mouse.containsMouse ? bgHover : bg)

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 120 } }
        scale: mouse.pressed ? 0.94 : 1.0

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: "#FFFFFF"
            font.pixelSize: Math.max(10, btn.diameter * 0.38)
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    component PillButton : Rectangle {
        id: pill
        property string label: ""
        property bool primary: false
        signal triggered()

        Layout.preferredHeight: 40
        Layout.preferredWidth: pillText.implicitWidth + 36
        radius: 20

        color: primary
               ? (mouse.pressed ? PlazmaStyle.color.burntOrange
                                 : (mouse.containsMouse ? PlazmaStyle.color.warmGold
                                                        : PlazmaStyle.color.goldenApricot))
               : (mouse.pressed ? Qt.rgba(1, 1, 1, 0.22)
                                 : (mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14)
                                                        : Qt.rgba(1, 1, 1, 0.08)))
        border.color: primary ? "transparent" : Qt.rgba(1, 1, 1, 0.16)
        border.width: 1

        Behavior on color { ColorAnimation { duration: 140 } }
        scale: mouse.pressed ? 0.96 : 1.0
        Behavior on scale { NumberAnimation { duration: 120 } }

        Text {
            id: pillText
            anchors.centerIn: parent
            text: pill.label
            color: "#FFFFFF"
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.triggered()
        }
    }

    component GhostIcon : Rectangle {
        id: gi
        property string glyph: ""
        property string tip: ""
        signal triggered()

        Layout.preferredHeight: 36
        Layout.preferredWidth: 36
        radius: 18

        color: mouse.pressed
               ? Qt.rgba(1, 1, 1, 0.22)
               : (mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06))
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1

        Behavior on color { ColorAnimation { duration: 140 } }
        scale: mouse.pressed ? 0.94 : 1.0
        Behavior on scale { NumberAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: gi.glyph
            color: "#FFFFFF"
            font.pixelSize: 15
        }

        ToolTip.visible: mouse.containsMouse && gi.tip.length > 0
        ToolTip.text: gi.tip
        ToolTip.delay: 500

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: gi.triggered()
        }
    }

    component SkipIndicator : Item {
        id: si
        property int direction: 1
        width: 96; height: 96
        visible: opacity > 0
        opacity: 0

        function pulse() { opacity = 1; fade.restart() }

        NumberAnimation on opacity {
            id: fade
            to: 0; duration: 550; easing.type: Easing.OutQuad
            running: false
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.rgba(0, 0, 0, 0.55)
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1
        }

        Text {
            anchors.centerIn: parent
            text: si.direction > 0 ? "\u23E9 10s" : "10s \u23EA"
            color: "#FFFFFF"
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }
}
