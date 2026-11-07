// Month calendar popup, opened by clicking the clock in the bar.
// Built like the launcher: a transparent full-screen overlay holding the card, so it gets mouse and
// keyboard input reliably (an xdg PopupWindow + HyprlandFocusGrab swallowed every click here).
// ‹ › / scroll / ←→ change the month, shift+scroll / ↑↓ change the year, clicking the title jumps back
// to today, clicking anywhere else (or Esc) closes it.
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: cal

    required property var barWindow
    required property Item anchorItem

    readonly property int cell: 40               // day column width
    readonly property int rowH: 30               // day row height (landscape grid, not squares)
    readonly property int pad: 20
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
    // ISO-8601 week number
    function isoWeek(d) {
        const t = new Date(d.getFullYear(), d.getMonth(), d.getDate())
        t.setDate(t.getDate() + 3 - (t.getDay() + 6) % 7)      // thursday of this week
        const jan4 = new Date(t.getFullYear(), 0, 4)
        return 1 + Math.round(((t - jan4) / 86400000 - 3 + (jan4.getDay() + 6) % 7) / 7)
    }
    function dayOfYear(d) {
        return Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - new Date(d.getFullYear(), 0, 1)) / 86400000) + 1
    }
    function shift(n) {
        const d = new Date(year, month + n, 1)
        year = d.getFullYear()
        month = d.getMonth()
    }

    visible: false
    screen: barWindow.screen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "archminimal-calendar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // click anywhere outside the card (the bar's clock included) closes it
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: cal.visible = false
    }

    Rectangle {
        // the clock is centred in the bar, so centre the card under it
        x: Math.round(parent.width / 2 - width / 2)
        y: Theme.barHeight + 8
        width: layout.implicitWidth + 2 * cal.pad
        height: layout.implicitHeight + 2 * cal.pad
        color: Theme.panel
        border { width: 1; color: "#2e00e5ff" }   // same edge as launcher / notifications
        focus: true
        Keys.onEscapePressed: cal.visible = false
        Keys.onLeftPressed: cal.shift(-1)
        Keys.onRightPressed: cal.shift(1)
        Keys.onUpPressed: cal.shift(-12)
        Keys.onDownPressed: cal.shift(12)

        // eat clicks on the card's empty areas so they don't reach the backdrop and close it
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        WheelHandler {
            // scroll = month, shift+scroll = year
            onWheel: event => {
                const step = (event.modifiers & Qt.ShiftModifier) ? 12 : 1
                const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                cal.shift(d > 0 ? -step : step)
            }
        }

        Row {
          id: layout
          x: cal.pad; y: cal.pad
          spacing: 22

          // ---- left: today, big ----
          Item {
            // as wide as its widest line, so nothing spills over the divider
            width: Math.max(112, info.implicitWidth, footer.implicitWidth)
            height: body.height

            Column {
                id: info
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                    verticalCenterOffset: -footer.height / 2
                }
                spacing: 4
                // letterSpacing also pads after the last glyph; leftPadding = letterSpacing evens it out
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(cal.today, "dddd").toUpperCase()
                    color: Theme.accent
                    leftPadding: 3
                    font { family: Theme.font; pixelSize: 10; letterSpacing: 3 }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(cal.today, "dd")
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: 56; weight: Font.Light }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(cal.today, "MMMM yyyy").toUpperCase()
                    color: Theme.mute
                    leftPadding: 2
                    font { family: Theme.font; pixelSize: 11; letterSpacing: 2 }
                }
            }
            Text {
                id: footer
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 4 }
                leftPadding: 2
                text: "WEEK " + cal.isoWeek(cal.today) + " · DAY " + cal.dayOfYear(cal.today)
                color: Theme.dim
                font { family: Theme.font; pixelSize: 10; letterSpacing: 2 }
            }
          }

          Rectangle { width: 1; height: body.height; color: Theme.line }

          // ---- right: month grid ----
          Column {
            id: body
            width: 7 * cal.cell

            // ---- header:  ‹   NOVEMBER 2026   › ----
            Item {
                width: parent.width
                height: 24

                CalendarNav {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: "‹"
                    onClicked: cal.shift(-1)
                }
                Text {
                    anchors.centerIn: parent
                    text: Qt.formatDate(new Date(cal.year, cal.month, 1), "MMMM yyyy").toUpperCase()
                    color: titleMa.containsMouse ? Theme.accent : Theme.fg
                    leftPadding: 3
                    font { family: Theme.font; pixelSize: 12; letterSpacing: 3 }
                    MouseArea {
                        id: titleMa
                        anchors.fill: parent; anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cal.open()          // back to this month
                    }
                }
                CalendarNav {
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    text: "›"
                    onClicked: cal.shift(1)
                }
            }

            Item { width: 1; height: 16 }

            // ---- weekday names (week starts on Monday) ----
            Row {
                Repeater {
                    model: ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
                    Text {
                        required property string modelData
                        required property int index
                        width: cal.cell
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        leftPadding: 2
                        color: index >= 5 ? Theme.dim : Theme.mute
                        font { family: Theme.font; pixelSize: 10; letterSpacing: 2 }
                    }
                }
            }

            Item { width: 1; height: 6 }

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
                        height: cal.rowH

                        HoverHandler { id: hover }

                        Rectangle {
                            anchors.centerIn: parent
                            width: cal.cell - 6; height: cal.rowH - 6
                            color: day.isToday ? Theme.accent : Theme.line
                            opacity: day.isToday ? 1 : hover.hovered ? 0.6 : 0
                            Behavior on opacity { NumberAnimation { duration: 90 } }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: day.date.getDate()
                            color: day.isToday ? Theme.panel
                                 : !day.inMonth ? Theme.dim
                                 : day.weekend ? Theme.mute : Theme.fg
                            font { family: Theme.font; pixelSize: 13; weight: day.isToday ? Font.Bold : Font.Normal }
                        }
                    }
                }
            }
          }
        }
    }
}
