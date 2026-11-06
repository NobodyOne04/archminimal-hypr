// archminimal desktop shell: wallpaper + bar on every monitor, one launcher.
// Run with `qs -c archminimal` (started from hyprland.lua).
//
// IPC (bound to keys in hyprland.lua):
//   qs -c archminimal ipc call launcher toggle
//   qs -c archminimal ipc call launcher power
//   qs -c archminimal ipc call bar toggle
//   qs -c archminimal ipc call lock lock      (hypridle, Super+Escape)
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

    IpcHandler {
        target: "launcher"
        function toggle(): void { LauncherState.toggle("apps") }
        function power(): void { LauncherState.toggle("power") }
        function close(): void { LauncherState.close() }
    }

    IpcHandler {
        target: "bar"
        function toggle(): void { shell.barVisible = !shell.barVisible }
    }
}
