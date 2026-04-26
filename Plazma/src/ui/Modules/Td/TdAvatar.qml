import QtQuick
import Td 1.0

// TdAvatar — port of `Ui::PeerUserpic` (lib_ui/ui/userpic_button.h).
// Circular avatar with one of seven gradient fallbacks chosen by hashing
// `name`, plus an image when `source` is set.

Item {
    id: root

    property url    source
    property string name: ""
    property int    size: TdStyle.metrics.avatarSizeMedium
    property bool   showInitials: true

    implicitWidth:  size
    implicitHeight: size

    readonly property var _palette: [
        TdPalette.c.avatarBgRed,
        TdPalette.c.avatarBgOrange,
        TdPalette.c.avatarBgYellow,
        TdPalette.c.avatarBgGreen,
        TdPalette.c.avatarBgCyan,
        TdPalette.c.avatarBgBlue,
        TdPalette.c.avatarBgPurple
    ]

    function _hash(s) {
        let h = 0;
        for (let i = 0; i < s.length; ++i) h = (h * 31 + s.charCodeAt(i)) | 0;
        return Math.abs(h);
    }

    function _initials(s) {
        const t = (s || "").trim();
        if (!t) return "?";
        const parts = t.split(/\s+/);
        if (parts.length === 1) return parts[0].substring(0, 1).toUpperCase();
        return (parts[0].substring(0, 1) + parts[parts.length - 1].substring(0, 1)).toUpperCase();
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: width / 2
        color: root._palette[root._hash(root.name) % root._palette.length]
        visible: imageHolder.status !== Image.Ready

        Text {
            anchors.centerIn: parent
            visible: root.showInitials
            text: root._initials(root.name)
            color: 'white'
            font.family: TdStyle.font.family
            font.pixelSize: root.size * 0.42
            font.weight: TdStyle.font.weightSemibold
            renderType: Text.NativeRendering
        }
    }

    Item {
        anchors.fill: parent
        visible: imageHolder.status === Image.Ready
        clip: true
        Image {
            id: imageHolder
            anchors.fill: parent
            source: root.source
            sourceSize.width: root.size * 2
            sourceSize.height: root.size * 2
            fillMode: Image.PreserveAspectCrop
            smooth: true
            antialiasing: true
            asynchronous: true
            // Round mask via container clip + rectangle frame.
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: 'transparent'
            border.color: TdPalette.c.dividerFg
            border.width: 1
        }
    }

    layer.enabled: true
    layer.smooth: true
}
