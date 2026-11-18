// Notification center (ADR-0011): this session's notifications, newest first, under the bar at the
// right edge of the focused monitor. Opened by the bar's `ntf` module, Super+Alt+N or
// `qs -c archminimal ipc call notifications panel`.
//
//   click a row   its default action, while the app still holds the notification
//   ×             clear that one          clear all   clear every one
//   dnd           toggle do not disturb   Esc / click outside   close
//
// Built like the calendar: a transparent full-screen overlay holding the card, created only while open.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: nc

    readonly property var focusedScreen: {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        return Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0]
    }

    function close() { NotifyState.panelOpen = false }
    function ago(t, now) {
        const s = Math.max(0, Math.floor((now - t) / 1000))
        return s < 60 ? "now" : s < 3600 ? Math.floor(s / 60) + "m" : s < 86400 ? Math.floor(s / 3600) + "h" : Math.floor(s / 86400) + "d"
    }

    visible: NotifyState.panelOpen
    screen: focusedScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "archminimal-notification-center"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    SystemClock { id: clock; precision: SystemClock.Minutes; enabled: nc.visible }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: nc.close()
    }

    Rectangle {
        id: card
        anchors { top: parent.top; right: parent.right; topMargin: Theme.barHeight + 8; rightMargin: 10 }
        width: 400
        height: Math.min(parent.height * 0.75, head.height + Math.max(list.contentHeight, 24) + 48)
        color: Theme.panel
        border { width: 1; color: "#2e00e5ff" }
        focus: true
        Keys.onEscapePressed: nc.close()

        // eat clicks on the card so they don't reach the backdrop
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        // ---- header: sys::notifications  N        dnd off   clear all ----
        Item {
            id: head
            x: 18; y: 16
            width: parent.width - 36
            height: 18

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Text {
                    text: "sys::notifications"
                    color: Theme.accent
                    font { family: Theme.font; pixelSize: 11; letterSpacing: 2 }
                }
                Text {
                    text: String(NotifyState.history.length)
                    color: Theme.dim
                    font { family: Theme.font; pixelSize: 11; letterSpacing: 2 }
                }
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 16
                Text {
                    text: "dnd " + (NotifyState.dnd ? "on" : "off")
                    color: dndMa.containsMouse ? Theme.accent : NotifyState.dnd ? Theme.danger : Theme.mute
                    font { family: Theme.font; pixelSize: 11; letterSpacing: 1.5 }
                    MouseArea {
                        id: dndMa
                        anchors.fill: parent; anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotifyState.dnd = !NotifyState.dnd
                    }
                }
                Text {
                    visible: NotifyState.history.length > 0
                    text: "clear all"
                    color: clearMa.containsMouse ? Theme.danger : Theme.mute
                    font { family: Theme.font; pixelSize: 11; letterSpacing: 1.5 }
                    MouseArea {
                        id: clearMa
                        anchors.fill: parent; anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotifyState.clearAll()
                    }
                }
            }
        }

        Text {
            visible: NotifyState.history.length === 0
            x: 18; y: head.y + head.height + 16
            text: "nothing here"
            color: Theme.dim
            font { family: Theme.font; pixelSize: 11; letterSpacing: 1.5 }
        }

        ListView {
            id: list
            x: 8; y: head.y + head.height + 14
            width: parent.width - 16
            height: parent.height - y - 10
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: ScriptModel { values: NotifyState.history; objectProp: "key" }

            delegate: Item {
                id: row
                required property var modelData
                readonly property var e: modelData
                readonly property var n: NotifyState.live[e.key] || null
                readonly property var buttons: n ? n.actions.filter(a => a.identifier !== "default" && a.text !== "") : []
                readonly property bool hasDefault: !!n && n.actions.some(a => a.identifier === "default")

                width: list.width
                implicitHeight: body.implicitHeight + 20

                Rectangle {
                    anchors.fill: parent
                    color: rowMa.containsMouse ? "#0affffff" : "transparent"
                }
                // accent rule on the left: cyan while the app still holds it, red when critical
                Rectangle {
                    x: 0; y: 10; width: 2; height: parent.height - 20
                    color: row.e.critical ? Theme.danger : row.n ? Theme.accent : Theme.line
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: row.hasDefault ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (row.hasDefault) NotifyState.act(row.e.key, null)
                }

                Row {
                    id: body
                    x: 12; y: 10
                    width: parent.width - 24
                    spacing: 12

                    Image {
                        id: icon
                        visible: row.e.icon !== "" && status !== Image.Error
                        width: 28; height: 28
                        sourceSize: Qt.size(56, 56)
                        source: row.e.icon
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    Column {
                        width: body.width - (icon.visible ? icon.width + body.spacing : 0)
                        spacing: 3

                        Item {
                            width: parent.width
                            height: appText.implicitHeight
                            Text {
                                id: appText
                                width: parent.width - 60
                                elide: Text.ElideRight
                                text: row.e.app.toLowerCase() + " · " + nc.ago(row.e.time, clock.date)
                                color: row.e.critical ? Theme.danger : Theme.mute
                                font { family: Theme.font; pixelSize: 10; letterSpacing: 2 }
                            }
                            Text {
                                anchors.right: parent.right
                                text: "×"
                                color: xMa.containsMouse ? Theme.danger : Theme.dim
                                font { family: Theme.font; pixelSize: 13 }
                                MouseArea {
                                    id: xMa
                                    anchors.fill: parent; anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NotifyState.remove(row.e.key)
                                }
                            }
                        }
                        Text {
                            width: parent.width
                            visible: text !== ""
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            text: row.e.summary
                            color: Theme.fg
                            font { family: Theme.font; pixelSize: 12; letterSpacing: 0.5 }
                        }
                        Text {
                            width: parent.width
                            visible: text !== ""
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            text: row.e.body
                            color: Theme.mute
                            font { family: Theme.font; pixelSize: 11; letterSpacing: 0.5 }
                        }
                        Row {
                            visible: row.buttons.length > 0
                            topPadding: 2
                            spacing: 16
                            Repeater {
                                model: row.buttons
                                Text {
                                    required property var modelData
                                    text: "› " + modelData.text.toLowerCase()
                                    color: btn.containsMouse ? Theme.accent : Theme.fg
                                    font { family: Theme.font; pixelSize: 11; letterSpacing: 1.5 }
                                    MouseArea {
                                        id: btn
                                        anchors.fill: parent; anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: NotifyState.act(row.e.key, parent.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
