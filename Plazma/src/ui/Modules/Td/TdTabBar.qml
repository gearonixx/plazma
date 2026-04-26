import QtQuick
import Td 1.0

// TdTabBar — port of `Ui::SettingsSlider` and similar tab strips
// (lib_ui/ui/widgets/discrete_sliders.h). Underline indicator slides
// between tabs.

Item {
    id: root

    property var    tabs: []        // array of strings
    property int    currentIndex: 0
    property color  indicatorColor: TdPalette.c.activeButtonBg

    signal tabClicked(int index, string label)

    implicitHeight: TdStyle.metrics.tabHeight
    implicitWidth: row.implicitWidth

    Row {
        id: row
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: root.tabs
            delegate: TdTab {
                text: modelData
                active: index === root.currentIndex
                onClicked: {
                    root.currentIndex = index;
                    root.tabClicked(index, modelData);
                }
            }
        }
    }

    // Underline indicator
    Rectangle {
        id: indicator
        height: TdStyle.metrics.tabIndicatorH
        color: root.indicatorColor
        radius: height / 2
        anchors.bottom: parent.bottom
        x: _indicatorX()
        width: _indicatorW()

        Behavior on x     { NumberAnimation { duration: TdStyle.duration.slide; easing.type: TdStyle.easing.standard } }
        Behavior on width { NumberAnimation { duration: TdStyle.duration.slide; easing.type: TdStyle.easing.standard } }

        function _indicatorX() {
            if (row.children.length === 0 || root.currentIndex >= row.children.length) return 0;
            const it = row.children[root.currentIndex];
            return it ? it.x : 0;
        }
        function _indicatorW() {
            if (row.children.length === 0 || root.currentIndex >= row.children.length) return 0;
            const it = row.children[root.currentIndex];
            return it ? it.width : 0;
        }
    }

    // Bottom hairline
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: TdStyle.metrics.lineWidth
        color: TdPalette.c.dividerFg
        z: -1
    }
}
