// archminimal desktop shell: wallpaper + bar on every monitor, one launcher.
// Run with `qs -c archminimal` (started from hyprland.lua).
//
// IPC (bound to keys in hyprland.lua):
//   qs -c archminimal ipc call launcher toggle
//   qs -c archminimal ipc call launcher power
//   qs -c archminimal ipc call bar toggle
//   qs -c archminimal ipc call launcher clip  (Super+V)
//   qs -c archminimal ipc call lock lock      (hypridle, Super+Escape)
//   qs -c archminimal ipc call keys toggle    (Super+/)
//   qs -c archminimal ipc call notifications clear | dnd
//   qs -c archminimal ipc call night toggle
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: shell

    property bool barVisible: true

    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }

    Variants {
        model: shell.barVisible ? Quickshell.screens : []
        Bar {}
    }

    Launcher {}

    Lock {}

    Notifications {}

    Cheatsheet {}

    // singletons load lazily; touch NightLight so its IPC exists from the start
    readonly property bool nightOn: NightLight.on

    IpcHandler {
        target: "launcher"
        function toggle(): void { LauncherState.toggle("apps") }
        function power(): void { LauncherState.toggle("power") }
        function clip(): void { LauncherState.toggle("clip") }
        function close(): void { LauncherState.close() }
    }

    IpcHandler {
        target: "bar"
        function toggle(): void { shell.barVisible = !shell.barVisible }
    }
}
