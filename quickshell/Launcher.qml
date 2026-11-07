// App launcher and power menu (same window, two modes).
//   apps:  fuzzy search over installed .desktop apps; most used first.
//          No match + Enter runs the text as a command in the terminal.
//   power: lock, suspend, log out, reboot, shut down.
//   clip:  clipboard history (cliphist), newest first. Enter copies the entry
//          back to the clipboard; Shift+Delete forgets it.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: win

    readonly property var focusedScreen: {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        return Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0]
    }

    visible: LauncherState.open
    screen: focusedScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "archminimal-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property var results: []
    property int selected: 0
    readonly property int maxRows: 8
    readonly property int rowHeight: 54

    // ---------- entries ----------
    readonly property var powerActions: [
        { id: "power:lock",     name: "Lock",      desc: "hyprlock",            icon: "system-lock-screen", cmd: ["loginctl", "lock-session"] },
        { id: "power:suspend",  name: "Suspend",   desc: "lock and sleep",      icon: "system-suspend",     cmd: ["systemctl", "suspend"] },
        { id: "power:logout",   name: "Log out",   desc: "leave hyprland",      icon: "system-log-out",     cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
        { id: "power:reboot",   name: "Reboot",    desc: "systemctl reboot",    icon: "system-reboot",      cmd: ["systemctl", "reboot"] },
        { id: "power:poweroff", name: "Shut down", desc: "systemctl poweroff",  icon: "system-shutdown",    cmd: ["systemctl", "poweroff"], danger: true }
    ]

    function appEntries() {
        return DesktopEntries.applications.values
            .filter(e => !e.noDisplay)
            .map(e => ({ id: e.id, name: e.name, desc: (e.genericName || e.comment || "").toLowerCase(),
                         keywords: (e.keywords || []).join(" "), icon: e.icon, entry: e }))
    }

    // Subsequence match; consecutive and prefix hits score higher.
    function score(item, q) {
        if (q === "") return 1
        const hay = (item.name + " " + item.desc + " " + (item.keywords || "")).toLowerCase()
        let pos = 0, pts = 0, prev = -2
        for (const c of q) {
            const j = hay.indexOf(c, pos)
            if (j < 0) return 0
            pts += (j === prev + 1) ? 3 : 1
            prev = j; pos = j + 1
        }
        if (item.name.toLowerCase().startsWith(q)) pts += 20
        return pts
    }

    // ---------- clipboard history ----------
    property var clips: []

    // "[[ binary data 48 KiB png 1280x720 ]]" -> "image · png 1280x720 · 48 KiB"
    function clipEntry(line) {
        const tab = line.indexOf("\t")
        if (tab < 0) return null
        const text = line.slice(tab + 1)
        const bin = text.match(/^\[\[ binary data (\S+ \S+) (\S+) ?(\S*) \]\]$/)
        return bin
            ? { id: "clip:" + line.slice(0, tab), name: "image · " + bin[2] + (bin[3] ? " " + bin[3] : ""), desc: bin[1].toLowerCase(), icon: "image-x-generic", clip: line }
            : { id: "clip:" + line.slice(0, tab), name: text.replace(/\s+/g, " ").trim().slice(0, 200), desc: "", icon: "edit-paste", clip: line }
    }

    Process {
        id: clipList
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                win.clips = text.split("\n").map(win.clipEntry).filter(e => e !== null && e.name !== "")
                win.refresh()
            }
        }
    }

    function loadClips() {
        clips = []
        clipList.running = false
        clipList.running = true
    }

    function forgetClip() {
        const item = results[selected]
        if (!item || !item.clip) return
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" | cliphist delete', "sh", item.clip])
        clips = clips.filter(c => c.id !== item.id)
        refresh()
    }

    function refresh() {
        const q = input.text.trim().toLowerCase()
        if (LauncherState.mode === "clip") {
            // keep history order (newest first); just filter
            results = clips.filter(c => score(c, q) > 0)
            selected = 0
            return
        }
        const pool = LauncherState.mode === "power" ? powerActions : appEntries().concat(powerActions)
        const counts = LauncherState.counts
        results = pool
            .map(it => ({ it: it, s: score(it, q) }))
            .filter(x => x.s > 0)
            .sort((a, b) => (b.s + Math.min(10, counts[b.it.id] || 0)) - (a.s + Math.min(10, counts[a.it.id] || 0))
                            || a.it.name.localeCompare(b.it.name))
            .map(x => x.it)
        selected = 0
    }

    function launch() {
        const item = results[selected]
        const q = input.text.trim()
        LauncherState.close()
        if (item && item.clip) {
            Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" | cliphist decode | wl-copy', "sh", item.clip])
            return
        }
        if (!item) {
            if (q !== "" && LauncherState.mode !== "clip")
                Quickshell.execDetached([Theme.terminal, "-e", "sh", "-c", q + "; exec \"${SHELL:-sh}\""])
            return
        }
        LauncherState.used(item.id)
        if (item.cmd) {
            Quickshell.execDetached(item.cmd)
        } else if (item.entry.runInTerminal) {
            Quickshell.execDetached([Theme.terminal, "-e"].concat(item.entry.command))
        } else {
            item.entry.execute()
        }
    }

    onVisibleChanged: {
        if (!visible) return
        input.text = ""
        if (LauncherState.mode === "clip") loadClips()
        refresh()
        input.forceActiveFocus()
    }
    Connections {
        target: LauncherState
        function onModeChanged() {
            if (!win.visible) return
            input.text = ""
            if (LauncherState.mode === "clip") win.loadClips()
            win.refresh()
        }
    }

    // ---------- scrim: click outside closes ----------
    Rectangle {
        anchors.fill: parent
        color: "#4d000000"
        MouseArea { anchors.fill: parent; onClicked: LauncherState.close() }
    }

    // ---------- panel ----------
    Rectangle {
        id: panel
        width: 620
        height: column.implicitHeight
        x: (parent.width - width) / 2
        y: parent.height * 0.23
        color: Theme.panel
        border { width: 1; color: "#2e00e5ff" }

        opacity: win.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        MouseArea { anchors.fill: parent }   // swallow clicks so they don't hit the scrim

        // corner marks, as on the login screen
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

        Column {
            id: column
            width: parent.width

            // ---- search line ----
            Item {
                width: parent.width
                height: 60
                Text {
                    id: prompt
                    anchors { left: parent.left; leftMargin: 22; verticalCenter: parent.verticalCenter }
                    text: "›"
                    color: Theme.accent
                    font { family: Theme.font; pixelSize: 18 }
                }
                TextInput {
                    id: input
                    anchors { left: prompt.right; leftMargin: 12; right: hint.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    color: Theme.fg
                    selectionColor: Theme.accent
                    selectedTextColor: "#000000"
                    font { family: Theme.font; pixelSize: 17; letterSpacing: 1 }
                    cursorDelegate: Rectangle {
                        width: 9
                        color: Theme.accent
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { to: 0; duration: 1 }
                            PauseAnimation { duration: 500 }
                            NumberAnimation { to: 1; duration: 1 }
                            PauseAnimation { duration: 500 }
                        }
                    }
                    onTextChanged: win.refresh()
                    Keys.onPressed: event => {
                        const ctrl = event.modifiers & Qt.ControlModifier
                        if (event.key === Qt.Key_Escape) LauncherState.close()
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) win.launch()
                        else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N)))
                            win.selected = Math.min(win.selected + 1, win.results.length - 1)
                        else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P)))
                            win.selected = Math.max(win.selected - 1, 0)
                        else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier))
                            win.forgetClip()
                        else if (event.key === Qt.Key_Tab) {
                            if (win.results[win.selected]) input.text = win.results[win.selected].name.toLowerCase()
                        } else return
                        event.accepted = true
                    }
                    Text {
                        visible: input.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        x: 14
                        text: LauncherState.mode === "power" ? "power" : LauncherState.mode === "clip" ? "clipboard" : "search"
                        color: Theme.mute
                        font { family: Theme.font; pixelSize: 17; letterSpacing: 2 }
                    }
                }
                Text {
                    id: hint
                    anchors { right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter }
                    text: LauncherState.mode === "power" ? "sys::power" : LauncherState.mode === "clip" ? "sys::clip" : "sys::run"
                    color: Theme.mute
                    font { family: Theme.font; pixelSize: 11; letterSpacing: 2 }
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#0fffffff" }

            // ---- results ----
            ListView {
                id: list
                width: parent.width
                height: Math.max(1, Math.min(count, win.maxRows)) * win.rowHeight + 16
                topMargin: 8; bottomMargin: 8
                clip: true
                model: win.results
                currentIndex: win.selected
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === win.selected

                    width: list.width
                    height: win.rowHeight

                    Rectangle { anchors.fill: parent; color: row.sel ? "#0d00e5ff" : "transparent" }
                    Rectangle {
                        visible: row.sel
                        x: 0; y: 9; width: 2; height: parent.height - 18
                        color: Theme.accent
                    }
                    Image {
                        id: icon
                        x: 22
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36; height: 36
                        sourceSize: Qt.size(72, 72)          // crisp on HiDPI
                        source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                        asynchronous: true
                        smooth: true
                    }
                    Column {
                        anchors { left: icon.right; leftMargin: 16; right: parent.right; rightMargin: 40; verticalCenter: parent.verticalCenter }
                        spacing: 2
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: row.modelData.name
                            color: row.modelData.danger && row.sel ? Theme.danger : Theme.fg
                            font { family: Theme.font; pixelSize: 15; letterSpacing: 0.5 }
                        }
                        Text {
                            width: parent.width
                            visible: text !== ""
                            elide: Text.ElideRight
                            text: row.modelData.desc
                            color: Theme.mute
                            font { family: Theme.font; pixelSize: 11; letterSpacing: 1 }
                        }
                    }
                    Text {
                        visible: row.sel
                        anchors { right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter }
                        text: "⏎"
                        color: Theme.dim
                        font { family: Theme.font; pixelSize: 12 }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: win.selected = row.index
                        onClicked: win.launch()
                    }
                }

                Text {
                    visible: list.count === 0
                    x: 22; y: 22
                    text: LauncherState.mode === "clip" ? (input.text === "" ? "clipboard history is empty" : "no match")
                        : input.text === "" ? "nothing here" : "no match · ⏎ runs \"" + input.text + "\" in " + Theme.terminal
                    color: Theme.mute
                    font { family: Theme.font; pixelSize: 12; letterSpacing: 2 }
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#0fffffff" }

            // ---- footer ----
            Item {
                width: parent.width
                height: 36
                Row {
                    anchors { left: parent.left; leftMargin: 22; verticalCenter: parent.verticalCenter }
                    spacing: 22
                    Repeater {
                        model: LauncherState.mode === "clip"
                            ? [["↑↓", "select"], ["⏎", "copy"], ["⇧del", "forget"], ["esc", "close"]]
                            : [["↑↓", "select"], ["⏎", "run"], ["tab", "complete"], ["esc", "close"]]
                        Row {
                            required property var modelData
                            spacing: 6
                            Text { text: modelData[0]; color: Theme.fg; font { family: Theme.font; pixelSize: 10; letterSpacing: 2 } }
                            Text { text: modelData[1]; color: Theme.mute; font { family: Theme.font; pixelSize: 10; letterSpacing: 2 } }
                        }
                    }
                }
                Text {
                    anchors { right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter }
                    text: String(list.count)
                    color: Theme.dim
                    font { family: Theme.font; pixelSize: 10; letterSpacing: 2 }
                }
            }
        }
    }
}
