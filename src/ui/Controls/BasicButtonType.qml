import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import Style 1.0


Button {
    id: root

    property string hoveredColor: PlazmaStyle.color.lightGray
    property string defaultColor: PlazmaStyle.color.paleGray
    property string disabledColor: PlazmaStyle.color.charcoalGray
    property string pressedColor: PlazmaStyle.color.mutedGray

    property string textColor: PlazmaStyle.color.midnightBlack

    property string borderColor: PlazmaStyle.color.paleGray
    property string borderFocusedColor: PlazmaStyle.color.paleGray
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
