// Night light through hyprsunset. The schedule (warm in the evening, neutral
// in the morning) lives in hypr/hyprsunset.conf; this only adds a manual
// toggle (bar `nl` module, Super+Shift+W) and shows the current state.
//
//   qs -c archminimal ipc call night toggle
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: night

    property bool available: false
    property int temperature: 6500            // 6500 K = neutral
    readonly property bool on: available && temperature < 6000

    function toggle() {
        if (!available) return
        Quickshell.execDetached(on ? ["hyprctl", "hyprsunset", "identity"]
                                   : ["hyprctl", "hyprsunset", "temperature", String(Theme.nightTemp)])
        temperature = on ? 6500 : Theme.nightTemp    // optimistic; the poll confirms
        settle.restart()
    }

    function poll() { query.running = false; query.running = true }

    Process {
        id: query
        command: ["hyprctl", "hyprsunset", "temperature"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = parseInt(text.trim())
                night.available = !isNaN(t)
                if (!isNaN(t)) night.temperature = t
            }
        }
    }

    // the schedule can change it behind our back: check every minute
    Timer { interval: 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: night.poll() }
    Timer { id: settle; interval: 800; onTriggered: night.poll() }

    IpcHandler {
        target: "night"
        function toggle(): void { night.toggle() }
    }
}
