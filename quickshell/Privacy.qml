// Mic and camera kill switches (ADR-0012).
//
// mic: mutes every PipeWire audio input (not app streams); while off, inputs that appear or get
//      unmuted elsewhere are muted again. At start it is read back from PipeWire, which remembers
//      mute state, so the shell keeps no state of its own.
// cam: /usr/local/bin/archminimal-camera (installed by `make privacy`) unloads and blocks the uvcvideo
//      driver through pkexec. Its status is read once at start and after each switch, never polled.
//
//   qs -c archminimal ipc call privacy mic | cam | status
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: p

    readonly property string helper: "/usr/local/bin/archminimal-camera"

    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)
    readonly property bool ready: sources.length > 0 && sources.every(n => n.ready)
    readonly property bool anyLive: ready && sources.some(n => !n.audio.muted)
    property bool micOff: false
    property bool synced: false
    property var mutedByUs: []           // node ids muted by the switch, unmuted again by it

    // on | off | partial (blocked, a video device still there) | none (no camera)
    // | missing (helper not installed) | busy (in use, could not switch off) | "" (not read yet)
    property string cam: ""
    readonly property bool camShown: cam !== "" && cam !== "missing"

    PwObjectTracker { objects: p.sources }

    onReadyChanged: if (ready && !synced) { synced = true; micOff = !anyLive }
    onAnyLiveChanged: if (micOff && anyLive) muteAll()

    // no bar module (ADR-0012): each switch says what it did in a short popup, kept out of the history
    function say(what) { Quickshell.execDetached(["notify-send", "-a", "privacy", "-e", "-t", "2000", what]) }

    function muteAll() {
        const ids = mutedByUs.slice()
        for (const s of sources) {
            if (!s.ready || s.audio.muted) continue
            s.audio.muted = true
            ids.push(s.id)
        }
        mutedByUs = ids
    }

    function toggleMic() {
        if (!micOff) {
            micOff = true
            muteAll()
            say("mic off")
            return
        }
        micOff = false
        // muted before this shell started (read back at start): we don't know which, so unmute all
        const all = mutedByUs.length === 0
        for (const s of sources)
            if (s.ready && (all || mutedByUs.includes(s.id))) s.audio.muted = false
        mutedByUs = []
        say("mic on")
    }

    function toggleCam() {
        if (cam === "missing") { say("camera switch not installed: make privacy"); return }
        if (cam === "none") { say("no camera"); return }
        if (cam === "" || camProc.running) return
        const verb = cam === "on" || cam === "busy" ? "off" : "on"
        camProc.command = ["pkexec", helper, verb]
        camProc.running = true
    }

    function readCam() {
        if (camProc.running) return
        camProc.command = ["sh", "-c", 'if [ -x "$1" ]; then exec "$1" status; else echo missing; fi', "sh", helper]
        camProc.running = true
    }

    Process {
        id: camProc
        stdout: StdioCollector { id: out }
        onExited: code => {
            const s = out.text.trim()
            const verb = camProc.command[0] === "pkexec" ? camProc.command[2] : ""
            if (["on", "off", "partial", "none", "missing", "busy"].includes(s)) p.cam = s
            if (verb !== "" && code === 0 && s !== "partial") p.say("camera " + s)
            if (verb !== "" && code !== 0) {
                const why = s === "busy" ? "the camera is in use; close the app using it and try again"
                          : code === 126 || code === 127 ? "not authorised (is `make privacy` installed?)"
                          : "the switch failed (exit " + code + ")"
                Quickshell.execDetached(["notify-send", "-a", "privacy", "camera not switched " + verb, why])
            }
            if (s === "partial" && verb === "off")
                Quickshell.execDetached(["notify-send", "-a", "privacy", "-u", "critical",
                    "camera blocked, but a video device is still there", "it isn't a uvcvideo camera; this switch can't turn it off"])
        }
    }

    Component.onCompleted: readCam()

    IpcHandler {
        target: "privacy"
        function mic(): void { p.toggleMic() }
        function cam(): void { p.toggleCam() }
        function status(): string { return "mic " + (p.micOff ? "off" : "on") + ", cam " + (p.cam || "?") }
    }
}
