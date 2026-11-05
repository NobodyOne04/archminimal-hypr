// Wallpaper on the background layer, with the login screen's soft vignette.
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    required property var modelData

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.bg
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "archminimal-wallpaper"

    Image {
        anchors.fill: parent
        source: "file://" + Theme.wallpaper
        fillMode: Image.PreserveAspectCrop
        // Decode at screen size only: keeps memory low with large images.
        sourceSize: Qt.size(modelData.width, modelData.height)
        asynchronous: true
        cache: false
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0;  color: "#55000000" }
            GradientStop { position: 0.25; color: "#00000000" }
            GradientStop { position: 0.75; color: "#00000000" }
            GradientStop { position: 1.0;  color: "#66000000" }
        }
    }
}
