// Notification popups (top right of the focused monitor). Quickshell is the
// notification daemon, so no mako/dunst is needed.
//
//   click        default action, or dismiss when there is none
//   right click  dismiss
//   hover        keeps it on screen
//
//   qs -c archminimal ipc call notifications clear   (Super+N)
//   qs -c archminimal ipc call notifications dnd     (Super+Shift+N)
//
// Do not disturb drops everything except critical notifications (low battery,
// failed updates). There is no history panel, by design.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications

Scope {
    id: root

    readonly property var list: server.trackedNotifications.values

    function clear() {
        for (const n of list.slice()) n.dismiss()
    }

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        imageSupported: true
        persistenceSupported: false

        onNotification: n => {
            if (NotifyState.dnd && n.urgency !== NotificationUrgency.Critical)
                return                                  // untracked = dropped
            const shown = root.list
            for (let i = 0; i <= shown.length - Theme.notifyMax; i++)
                shown[i].expire()
            n.tracked = true
        }
    }

    PanelWindow {
        id: win

        readonly property var focusedScreen: {
            const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
            return Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0]
        }

        visible: root.list.length > 0
        screen: focusedScreen
        anchors { top: true; right: true }
        margins { top: Theme.barHeight + 10; right: 10 }
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 380
        implicitHeight: Math.max(1, stack.contentHeight)
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "archminimal-notifications"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        ListView {
            id: stack
            width: parent.width
            height: contentHeight
            spacing: 8
            interactive: false
            // the server's live model, so existing popups keep their timers;
            // bottom-to-top puts the newest on top
            verticalLayoutDirection: ListView.BottomToTop
            model: server.trackedNotifications

            delegate: Rectangle {
                id: card
                required property var modelData
                readonly property var n: modelData
                readonly property bool critical: n.urgency === NotificationUrgency.Critical
                readonly property var defaultAction: n.actions.find(a => a.identifier === "default") || null
                readonly property var buttons: n.actions.filter(a => a.identifier !== "default" && a.text !== "")
                readonly property string iconSource: n.image !== "" ? n.image
                    : n.appIcon !== "" ? Quickshell.iconPath(n.appIcon, true)
                    : n.desktopEntry !== "" ? Quickshell.iconPath(n.desktopEntry, true) : ""

                width: stack.width
                implicitHeight: body.implicitHeight + 26
                color: Theme.panel
                border { width: 1; color: critical ? Theme.danger : "#2e00e5ff" }

                // accent rule on the left, as on the launcher's selected row
                Rectangle {
                    x: 0; y: 10; width: 2; height: parent.height - 20
                    color: card.critical ? Theme.danger : Theme.accent
                }

                Timer {
                    // the app's timeout arrives in milliseconds (as sent over D-Bus),
                    // otherwise our default; critical ones stay until clicked
                    interval: card.n.expireTimeout > 0 ? card.n.expireTimeout : Theme.notifyTimeout * 1000
                    running: !card.critical && !ma.containsMouse
                    onTriggered: card.n.expire()
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton && card.defaultAction) card.defaultAction.invoke()
                        else card.n.dismiss()
                    }
                }

                Row {
                    id: body
                    x: 18; y: 13
                    width: parent.width - 36
                    spacing: 14

                    Image {
                        id: icon
                        visible: card.iconSource !== "" && status !== Image.Error
                        width: 36; height: 36
                        sourceSize: Qt.size(72, 72)
                        source: card.iconSource
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                    }

                    Column {
                        width: body.width - (icon.visible ? icon.width + body.spacing : 0)
                        spacing: 4

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: (card.n.appName || "notification").toLowerCase()
                            color: card.critical ? Theme.danger : Theme.mute
                            font { family: Theme.font; pixelSize: 10; letterSpacing: 2 }
                        }
                        Text {
                            width: parent.width
                            visible: text !== ""
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            text: card.n.summary
                            color: Theme.fg
                            font { family: Theme.font; pixelSize: 13; letterSpacing: 0.5 }
                        }
                        Text {
                            width: parent.width
                            visible: text !== ""
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            text: card.n.body
                            color: Theme.mute
                            font { family: Theme.font; pixelSize: 11; letterSpacing: 0.5 }
                        }
                        Row {
                            visible: card.buttons.length > 0
                            topPadding: 4
                            spacing: 16
                            Repeater {
                                model: card.buttons
                                Text {
                                    required property var modelData
                                    text: "› " + modelData.text.toLowerCase()
                                    color: btn.containsMouse ? Theme.accent : Theme.fg
                                    font { family: Theme.font; pixelSize: 11; letterSpacing: 1.5 }
                                    MouseArea {
                                        id: btn
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: parent.modelData.invoke()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "notifications"
        function clear(): void { root.clear() }
        function dnd(): void { NotifyState.dnd = !NotifyState.dnd }
        function isDnd(): bool { return NotifyState.dnd }
    }
}
