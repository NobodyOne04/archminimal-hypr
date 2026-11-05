// A bar module: dim label, value, optional meter, and a details popup on hover.
import QtQuick
import Quickshell

Item {
    id: mod

    required property var barWindow
    property string label
    property string value
    property real meter: -1              // 0..100; negative hides the meter
    property bool hot: false             // value turns red
    property bool accent: false          // value turns cyan
    property bool clickable: false
    property Component tip: null         // popup contents (Column of Kv)

    signal clicked(var mouse)
    signal scrolled(int delta)

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: mod.label !== ""
            text: mod.label
            color: Theme.mute
            font { family: Theme.font; pixelSize: 10; letterSpacing: 2 }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: mod.value
            color: mod.hot ? Theme.danger : mod.accent ? Theme.accent : (ma.containsMouse && mod.clickable ? Theme.accent : Theme.fg)
            font { family: Theme.font; pixelSize: 12; letterSpacing: 1.5 }
        }
        Item {
            anchors.verticalCenter: parent.verticalCenter
            visible: mod.meter >= 0
            width: 22; height: 2
            Rectangle { anchors.fill: parent; color: "#14ffffff" }
            Rectangle {
                height: parent.height
                width: parent.width * Math.max(0, Math.min(100, mod.meter)) / 100
                color: mod.hot ? Theme.danger : Theme.mute
                Behavior on width { NumberAnimation { duration: 500 } }
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: mod.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => mod.clicked(mouse)
        onWheel: wheel => mod.scrolled(wheel.angleDelta.y)
    }

    // Show details after a short hover, so passing the mouse over the bar
    // does not flash popups.
    Timer {
        id: hoverDelay
        interval: 350
        running: ma.containsMouse && mod.tip !== null
        onTriggered: popup.visible = true
    }
    Connections {
        target: ma
        function onContainsMouseChanged() { if (!ma.containsMouse) popup.visible = false }
    }

    PopupWindow {
        id: popup
        visible: false
        color: "transparent"
        anchor.window: mod.barWindow
        anchor.rect.x: {
            const p = mod.mapToItem(null, 0, 0)
            const x = p.x + mod.width / 2 - implicitWidth / 2
            return Math.max(8, Math.min(x, mod.barWindow.width - implicitWidth - 8))
        }
        anchor.rect.y: Theme.barHeight + 6
        implicitWidth: content.implicitWidth + 28
        implicitHeight: content.implicitHeight + 24

        Rectangle {
            anchors.fill: parent
            color: Theme.panel
            border { width: 1; color: "#2600e5ff" }

            Loader {
                id: content
                x: 14; y: 12
                active: popup.visible
                sourceComponent: mod.tip
            }
        }
    }
}
