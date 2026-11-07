// Launcher visibility, mode and launch counts (most used apps float to the top).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: state

    property bool open: false
    property string mode: "apps"        // apps | power | clip
    property var counts: ({})

    function toggle(m) {
        if (open && mode === m) { open = false; return }
        mode = m
        open = true
    }
    function close() { open = false }

    function used(id) {
        const c = Object.assign({}, counts)
        c[id] = (c[id] || 0) + 1
        counts = c
        file.setText(JSON.stringify(c))
    }

    FileView {
        id: file
        path: Theme.stateDir + "/launcher.json"
        blockLoading: true
        atomicWrites: true
    }

    Component.onCompleted: {
        try { counts = JSON.parse(file.text() || "{}") } catch (e) { counts = {} }
    }
}
