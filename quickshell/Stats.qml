// CPU, memory, temperature, network and GPU numbers, fed by one long-running
// scripts/stats.sh process (one JSON line every Theme.statsInterval seconds).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: stats

    property real cpu: 0
    property var cores: []
    property var cpuTemp: null
    property string load: ""
    property real memUsed: 0
    property real memTotal: 1
    property real memCache: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property var net: ({ iface: "", rx: 0, tx: 0, wifi: null, ssid: "" })
    property var gpu: null

    readonly property real memPercent: memTotal > 0 ? memUsed * 100 / memTotal : 0

    function gib(bytes) { return (bytes / 1073741824).toFixed(1) }

    function rate(bps) {
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + "M"
        if (bps >= 1024) return Math.round(bps / 1024) + "K"
        return Math.round(bps) + "B"
    }

    function update(line) {
        let d
        try { d = JSON.parse(line) } catch (e) { return }
        cpu = d.cpu; cores = d.cores; cpuTemp = d.cpu_temp; load = d.load
        memUsed = d.mem_used; memTotal = d.mem_total; memCache = d.mem_cache
        swapUsed = d.swap_used; swapTotal = d.swap_total
        net = d.net; gpu = d.gpu
    }

    Process {
        id: proc
        running: true
        command: ["sh", Qt.resolvedUrl("scripts/stats.sh").toString().replace(/^file:\/\//, ""), String(Theme.statsInterval)]
        environment: ({ ARCHMINIMAL_GPU: Theme.gpu })
        stdout: SplitParser { onRead: data => stats.update(data) }
        onExited: restart.start()
    }

    // If the collector ever dies, bring it back without spinning.
    Timer { id: restart; interval: 5000; onTriggered: proc.running = true }
}
