// One "key ........ value" row inside a bar popup.
import QtQuick

Item {
    property string k
    property string v
    property color vColor: Theme.fg

    implicitWidth: Math.max(220, kText.implicitWidth + vText.implicitWidth + 24)
    implicitHeight: 21

    Text {
        id: kText
        anchors.verticalCenter: parent.verticalCenter
        text: parent.k
        color: Theme.mute
        font { family: Theme.font; pixelSize: 11; letterSpacing: 1 }
    }
    Text {
        id: vText
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        text: parent.v
        color: parent.vColor
        font { family: Theme.font; pixelSize: 11; letterSpacing: 1 }
    }
}
