import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import dev.gearonixx.plazma 1.0

import "../Controls"

import Style 1.0

Page {
    id: root

    background: Rectangle {
        color: PlazmaStyle.color.warmWhite
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width
        spacing: 0

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 24
            width: 96
            height: 96
            radius: 48
            color: PlazmaStyle.color.softAmber

            Text {
                anchors.centerIn: parent
                text: Session.firstName.charAt(0)
                font.pixelSize: 40
                font.weight: Font.Bold
                color: PlazmaStyle.color.warmGold
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 8
            text: qsTr("Welcome, %1").arg(Session.firstName)
            font.pixelSize: 24
            font.weight: Font.Bold
            color: PlazmaStyle.color.textPrimary
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 48
            text: "@" + Session.username
            font.pixelSize: 14
            color: PlazmaStyle.color.textSecondary
            visible: Session.username.length > 0
        }

        BasicButtonType {
            Layout.fillWidth: true
            Layout.leftMargin: 40
            Layout.rightMargin: 40
            Layout.preferredHeight: 50

            defaultColor: PlazmaStyle.color.goldenApricot
            hoveredColor: PlazmaStyle.color.warmGold
            pressedColor: PlazmaStyle.color.burntOrange
            textColor: "#FFFFFF"

            text: qsTr("Upload Video")
            font.pixelSize: 16
            font.weight: Font.DemiBold

            clickedFunc: function() {
                FileDialogModel.openFilePicker()
            }
        }
    }
}
