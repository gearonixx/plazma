import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import Style 1.0


Button {
    id: root

    property string hoveredColor: AmneziaStyle.color.lightGray
    property string defaultColor: AmneziaStyle.color.paleGray
    property string disabledColor: AmneziaStyle.color.charcoalGray
    property string pressedColor: AmneziaStyle.color.mutedGray

    property string textColor: AmneziaStyle.color.midnightBlack

    property string borderColor: AmneziaStyle.color.paleGray
    property string borderFocusedColor: AmneziaStyle.color.paleGray
    property int borderWidth: 0
    property int borderFocusedWidth: 1

    hoverEnabled: true
    implicitHeight: 56

    property var clickedFunc

    property bool isFocusable: true

    onClicked: {
        if (root.clickedFunc && typeof root.clickedFunc === 'function')  {
            root.clickedFunc()
        };
    }
}
