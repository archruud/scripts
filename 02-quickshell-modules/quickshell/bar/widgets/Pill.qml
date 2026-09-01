// widgets/Pill.qml
// Gjenbrukbar avrundet "pille"-knapp, stilt for å matche fargene og
// formen i din nåværende Waybar style.css.
// Theme.qml ligger som søsken i samme mappe (widgets/) og brukes
// direkte uten import - bekreftet mønster fra referanseprosjektet
// (deres Bar.qml bruker DefaultTheme.qml på nøyaktig samme måte).
import QtQuick

Rectangle {
    id: pill

    default property alias content: contentHolder.children

    signal clicked()
    signal wheelUp()
    signal wheelDown()

    Theme { id: theme }

    height: 37
    width: contentHolder.implicitWidth + 23
    radius: 11
    color: mouseArea.containsMouse ? theme.bgSurfaceHover : theme.bgSurface
    border.width: 1
    border.color: mouseArea.containsMouse ? theme.accentBlueBorderHover : theme.accentBlueBorder

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    Row {
        id: contentHolder
        anchors.centerIn: parent
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton

        onClicked: pill.clicked()
        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) pill.wheelUp();
            else if (wheel.angleDelta.y < 0) pill.wheelDown();
        }
    }
}
