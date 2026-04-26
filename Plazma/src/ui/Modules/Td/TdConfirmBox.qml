import QtQuick
import Td 1.0

// TdConfirmBox — preset wrap of TdBoxContent for "Are you sure?" flows.
// Title + body text + confirm/cancel pair. Mirrors `Ui::ConfirmBox` in
// tdesktop boxes/confirm_box.cpp.

TdBoxContent {
    id: root

    property string question: ""
    property string confirmText: qsTr("OK")
    property string cancelText: qsTr("Cancel")
    property bool   destructive: false

    signal confirmed()
    signal cancelled()

    boxWidth: 380

    body: [
        Item {
            id: bodyArea
            width: parent ? parent.width : 380
            implicitHeight: questionLabel.implicitHeight + TdStyle.metrics.boxPadding * 2

            Text {
                id: questionLabel
                anchors.fill: parent
                anchors.margins: TdStyle.metrics.boxPadding
                text: root.question
                color: TdPalette.c.windowFg
                wrapMode: Text.WordWrap
                font.family: TdStyle.font.family
                font.pixelSize: TdStyle.font.fsize + 1
                renderType: Text.NativeRendering
            }
        }
    ]

    buttons: [
        TdRoundButton {
            text: root.confirmText
            variant: root.destructive ? TdRoundButton.Attention : TdRoundButton.Active
            onClicked: { root.confirmed(); root.hide(); }
        },
        TdRoundButton {
            text: root.cancelText
            variant: TdRoundButton.Light
            onClicked: { root.cancelled(); root.hide(); }
        }
    ]
}
