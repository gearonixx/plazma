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
    property string currentFileName: VideoFeedModel.currentTitle
    property bool mouseIdle: false
    property string lastToast: ""

    background: Rectangle { color: PlazmaStyle.color.warmWhite }

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
            player.source = VideoFeedModel.currentUrl
        }
    }

    Connections {
        target: VideoFeedModel
        function onCurrentChanged() {
            if (VideoFeedModel.currentUrl.length > 0) {
                player.source = VideoFeedModel.currentUrl
            }
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
        function onPlaybackError(msg)    { root.showToast(qsTr("Error: %1").arg(msg)) }
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
    Shortcut { sequence: "Escape"; enabled: root.hasVideo; onActivated: {
        const win = root.Window.window
        if (win && win.visibility === Window.FullScreen) win.visibility = Window.Windowed
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

    // Header with back button + title
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 56
        color: PlazmaStyle.color.creamWhite
        border.color: PlazmaStyle.color.inputBorder
        border.width: 1
        z: 10

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 16
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: backMouse.containsMouse ? PlazmaStyle.color.softAmber : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "\u2190"
                    font.pixelSize: 20
                    color: PlazmaStyle.color.textPrimary
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        player.stop()
                        VideoFeedModel.clearCurrent()
                        PageController.replacePage(PageEnum.PageFeed)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.currentFileName.length > 0 ? root.currentFileName : qsTr("Player")
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: PlazmaStyle.color.textPrimary
                elide: Text.ElideRight
            }
        }
    }

    // Stage
    Rectangle {
        id: stage
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        color: "black"
        radius: 12
        clip: true

        MpvObject {
            id: player
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.centerIn: parent
            visible: !root.hasVideo && !player.loading
            spacing: 12

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 80; height: 80; radius: 40
                color: PlazmaStyle.color.translucentWhite

                Text {
                    anchors.centerIn: parent
                    text: "\u25B6"
                    font.pixelSize: 32
                    color: "#FFFFFF"
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("No video selected")
                color: "#FFFFFF"
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Pick a video from the feed")
                color: PlazmaStyle.color.mistyGray
                font.pixelSize: 12
            }
        }

        BusyIndicator {
            anchors.centerIn: parent
            running: player.loading
            visible: running
            width: 48; height: 48
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

        Timer { id: controlsTimer; interval: 2500; repeat: false; running: root.hasVideo && !player.paused }
        Timer { id: idleTimer; interval: 3000; repeat: false; onTriggered: if (root.hasVideo && !player.paused) root.mouseIdle = true }

        SkipIndicator {
            id: skipLeft
            direction: -1
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 40
        }
        SkipIndicator {
            id: skipRight
            direction: 1
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 40
        }

        Rectangle {
            visible: root.hasVideo && root.currentFileName.length > 0
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 12
            height: 28
            width: Math.min(nameText.implicitWidth + 24, stage.width - 40)
            radius: 14
            color: PlazmaStyle.color.translucentMidnightBlack

            opacity: (player.paused || stageMouse.containsMouse) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Text {
                id: nameText
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter
                text: {
                    const res = player.videoWidth > 0 ? "  " + player.videoWidth + "×" + player.videoHeight : ""
                    return root.currentFileName + res
                }
                color: "#FFFFFF"
                font.pixelSize: 11
                elide: Text.ElideMiddle
            }
        }

        Rectangle {
            visible: toastTimer.running
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 50
            width: Math.min(toastText.implicitWidth + 28, stage.width - 40)
            height: 34
            radius: 17
            color: PlazmaStyle.color.translucentMidnightBlack

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

            Timer { id: toastTimer; interval: 1400; repeat: false }
        }

        // Overlay
        Rectangle {
            id: overlay
            visible: root.hasVideo
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 110
            radius: 12

            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.8) }
            }

            opacity: (player.paused || stageMouse.containsMouse || controlsTimer.running) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.bottomMargin: 10
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
                        color: PlazmaStyle.color.translucentWhite

                        Rectangle {
                            visible: player.bufferedPosition > 0 && player.duration > 0
                            width: parent.width * Math.min(1, player.bufferedPosition / player.duration)
                            height: parent.height
                            radius: parent.radius
                            color: PlazmaStyle.color.mistyGray
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
                        width: 14; height: 14; radius: 7
                        color: PlazmaStyle.color.warmGold
                        border.color: "#FFFFFF"
                        border.width: 2
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    CircleButton {
                        diameter: 38
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
                        bg: "transparent"; bgHover: PlazmaStyle.color.translucentWhite
                        onClicked: player.frameBackStep()
                    }
                    CircleButton {
                        visible: player.paused
                        diameter: 28
                        glyph: "\u23E9"
                        bg: "transparent"; bgHover: PlazmaStyle.color.translucentWhite
                        onClicked: player.frameStep()
                    }

                    Text {
                        text: root.formatTime(player.position) + " / " + root.formatTime(player.duration)
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        Layout.minimumWidth: 96
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: speedText.implicitWidth + 20
                        radius: 14
                        color: speedMouse.containsMouse ? PlazmaStyle.color.translucentWhite : "transparent"
                        border.color: PlazmaStyle.color.translucentWhite
                        border.width: 1

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
                        bgHover: player.loop ? PlazmaStyle.color.warmGold : PlazmaStyle.color.translucentWhite
                        onClicked: { player.toggleLoop(); root.showToast(player.loop ? qsTr("Loop on") : qsTr("Loop off")) }
                    }

                    CircleButton {
                        diameter: 32
                        glyph: (player.muted || player.volume === 0) ? "\uD83D\uDD07" : "\uD83D\uDD0A"
                        bg: "transparent"; bgHover: PlazmaStyle.color.translucentWhite
                        onClicked: player.toggleMute()
                    }

                    Slider {
                        id: volumeSlider
                        Layout.preferredWidth: 80
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
                            color: PlazmaStyle.color.translucentWhite

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
                        bg: "transparent"; bgHover: PlazmaStyle.color.translucentWhite
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
                        bg: "transparent"; bgHover: PlazmaStyle.color.translucentWhite
                        onClicked: root.toggleFullscreen()
                    }
                }
            }
        }
    }

    // Reusable components
    component CircleButton : Rectangle {
        id: btn
        property int diameter: 32
        property string glyph: ""
        property color bg: "transparent"
        property color bgHover: Qt.rgba(1, 1, 1, 0.12)
        property color bgPressed: Qt.rgba(1, 1, 1, 0.22)
        signal clicked()

        Layout.preferredWidth: diameter
        Layout.preferredHeight: diameter
        width: diameter; height: diameter
        radius: diameter / 2
        color: mouse.pressed ? bgPressed : (mouse.containsMouse ? bgHover : bg)

        Behavior on color { ColorAnimation { duration: 120 } }

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

    component SkipIndicator : Item {
        id: si
        property int direction: 1
        width: 80; height: 80
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
            color: PlazmaStyle.color.translucentMidnightBlack
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
