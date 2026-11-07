// Do-not-disturb flag, shared by the notification popups and the bar.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    property bool dnd: false
}
