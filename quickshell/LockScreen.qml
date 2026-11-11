// One monitor of the lock screen. Visually a copy of the login greeter
// (archminimal-greeter/greeter/Greeter.qml): keep the two in step when changing either.
// One difference on purpose: no reboot / shutdown buttons. Behind a lock screen
// your apps are still open, so anyone at the keyboard could throw away unsaved
// work without the password. Power off from the power menu once unlocked.
import QtQuick
import QtQuick.Controls
import Quickshell

Item {
    id: root

    required property var lock

    readonly property color accent: Theme.accent
    readonly property color danger: Theme.danger
    readonly property color fg: Theme.fg
    readonly property color mute: Theme.mute
    readonly property string mono: "JetBrains Mono"   // the greeter's font
    readonly property real loginY: 0.70

    property real shakeX: 0
    property string timeStr: ""
    property string dateStr: ""

    // ---------- WALLPAPER ----------
    Rectangle { anchors.fill: parent; color: Theme.bg }

    Image {
        id: bg
        anchors.fill: parent
        source: "file://" + Theme.wallpaper
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.width, root.height)
        smooth: true
    }

    // soft vignette (top and bottom)
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0;  color: "#77000000" }
            GradientStop { position: 0.30; color: "#00000000" }
            GradientStop { position: 0.70; color: "#00000000" }
            GradientStop { position: 1.0;  color: "#88000000" }
        }
    }

    // very faint scanlines
    Canvas {
        anchors.fill: parent
        opacity: 0.05
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = "#000000"
            for (let y = 0; y < height; y += 4)
                ctx.fillRect(0, y, width, 1)
        }
    }

    // ---------- LOGO GLITCH (brief flicker every ~2.5s) ----------
    component Ghost: Item {
        id: ghost
        property real bandTop
        property real bandH
        property color tint
        property real dx: 0
        x: root.width * 0.32
        y: root.height * bandTop
        width: root.width * 0.36
        height: root.height * bandH
        clip: true
        opacity: 0

        Image {
            x: -ghost.x + ghost.dx
            y: -ghost.y
            width: root.width
            height: root.height
            source: bg.source
            sourceSize: bg.sourceSize
            fillMode: Image.PreserveAspectCrop
        }
        Rectangle { anchors.fill: parent; color: ghost.tint; opacity: 0.22 }
    }

    Ghost { id: ghostCyan; tint: root.accent; bandTop: 0.38; bandH: 0.18 }
    Ghost { id: ghostRed;  tint: root.danger; bandTop: 0.52; bandH: 0.12 }

    SequentialAnimation {
        running: true
        loops: Animation.Infinite
        PauseAnimation { duration: 2200 }
        ScriptAction { script: { ghostCyan.dx = -6; ghostCyan.opacity = 0.7 } }
        PauseAnimation { duration: 60 }
        ScriptAction { script: { ghostRed.dx = 6; ghostRed.opacity = 0.75 } }
        PauseAnimation { duration: 60 }
        ScriptAction { script: { ghostCyan.opacity = 0 } }
        PauseAnimation { duration: 60 }
        ScriptAction { script: { ghostCyan.dx = 5; ghostCyan.opacity = 0.6; ghostRed.dx = -4 } }
        PauseAnimation { duration: 70 }
        ScriptAction { script: { ghostRed.opacity = 0 } }
        PauseAnimation { duration: 50 }
        ScriptAction { script: { ghostCyan.opacity = 0; ghostCyan.dx = 0; ghostRed.dx = 0 } }
    }

    // ---------- CORNER MARKS ----------
    Repeater {
        model: 4
        Item {
            required property int index
            width: 16; height: 16
            opacity: 0.45
            x: (index % 2 === 0) ? 20 : root.width - 36
            y: (index < 2) ? 20 : root.height - 36
            Rectangle {
                width: 16; height: 1; color: root.accent
                anchors.top: index < 2 ? parent.top : undefined
                anchors.bottom: index >= 2 ? parent.bottom : undefined
            }
            Rectangle {
                width: 1; height: 16; color: root.accent
                anchors.left: index % 2 === 0 ? parent.left : undefined
                anchors.right: index % 2 === 1 ? parent.right : undefined
            }
        }
    }

    // ---------- HEADER + CLOCK ----------
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            const d = new Date()
            root.timeStr = Qt.formatDateTime(d, "HH:mm")
            root.dateStr = Qt.formatDateTime(d, "ddd dd MMM").toUpperCase()
        }
    }

    Text {
        anchors { top: parent.top; left: parent.left; topMargin: 44; leftMargin: 44 }
        text: "ARCH//LINUX"
        color: root.mute
        font { family: root.mono; pixelSize: 12; letterSpacing: 2 }
    }

    Column {
        anchors { top: parent.top; right: parent.right; topMargin: 40; rightMargin: 44 }
        spacing: 2
        Text {
            anchors.right: parent.right
            text: root.timeStr
            color: root.fg
            font { family: root.mono; pixelSize: 22; weight: Font.Light; letterSpacing: 3 }
        }
        Text {
            anchors.right: parent.right
            text: root.dateStr
            color: root.mute
            font { family: root.mono; pixelSize: 11; letterSpacing: 2 }
        }
    }

    // ---------- LOGIN (sits under the logo) ----------
    Column {
        width: 300
        x: (root.width - width) / 2
        y: root.height * root.loginY
        spacing: 12
        transform: Translate { x: root.shakeX }

        // glowing accent line
        Item {
            width: parent.width; height: 10
            Rectangle {
                width: 36; height: 3; color: root.accent; opacity: 0.2
                anchors.horizontalCenter: parent.horizontalCenter; y: 0
            }
            Rectangle {
                width: 36; height: 1; color: root.accent
                anchors.horizontalCenter: parent.horizontalCenter; y: 1
            }
        }

        // username: fixed to the locked user
        Item {
            width: parent.width; height: 30
            Text {
                anchors.centerIn: parent
                text: root.lock.user
                color: root.fg
                font { family: root.mono; pixelSize: 13; letterSpacing: 4; capitalization: Font.AllUppercase }
            }
        }

        // password
        Item {
            width: parent.width; height: 36
            TextField {
                id: passField
                anchors.fill: parent
                leftPadding: 30
                rightPadding: 30
                focus: true
                enabled: !root.lock.busy
                echoMode: TextInput.Password
                passwordCharacter: "•"
                horizontalAlignment: TextInput.AlignHCenter
                color: root.fg
                selectionColor: root.accent
                selectedTextColor: "#000000"
                font { family: root.mono; pixelSize: 14; letterSpacing: 6 }
                background: Rectangle {
                    color: "transparent"
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1
                        color: passField.activeFocus ? root.accent : "#4a4c54"
                    }
                }
                text: root.lock.password
                onTextChanged: {
                    if (text !== root.lock.password) {
                        root.lock.password = text
                        root.lock.failed = false
                    }
                }
                onAccepted: root.lock.submit()
            }
            Text {
                anchors.centerIn: parent
                visible: passField.text.length === 0
                text: "password"
                color: root.mute
                font { family: root.mono; pixelSize: 12; letterSpacing: 3 }
            }
            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: "→"
                color: (goMa.containsMouse || passField.activeFocus) ? root.accent : root.mute
                font { family: root.mono; pixelSize: 16 }
                MouseArea {
                    id: goMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.lock.submit()
                }
            }
        }

        // status line
        Item {
            width: parent.width; height: 16
            Row {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    text: root.lock.failed ? (root.lock.failMsg || "authentication failed")
                                           : root.lock.busy ? "auth::pending" : "sys::locked"
                    color: root.lock.failed ? root.danger : root.mute
                    font { family: root.mono; pixelSize: 11; letterSpacing: 2 }
                }
                Rectangle {
                    visible: !root.lock.failed
                    width: 7; height: 12
                    color: root.accent
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0; duration: 1 }
                        PauseAnimation { duration: root.lock.busy ? 150 : 500 }
                        NumberAnimation { to: 1; duration: 1 }
                        PauseAnimation { duration: root.lock.busy ? 150 : 500 }
                    }
                }
            }
        }
    }

    // ---------- FAILURE SHAKE ----------
    Connections {
        target: root.lock
        function onFailCountChanged() {
            shake.start()
            passField.forceActiveFocus()
        }
    }

    SequentialAnimation {
        id: shake
        NumberAnimation { target: root; property: "shakeX"; to: -6; duration: 60 }
        NumberAnimation { target: root; property: "shakeX"; to: 6;  duration: 60 }
        NumberAnimation { target: root; property: "shakeX"; to: -4; duration: 60 }
        NumberAnimation { target: root; property: "shakeX"; to: 0;  duration: 60 }
    }

    Component.onCompleted: passField.forceActiveFocus()
}
