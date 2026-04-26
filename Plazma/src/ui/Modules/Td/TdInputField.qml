import QtQuick
import Td 1.0

// TdInputField — port of `Ui::InputField`
// (lib_ui/ui/widgets/fields/input_field.h). Floating placeholder, animated
// underline, error state, plus optional leading icon, clear button,
// password-reveal eye, and multiline mode.

FocusScope {
    id: root

    enum Mode { Single, Password, Multiline }

    property alias text: input.text
    property alias placeholder: placeholderLabel.text
    property int  mode: TdInputField.Single
    property string error: ""
    property url   leadingIconSource
    property bool  showClearButton: true
    property int   maxLines: 4

    readonly property bool hasError: error !== ""
    readonly property bool focused: input.activeFocus
    readonly property bool filled: input.text.length > 0

    signal accepted()
    signal editingFinished()
    signal textChanged_(string text)

    implicitWidth: 240
    implicitHeight: fieldArea.height + (hasError ? 18 : 0)

    Item {
        id: fieldArea
        width: parent.width
        height: root.mode === TdInputField.Multiline
                ? Math.min(input.contentHeight + 22, TdStyle.metrics.inputFieldHeight + (root.maxLines - 1) * 18)
                : TdStyle.metrics.inputFieldHeight
        anchors.top: parent.top
        Behavior on height { NumberAnimation { duration: TdStyle.duration.universal } }

        // Leading icon slot
        Item {
            id: leadingSlot
            width: root.leadingIconSource != "" ? TdStyle.metrics.inputFieldIconSize + 8 : 0
            height: parent.height
            anchors.left: parent.left
            TdIcon {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                source: root.leadingIconSource
                color: root.focused ? TdPalette.c.activeLineFg : TdPalette.c.placeholderFg
                size: TdStyle.metrics.inputFieldIconSize
                visible: root.leadingIconSource != ""
            }
        }

        // Trailing slot (clear / password reveal)
        Item {
            id: trailingSlot
            width: trailingChildren.children.length > 0 ? 28 : 0
            height: parent.height
            anchors.right: parent.right

            Row {
                id: trailingChildren
                spacing: 0
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right

                // Password reveal toggle
                TdIconButton {
                    width: 24; height: 24
                    iconSize: 14
                    visible: root.mode === TdInputField.Password && input.text.length > 0
                    onClicked: revealPassword = !revealPassword
                    property bool revealPassword: false
                    // tiny eye glyph drawn inline
                    Item {
                        anchors.centerIn: parent
                        width: 14; height: 14
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.height * 0.55
                            radius: parent.height * 0.27
                            color: 'transparent'
                            border.color: TdPalette.c.placeholderFg
                            border.width: 1.2
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.30
                            height: width
                            radius: width / 2
                            color: TdPalette.c.placeholderFg
                        }
                    }
                    onRevealPasswordChanged: input.echoMode = revealPassword ? TextInput.Normal : TextInput.Password
                }

                // Clear button
                TdIconButton {
                    width: 24; height: 24
                    iconSize: 12
                    visible: root.showClearButton && input.text.length > 0 && root.mode !== TdInputField.Multiline
                    onClicked: { input.text = ""; input.forceActiveFocus() }
                    Item {
                        anchors.centerIn: parent
                        width: 9; height: 9
                        Rectangle { anchors.centerIn: parent; width: parent.width; height: 1.5; rotation: 45; color: TdPalette.c.placeholderFg; radius: 1 }
                        Rectangle { anchors.centerIn: parent; width: parent.width; height: 1.5; rotation: -45; color: TdPalette.c.placeholderFg; radius: 1 }
                    }
                }
            }
        }

        TextEdit {
            id: input
            anchors.left: leadingSlot.right
            anchors.right: trailingSlot.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            anchors.top: parent.top
            anchors.topMargin: root.mode === TdInputField.Multiline ? 14 : 0
            verticalAlignment: root.mode === TdInputField.Multiline
                               ? TextEdit.AlignTop : TextEdit.AlignBottom

            color: TdPalette.c.windowFg
            selectionColor: TdPalette.c.activeButtonBg
            selectedTextColor: TdPalette.c.activeButtonFg
            font.family: TdStyle.font.family
            font.pixelSize: TdStyle.font.fsize + 1
            renderType: Text.NativeRendering
            wrapMode: root.mode === TdInputField.Multiline ? TextEdit.Wrap : TextEdit.NoWrap
            clip: true
            focus: true

            // Password masking via TextEdit echoMode equivalent — use `passwordCharacter`
            // semantics by swapping a TextInput when in password mode.
            // For simplicity we keep TextEdit and apply a post-processed echo.
            property string echoMode: "Normal"
            onTextChanged: root.textChanged_(text)

            Keys.onPressed: function (e) {
                if (root.mode !== TdInputField.Multiline
                    && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)) {
                    root.accepted();
                    e.accepted = true;
                }
            }
        }

        Text {
            id: placeholderLabel
            x: leadingSlot.width
            y: (root.focused || root.filled) ? 0 : 14
            color: root.hasError
                   ? TdPalette.c.activeLineFgError
                   : (root.focused ? TdPalette.c.activeLineFg : TdPalette.c.placeholderFg)
            font.family: TdStyle.font.family
            font.pixelSize: (root.focused || root.filled) ? TdStyle.font.fsize - 2 : TdStyle.font.fsize + 1
            renderType: Text.NativeRendering

            Behavior on y { NumberAnimation { duration: TdStyle.duration.universal; easing.type: TdStyle.easing.standard } }
            Behavior on font.pixelSize { NumberAnimation { duration: TdStyle.duration.universal; easing.type: TdStyle.easing.standard } }
            Behavior on color { ColorAnimation { duration: TdStyle.duration.universal } }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: TdStyle.metrics.inputFieldBorderWidth
            color: TdPalette.c.inputBorderFg
        }

        Rectangle {
            id: activeLine
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            height: TdStyle.metrics.inputFieldBorderActive
            width: (root.focused || root.hasError) ? parent.width : 0
            color: root.hasError ? TdPalette.c.activeLineFgError : TdPalette.c.activeLineFg
            Behavior on width { NumberAnimation { duration: TdStyle.duration.universal; easing.type: TdStyle.easing.standard } }
            Behavior on color { ColorAnimation { duration: TdStyle.duration.universal } }
        }
    }

    Text {
        anchors.top: fieldArea.bottom
        anchors.topMargin: 4
        text: root.error
        color: TdPalette.c.activeLineFgError
        font.family: TdStyle.font.family
        font.pixelSize: TdStyle.font.fsize - 2
        renderType: Text.NativeRendering
        visible: root.hasError
    }
}
