import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qt.labs.settings

import dev.gearonixx.plazma 1.0

import "../Controls"

import PageEnum 1.0
import Style 1.0

// PagePlayer
// ──────────
// YouTube-style watch page. The window is split vertically:
//
//   ┌────────────────────────────────────────────────┐
//   │           Stage (mpv + chrome)                 │   ← height-capped
//   │                                                │     in windowed mode
//   │      ─ floating top bar + bottom controls ─    │     (fills in FS)
//   ├────────────────────────────────────────────────┤
//   │  Title                                         │
//   │  Author row (avatar + name) · upload date      │   ← info panel,
//   │  [ Save ] [ Share ] [ Download ] [ ⋮ ]         │     scrollable
//   │  About this video (codec, res, HW, …)          │
//   └────────────────────────────────────────────────┘
//
// The info panel collapses in fullscreen so the stage takes the whole window.
// tdesktop's right-click message menu (Ui::PopupMenu + fillContextMenu in
// history_view_context_menu.cpp) was the template for the action rail +
// more-menu — same verbs, same separator placement, same state-dependent
// labels on Download (Open / Downloading…).
Page {
    id: root

    // ── Current-video metadata (single source of truth) ────────────────────
    //
    // Feed / profile / playlist callers push a full row into
    // VideoFeedModel.setCurrentVideo(); the drag-and-drop + file picker
    // flows fall back to setCurrent(url, title) which seeds a minimal map.
    // Everything downstream (title, author, createdAt, …) reads from this
    // one object so there is no divergence.
    readonly property var currentVideo: VideoFeedModel.currentVideo || ({})
    readonly property string currentId:        String(root.currentVideo.id         || "")
    readonly property string currentTitleStr:  String(root.currentVideo.title      || VideoFeedModel.currentTitle || "")
    readonly property string currentUrl:       String(root.currentVideo.url        || VideoFeedModel.currentUrl   || "")
    readonly property string currentAuthor:    String(root.currentVideo.author     || "")
    readonly property string currentCreatedAt: String(root.currentVideo.createdAt  || "")
    readonly property string currentThumbnail: String(root.currentVideo.thumbnail  || "")
    readonly property string currentMime:      String(root.currentVideo.mime       || "")
    readonly property string currentDescription: String(root.currentVideo.description || "")
    readonly property var    currentSizeRaw:   root.currentVideo.size
    readonly property real   currentSize:      Number(root.currentSizeRaw || 0)

    // ── Fullscreen tracking ────────────────────────────────────────────────
    //
    // We drive the stage-height binding off this flag rather than reading
    // Window.visibility on each layout tick. Kept in sync imperatively
    // wherever we flip visibility (toggleFullscreen + the Escape shortcut).
    property bool fullscreen: false

    Component.onCompleted: {
        const w = root.Window.window
        if (w) root.fullscreen = (w.visibility === Window.FullScreen)

        player.volume = persisted.volume
        player.muted = persisted.muted
        player.speed = persisted.speed
        player.loop = persisted.loop
        player.hwdec = persisted.hwdec

        if (root.currentUrl.length > 0) {
            root.lastError = ""
            player.source = root.currentUrl
        }
    }

    property bool hasVideo: player.hasMedia
    property string lastError: ""
    property bool mouseIdle: false
    property string lastToast: ""

    // Chrome visibility is a union of "something that should make it stick":
    // no video loaded yet, video paused, cursor hovering player / chromes,
    // or the post-interaction grace window.
    property bool chromeVisible: !root.hasVideo
                                 || player.paused
                                 || stageMouse.containsMouse
                                 || topChromeHover.containsMouse
                                 || bottomChromeHover.containsMouse
                                 || controlsTimer.running

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

    Connections {
        target: VideoFeedModel
        function onCurrentChanged() {
            if (root.currentUrl.length > 0) {
                root.lastError = ""
                player.source = root.currentUrl
            }
        }
    }

    Connections {
        target: FileDialogModel
        function onFileSelected(path) {
            root.lastError = ""
            const raw = path.startsWith("file://") ? path.slice(7) : path
            VideoFeedModel.setCurrent("file://" + raw, raw.split("/").pop())
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
        function onEndReached() {
            // Natural end of playback — clear the resume point so next watch
            // starts from the beginning rather than dumping the user at the
            // credits. Matches YouTube's mark-as-watched behavior.
            if (root.currentId.length > 0) root.saveResumePosition(root.currentId, 0)
            if (!player.loop) root.showToast(qsTr("End of video"))
        }
        function onFileLoaded() {
            const want = player.hwdec
            const got  = player.hwdecCurrent
            if (want !== "auto-safe" && want !== "no" && (got === "no" || got.length === 0)) {
                root.showToast(qsTr("HW %1 unavailable — using CPU").arg(root.hwdecLabel(want)))
            }

            // Resume if we have a saved position and it's in the "middle"
            // of the file (≥ 8s in, ≥ 10s from the end). Avoids surprise-
            // jumps for short clips and for videos near completion.
            if (root.currentId.length > 0 && player.duration > 30) {
                const saved = root.loadResumePosition(root.currentId)
                if (saved >= 8 && saved <= player.duration - 10) {
                    player.seek(saved)
                    root.showToast(qsTr("Resumed from %1").arg(root.formatTime(saved)))
                }
            }
        }
    }

    // Download status for the currently playing video. When the user hits
    // Download on this page, our id becomes `latestId` and the progress bar
    // ticks on every `latestChanged` emit — so we bind live instead of
    // polling. For any other state (already downloaded / never downloaded
    // / in-flight from a different page) we read the snapshot via statusOf.
    readonly property int dlStatus:
        root.currentId.length > 0 ? DownloadsModel.statusOf(root.currentId) : -1
    readonly property bool dlIsLatest:
        root.currentId.length > 0 && DownloadsModel.latestId === root.currentId
    readonly property bool dlActive: dlStatus === 0 || dlStatus === 1
    readonly property bool dlCompleted: dlStatus === 2
    readonly property bool dlFailed: dlStatus === 3
    readonly property real dlProgress: dlIsLatest ? DownloadsModel.latestProgress : 0

    Connections {
        target: DownloadsModel
        // Re-evaluate dlStatus bindings when any entry changes. Cheap: the
        // bindings above already depend on `latestId`/`latestProgress`, but
        // statusOf() is not a Q_PROPERTY so an explicit nudge is needed
        // when the user opens a page for a previously-completed download.
        function onCountChanged() {}
        function onLatestChanged() {}
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
        const next = (win.visibility === Window.FullScreen) ? Window.Windowed : Window.FullScreen
        win.visibility = next
        root.fullscreen = (next === Window.FullScreen)
    }

    function showToast(text) {
        root.lastToast = text
        toastTimer.restart()
    }

    function goBack() {
        // Save resume point before tearing down the pipeline. Without this
        // the user would come back to the beginning after backing out —
        // defeating the whole point of the per-video position store.
        if (root.currentId.length > 0 && player.duration > 0 && player.position > 4) {
            if (player.position >= player.duration - 10) {
                root.saveResumePosition(root.currentId, 0)
            } else {
                root.saveResumePosition(root.currentId, player.position)
            }
        }
        player.stop()
        VideoFeedModel.clearCurrent()
        PageController.replacePage(PageEnum.PageFeed)
    }

    // ── Shortcuts ─────────────────────────────────────────────────────────
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
    Shortcut { sequence: "T";     enabled: root.hasVideo; onActivated: { root.theaterMode = !root.theaterMode; root.showToast(root.theaterMode ? qsTr("Theater mode") : qsTr("Default view")) } }
    Shortcut { sequence: "Escape"; onActivated: {
        const win = root.Window.window
        if (win && win.visibility === Window.FullScreen) {
            win.visibility = Window.Windowed
            root.fullscreen = false
            return
        }
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

    // ── Theater mode ──────────────────────────────────────────────────────
    //
    // Widens the stage to take ~88% of the window height and tucks the info
    // panel into a slim strip underneath. Comes in via `T` (same key as
    // YouTube). Off by default — most of the time you want to see author +
    // actions alongside the video.
    property bool theaterMode: false

    // ── Stage height ──────────────────────────────────────────────────────
    //
    // Cap on the windowed-mode stage. In fullscreen we hand the whole
    // viewport over; in theater mode we take most of it; otherwise we keep
    // the player to a 16:9 box constrained by both width and a percentage
    // of the window height so info stays on-screen.
    readonly property int stageMaxHeight: 820
    readonly property int stageMinHeight: 280
    readonly property real stageHeightFraction:
        root.theaterMode ? 0.88 : 0.70

    readonly property int stageHeight: {
        if (root.fullscreen) return root.height
        const byAspect = Math.floor(root.width * 9 / 16)
        const byWindow = Math.floor(root.height * root.stageHeightFraction)
        return Math.max(
            root.stageMinHeight,
            Math.min(root.stageMaxHeight, Math.min(byAspect, byWindow))
        )
    }

    // ======================================================================
    //  STAGE (player + chromes)
    // ======================================================================
    Rectangle {
        id: stage
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.stageHeight
        color: "#050608"
        clip: true

        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

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
                    VideoFeedModel.setCurrent("file://" + p, p.split("/").pop())
                    root.lastError = ""
                    player.source = "file://" + p
                    drop.accept()
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: parent.containsDrag
                color: Qt.rgba(0.55, 0.36, 0.96, 0.15)
                border.color: PlazmaStyle.color.goldenApricot
                border.width: 3
                z: 200

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "⬇"
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

        // ───────── Empty state (no video selected) ─────────
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
                            text: "▶"
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

        // ───────── Error state ─────────
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
                        text: "⚠"
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
                                const url = root.currentUrl.length > 0 ? root.currentUrl : player.source
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

        // ───────── Toast ─────────
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

        // ───────── Top chrome (back + title + quick icons) ─────────
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
                        Text { text: "‹"; color: "#FFFFFF"; font.pixelSize: 22; font.weight: Font.DemiBold }
                        Text { text: qsTr("Back"); color: "#FFFFFF"; font.pixelSize: 13; font.weight: Font.DemiBold }
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
                        text: root.currentTitleStr.length > 0 ? root.currentTitleStr : qsTr("Player")
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
                    glyph: "⬆"
                    tip: qsTr("Open local file")
                    onTriggered: FileDialogModel.openFilePicker()
                }

                GhostIcon {
                    glyph: root.theaterMode ? "▯" : "▮"
                    tip: root.theaterMode ? qsTr("Default view  (T)") : qsTr("Theater mode  (T)")
                    onTriggered: { root.theaterMode = !root.theaterMode }
                }

                GhostIcon {
                    glyph: "⛶"
                    tip: qsTr("Fullscreen  (F)")
                    onTriggered: root.toggleFullscreen()
                }
            }
        }

        // ───────── Bottom chrome (seek + transport controls) ─────────
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
                        glyph: player.paused ? "▶" : "❚❚"
                        bg: PlazmaStyle.color.goldenApricot
                        bgHover: PlazmaStyle.color.warmGold
                        bgPressed: PlazmaStyle.color.burntOrange
                        onClicked: player.playPause()
                    }

                    CircleButton {
                        visible: player.paused
                        diameter: 28
                        glyph: "⏪"
                        bg: "transparent"; bgHover: Qt.rgba(1, 1, 1, 0.16)
                        onClicked: player.frameBackStep()
                    }
                    CircleButton {
                        visible: player.paused
                        diameter: 28
                        glyph: "⏩"
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
                                          (Math.abs(modelData - player.speed) < 0.01 ? "  ✓" : "")
                                    onTriggered: player.speed = modelData
                                }
                            }
                        }
                    }

                    CircleButton {
                        diameter: 32
                        glyph: "↻"
                        bg: player.loop ? PlazmaStyle.color.goldenApricot : "transparent"
                        bgHover: player.loop ? PlazmaStyle.color.warmGold : Qt.rgba(1, 1, 1, 0.16)
                        onClicked: { player.toggleLoop(); root.showToast(player.loop ? qsTr("Loop on") : qsTr("Loop off")) }
                    }

                    CircleButton {
                        diameter: 32
                        glyph: (player.muted || player.volume === 0) ? "🔇" : "🔊"
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
                        glyph: "⋮"
                        bg: "transparent"; bgHover: Qt.rgba(1, 1, 1, 0.16)
                        onClicked: playerMenu.open()

                        Menu {
                            id: playerMenu
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

                            MenuItem { text: qsTr("Open local file"); onTriggered: FileDialogModel.openFilePicker() }
                            MenuItem { text: qsTr("Take screenshot");  onTriggered: player.takeScreenshot() }

                            MenuSeparator {}

                            Menu {
                                title: qsTr("Audio track")
                                enabled: player.audioTracks.length > 0
                                Repeater {
                                    model: player.audioTracks
                                    MenuItem {
                                        text: (modelData.title || qsTr("Track %1").arg(modelData.id))
                                              + (modelData.selected ? "  ✓" : "")
                                        onTriggered: player.setAudioTrack(modelData.id)
                                    }
                                }
                            }

                            Menu {
                                title: qsTr("Subtitles")
                                MenuItem { text: qsTr("Off"); onTriggered: player.setSubtitleTrack(0) }
                                Repeater {
                                    model: player.subtitleTracks
                                    MenuItem {
                                        text: (modelData.title || qsTr("Track %1").arg(modelData.id))
                                              + (modelData.selected ? "  ✓" : "")
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
                                              (modelData.id === player.hwdec ? "  ✓" : "")
                                        onTriggered: player.hwdec = modelData.id
                                    }
                                }
                            }
                        }
                    }

                    CircleButton {
                        diameter: 32
                        glyph: "⛶"
                        bg: "transparent"; bgHover: Qt.rgba(1, 1, 1, 0.16)
                        onClicked: root.toggleFullscreen()
                    }
                }
            }
        }
    }

    // ======================================================================
    //  INFO PANEL (under the stage — hidden in fullscreen)
    // ======================================================================
    Flickable {
        id: infoScroll
        visible: !root.fullscreen
        anchors.top: stage.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true

        contentWidth: width
        contentHeight: infoColumn.implicitHeight + 48
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: infoScroll.contentHeight > infoScroll.height
                    ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        // Gentle drop-shadow at the top — telegram's message info stripe
        // uses the same separator treatment when a section closes the stage.
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: PlazmaStyle.color.inputBorder
        }

        ColumnLayout {
            id: infoColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Math.max(20, Math.floor((parent.width - 960) / 2))
            anchors.rightMargin: Math.max(20, Math.floor((parent.width - 960) / 2))
            anchors.topMargin: 22
            spacing: 14

            // ── Title ────────────────────────────────────────────────────
            Text {
                Layout.fillWidth: true
                text: root.currentTitleStr.length > 0 ? root.currentTitleStr : qsTr("Untitled")
                color: PlazmaStyle.color.textPrimary
                font.pixelSize: 20
                font.weight: Font.Bold
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            // ── Channel row + action rail ────────────────────────────────
            //
            // Two groups on one line: left = author chip (avatar + name +
            // ID), right = [Save][Share][Download][⋮]. Wraps to two rows
            // when the window is narrow.
            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 10
                rowSpacing: 10
                columns: parent.width < 640 ? 1 : 2

                // ── Author chip ─────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    radius: 14
                    color: authorMouse.containsMouse && root.authorIsMe
                           ? PlazmaStyle.color.softAmber
                           : "transparent"
                    border.color: PlazmaStyle.color.inputBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 14
                        spacing: 12

                        // Avatar — gradient disc with the author's initial.
                        // Colour is derived from a hash of the author name
                        // so it stays stable across sessions (matches the
                        // ProfileModel palette convention).
                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 20
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0.0; color: root.authorPalette.from }
                                GradientStop { position: 1.0; color: root.authorPalette.to }
                            }

                            // Subtle gloss (same trick as PageProfile).
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: parent.height * 0.55
                                radius: height / 2
                                opacity: 0.22
                                gradient: Gradient {
                                    orientation: Gradient.Vertical
                                    GradientStop { position: 0.0; color: "#FFFFFF" }
                                    GradientStop { position: 1.0; color: "transparent" }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: root.authorInitial
                                color: "#FFFFFF"
                                font.pixelSize: 17
                                font.weight: Font.Bold
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: root.authorDisplayName
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: PlazmaStyle.color.textPrimary
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.formatDate(root.currentCreatedAt)
                                font.pixelSize: 11
                                color: PlazmaStyle.color.textSecondary
                                elide: Text.ElideRight
                                visible: text.length > 0
                            }
                        }

                        // "Your channel" badge — only when the author matches
                        // the signed-in user. Mirrors YouTube's "your video"
                        // affordance but calmer (no subscribe button).
                        Rectangle {
                            visible: root.authorIsMe
                            Layout.preferredHeight: 26
                            Layout.preferredWidth: meLabel.implicitWidth + 20
                            radius: 13
                            color: PlazmaStyle.color.softAmber

                            Text {
                                id: meLabel
                                anchors.centerIn: parent
                                text: qsTr("Your channel")
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: PlazmaStyle.color.warmGold
                            }
                        }
                    }

                    MouseArea {
                        id: authorMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.authorIsMe
                        cursorShape: root.authorIsMe ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: PageController.replacePage(PageEnum.PageProfile)
                    }

                    ToolTip.visible: authorMouse.containsMouse && root.authorIsMe
                    ToolTip.text: qsTr("Open your channel")
                    ToolTip.delay: 500
                }

                // ── Action rail ──────────────────────────────────────────
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 8

                    ActionPill {
                        glyph: "+"
                        label: qsTr("Save")
                        // Hint the current membership so the user sees it's
                        // already in a playlist without having to open the
                        // picker. Gentle "· in 2" suffix — matches the feed
                        // card menu's copy.
                        hint: {
                            if (root.currentId.length === 0) return ""
                            const n = PlaylistsModel.playlistsContaining(root.currentId).length
                            return n > 0 ? qsTr("in %1").arg(n) : ""
                        }
                        enabled: root.currentUrl.length > 0
                        onTriggered: {
                            if (root.currentUrl.length === 0) return
                            savePicker.openWith(root.effectiveVideoPayload())
                        }
                    }

                    ActionPill {
                        glyph: "↗"   // upper-right arrow, tdesktop-ish
                        label: qsTr("Share")
                        enabled: root.currentUrl.length > 0
                        onTriggered: root.copyShareLink()
                    }

                    ActionPill {
                        // State-dependent label, matching tdesktop's
                        // AddSaveDocumentAction copy. Bound to `dlStatus`
                        // so it refreshes as the download moves through
                        // queued → downloading → completed.
                        glyph: root.dlCompleted ? "✓" : "↓"
                        label: root.dlActive
                               ? qsTr("Downloading")
                               : (root.dlCompleted
                                  ? qsTr("Open")
                                  : (root.dlFailed ? qsTr("Retry") : qsTr("Download")))
                        hint: root.dlActive && root.dlIsLatest
                              ? Math.round(root.dlProgress * 100) + "%"
                              : ""
                        enabled: !root.dlActive && root.currentUrl.length > 0
                        // Primary tint while downloading to pull attention
                        // into the progress — YouTube Premium does the same.
                        primary: root.dlActive || root.dlCompleted
                        onTriggered: {
                            if (root.currentId.length === 0 && root.currentUrl.length === 0) return
                            if (root.dlCompleted) {
                                DownloadsModel.openFile(root.currentId)
                                return
                            }
                            DownloadsModel.start(root.effectiveVideoPayload())
                        }

                        // Progress bar painted underneath the pill while a
                        // download is in flight. Only visible when *this*
                        // video is the current download.
                        progress: root.dlActive && root.dlIsLatest ? root.dlProgress : 0
                    }

                    // ⋮ more
                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: 18
                        color: moreMouse.containsMouse
                               ? PlazmaStyle.color.softAmber
                               : "transparent"
                        border.color: PlazmaStyle.color.inputBorder
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "⋮"
                            color: PlazmaStyle.color.textPrimary
                            font.pixelSize: 18
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: moreMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openMoreMenu(moreMouse, moreMouse.width / 2, moreMouse.height)
                        }

                        ToolTip.visible: moreMouse.containsMouse
                        ToolTip.text: qsTr("More actions")
                        ToolTip.delay: 500
                    }
                }
            }

            // ── Meta chip strip ──────────────────────────────────────────
            //
            // Compact, YouTube-style strip under the action rail showing
            // the uploaded-at chip and quick-glance file facts. Shows only
            // when there's something meaningful to show.
            Flow {
                Layout.fillWidth: true
                spacing: 8

                MetaChip {
                    visible: root.currentCreatedAt.length > 0
                    glyph: "🗓"    // calendar
                    text: qsTr("Uploaded %1").arg(root.formatDateAbsolute(root.currentCreatedAt))
                }
                MetaChip {
                    visible: root.currentSize > 0
                    glyph: "◰"
                    text: root.formatSize(root.currentSize)
                }
                MetaChip {
                    visible: player.videoWidth > 0
                    glyph: "▢"
                    text: player.videoHeight + "p"
                }
                MetaChip {
                    visible: player.duration > 0
                    glyph: "⧖"
                    text: root.formatTime(player.duration)
                }
                MetaChip {
                    visible: root.currentMime.length > 0
                    glyph: "📄"
                    text: root.currentMime
                }
            }

            // ── Description ──────────────────────────────────────────────
            //
            // YouTube-style long-form description: soft card, 4 lines by
            // default, "Show more" toggles to full height with a smooth
            // easing. Hidden entirely when the server didn't supply a
            // description — avoids the "[empty]" placeholder feel.
            //
            // The Show-more affordance only appears when the text would
            // actually overflow at the collapsed line count; we detect that
            // by painting a hidden "measurer" Text off-screen and comparing
            // its implicitHeight to the visible one. Simple and cheap.
            Rectangle {
                id: descCard
                Layout.fillWidth: true
                visible: root.currentDescription.length > 0
                radius: 14
                color: PlazmaStyle.color.creamWhite
                border.color: PlazmaStyle.color.inputBorder
                border.width: 1

                Layout.preferredHeight: descCol.implicitHeight + 28
                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                // Off-screen measurer — renders with no line cap so we can
                // tell whether the visible (capped) Text is actually clipping.
                Text {
                    id: descMeasure
                    visible: false
                    width: descCard.width - 28
                    text: root.currentDescription
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    lineHeight: 1.45
                }

                ColumnLayout {
                    id: descCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Description")
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: PlazmaStyle.color.textPrimary
                        }

                        // Show more / less affordance — only when the text
                        // is actually overflowing.
                        Text {
                            visible: descMeasure.implicitHeight > descBody.implicitHeight + 2
                                     || root.descExpanded
                            text: root.descExpanded ? qsTr("Show less") : qsTr("Show more")
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: PlazmaStyle.color.warmGold

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.descExpanded = !root.descExpanded
                            }
                        }
                    }

                    Text {
                        id: descBody
                        Layout.fillWidth: true
                        // Rich text so timestamps and URLs can render as
                        // clickable anchors. The measurer above stays in
                        // plain text — it only exists to detect overflow
                        // and rich-text would add <a> padding noise.
                        textFormat: Text.RichText
                        text: root.descHtml(root.currentDescription)
                        font.pixelSize: 13
                        color: PlazmaStyle.color.textPrimary
                        wrapMode: Text.WordWrap
                        lineHeight: 1.45
                        maximumLineCount: root.descExpanded ? 9999 : 4
                        elide: Text.ElideRight
                        // Anchor colours — Qt's default is too-light blue.
                        linkColor: PlazmaStyle.color.warmGold

                        onLinkActivated: (link) => root.onDescLinkActivated(link)
                        onLinkHovered: (link) => {
                            hoverTip.text = link
                            hoverTip.visible = link.length > 0
                        }

                        // Hover cursor — Text doesn't give us a cursor over
                        // anchors unless we add a mouse filter.
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            cursorShape: parent.hoveredLink.length > 0
                                         ? Qt.PointingHandCursor
                                         : Qt.ArrowCursor
                        }
                    }

                    // Tiny hover hint that shows the resolved URL or the
                    // parsed timestamp. Piggybacks on descBody.hoveredLink.
                    Text {
                        id: hoverTip
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: ""
                        font.pixelSize: 11
                        color: PlazmaStyle.color.textHint
                        elide: Text.ElideMiddle
                    }
                }
            }

            // ── About this video (file-info grid) ────────────────────────
            //
            // Technical facts the mpv pipeline knows about the file
            // (resolution, codec, decoder, file size…). Complements the
            // description above — when the author didn't write prose, this
            // is still informative on its own. Clicking the header
            // collapses the card — matches YouTube's "Show more" idiom.
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 4
                radius: 14
                color: PlazmaStyle.color.creamWhite
                border.color: PlazmaStyle.color.inputBorder
                border.width: 1

                // Animated height so expand/collapse doesn't snap.
                Layout.preferredHeight: aboutCol.implicitHeight + 28
                Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                ColumnLayout {
                    id: aboutCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("About this video")
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: PlazmaStyle.color.textPrimary
                        }

                        Text {
                            text: root.aboutExpanded ? qsTr("Show less") : qsTr("Show more")
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: PlazmaStyle.color.warmGold

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.aboutExpanded = !root.aboutExpanded
                            }
                        }
                    }

                    // Summary line — always visible.
                    Text {
                        Layout.fillWidth: true
                        text: root.aboutSummary
                        font.pixelSize: 12
                        color: PlazmaStyle.color.textSecondary
                        wrapMode: Text.WordWrap
                    }

                    // Detail grid — visible on expand.
                    GridLayout {
                        Layout.fillWidth: true
                        visible: root.aboutExpanded
                        columns: 2
                        columnSpacing: 18
                        rowSpacing: 6

                        AboutRow { label: qsTr("Title");      value: root.currentTitleStr }
                        AboutRow { label: qsTr("Uploaded by");  value: root.authorDisplayName }
                        AboutRow { label: qsTr("Uploaded");     value: root.formatDateAbsolute(root.currentCreatedAt); visible: root.currentCreatedAt.length > 0 }
                        AboutRow { label: qsTr("Duration");     value: root.formatTime(player.duration); visible: player.duration > 0 }
                        AboutRow { label: qsTr("Resolution");   value: player.videoWidth + " × " + player.videoHeight; visible: player.videoWidth > 0 }
                        AboutRow { label: qsTr("Codec");        value: player.videoCodec; visible: player.videoCodec.length > 0 }
                        AboutRow { label: qsTr("Decoder");      value: {
                            const hw = player.hwdecCurrent
                            return (!hw || hw === "no") ? qsTr("CPU") : hw.toUpperCase()
                        }}
                        AboutRow { label: qsTr("File size");    value: root.formatSize(root.currentSize); visible: root.currentSize > 0 }
                        AboutRow { label: qsTr("Content type"); value: root.currentMime; visible: root.currentMime.length > 0 }
                        AboutRow { label: qsTr("URL");          value: root.currentUrl; mono: true; visible: root.currentUrl.length > 0 }
                    }
                }
            }
        }
    }

    // Hidden helper for clipboard — TextEdit.copy() dispatches through
    // QClipboard without any C++ bridge.
    TextEdit {
        id: clipboardEdit
        visible: false
        width: 0
        height: 0
    }

    // SaveToPlaylistDialog renders on the app overlay so it dims the whole
    // page consistently with every other caller (PageFeed, PageProfile, …).
    SaveToPlaylistDialog {
        id: savePicker
        parent: Overlay.overlay
    }

    // tdesktop-style floating menu — same component used in the feed card
    // menus (history_view_context_menu.cpp in tdesktop). Rebuilt on open so
    // state-dependent labels (Download vs. Downloading…) stay fresh.
    PlazmaPopupMenu {
        id: moreMenu

        actions: [
            {
                text: qsTr("Copy link"),
                glyph: "⎘",
                onTriggered: function() { root.copyShareLink() }
            },
            {
                text: qsTr("Copy link at current time"),
                glyph: "⧖",
                enabled: root.hasVideo,
                onTriggered: function() { root.copyShareLinkAtTime() }
            },
            {
                text: qsTr("Reveal downloaded file"),
                glyph: "❐",
                enabled: root.dlCompleted,
                onTriggered: function() {
                    if (root.currentId.length > 0) DownloadsModel.openFolder(root.currentId)
                }
            },
            { separator: true },
            {
                text: qsTr("Take screenshot"),
                glyph: "▣",
                enabled: root.hasVideo,
                onTriggered: function() { player.takeScreenshot() }
            },
            {
                text: root.theaterMode ? qsTr("Default view") : qsTr("Theater mode"),
                glyph: "⬚",
                onTriggered: function() { root.theaterMode = !root.theaterMode }
            },
            {
                text: qsTr("Fullscreen"),
                glyph: "⛶",
                enabled: root.hasVideo,
                onTriggered: function() { root.toggleFullscreen() }
            }
        ]
    }

    function openMoreMenu(anchor, px, py) {
        moreMenu.openAt(anchor, px, py)
    }

    // ── Identity derivation (author → avatar/profile link) ────────────────

    // The "me" check mirrors ProfileModel::isMine — author string matches
    // any of username / firstName / lastName (trimmed, case-insensitive).
    // When it matches, clicking the author chip routes to PageProfile.
    readonly property bool authorIsMe: {
        const a = root.currentAuthor.trim()
        if (a.length === 0) return false
        const un = (Session.username || "").trim()
        const fn = (Session.firstName || "").trim()
        const ln = (Session.lastName || "").trim()
        const eq = function(x, y) { return x.length > 0 && x.localeCompare(y, undefined, {sensitivity:"accent"}) === 0 }
        if (eq(un, a)) return true
        if (fn.length > 0 && a.toLowerCase() === fn.toLowerCase()) return true
        if (ln.length > 0 && a.toLowerCase() === ln.toLowerCase()) return true
        if (un.length > 0 && a.toLowerCase() === ("@" + un).toLowerCase()) return true
        return false
    }

    readonly property string authorDisplayName: {
        const a = root.currentAuthor.trim()
        if (a.length > 0) return a.startsWith("@") ? a : "@" + a
        // Fallback: session handle when we are playing our own untagged
        // upload, else a generic "Unknown" so the row still renders.
        if (Session.username && Session.username.length > 0) return "@" + Session.username
        return qsTr("Unknown")
    }

    readonly property string authorInitial: {
        const n = root.authorDisplayName
        if (!n || n.length === 0) return "#"
        let i = 0
        while (i < n.length && (n[i] === "@" || n[i] === " ")) ++i
        return i < n.length ? n.substring(i, i + 1).toUpperCase() : "#"
    }

    // Same seven-colour palette ProfileModel walks through, so every user
    // reads as the same colour in both places.
    readonly property var authorAvatarPalette: [
        { from: "#8B5CF6", to: "#6D28D9" },
        { from: "#F59E0B", to: "#D97706" },
        { from: "#10B981", to: "#047857" },
        { from: "#EF4444", to: "#B91C1C" },
        { from: "#3B82F6", to: "#1D4ED8" },
        { from: "#EC4899", to: "#BE185D" },
        { from: "#06B6D4", to: "#0E7490" }
    ]

    readonly property var authorPalette: {
        const name = root.authorDisplayName
        let h = 0
        for (let i = 0; i < name.length; ++i) h = (h * 31 + name.charCodeAt(i)) & 0x7FFFFFFF
        return root.authorAvatarPalette[h % root.authorAvatarPalette.length]
    }

    // ── Share / copy ─────────────────────────────────────────────────────
    function copyShareLink() {
        if (root.currentUrl.length === 0) return
        clipboardEdit.text = root.currentUrl
        clipboardEdit.selectAll()
        clipboardEdit.copy()
        root.showToast(qsTr("Link copied"))
    }

    function copyShareLinkAtTime() {
        if (root.currentUrl.length === 0) return
        const t = Math.max(0, Math.floor(player.position))
        clipboardEdit.text = root.currentUrl + "#t=" + t
        clipboardEdit.selectAll()
        clipboardEdit.copy()
        root.showToast(qsTr("Link copied at %1").arg(root.formatTime(t)))
    }

    // Pass a normalized payload downstream so callers that only got a URL
    // (drag-and-drop / file picker) still get a title on the downloaded file.
    function effectiveVideoPayload() {
        const v = root.currentVideo || ({})
        if (v && v.url) return v
        return {
            "id": root.currentId,
            "title": root.currentTitleStr,
            "url": root.currentUrl,
            "mime": root.currentMime,
        }
    }

    // ── About block ───────────────────────────────────────────────────────
    property bool aboutExpanded: false

    // Description expand state. Collapsed by default; flips on click of the
    // "Show more" link in the description card.
    property bool descExpanded: false

    // ── Rich description rendering ───────────────────────────────────────
    //
    // Converts a raw description string into HTML with:
    //   • timestamps (MM:SS / HH:MM:SS) → anchors that seek the player
    //   • http(s) URLs                   → anchors that open externally
    //
    // HTML-escapes first so user-supplied angle brackets can't leak into
    // the rich-text tree. Timestamp scan validates the minute/second
    // ranges so false positives like "99:99" aren't matched. The scheme
    // `plazma:seek:<seconds>` is our internal glue — see
    // onDescLinkActivated for the dispatch.
    function descHtml(raw) {
        if (!raw || raw.length === 0) return ""
        let html = String(raw)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")

        // URLs first. We match http/https only — naked www.* is ambiguous
        // and we prefer a bit of under-linking to risking mis-parses.
        // `&amp;` from the previous escape is preserved so query strings
        // round-trip correctly when the anchor is clicked.
        html = html.replace(/\bhttps?:\/\/[^\s<]+/g, function(m) {
            return '<a href="' + m + '">' + m + '</a>'
        })

        // Then timestamps. We allow an optional hour segment and bound the
        // minute/second parts so gibberish like "72:99" doesn't match.
        html = html.replace(
            /(^|\s)((?:(\d{1,2}):)?([0-5]?\d):([0-5]\d))(?=\s|$|[.,;:!?)])/g,
            function(match, pre, stamp, h, m, s) {
                const total = (parseInt(h || "0") * 3600) +
                              (parseInt(m)      *   60) +
                               parseInt(s)
                return pre + '<a href="plazma:seek:' + total + '">' + stamp + '</a>'
            }
        )

        return html.replace(/\n/g, "<br/>")
    }

    function onDescLinkActivated(link) {
        if (!link || link.length === 0) return
        if (link.indexOf("plazma:seek:") === 0) {
            const secs = parseInt(link.substring("plazma:seek:".length))
            if (!isFinite(secs) || secs < 0) return
            player.seek(secs)
            root.showToast(qsTr("Jumped to %1").arg(root.formatTime(secs)))
            return
        }
        // External URL — hand off to the OS default browser. Qt.openUrlExternally
        // routes through QDesktopServices::openUrl which picks xdg-open on
        // Linux and ShellExecute on Windows.
        Qt.openUrlExternally(link)
    }

    // ── Resume playback ──────────────────────────────────────────────────
    //
    // Per-video-id persistence of the last-watched position, in seconds.
    // When the user re-opens the same video we seek back to where they left
    // off (if the saved position is ≥ 8s and ≤ duration - 10s, i.e. the
    // middle of the video — we don't resume 2-second clips or the last
    // 10 seconds; they probably meant to finish). Stored via Qt.labs.settings
    // under "player/positions" so it survives across app restarts on every
    // platform. Modelled on YouTube Premium's "continue watching" behavior.
    Settings {
        id: resumeStore
        category: "player/positions"
        // The Settings object only knows about declared properties, so we
        // stash a JSON blob and parse on read — keyed by video id. Sparse
        // across videos; clean-up happens in saveResumePosition when a
        // video finishes.
        property string positionsJson: "{}"
    }

    function _resumeMap() {
        try {
            const m = JSON.parse(resumeStore.positionsJson)
            return m && typeof m === "object" ? m : ({})
        } catch (e) {
            return ({})
        }
    }

    function saveResumePosition(id, pos) {
        if (!id || id.length === 0) return
        const map = _resumeMap()
        if (pos <= 0) {
            delete map[id]
        } else {
            map[id] = Math.floor(pos)
        }
        resumeStore.positionsJson = JSON.stringify(map)
    }

    function loadResumePosition(id) {
        if (!id || id.length === 0) return 0
        const v = _resumeMap()[id]
        return (typeof v === "number" && v > 0) ? v : 0
    }

    // Tick every 4 seconds while playing so we don't thrash QSettings on
    // every position change. We also save on pause and on page-leave.
    Timer {
        id: resumeTick
        interval: 4000
        repeat: true
        running: root.hasVideo && !player.paused && root.currentId.length > 0
        onTriggered: {
            if (player.duration > 0 && player.position > 4) {
                // Near the end? Treat as finished — clear the resume point
                // so next watch starts fresh. 10s tail matches YouTube's
                // "mark as watched" threshold.
                if (player.position >= player.duration - 10) {
                    root.saveResumePosition(root.currentId, 0)
                } else {
                    root.saveResumePosition(root.currentId, player.position)
                }
            }
        }
    }

    readonly property string aboutSummary: {
        const bits = []
        if (root.authorDisplayName.length > 0 && root.authorDisplayName !== qsTr("Unknown"))
            bits.push(qsTr("By %1").arg(root.authorDisplayName))
        if (root.currentCreatedAt.length > 0)
            bits.push(root.formatDateAbsolute(root.currentCreatedAt))
        if (player.videoWidth > 0)
            bits.push(player.videoHeight + "p")
        if (root.currentSize > 0)
            bits.push(root.formatSize(root.currentSize))
        return bits.length > 0 ? bits.join(" · ")
                               : qsTr("No additional information is available for this video.")
    }

    // ── Helpers (kept in sync with PageFeed / PageProfile) ────────────────

    function formatDate(dateStr) {
        if (!dateStr || dateStr.length === 0) return ""
        var d = new Date(dateStr.replace(" ", "T"))
        if (isNaN(d.getTime())) return dateStr

        var now = new Date()
        var secs = (now - d) / 1000
        if (secs < 60) return qsTr("Just now")

        var mins = secs / 60
        if (mins < 60) {
            var m = Math.floor(mins)
            return m === 1 ? qsTr("1 minute ago") : qsTr("%1 minutes ago").arg(m)
        }
        var hours = mins / 60
        if (hours < 24) {
            var h = Math.floor(hours)
            return h === 1 ? qsTr("1 hour ago") : qsTr("%1 hours ago").arg(h)
        }
        var days = hours / 24
        if (days < 2) return qsTr("Yesterday")
        if (days < 7) return qsTr("%1 days ago").arg(Math.floor(days))

        var weeks = days / 7
        if (weeks < 5) {
            var w = Math.floor(weeks)
            return w === 1 ? qsTr("1 week ago") : qsTr("%1 weeks ago").arg(w)
        }
        var months = days / 30.44
        if (months < 12) {
            var mo = Math.floor(months)
            return mo === 1 ? qsTr("1 month ago") : qsTr("%1 months ago").arg(mo)
        }
        var monthNames = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        return monthNames[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear()
    }

    function formatDateAbsolute(dateStr) {
        if (!dateStr || dateStr.length === 0) return ""
        var d = new Date(dateStr.replace(" ", "T"))
        if (isNaN(d.getTime())) return dateStr
        var monthNames = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        return monthNames[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear()
    }

    function formatSize(bytes) {
        if (!bytes || bytes <= 0) return ""
        var kb = bytes / 1024
        if (kb < 1024) return kb.toFixed(0) + " KB"
        var mb = kb / 1024
        if (mb < 1024) return mb.toFixed(1) + " MB"
        return (mb / 1024).toFixed(2) + " GB"
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
            text: si.direction > 0 ? "⏩ 10s" : "10s ⏪"
            color: "#FFFFFF"
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }

    // ActionPill — YouTube-style wide pill button on the watch page action
    // rail. Shows glyph + label + optional hint ("in 2", "42%") with an
    // animated progress fill underneath when `progress > 0`. When `primary`
    // is set the colour flips to the accent, matching tdesktop's primary
    // button treatment in the message context menu for confirmable actions.
    component ActionPill : Rectangle {
        id: ap
        property string glyph: ""
        property string label: ""
        property string hint: ""
        property bool primary: false
        property bool enabled_: enabled
        property real progress: 0
        signal triggered()

        Layout.preferredHeight: 38
        Layout.preferredWidth: apRow.implicitWidth + 22
        radius: 19

        opacity: enabled ? 1.0 : 0.55

        color: primary
               ? (apMouse.pressed ? PlazmaStyle.color.burntOrange
                  : (apMouse.containsMouse ? PlazmaStyle.color.warmGold
                                            : PlazmaStyle.color.goldenApricot))
               : (apMouse.pressed ? PlazmaStyle.color.softGoldenApricot
                  : (apMouse.containsMouse ? PlazmaStyle.color.softAmber
                                            : PlazmaStyle.color.creamWhite))
        border.color: primary ? "transparent" : PlazmaStyle.color.inputBorder
        border.width: 1

        Behavior on color { ColorAnimation { duration: 140 } }
        scale: apMouse.pressed ? 0.97 : 1.0
        Behavior on scale { NumberAnimation { duration: 120 } }

        // Progress fill — a rounded rectangle inset 2px so the border
        // radius shows through. Shown only during an active download.
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 2
            radius: ap.radius - 2
            width: Math.max(0, (parent.width - 4) * Math.min(1, Math.max(0, ap.progress)))
            visible: ap.progress > 0
            color: Qt.rgba(1, 1, 1, 0.22)
        }

        RowLayout {
            id: apRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: ap.glyph
                color: ap.primary ? "#FFFFFF" : PlazmaStyle.color.warmGold
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Text {
                text: ap.label
                color: ap.primary ? "#FFFFFF" : PlazmaStyle.color.textPrimary
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Text {
                visible: ap.hint.length > 0
                text: "· " + ap.hint
                color: ap.primary ? "#EDE4FB" : PlazmaStyle.color.textSecondary
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }

        MouseArea {
            id: apMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: ap.enabled
            cursorShape: ap.enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
            onClicked: ap.triggered()
        }
    }

    // MetaChip — compact key-value pill under the action rail. Uniform
    // look-and-feel across the whole info panel, no colour variants (keeps
    // the accent reserved for interactive elements).
    component MetaChip : Rectangle {
        id: mc
        property string glyph: ""
        property string text: ""

        Layout.preferredHeight: 26
        implicitWidth: mcRow.implicitWidth + 14
        height: 26
        radius: 13
        color: PlazmaStyle.color.softAmber
        visible: text.length > 0

        RowLayout {
            id: mcRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                visible: mc.glyph.length > 0
                text: mc.glyph
                color: PlazmaStyle.color.warmGold
                font.pixelSize: 11
            }

            Text {
                text: mc.text
                color: PlazmaStyle.color.warmGold
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }
    }

    // AboutRow — label + value pair for the about grid. Two columns per
    // row so long URLs wrap into the value cell.
    component AboutRow : RowLayout {
        id: ar
        property string label: ""
        property string value: ""
        property bool mono: false

        Layout.fillWidth: true
        spacing: 10

        Text {
            Layout.preferredWidth: 120
            text: ar.label
            font.pixelSize: 12
            color: PlazmaStyle.color.textHint
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: ar.value
            font.pixelSize: 12
            font.family: ar.mono ? "Monospace" : ""
            color: PlazmaStyle.color.textPrimary
            wrapMode: Text.WrapAnywhere
        }
    }
}
