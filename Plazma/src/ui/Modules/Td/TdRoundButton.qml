import QtQuick
import Td 1.0

// TdRoundButton — port of `Ui::RoundButton`
// (lib_ui/ui/widgets/buttons.h). Style variants matching upstream:
//   - "active":    filled accent (default)
//   - "light":     transparent text-style
//   - "attention": destructive
//
// Optional leading icon (via TdIcon), optional `fullWidth` to fill the
// parent's width.

Item {
    id: root

    enum Variant { Active, Light, Attention }

    property string text: ""
    property int variant: TdRoundButton.Active
    property bool busy: false
    property bool enabledState: !busy
    property bool fullWidth: false
    property real radius: TdStyle.metrics.buttonRadius
    property int  paddingHorizontal: TdStyle.metrics.buttonPadding
    property url  iconSource

    signal clicked()

    implicitHeight: TdStyle.metrics.buttonHeight
    implicitWidth: fullWidth
        ? (parent ? parent.width : 200)
        : Math.max(label.implicitWidth + paddingHorizontal * 2 + (iconSource != "" ? 22 : 0),
                   TdStyle.metrics.buttonMinWidth)

    readonly property color _bgIdle:  variant === TdRoundButton.Active ? TdPalette.c.activeButtonBg
                                    : variant === TdRoundButton.Light  ? TdPalette.c.lightButtonBg
                                                                       : TdPalette.c.attentionButtonBgOver
    readonly property color _bgOver:  variant === TdRoundButton.Active ? TdPalette.c.activeButtonBgOver
                                    : variant === TdRoundButton.Light  ? TdPalette.c.lightButtonBgOver
                                                                       : TdPalette.c.attentionButtonBgOver
    readonly property color _ripple:  variant === TdRoundButton.Active ? TdPalette.c.activeButtonBgRipple
                                    : variant === TdRoundButton.Light  ? TdPalette.c.lightButtonBgRipple
                                                                       : TdPalette.c.attentionButtonBgRipple
    readonly property color _fg:      variant === TdRoundButton.Active ? TdPalette.c.activeButtonFg
                                    : variant === TdRoundButton.Light  ? TdPalette.c.lightButtonFg
                                                                       : TdPalette.c.attentionButtonFg

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.radius
        color: button.hovered ? root._bgOver : root._bgIdle
        opacity: root.enabledState ? 1.0 : 0.55
        Behavior on color { ColorAnimation { duration: TdStyle.duration.universal; easing.type: TdStyle.easing.standard } }
    }

    TdAbstractButton {
        id: button
        anchors.fill: parent
        rippleColor: root._ripple
        enabledState: root.enabledState
        onClicked: root.clicked()

        Row {
            anchors.centerIn: parent
            spacing: TdStyle.metrics.buttonIconSpacing
            visible: !root.busy

            TdIcon {
                anchors.verticalCenter: parent.verticalCenter
                source: root.iconSource
                color: root._fg
                size: 16
                visible: root.iconSource != ""
            }

            Text {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                color: root._fg
                font.family: TdStyle.font.family
                font.pixelSize: TdStyle.font.fsize + 1
                font.weight: TdStyle.font.weightSemibold
                renderType: Text.NativeRendering
            }
        }

        TdSpinner {
            anchors.centerIn: parent
            visible: root.busy
            color: root._fg
            size: 18
            thickness: 2
            running: root.busy
        }
    }
}
