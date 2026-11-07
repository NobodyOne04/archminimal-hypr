// Month calendar popup, opened by clicking the clock in the bar.
// ‹ › / scroll change the month, « » / shift+scroll change the year, clicking the title jumps back to today,
// clicking anywhere else (or Esc) closes it.
import QtQuick
import Quickshell
import Quickshell.Hyprland

PopupWindow {
    id: cal

    required property var barWindow
    required property Item anchorItem

    readonly property int cell: 64               // size of one day square
    readonly property int pad: 28
    property date today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()          // 0..11

    function open() {
        today = new Date()
        year = today.getFullYear()
        month = today.getMonth()
        visible = true
    }
    function toggle() { if (visible) visible = false; else open() }
    function shift(n) {
        const d = new Date(year, month + n, 1)
        year = d.getFullYear()
        month = d.getMonth()
    }

    visible: false
    color: "transparent"
    anchor.window: barWindow
    // the clock is centred in the bar, so centre the popup on the bar
    anchor.rect.x: Math.round(barWindow.width / 2 - implicitWidth / 2)
    anchor.rect.y: Theme.barHeight + 8
    implicitWidth: 7 * cell + 2 * pad
    implicitHeight: body.implicitHeight + 2 * pad

    // close on any click outside the popup and the bar
    HyprlandFocusGrab {
        active: cal.visible
        windows: [cal, cal.barWindow]
        onCleared: cal.visible = false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.panel
        border { width: 1; color: "#2600e5ff" }
        focus: true
        Keys.onEscapePressed: cal.visible = false
        Keys.onLeftPressed: cal.shift(-1)
        Keys.onRightPressed: cal.shift(1)
        Keys.onUpPressed: cal.shift(-12)
        Keys.onDownPressed: cal.shift(12)

        WheelHandler {
            // scroll = month, shift+scroll = year
            onWheel: event => {
                const step = (event.modifiers & Qt.ShiftModifier) ? 12 : 1
                const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                cal.shift(d > 0 ? -step : step)
            }
        }

        Column {
            id: body
            x: cal.pad; y: cal.pad
            spacing: 14

            // ---- header: «  ‹   NOVEMBER 2026   ›  » ----
            Item {
                width: 7 * cal.cell
                height: 36

                Row {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    spacing: 22
                    CalendarNav { text: "«"; onClicked: cal.shift(-12) }
                    CalendarNav { text: "‹"; onClicked: cal.shift(-1) }
                }
                Text {
                    anchors.centerIn: parent
                    text: Qt.formatDate(new Date(cal.year, cal.month, 1), "MMMM yyyy").toUpperCase()
                    color: titleMa.containsMouse ? Theme.accent : Theme.fg
                    font { family: Theme.font; pixelSize: 18; letterSpacing: 4 }
                    MouseArea {
                        id: titleMa
                        anchors.fill: parent; anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cal.open()          // back to this month
                    }
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 22
                    CalendarNav { text: "›"; onClicked: cal.shift(1) }
                    CalendarNav { text: "»"; onClicked: cal.shift(12) }
                }
            }

            // ---- weekday names (week starts on Monday) ----
            Row {
                Repeater {
                    model: ["mo", "tu", "we", "th", "fr", "sa", "su"]
                    Text {
                        required property string modelData
                        required property int index
                        width: cal.cell
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: index >= 5 ? Theme.dim : Theme.mute
                        font { family: Theme.font; pixelSize: 13; letterSpacing: 2 }
                    }
                }
            }

            Rectangle { width: 7 * cal.cell; height: 1; color: Theme.line }

            // ---- days: always 6 weeks so the popup keeps its size ----
            Grid {
                id: grid
                columns: 7
                readonly property int offset: (new Date(cal.year, cal.month, 1).getDay() + 6) % 7

                Repeater {
                    model: 42
                    Item {
                        id: day
                        required property int index
                        readonly property date date: new Date(cal.year, cal.month, 1 - grid.offset + index)
                        readonly property bool inMonth: date.getMonth() === cal.month
                        readonly property bool isToday: date.getFullYear() === cal.today.getFullYear()
                                                     && date.getMonth() === cal.today.getMonth()
                                                     && date.getDate() === cal.today.getDate()
                        readonly property bool weekend: index % 7 >= 5

                        width: cal.cell
                        height: cal.cell - 10

                        Rectangle {
                            anchors.centerIn: parent
                            width: cal.cell - 10; height: cal.cell - 14
                            visible: day.isToday
                            color: "transparent"
                            border { width: 1; color: Theme.accent }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: day.date.getDate()
                            color: day.isToday ? Theme.accent
                                 : !day.inMonth ? Theme.line
                                 : day.weekend ? Theme.mute : Theme.fg
                            font { family: Theme.font; pixelSize: 14 }
                        }
                    }
                }
            }
        }
    }
}
