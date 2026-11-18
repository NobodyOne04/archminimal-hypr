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
    onAnyLiveChanged: if (micOff && anyLive) Qt.callLater(muteAll)     // deferred: muting changes anyLive itself

    // no bar module (ADR-0012): each switch says what it did in a full notification
    function say(summary, body, critical) {
        Quickshell.execDetached(["notify-send", "-a", "Privacy", "-u", critical ? "critical" : "normal", summary, body])
    }

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
            say("Microphone off", "Every microphone is muted, including ones plugged in later.")
            return
        }
        micOff = false
        // muted before this shell started (read back at start): we don't know which, so unmute all
        const all = mutedByUs.length === 0
        for (const s of sources)
            if (s.ready && (all || mutedByUs.includes(s.id))) s.audio.muted = false
        mutedByUs = []
        say("Microphone on", "Microphones are unmuted.")
    }

    // read the state fresh on every press (the helper may have been installed since start), then switch
    property bool switchPending: false
    function toggleCam() {
        if (camProc.running) return
        switchPending = true
        readCam()
    }
    function switchCam() {
        if (cam === "missing") {
            say("Camera switch not installed", "Run \"sudo make privacy\" in ~/projects/archminimal-hypr once.")
            return
        }
        if (cam === "none") { say("No camera", "There is no camera to switch."); return }
        camProc.command = ["pkexec", helper, cam === "on" || cam === "busy" ? "off" : "on"]
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
            if (verb === "" && p.switchPending) {
                p.switchPending = false
                p.switchCam()
                return
            }
            if (verb === "") return
            if (code === 0 && s === "off") p.say("Camera off", "The camera driver is unloaded and blocked, also after a reboot.")
            else if (code === 0 && s === "on") p.say("Camera on", "The camera driver is loaded again.")
            else if (s === "partial")
                p.say("Camera blocked, but a video device is still there", "It isn't a uvcvideo camera, so this switch can't turn it off.", true)
            else if (code !== 0)
                p.say("Camera not switched " + verb,
                      s === "busy" ? "The camera is in use. Close the app using it and try again."
                    : code === 126 || code === 127 ? "Not authorised. Is the polkit rule installed (sudo make privacy)?"
                    : "The switch failed (exit " + code + ").")
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
