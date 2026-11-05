// Workspace numbers: 01..N always, plus any busy workspace beyond N.
// Active = cyan with a glowing underline; occupied = light; empty = dim.
// Hyprland 0.57+ dispatches are Lua expressions (hl.dsp.*).
import QtQuick
import Quickshell
import Quickshell.Hyprland

Row {
    id: ws
    spacing: 4

    readonly property int activeId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    readonly property var existing: Hyprland.workspaces.values.map(w => w.id).filter(id => id > 0)
    readonly property var slots: {
        const ids = new Set(existing)
        for (let i = 1; i <= Theme.workspaces; i++) ids.add(i)
        return Array.from(ids).sort((a, b) => a - b)
    }

    Repeater {
        model: ws.slots

        Item {
            required property int modelData
            readonly property bool active: modelData === ws.activeId
            readonly property bool occupied: ws.existing.includes(modelData)

            width: 24
            height: Theme.barHeight

            Text {
                anchors.centerIn: parent
                text: String(parent.modelData).padStart(2, "0")
                color: parent.active ? Theme.accent : parent.occupied ? Theme.mute : Theme.dim
                font { family: Theme.font; pixelSize: 12; letterSpacing: 1.5 }
            }
            Rectangle {
                visible: parent.active
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 6 }
                width: 12; height: 1
                color: Theme.accent
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + parent.modelData + " })")
            }
        }
    }

    // scroll over the numbers to move between workspaces
    WheelHandler {
        onWheel: event => Hyprland.dispatch('hl.dsp.focus({ workspace = "' + (event.angleDelta.y > 0 ? "m-1" : "m+1") + '" })')
    }
}
