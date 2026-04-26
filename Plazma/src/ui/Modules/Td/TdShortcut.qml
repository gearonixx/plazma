import QtQuick

// TdShortcut — thin wrapper around QtQuick's Shortcut with a friendly
// API mirroring tdesktop's `Shortcuts::Listen` helper. Place inside any
// Item; binds globally to the window unless `context = ApplicationShortcut`.

Shortcut {
    id: root

    // Inherit Shortcut's `sequence`, `enabled`, etc. Add aliases for
    // discoverability:
    property alias keys: root.sequence
    property string description: ""

    autoRepeat: false
    context: Qt.WindowShortcut
}
