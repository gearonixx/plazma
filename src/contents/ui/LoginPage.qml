import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import dev.gearonixx.plazma 1.0

Page {
    anchors.fill: parent

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 4

        visible: PhoneNumberModel.waitingForPhone

        TextField {
            id: phoneField
            Layout.fillWidth: true
            placeholderText: "Enter phone..."
            background: Rectangle {
                radius: 8
                color: "#f0f0f0"
                border.color: "#ccc"
            }
        }

        Button {
            text: "Send"
            enabled: phoneField.length > 0
            onClicked: {
                PhoneNumberModel.submitPhoneNumber(phoneField.text)
                phoneField.text = ""
            }
        }


    }

     RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 4

        visible: AuthorizationCodeModel.waitingForAuthCode

        TextField {
            id: codeField
            Layout.fillWidth: true
            placeholderText: "Enter code..."
            background: Rectangle {
                radius: 8
                color: "#f0f0f0"
                border.color: "#ccc"
            }
        }

        Button {
            text: "Send"
            enabled: codeField.length > 0
            onClicked: {
                AuthorizationCodeModel.submitAuthCode(codeField.text)
                codeField.text = ""
            }
        }

    }
}