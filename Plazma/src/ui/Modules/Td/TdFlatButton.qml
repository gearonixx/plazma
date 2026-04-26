import QtQuick
import Td 1.0

// TdFlatButton — text-only button (no fill) with hover underline.
// Mirrors the “link button” style used in tdesktop boxes for secondary
// actions like “Forgot password?” / “Sign up”.

Item {
    id: root

    property string text: ""
    property bool   destructive: false
    property bool   enabledState: true

    signal clicked()

    implicitHeight: TdStyle.metrics.flatButtonHeight
    implicitWidth: label.implicitWidth + TdStyle.metrics.flatButtonPadding * 2

    TdAbstractButton {
        id: button
        anchors.fill: parent
        rippleColor: 'transparent'
        ripplesEnabled: false
        enabledState: root.enabledState
        onClicked: root.clicked()

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: !root.enabledState ? TdPalette.c.menuFgDisabled
                : root.destructive   ? TdPalette.c.attentionButtonFg
                : button.hovered     ? TdPalette.c.linkFgOver
                                     : TdPalette.c.linkFg
            font.family: TdStyle.font.family
            font.pixelSize: TdStyle.font.fsize + 1
            font.weight: TdStyle.font.weightMedium
            font.underline: button.hovered
            renderType: Text.NativeRendering
        }
    }
}
