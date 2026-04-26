pragma Singleton

import QtQuick
import Qt.labs.settings 1.0

// TdTheme — singleton driver that owns the dark/light decision and
// pushes it into TdPalette. Mirrors the role of `Window::Theme` in
// tdesktop (window/themes/window_theme.h) but trimmed to what the
// QML layer needs.
//
// Modes:
//   - Light   :  always light
//   - Dark    :  always dark
//   - System  :  follow Qt.styleHints.colorScheme (Qt 6.5+)
//
// The choice is persisted via Qt.labs.settings so users keep their
// preference across launches.

QtObject {
    id: theme

    enum Mode { Light, Dark, System }

    property int mode: TdTheme.System

    readonly property bool dark: {
        switch (mode) {
        case TdTheme.Light: return false;
        case TdTheme.Dark:  return true;
        default:
            // Qt.styleHints.colorScheme: 1 = Light, 2 = Dark
            return Qt.styleHints && Qt.styleHints.colorScheme === 2;
        }
    }

    onDarkChanged: {
        // Bind into TdPalette without import cycle by deferred lookup
        const p = Qt.createQmlObject(
            'import Td 1.0; QtObject { property var pal: TdPalette }',
            theme, 'TdThemeBindHelper');
        if (p && p.pal) p.pal.dark = dark;
        if (p) p.destroy();
    }

    function toggleDark() {
        mode = dark ? TdTheme.Light : TdTheme.Dark;
    }

    function setLight()  { mode = TdTheme.Light }
    function setDark()   { mode = TdTheme.Dark }
    function setSystem() { mode = TdTheme.System }

    property Settings _store: Settings {
        category: "TdTheme"
        property alias mode: theme.mode
    }

    Component.onCompleted: {
        // Apply once on startup
        const p = Qt.createQmlObject(
            'import Td 1.0; QtObject { property var pal: TdPalette }',
            theme, 'TdThemeBindHelper');
        if (p && p.pal) p.pal.dark = dark;
        if (p) p.destroy();
    }
}
