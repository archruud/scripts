// widgets/Theme.qml
// Fargepalett hentet fra din Waybar style.css.
// IKKE singleton lenger - instansieres lokalt der den trengs
// (Theme { id: theme }), akkurat slik referanseprosjektet gjør det.
// Dette unngår qmldir/singleton-krøll helt.
import QtQuick

QtObject {
    readonly property color bgSurface: Qt.rgba(65/255, 66/255, 73/255, 0.8)
    readonly property color bgSurfaceHover: Qt.rgba(65/255, 66/255, 73/255, 0.95)

    readonly property color accentBlue: "#2e92db"
    readonly property color accentBlueBorder: Qt.rgba(46/255, 146/255, 219/255, 0.3)
    readonly property color accentBlueBorderHover: Qt.rgba(46/255, 146/255, 219/255, 0.5)

    readonly property color textPrimary: "#f8f8f4"
    readonly property color critical: "#05142c"

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
}
