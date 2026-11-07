// The top bar: arch mark, workspaces, window title | clock | stats.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth

PanelWindow {
    id: bar
    required property var modelData

    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight
    color: Theme.bar
    WlrLayershell.namespace: "archminimal-bar"

    function run(cmd) { Quickshell.execDetached(cmd) }

    function duration(seconds) {
        if (!seconds || seconds <= 0) return "—"
        const h = Math.floor(seconds / 3600), m = Math.round((seconds % 3600) / 60)
        return h > 0 ? h + " h " + m + " min" : m + " min"
    }

    // hairline under the bar
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: "#0dffffff"
    }

    // ================= LEFT =================
    Row {
        anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
        spacing: 18

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ""                       // Arch logo (Nerd Font)
            color: Theme.accent
            font { family: Theme.font; pixelSize: 15 }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: LauncherState.toggle("apps")
            }
        }

        Workspaces { anchors.verticalCenter: parent.verticalCenter }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 420)
            elide: Text.ElideRight
            text: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.title.toLowerCase() : ""
            color: Theme.mute
            font { family: Theme.font; pixelSize: 12; letterSpacing: 1.5 }
        }
    }

    // ================= CENTER =================
    SystemClock { id: clock; precision: SystemClock.Minutes }

    Row {
        anchors.centerIn: parent
        spacing: 12
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.fg
            font { family: Theme.font; pixelSize: 12; letterSpacing: 3 }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "ddd dd MMM").toUpperCase()
            color: Theme.mute
            font { family: Theme.font; pixelSize: 11; letterSpacing: 2 }
        }
    }

    // ================= RIGHT =================
    Row {
        anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
        spacing: 18

        // ---- cpu ----
        Module {
            barWindow: bar
            label: "cpu"
            value: Math.round(Stats.cpu) + "%"
            meter: Stats.cpu
            hot: Stats.cpu >= Theme.cpuHot
            clickable: true
            onClicked: bar.run(Theme.monitorCmd)
            tip: Component {
                Column {
                    spacing: 2
                    Kv { k: "temperature"; v: Stats.cpuTemp === null ? "—" : Math.round(Stats.cpuTemp) + "°" }
                    Kv { k: "load average"; v: Stats.load }
                    Kv { k: "cores"; v: String(Stats.cores.length) }
                    Row {
                        spacing: 3
                        height: 30
                        Repeater {
                            model: Stats.cores
                            Item {
                                required property var modelData
                                width: Math.max(4, (220 - 3 * (Stats.cores.length - 1)) / Math.max(1, Stats.cores.length))
                                height: 30
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: Math.max(2, parent.height * parent.modelData / 100)
                                    color: parent.modelData >= Theme.cpuHot ? Theme.danger : Theme.accent
                                    opacity: 0.75
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- memory ----
        Module {
            barWindow: bar
            label: "mem"
            value: Stats.gib(Stats.memUsed) + "G"
            meter: Stats.memPercent
            hot: Stats.memPercent >= Theme.memHot
            clickable: true
            onClicked: bar.run(Theme.monitorCmd)
            tip: Component {
                Column {
                    spacing: 2
                    Kv { k: "used"; v: Stats.gib(Stats.memUsed) + " / " + Stats.gib(Stats.memTotal) + " G" }
                    Kv { k: "cache"; v: Stats.gib(Stats.memCache) + " G" }
                    Kv { k: "swap"; v: Stats.gib(Stats.swapUsed) + " / " + Stats.gib(Stats.swapTotal) + " G" }
                }
            }
        }

        // ---- gpu (auto-detected; hidden when none) ----
        Module {
            barWindow: bar
            visible: Stats.gpu !== null
            label: "gpu"
            value: Stats.gpu && Stats.gpu.busy !== null ? Math.round(Stats.gpu.busy) + "%" : "—"
            meter: Stats.gpu && Stats.gpu.busy !== null ? Stats.gpu.busy : -1
            hot: !!Stats.gpu && Stats.gpu.temp !== null && Stats.gpu.temp >= Theme.tempHot
            clickable: true
            onClicked: bar.run(Theme.monitorCmd)
            tip: Component {
                Column {
                    spacing: 2
                    Kv { k: "device"; v: Stats.gpu ? (Stats.gpu.name || Stats.gpu.vendor) : "" }
                    Kv { k: "temperature"; v: Stats.gpu && Stats.gpu.temp !== null ? Math.round(Stats.gpu.temp) + "°" : "—" }
                    Kv {
                        visible: !!Stats.gpu && Stats.gpu.vram_total > 0
                        k: "vram"
                        v: Stats.gpu && Stats.gpu.vram_total ? Stats.gib(Stats.gpu.vram_used) + " / " + Stats.gib(Stats.gpu.vram_total) + " G" : ""
                    }
                    Kv {
                        visible: !!Stats.gpu && Stats.gpu.power !== null && Stats.gpu.power !== undefined
                        k: "power"
                        v: Stats.gpu && Stats.gpu.power ? Math.round(Stats.gpu.power) + " W" : "—"
                    }
                    Kv {
                        visible: !!Stats.gpu && !!Stats.gpu.freq
                        k: "frequency"
                        v: Stats.gpu && Stats.gpu.freq ? Stats.gpu.freq + " MHz" : ""
                    }
                    Kv {
                        visible: !!Stats.gpu && !!Stats.gpu.dgpu
                        k: "discrete gpu"
                        v: Stats.gpu && Stats.gpu.dgpu ? Stats.gpu.dgpu : ""
                        vColor: Stats.gpu && Stats.gpu.dgpu === "on" ? Theme.accent : Theme.mute
                    }
                }
            }
        }

        // ---- cpu temperature ----
        Module {
            barWindow: bar
            visible: Stats.cpuTemp !== null
            label: "tmp"
            value: Stats.cpuTemp === null ? "" : Math.round(Stats.cpuTemp) + "°"
            hot: Stats.cpuTemp !== null && Stats.cpuTemp >= Theme.tempHot
        }

        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 12; color: Theme.line }

        // ---- network ----
        Module {
            barWindow: bar
            label: "net"
            value: Stats.net.iface === "" ? "offline" : "↓ " + Stats.rate(Stats.net.rx)
            hot: Stats.net.iface === ""
            clickable: true
            onClicked: bar.run(Theme.networkCmd)
            tip: Component {
                Column {
                    spacing: 2
                    Kv { k: "interface"; v: Stats.net.iface || "none" }
                    Kv { visible: Stats.net.ssid !== ""; k: "network"; v: Stats.net.ssid }
                    Kv { visible: Stats.net.wifi !== null; k: "signal"; v: Stats.net.wifi === null ? "" : Math.round(Stats.net.wifi * 100 / 70) + "%" }
                    Kv { k: "down"; v: Stats.rate(Stats.net.rx) + "/s" }
                    Kv { k: "up"; v: Stats.rate(Stats.net.tx) + "/s" }
                }
            }
        }

        // ---- bluetooth ----
        Module {
            id: btMod
            readonly property var adapter: Bluetooth.defaultAdapter
            readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)

            barWindow: bar
            visible: adapter !== null
            label: "bt"
            value: !adapter || !adapter.enabled ? "off"
                 : connected.length > 0 ? connected[0].name.toLowerCase().slice(0, 10) : "on"
            accent: !!adapter && adapter.enabled && connected.length > 0
            clickable: true
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) adapter.enabled = !adapter.enabled
                else bar.run(Theme.bluetoothCmd)
            }
            tip: Component {
                Column {
                    spacing: 2
                    Kv { k: "bluetooth"; v: btMod.adapter && btMod.adapter.enabled ? "on" : "off" }
                    Repeater {
                        model: btMod.connected
                        Kv {
                            required property var modelData
                            k: modelData.name.toLowerCase()
                            v: modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : "connected"
                        }
                    }
                    Kv { k: "left click"; v: "bluetui"; vColor: Theme.dim }
                    Kv { k: "right click"; v: "power on/off"; vColor: Theme.dim }
                }
            }
        }

        // ---- keyboard layout (auto-hidden with a single layout) ----
        Module {
            barWindow: bar
            visible: Keyboard.shown
            label: "kb"
            value: Keyboard.layout
            clickable: true
            onClicked: Keyboard.next()
        }

        // ---- night light (hidden when hyprsunset is not running) ----
        Module {
            barWindow: bar
            visible: NightLight.available
            label: "nl"
            value: NightLight.on ? NightLight.temperature + "k" : "off"
            accent: NightLight.on
            clickable: true
            onClicked: NightLight.toggle()
            tip: Component {
                Column {
                    spacing: 2
                    Kv { k: "night light"; v: NightLight.on ? "on · " + NightLight.temperature + " K" : "off" }
                    Kv { k: "schedule"; v: "hypr/hyprsunset.conf"; vColor: Theme.dim }
                    Kv { k: "click"; v: "on / off"; vColor: Theme.dim }
                }
            }
        }

        // ---- do not disturb (only shown while on) ----
        Module {
            barWindow: bar
            visible: NotifyState.dnd
            label: "dnd"
            value: "on"
            hot: true
            clickable: true
            onClicked: NotifyState.dnd = false
        }

        // ---- volume ----
        Module {
            id: volMod
            readonly property var sink: Pipewire.defaultAudioSink
            readonly property var source: Pipewire.defaultAudioSource
            readonly property bool ready: !!sink && !!sink.audio

            PwObjectTracker { objects: [volMod.sink, volMod.source] }

            barWindow: bar
            visible: ready
            label: "vol"
            value: !ready ? "" : sink.audio.muted ? "mute" : Math.round(sink.audio.volume * 100) + "%"
            hot: ready && sink.audio.muted
            clickable: true
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) bar.run(Theme.mixerCmd)
                else sink.audio.muted = !sink.audio.muted
            }
            onScrolled: delta => {
                const v = sink.audio.volume + (delta > 0 ? 0.05 : -0.05)
                sink.audio.volume = Math.max(0, Math.min(1.0, v))
            }
            tip: Component {
                Column {
                    spacing: 2
                    Kv { k: "output"; v: volMod.sink ? (volMod.sink.nickname || volMod.sink.description || volMod.sink.name).toLowerCase() : "" }
                    Kv {
                        k: "mic"
                        v: volMod.source && volMod.source.audio ? (volMod.source.audio.muted ? "muted" : Math.round(volMod.source.audio.volume * 100) + "%") : "none"
                    }
                    Kv { k: "scroll / click"; v: "volume / mute"; vColor: Theme.dim }
                    Kv { k: "right click"; v: "mixer"; vColor: Theme.dim }
                }
            }
        }

        // ---- battery + power profile ----
        Module {
            id: batMod
            readonly property var dev: UPower.displayDevice
            readonly property real pct: !dev ? 0 : (dev.percentage <= 1 ? dev.percentage * 100 : dev.percentage)
            readonly property bool charging: !!dev && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged)
            readonly property var profiles: [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
            readonly property var profileNames: ["power saver", "balanced", "performance"]

            barWindow: bar
            visible: !!dev && dev.isLaptopBattery
            label: "bat"
            value: (charging ? "↑" : "") + Math.round(pct) + "%"
            hot: !charging && pct <= Theme.batteryLow
            accent: charging
            clickable: true
            onClicked: {
                // cycle power profiles; skip performance if the machine has none
                let i = profiles.indexOf(PowerProfiles.profile)
                do { i = (i + 1) % profiles.length } while (profiles[i] === PowerProfile.Performance && !PowerProfiles.hasPerformanceProfile)
                PowerProfiles.profile = profiles[i]
            }
            tip: Component {
                Column {
                    spacing: 2
                    Kv { k: "status"; v: batMod.charging ? (batMod.dev.state === UPowerDeviceState.FullyCharged ? "full" : "charging") : "discharging" }
                    Kv { k: batMod.charging ? "until full" : "remaining"; v: bar.duration(batMod.charging ? batMod.dev.timeToFull : batMod.dev.timeToEmpty) }
                    Kv { k: "power draw"; v: batMod.dev.changeRate ? Math.abs(batMod.dev.changeRate).toFixed(1) + " W" : "—" }
                    Kv {
                        k: "profile"
                        v: batMod.profileNames[Math.max(0, batMod.profiles.indexOf(PowerProfiles.profile))]
                        vColor: Theme.accent
                    }
                    Kv { k: "click"; v: "next profile"; vColor: Theme.dim }
                }
            }
        }

        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 12; color: Theme.line }

        // ---- power menu ----
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "⏻"
            color: powerMa.containsMouse ? Theme.danger : Theme.mute
            font { family: Theme.font; pixelSize: 13 }
            MouseArea {
                id: powerMa
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: LauncherState.toggle("power")
            }
        }
    }
}
