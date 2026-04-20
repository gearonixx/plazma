import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import dev.gearonixx.plazma 1.0

import PageEnum 1.0
import Style 1.0

Rectangle {
    id: root

    property int activePage: PageEnum.PageFeed

    implicitHeight: 52
    color: PlazmaStyle.color.creamWhite
    border.color: PlazmaStyle.color.inputBorder
    border.width: 1
    z: 10

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: 18
            color: PlazmaStyle.color.softAmber

            Text {
                anchors.centerIn: parent
                text: Session.firstName.length > 0 ? Session.firstName.charAt(0) : "?"
                font.pixelSize: 16
                font.weight: Font.Bold
                color: PlazmaStyle.color.warmGold
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text: qsTr("Plazma")
                font.pixelSize: 16
                font.weight: Font.DemiBold
                color: PlazmaStyle.color.textPrimary
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: Session.username.length > 0 ? "@" + Session.username : Session.phoneNumber
                font.pixelSize: 11
                color: PlazmaStyle.color.textSecondary
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        // TODO: remove reload button once background refresh is implemented
        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 16
            color: reloadMouse.containsMouse ? PlazmaStyle.color.softAmber : "transparent"

            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "↻"
                font.pixelSize: 17
                color: VideoFeedModel.loading
                       ? PlazmaStyle.color.textHint
                       : PlazmaStyle.color.textSecondary
            }

            MouseArea {
                id: reloadMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !VideoFeedModel.loading
                onClicked: VideoFeedModel.refresh()
            }
        }

        NavTab {
            label: qsTr("Feed")
            active: root.activePage === PageEnum.PageFeed
            onTriggered: {
                if (!active) PageController.replacePage(PageEnum.PageFeed)
            }
        }

        NavTab {
            label: qsTr("Upload")
            active: root.activePage === PageEnum.PageUpload
            onTriggered: {
                if (!active) PageController.replacePage(PageEnum.PageUpload)
            }
        }
    }

    component NavTab : Rectangle {
        id: tab
        property string label: ""
        property bool active: false
        signal triggered()

        Layout.preferredHeight: 36
        Layout.preferredWidth: 96
        radius: 18

        color: active
               ? PlazmaStyle.color.goldenApricot
               : (mouse.containsMouse ? PlazmaStyle.color.softAmber : "transparent")
        border.color: active ? PlazmaStyle.color.warmGold : PlazmaStyle.color.inputBorder
        border.width: 1

        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: tab.label
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: tab.active ? "#FFFFFF" : PlazmaStyle.color.textPrimary
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tab.triggered()
        }
    }
}
