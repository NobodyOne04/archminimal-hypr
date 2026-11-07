// Arrow button in the calendar header: ‹ › move a month.
import QtQuick

Text {
    id: nav
    signal clicked()

    color: ma.containsMouse ? Theme.accent : Theme.mute
    font { family: Theme.font; pixelSize: 16 }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -8
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: nav.clicked()
    }
}
