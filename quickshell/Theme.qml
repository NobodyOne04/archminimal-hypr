// Colors, fonts and behaviour for the bar, launcher and wallpaper.
// This is the one file to edit for personal tweaks.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // ---- palette (same as the login screen) ----
    readonly property color bg: "#28292d"
    readonly property color bar: "#c716171a"        // #AARRGGBB
    readonly property color panel: "#18191d"
    readonly property color fg: "#d0d2d0"
    readonly property color mute: "#7d8088"
    readonly property color dim: "#565962"
    readonly property color line: "#3a3c44"
    readonly property color accent: "#00e5ff"
    readonly property color danger: "#ff2a6d"

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int barHeight: 32

    // ---- behaviour ----
    readonly property string home: Quickshell.env("HOME")
    readonly property string wallpaper: home + "/.local/share/archminimal/wallpaper.png"
    readonly property string stateDir: home + "/.local/state/archminimal"
    readonly property string terminal: "kitty"
    readonly property int workspaces: 5                 // always shown; busy ones beyond are added
    readonly property string gpu: "auto"                // auto | amd | intel | nvidia | none
    readonly property string showKeyboard: "auto"       // auto (2+ layouts) | always | never
    readonly property int statsInterval: 2              // seconds

    // ---- notifications ----
    readonly property int notifyTimeout: 6              // seconds, unless the app asks otherwise
    readonly property int notifyMax: 4                  // popups on screen at once; oldest goes first
    readonly property int notifyHistory: 50             // kept in the notification center (this session only)

    // ---- night light (hyprsunset; schedule in hypr/hyprsunset.conf) ----
    readonly property int nightTemp: 4000               // kelvin used by the bar toggle

    // ---- thresholds that turn a value red ----
    readonly property int cpuHot: 85
    readonly property int memHot: 85
    readonly property int tempHot: 85
    readonly property int batteryLow: 15

    // ---- what clicking a module opens (console tools in kitty) ----
    readonly property var monitorCmd: [terminal, "-e", "btop"]
    // the frontend of whichever Wi-Fi service runs; neither: say so instead of a terminal that closes at once
    readonly property var networkCmd: [terminal, "-e", "sh", "-c",
        "if systemctl is-active -q NetworkManager; then command -v nmtui >/dev/null && exec nmtui; " +
        "echo 'NetworkManager runs, but nmtui is missing (package networkmanager)'; " +
        "elif systemctl is-active -q iwd; then command -v impala >/dev/null && exec impala; " +
        "echo 'iwd runs, but impala is missing: make deps installs it'; " +
        "else echo 'Neither NetworkManager nor iwd is active: this button supports those two'; fi; read -r _"]
    readonly property var bluetoothCmd: [terminal, "-e", "bluetui"]
    readonly property var mixerCmd: [terminal, "-e", "sh", "-c", "command -v wiremix >/dev/null && exec wiremix || exec pulsemixer"]
}
