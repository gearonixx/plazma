import QtQuick
import QtQuick.Controls

import "Pages"

import dev.gearonixx.plazma 1.0

import PageEnum 1.0
import Style 1.0

ApplicationWindow {
    id: root
    width: 780
    height: 540
    minimumWidth: 780
    minimumHeight: 540
    maximumWidth: 780
    maximumHeight: 540
    visible: true
    title: "Plazma"
    visibility: Window.Windowed
    color: PlazmaStyle.color.warmWhite

    function leaveSplashIfNeeded(page) {
        if (!stackView.currentItem || stackView.currentItem.objectName !== "splash") {
            return
        }
        const pagePath = PageController.getPagePath(page);
        stackView.replace(null, pagePath, {}, StackView.Immediate);
    }

    function reroute() {
        if (Session.valid) {
            const pagePath = PageController.getPagePath(PageEnum.PageFeed);
            if (stackView.currentItem && stackView.currentItem.objectName === pagePath) return
            if (stackView.currentItem && stackView.currentItem.objectName !== "splash") return
            stackView.replace(null, pagePath, { "objectName": pagePath }, StackView.Immediate);
        } else if (PhoneNumberModel.waitingForPhone || Session.errorMessage !== "") {
            leaveSplashIfNeeded(PageEnum.PageStart);
        }
    }

    Component.onCompleted: reroute()

    Connections {
        objectName: "pageControllerConnection"
        target: PageController

        function onGoToPageRequested(page) {
            const pagePath = PageController.getPagePath(page);
            stackView.push(pagePath, { "objectName": pagePath }, StackView.Immediate);
        }

        function onReplacePageRequested(page) {
            const pagePath = PageController.getPagePath(page);
            stackView.replace(null, pagePath, { "objectName": pagePath }, StackView.Immediate);
        }
    }

    Connections {
        target: Session

        function onSessionChanged() { reroute() }
        function onErrorChanged() { reroute() }
    }

    Connections {
        target: PhoneNumberModel

        function onWaitingForPhoneChanged() { reroute() }
    }

    Timer {
        id: splashFailsafe
        interval: 8000
        running: true
        repeat: false
        onTriggered: leaveSplashIfNeeded(PageEnum.PageStart)
    }

    StackView {
        id: stackView
        anchors.fill: parent

        initialItem: Rectangle {
            objectName: "splash"
            color: PlazmaStyle.color.warmWhite

            Rectangle {
                anchors.centerIn: parent
                width: 120
                height: 120
                radius: 60
                color: PlazmaStyle.color.softAmber

                Text {
                    anchors.centerIn: parent
                    text: "P"
                    font.pixelSize: 52
                    font.weight: Font.Bold
                    color: PlazmaStyle.color.warmGold
                }
            }
        }
    }
}