// Super + / : every key bind, read live from Hyprland (`hyprctl binds -j`), so
// it never drifts from hyprland.lua. Only binds with a "group: what" description
// are listed; binds sharing a description are merged (Super + 1…9).
//
//   qs -c archminimal ipc call keys toggle
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property bool open: false
    property var groups: []        // [{ name, rows: [{ keys, what }] }]

    readonly property var order: ["apps", "session", "windows", "focus", "workspaces", "screenshots", "media"]
    readonly property var keyNames: ({
        "Return": "enter", "Escape": "esc", "slash": "/", "Print": "print", "Tab": "tab", "Space": "space",
        "space": "space", "left": "←", "right": "→", "up": "↑", "down": "↓",
        "mouse:272": "left drag", "mouse:273": "right drag", "mouse_down": "scroll", "mouse_up": "scroll",
        "XF86AudioRaiseVolume": "vol +", "XF86AudioLowerVolume": "vol −", "XF86AudioMute": "mute key",
        "XF86AudioMicMute": "mic key", "XF86MonBrightnessUp": "bright +", "XF86MonBrightnessDown": "bright −",
        "XF86AudioPlay": "play", "XF86AudioPause": "pause", "XF86AudioNext": "next", "XF86AudioPrev": "prev"
    })

    function mods(mask) {
        const out = []
        if (mask & 64) out.push("super")
        if (mask & 4) out.push("ctrl")
        if (mask & 8) out.push("alt")
        if (mask & 1) out.push("shift")
        return out
    }

    function keyName(k) {
        return keyNames[k] !== undefined ? keyNames[k] : k.toLowerCase()
    }

    // binds JSON -> groups of rows, in the order above
    function build(json) {
        let binds = []
        try { binds = JSON.parse(json) } catch (e) { return [] }
        const rows = {}            // "group\u0000what\u0000mods" -> row
        for (const b of binds) {
            const d = b.description || ""
            const colon = d.indexOf(": ")
            if (colon < 0) continue
            const group = d.slice(0, colon), what = d.slice(colon + 2)
            const m = mods(b.modmask).join(" + ")
            const id = group + "\u0000" + what + "\u0000" + m
            if (!rows[id]) rows[id] = { group: group, what: what, mods: m, keys: [] }
            const k = keyName(b.key)
            if (!rows[id].keys.includes(k)) rows[id].keys.push(k)
        }
        // merge rows with the same description: "super + h j k / super + ← ↓ ↑ →"
        const byWhat = {}
        for (const r of Object.values(rows)) {
            let keys = r.keys
            if (keys.length >= 3 && keys.every(k => /^[0-9]$/.test(k)))
                keys = [keys[0] + "…" + keys[keys.length - 1]]
            // h j k l / arrows read as one set; other alternatives get a slash
            const set = keys.length >= 3 && keys.every(k => k.length === 1)
            const text = (r.mods ? r.mods + " + " : "") + keys.join(set ? " " : " / ")
            const id = r.group + "\u0000" + r.what
            if (!byWhat[id]) byWhat[id] = { group: r.group, what: r.what, keys: [] }
            byWhat[id].keys.push(text)
        }
        const out = {}
        for (const r of Object.values(byWhat)) {
            if (!out[r.group]) out[r.group] = []
            out[r.group].push({ keys: r.keys.join("  ·  "), what: r.what })
        }
        const names = Object.keys(out).sort((a, b) => {
            const ia = order.indexOf(a), ib = order.indexOf(b)
            return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib) || a.localeCompare(b)
        })
        return names.map(n => ({ name: n, rows: out[n] }))
    }

    Process {
        id: binds
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector { onStreamFinished: root.groups = root.build(text) }
    }

    function toggle() {
        open = !open
        if (open) { binds.running = false; binds.running = true }
    }

    PanelWindow {
        id: win

        readonly property var focusedScreen: {
            const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
            return Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0]
        }

        visible: root.open
        screen: focusedScreen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "archminimal-keys"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        // scrim: click anywhere closes
        Rectangle {
            anchors.fill: parent
            color: "#4d000000"
            MouseArea { anchors.fill: parent; onClicked: root.open = false }
        }

        Item {
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Slash || event.key === Qt.Key_Question) {
                    root.open = false
                    event.accepted = true
                }
            }
        }

        Rectangle {
            id: panel
            width: Math.min(parent.width - 80, 1080)
            height: Math.min(parent.height - 80, content.implicitHeight + 40)
            anchors.centerIn: parent
            color: Theme.panel
            border { width: 1; color: "#2e00e5ff" }

            MouseArea { anchors.fill: parent }   // swallow clicks

            // corner marks, as on the launcher and login screen
            Repeater {
                model: 4
                Item {
                    required property int index
                    width: 12; height: 12
                    x: index % 2 === 0 ? -1 : panel.width - 11
                    y: index < 2 ? -1 : panel.height - 11
                    opacity: 0.8
                    Rectangle { width: 12; height: 1; color: Theme.accent; y: index < 2 ? 0 : 11 }
                    Rectangle { width: 1; height: 12; color: Theme.accent; x: index % 2 === 0 ? 0 : 11 }
                }
            }

            Flickable {
                anchors { fill: parent; margins: 20 }
                contentHeight: content.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: content
                    width: parent.width
                    spacing: 14

                    Item {
                        width: parent.width
                        height: 20
                        Text {
                            text: "keys"
                            color: Theme.fg
                            font { family: Theme.font; pixelSize: 13; letterSpacing: 3 }
                        }
                        Text {
                            anchors.right: parent.right
                            text: "sys::keys · esc closes"
                            color: Theme.mute
                            font { family: Theme.font; pixelSize: 10; letterSpacing: 2 }
                        }
                    }

                    Flow {
                        width: parent.width
                        spacing: 28

                        Repeater {
                            model: root.groups
                            Column {
                                required property var modelData
                                width: (content.width - 2 * 28) / 3
                                spacing: 3

                                Text {
                                    text: modelData.name
                                    color: Theme.accent
                                    bottomPadding: 4
                                    font { family: Theme.font; pixelSize: 10; letterSpacing: 3 }
                                }
                                Repeater {
                                    model: modelData.rows
                                    Item {
                                        required property var modelData
                                        width: parent.width
                                        height: Math.max(keysText.implicitHeight, whatText.implicitHeight) + 4
                                        Text {
                                            id: whatText
                                            width: parent.width * 0.45
                                            wrapMode: Text.Wrap
                                            text: modelData.what
                                            color: Theme.mute
                                            font { family: Theme.font; pixelSize: 11; letterSpacing: 0.5 }
                                        }
                                        Text {
                                            id: keysText
                                            anchors.right: parent.right
                                            width: parent.width * 0.55 - 8
                                            horizontalAlignment: Text.AlignRight
                                            wrapMode: Text.Wrap
                                            text: modelData.keys
                                            color: Theme.fg
                                            font { family: Theme.font; pixelSize: 11; letterSpacing: 0.5 }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.groups.length === 0
                        text: "no described binds found (hyprctl binds -j)"
                        color: Theme.mute
                        font { family: Theme.font; pixelSize: 11; letterSpacing: 2 }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "keys"
        function toggle(): void { root.toggle() }
    }
}
