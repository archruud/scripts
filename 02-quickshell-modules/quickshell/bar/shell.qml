// shell.qml
// Inngangspunkt. "import "widgets"" er en MAPPE-import (bekreftet
// mønster fra doannc2212/quickshell-config sin egen shell.qml) - det
// gjør alle typene i widgets/ (Bar, Pill, Theme) direkte tilgjengelige
// her uten navnerom-prefiks. Ingen qmldir, ingen "as"-alias.
import Quickshell
import "widgets"

ShellRoot {
    Bar {}
}
