// Active keyboard layout, from Hyprland.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: kb

    property string layout: ""
    property int count: 1
    readonly property bool shown: Theme.showKeyboard === "always" || (Theme.showKeyboard === "auto" && count > 1)

    function short(keymap) {
        const known = { "English (US)": "us", "English (UK)": "gb", "Russian": "ru", "Ukrainian": "ua", "German": "de", "French": "fr", "Polish": "pl" }
        if (known[keymap]) return known[keymap]
        return keymap.slice(0, 2).toLowerCase()
    }

    function next() { Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]) }

    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(this.text).keyboards
                    const main = kbs.find(k => k.main) || kbs[0]
                    kb.layout = kb.short(main.active_keymap)
                    kb.count = main.layout.split(",").length
                } catch (e) {}
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout")
                kb.layout = kb.short(event.data.split(",").slice(1).join(","))
        }
    }
}
