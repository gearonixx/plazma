import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import dev.gearonixx.plazma 1.0

import "../Controls"

import PageEnum 1.0


Page {
    id: root
    anchors.fill: parent

    ColumnLayout {
        id: content

        anchors.fill: parent
        spacing: 0

        BasicButtonType {
            id: startButton
            Layout.fillWidth: true
            Layout.bottomMargin: 48
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.alignment: Qt.AlignBottom

            text: "Let's get started"


            clickedFunc: function() {
                PageController.goToPage(PageEnum.PageLogin)
            }

        }
    }

}
