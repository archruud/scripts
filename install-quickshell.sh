#!/bin/bash
# ============================================================
# Quickshell Module Installer for Arch Linux + Hyprland
# ============================================================
#
# Installerer valgfrie Quickshell-moduler:
#   - bar          (statusbar: workspaces, klokke, wifi/bt/lyd, strøm)
#   - overview     (app-oversikt, CTRL+Tab-toggle)
#   - wvkbd-norsk  (virtuelt tastatur med norsk æøå-layout, del av bar)
#
# Rører IKKE hyprland.lua. Alle linjer du trenger å legge inn selv
# skrives ut på slutten av scriptet - kopier dem inn manuelt.
#
# Idempotent: trygt å kjøre flere ganger. Eksisterende config
# tas alltid backup av før overskriving.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step()    { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error()   { echo -e "${RED}✗${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

QS_CONFIG_DIR="$HOME/.config/quickshell"
MANUAL_LINES=""

echo "╔════════════════════════════════════════════════════════════╗"
echo "║        Quickshell Module Installer - Arch + Hyprland        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

if [ ! -f /etc/arch-release ]; then
    print_error "Dette scriptet er kun for Arch Linux!"
    exit 1
fi
print_success "Arch Linux detektert"

# ------------------------------------------------------------
# Modulvalg
# ------------------------------------------------------------
echo ""
echo "Hvilke moduler vil du installere?"
echo ""
read -rp "Installer bar (statusbar)? [J/n]: " ANS_BAR
ANS_BAR=${ANS_BAR:-J}

INSTALL_BAR=false
[[ "$ANS_BAR" =~ ^[JjYy]$ ]] && INSTALL_BAR=true

INSTALL_WVKBD=false
INSTALL_CALENDAR=false
if [ "$INSTALL_BAR" = true ]; then
    echo ""
    echo "  bar har to valgfrie tilleggsfunksjoner:"
    read -rp "  - Virtuelt tastatur med norsk layout (wvkbd-norsk)? [J/n]: " ANS_WVKBD
    ANS_WVKBD=${ANS_WVKBD:-J}
    [[ "$ANS_WVKBD" =~ ^[JjYy]$ ]] && INSTALL_WVKBD=true

    read -rp "  - Google Kalender-knapp (krever manuelt oppsett underveis)? [J/n]: " ANS_CAL
    ANS_CAL=${ANS_CAL:-J}
    [[ "$ANS_CAL" =~ ^[JjYy]$ ]] && INSTALL_CALENDAR=true
fi

read -rp "Installer overview (app-oversikt)? [J/n]: " ANS_OVERVIEW
ANS_OVERVIEW=${ANS_OVERVIEW:-J}
INSTALL_OVERVIEW=false
[[ "$ANS_OVERVIEW" =~ ^[JjYy]$ ]] && INSTALL_OVERVIEW=true

if [ "$INSTALL_BAR" = false ] && [ "$INSTALL_OVERVIEW" = false ]; then
    print_warning "Ingen moduler valgt - avslutter."
    exit 0
fi

# ------------------------------------------------------------
# Felles Quickshell-avhengigheter
# ------------------------------------------------------------
print_step "Installerer Qt6/Quickshell-avhengigheter..."
sudo pacman -S --needed --noconfirm qt6-base qt6-declarative qt6-wayland qt6-svg qt6-5compat wayland-protocols quickshell
print_success "Quickshell og avhengigheter installert"

if ! command -v qs &> /dev/null; then
    print_error "qs-kommandoen ikke funnet etter installasjon!"
    exit 1
fi

mkdir -p "$QS_CONFIG_DIR"


# ------------------------------------------------------------
# BAR-modul
# ------------------------------------------------------------
if [ "$INSTALL_BAR" = true ]; then
    print_step "Installerer bar-modulen..."

    if [ -d "$QS_CONFIG_DIR/bar" ]; then
        BACKUP_NAME="bar-backup-$(date +%Y%m%d-%H%M%S)"
        print_warning "Eksisterende bar funnet, lager backup..."
        mv "$QS_CONFIG_DIR/bar" "$QS_CONFIG_DIR/$BACKUP_NAME"
        print_success "Backup lagret til $QS_CONFIG_DIR/$BACKUP_NAME"
    fi

    mkdir -p "$QS_CONFIG_DIR/bar/widgets"

    cat > "$QS_CONFIG_DIR/bar/shell.qml" << 'QSEOF'
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
QSEOF

    cat > "$QS_CONFIG_DIR/bar/widgets/Theme.qml" << 'QSEOF'
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
QSEOF

    cat > "$QS_CONFIG_DIR/bar/widgets/Pill.qml" << 'QSEOF'
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
QSEOF

    cat > "$QS_CONFIG_DIR/bar/widgets/Bar.qml" << 'QSEOF'
// Bar.qml
// Minimal statusbar for Hyprland, bygget direkte mot Quickshell sitt eget
// API (ikke end-4 sitt store rammeverk). 9 moduler, ingenting mer:
//
// VENSTRE:  app-launcher | 10 workspaces | aktivt vindu
// SENTER:   klokke
// HØYRE:    wifi | bluetooth | volum+mikrofon | strøm
//
// VIKTIG (les dette først):
// Workspace-klikk bruker "Hyprland.dispatch('hl.dsp.focus({workspace=N})')"
// - den BEKREFTEDE Lua-syntaksen vi allerede vet fungerer fra Waybar-fiksen,
// IKKE den gamle "workspace N"-formen. Quickshell sin egen dispatch()-
// funksjon tar imot en rå tekststreng på samme måte som hyprctl gjorde,
// så den er i prinsippet utsatt for akkurat samme type feil som rammet
// Waybar. Test dette FØRST når du har bygget - se testeinstruksjonene.

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Scope {
    id: root

    Theme { id: theme }

    // Pipewire trenger at nodene "spores" for at volum/mute skal
    // oppdateres reaktivt i UI-et.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    // --- Nettverksstatus: kabel ELLER wifi (ingen innebygd Quickshell-
    // modul for NetworkManager, så vi poller nmcli). Finner den første
    // "connected" enheten uansett type, og henter IP for hover-tooltip. ---
    property string netState: "disconnected"  // "connected" | "disconnected"
    property string netType: ""               // "ethernet" | "wifi" | ""
    property string netIP: ""
    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: netCheck.running = true
    }
    Process {
        id: netCheck
        command: ["sh", "-c",
            "D=$(nmcli -t -f DEVICE,TYPE,STATE device status | awk -F: '$3==\"connected\"{print $1\":\"$2; exit}'); " +
            "if [ -n \"$D\" ]; then " +
            "  DEV=$(echo \"$D\" | cut -d: -f1); TYPE=$(echo \"$D\" | cut -d: -f2); " +
            "  IP=$(nmcli -g IP4.ADDRESS device show \"$DEV\" 2>/dev/null | cut -d/ -f1); " +
            "  echo \"connected|$TYPE|$IP\"; " +
            "else echo 'disconnected||'; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("|");
                root.netState = parts[0] || "disconnected";
                root.netType = parts[1] || "";
                root.netIP = parts[2] || "";
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            anchors { top: true; left: true; right: true }
            implicitHeight: 52
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(13/255, 14/255, 18/255, 0.75)  // samme alpha-mønster som pillene
            }

            Item {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8

                // ============== VENSTRE ==============
                Row {
                    id: leftSection
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    // App-launcher ("A") - kjører samme rofi-kommando som
                    // custom/menu#user i din UserModules i dag
                    Pill {
                        id: launcherPill
                        content: Text {
                            text: "\uF303"  // nf-linux-archlinux
                            color: theme.textPrimary
                            font.pixelSize: 23
                            font.family: theme.fontFamily
                        }
                        onClicked: launcherProc.running = true
                    }
                    Process {
                        id: launcherProc
                        command: ["sh", "-c", "killall rofi || $HOME/.config/rofi/launchers/type-3/launcher.sh"]
                    }

                    // 10 faste workspace-knapper (statisk 1-10, akkurat som
                    // persistent-workspaces i din nåværende Waybar-config)
                    Row {
                        spacing: 3

                        Repeater {
                            model: 10
                            Rectangle {
                                id: wsPill
                                required property int index
                                property int wsId: index + 1
                                property var hyprWs: {
                                    for (const w of Hyprland.workspaces.values) {
                                        if (w.id === wsId) return w;
                                    }
                                    return null;
                                }
                                property bool isFocused: hyprWs !== null && hyprWs.focused
                                property bool isOccupied: hyprWs !== null && hyprWs.toplevels
                                                           && hyprWs.toplevels.values.length > 0

                                width: isFocused ? 41 : 37
                                height: 37
                                radius: 11
                                // Alle workspace-knapper har samme mørke bakgrunn som
                                // resten av baren (konsistent "pille"-utseende). Aktiv
                                // får i tillegg en svak blå glød og kant.
                                color: isFocused ? Qt.rgba(46/255, 146/255, 219/255, 0.22) : theme.bgSurface
                                border.width: 1
                                border.color: isFocused ? theme.accentBlue : theme.accentBlueBorder

                                Behavior on width { NumberAnimation { duration: 120 } }
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: wsPill.wsId
                                    // Blå tekst for både aktiv OG opptatt - kun tom er hvit/dempet
                                    color: (wsPill.isFocused || wsPill.isOccupied) ? theme.accentBlue : theme.textPrimary
                                    font.bold: wsPill.isFocused
                                    font.pixelSize: 15
                                    font.family: theme.fontFamily
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        // Bekreftet Lua-dispatch-syntaks (se merknad øverst i filen)
                                        Hyprland.dispatch("hl.dsp.focus({workspace=" + wsPill.wsId + "})")
                                    }
                                }
                            }
                        }
                    }

                    // Aktivt vindu / program i bruk
                    Pill {
                        id: activeWindowPill
                        visible: Hyprland.activeToplevel !== null
                        content: Text {
                            text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""
                            color: theme.textPrimary
                            font.pixelSize: 15
                            font.family: theme.fontFamily
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, 170)
                        }
                    }
                }

                // ============== SENTER: klokke ==============
                // Kun klokkeslett synlig - dato vises som popup ved hover,
                // klikk åpner kalender (kommando settes inn når du har valgt
                // GNOME Calendar eller Google Calendar i nettleservindu).
                Rectangle {
                    id: clockBox
                    anchors.centerIn: parent
                    height: 37
                    width: clockContent.implicitWidth + 23
                    radius: 11
                    color: clockMouseArea.containsMouse ? theme.bgSurfaceHover : theme.bgSurface
                    border.width: 1
                    border.color: clockMouseArea.containsMouse ? theme.accentBlueBorderHover : theme.accentBlueBorder

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: clockContent
                        anchors.centerIn: parent
                        text: "󰥔 " + Qt.formatDateTime(clockTimer.now, "HH:mm:ss")
                        color: theme.textPrimary
                        font.pixelSize: 20
                        font.bold: true
                        font.family: theme.fontFamily
                    }

                    MouseArea {
                        id: clockMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calendarProc.running = true
                    }

                    PopupWindow {
                        visible: clockMouseArea.containsMouse
                        anchor.window: bar
                        anchor.rect.x: (bar.width - implicitWidth) / 2
                        anchor.rect.y: bar.implicitHeight
                        implicitWidth: dateText.implicitWidth + 24
                        implicitHeight: 36
                        color: theme.bgSurfaceHover

                        Text {
                            id: dateText
                            anchors.centerIn: parent
                            // Norsk dag/måned-navn følger systemets locale (LC_TIME).
                            text: "󰃭 " + Qt.formatDate(clockTimer.now, "dddd d. MMMM yyyy")
                            color: theme.accentBlue
                            font.pixelSize: 15
                            font.family: theme.fontFamily
                        }
                    }
                }
                Process {
                    id: calendarProc
                    command: ["sh", "-c", "XAPP_FORCE_GTKWINDOW_ICON=\"$HOME/Nedlastinger/google-calendar64.png\" firefox --class __CALENDAR_APP_ID__ --name __CALENDAR_APP_ID__ --profile $HOME/.local/share/ice/firefox/__CALENDAR_APP_ID__ --no-remote \"http://calendar.google.com\""]
                }
                Timer {
                    id: clockTimer
                    property date now: new Date()
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: now = new Date()
                }

                // ============== HØYRE ==============
                Row {
                    id: rightSection
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12  // litt mer luft mellom de store gruppene

                    // Samlet gruppe: wifi/kabel + bluetooth + mikrofon + volum
                    // Én felles grå bakgrunn i stedet for fire separate piller,
                    // slik at de fire fremstår som én sammenhengende modul.
                    Rectangle {
                        id: networkGroup
                        height: 37
                        width: groupContent.implicitWidth + 26
                        radius: 11
                        color: theme.bgSurface
                        border.width: 1
                        border.color: theme.accentBlueBorder

                        Row {
                            id: groupContent
                            anchors.centerIn: parent
                            spacing: 16

                            // --- Nettverk: kabel ELLER wifi ---
                            Item {
                                width: netIcon.implicitWidth
                                height: netIcon.implicitHeight
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    id: netIcon
                                    text: root.netType === "ethernet"
                                          ? String.fromCodePoint(0xF0200)  // md-ethernet
                                          : (root.netState === "connected" ? "󰖩" : "󰖪")
                                    color: root.netState === "connected" ? theme.accentBlue : theme.textPrimary
                                    font.pixelSize: 20
                                    font.family: theme.fontFamily
                                }
                                MouseArea {
                                    id: netMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: nmguiProc.running = true
                                }
                            }
                            Process { id: nmguiProc; command: ["nmgui"] }

                            // --- Bluetooth ---
                            Item {
                                width: btIcon.implicitWidth
                                height: btIcon.implicitHeight
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    id: btIcon
                                    text: "󰂯"
                                    color: (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled)
                                           ? theme.accentBlue : theme.textPrimary
                                    font.pixelSize: 20
                                    font.family: theme.fontFamily
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: bluemanProc.running = true
                                }
                            }
                            Process { id: bluemanProc; command: ["blueman-manager"] }

                            // --- Mikrofon ---
                            Item {
                                width: micIcon.implicitWidth
                                height: micIcon.implicitHeight
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    id: micIcon
                                    property var src: Pipewire.defaultAudioSource
                                    text: (src && src.audio && src.audio.muted) ? "󰍭" : "󰍬"
                                    color: (src && src.audio && src.audio.muted) ? theme.textPrimary : theme.accentBlue
                                    font.pixelSize: 20
                                    font.family: theme.fontFamily
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            pavuMicProc.running = true;
                                        } else {
                                            const src = Pipewire.defaultAudioSource;
                                            if (src && src.audio) src.audio.muted = !src.audio.muted;
                                        }
                                    }
                                }
                            }
                            Process { id: pavuMicProc; command: ["pavucontrol", "-t", "4"] }  // Input Devices

                            // --- Volum (ikon + %) ---
                            Item {
                                id: volSegment
                                width: volContent.implicitWidth
                                height: volContent.implicitHeight
                                anchors.verticalCenter: parent.verticalCenter

                                Row {
                                    id: volContent
                                    spacing: 5
                                    Text {
                                        property var sink: Pipewire.defaultAudioSink
                                        text: {
                                            if (!sink || !sink.audio || sink.audio.muted || sink.audio.volume <= 0) return "󰖁";
                                            if (sink.audio.volume < 0.33) return "󰕿";
                                            if (sink.audio.volume < 0.66) return "󰖀";
                                            return "󰕾";
                                        }
                                        color: (sink && sink.audio && !sink.audio.muted) ? theme.accentBlue : theme.textPrimary
                                        font.pixelSize: 20
                                        font.family: theme.fontFamily
                                    }
                                    Text {
                                        property var sink: Pipewire.defaultAudioSink
                                        text: (sink && sink.audio) ? Math.round(sink.audio.volume * 100) + "%" : "–"
                                        color: theme.textPrimary
                                        font.pixelSize: 15
                                        font.family: theme.fontFamily
                                    }
                                }

                                MouseArea {
                                    id: volMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            pavuVolProc.running = true;
                                        } else {
                                            const sink = Pipewire.defaultAudioSink;
                                            if (sink && sink.audio) sink.audio.muted = !sink.audio.muted;
                                        }
                                    }
                                    onWheel: (wheel) => {
                                        const sink = Pipewire.defaultAudioSink;
                                        if (!sink || !sink.audio) return;
                                        const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                        sink.audio.volume = Math.max(0, Math.min(1.5, sink.audio.volume + delta));
                                    }
                                }
                            }
                            Process { id: pavuVolProc; command: ["pavucontrol", "-t", "3"] }  // Output Devices
                        }

                        // Nettverk-IP hover-tooltip - ekte søsken av gruppa
                        PopupWindow {
                            visible: netMouseArea.containsMouse && root.netState === "connected"
                            anchor.window: bar
                            anchor.rect.x: (bar.width - implicitWidth) / 2
                            anchor.rect.y: bar.implicitHeight
                            implicitWidth: netIpText.implicitWidth + 24
                            implicitHeight: 34
                            color: theme.bgSurfaceHover

                            Text {
                                id: netIpText
                                anchors.centerIn: parent
                                text: (root.netType === "ethernet" ? "Kabel: " : "Wifi: ") + (root.netIP || "?")
                                color: theme.accentBlue
                                font.pixelSize: 13
                                font.family: theme.fontFamily
                            }
                        }

                        // Volum-slider - ekte søsken av gruppa
                        PopupWindow {
                            visible: volMouseArea.containsMouse
                            anchor.window: bar
                            anchor.rect.x: (bar.width - implicitWidth) / 2
                            anchor.rect.y: bar.implicitHeight
                            implicitWidth: 160
                            implicitHeight: 40
                            color: theme.bgSurfaceHover

                            Slider {
                                anchors.fill: parent
                                anchors.margins: 8
                                from: 0
                                to: 1.5
                                value: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio
                                       ? Pipewire.defaultAudioSink.audio.volume : 0
                                onMoved: {
                                    const sink = Pipewire.defaultAudioSink;
                                    if (sink && sink.audio) sink.audio.volume = value;
                                }
                            }
                        }
                    }

                    // __KEYBOARD_BUTTON_START__
                    // Virtuelt tastatur - samme toggle-signal (SIGRTMIN) som SUPER+T
                    Pill {
                        content: Text {
                            text: String.fromCodePoint(0xF030C)  // nf-md-keyboard
                            color: theme.textPrimary
                            font.pixelSize: 20
                            font.family: theme.fontFamily
                        }
                        onClicked: vkbdProc.running = true
                    }
                    Process { id: vkbdProc; command: ["pkill", "--signal", "SIGRTMIN", "wvkbd-norsk"] }
                    // __KEYBOARD_BUTTON_END__

                    // Strøm - klikk åpner wlogout (samme som i dag)
                    Pill {
                        content: Text {
                            text: "⏻"
                            color: theme.textPrimary
                            font.pixelSize: 20
                            font.family: theme.fontFamily
                        }
                        onClicked: powerProc.running = true
                    }
                    Process { id: powerProc; command: ["wlogout"] }
                }
            }
        }
    }
}
QSEOF

    # --- Betinget: fjern tastatur-knappen hvis wvkbd-norsk ikke er valgt ---
    if [ "$INSTALL_WVKBD" = false ]; then
        print_step "Fjerner tastatur-knapp fra baren (wvkbd-norsk ikke valgt)..."
        sed -i '/__KEYBOARD_BUTTON_START__/,/__KEYBOARD_BUTTON_END__/d' "$QS_CONFIG_DIR/bar/widgets/Bar.qml"
        print_success "Tastatur-knapp fjernet"
    else
        sed -i '/__KEYBOARD_BUTTON_START__/d; /__KEYBOARD_BUTTON_END__/d' "$QS_CONFIG_DIR/bar/widgets/Bar.qml"
    fi

    # --- Betinget: Google Kalender-oppsett ---
    CAL_APP_NAME="GoogleKalender"

    if [ "$INSTALL_CALENDAR" = true ]; then
        print_step "Setter opp Google Kalender-nettapp (ice-ssb)..."

        if ! command -v ice-ssb &> /dev/null && ! pacman -Qi ice-ssb &> /dev/null; then
            print_step "Installerer ice-ssb fra AUR..."
            if [ -n "$AUR_HELPER" ]; then
                "$AUR_HELPER" -S --needed --noconfirm ice-ssb
            else
                print_error "Ingen AUR-hjelper funnet - installer ice-ssb manuelt (yay -S ice-ssb) og kjør scriptet på nytt."
                INSTALL_CALENDAR=false
            fi
        fi
    fi

    if [ "$INSTALL_CALENDAR" = true ]; then
        mkdir -p "$HOME/Nedlastinger"
        cat > /tmp/google-calendar.svg << 'SVGEOF'
<?xml version="1.0" encoding="utf-8"?><!-- Uploaded to: SVG Repo, www.svgrepo.com, Generator: SVG Repo Mixer Tools -->
<svg xmlns="http://www.w3.org/2000/svg"
aria-label="Google Calendar" role="img"
viewBox="0 0 512 512"><rect
width="512" height="512"
rx="15%"
fill="#ffffff"/><path d="M100 340h74V174H340v-74H137Q100 100 100 135" fill="#4285f4"/><path d="M338 100v76h74v-41q0-35-35-35" fill="#1967d2"/><path d="M338 174h74V338h-74" fill="#fbbc04"/><path d="M100 338v39q0 35 35 35h41v-74" fill="#188038"/><path d="M174 338H338v74H174" fill="#34a853"/><path d="M338 412v-74h74" fill="#ea4335"/><path d="M204 229a25 22 1 1 1 25 27h-9h9a25 22 1 1 1-25 27M270 231l27-19h4v-7V308" stroke="#4285f4" stroke-width="15" stroke-linejoin="bevel" fill="none"/></svg>
SVGEOF
        if command -v rsvg-convert &> /dev/null; then
            rsvg-convert -w 64 -h 64 /tmp/google-calendar.svg -o "$HOME/Nedlastinger/google-calendar64.png"
        elif command -v magick &> /dev/null; then
            magick /tmp/google-calendar.svg -resize 64x64 "$HOME/Nedlastinger/google-calendar64.png"
        elif command -v convert &> /dev/null; then
            convert -background none /tmp/google-calendar.svg -resize 64x64 "$HOME/Nedlastinger/google-calendar64.png"
        else
            print_warning "Fant verken rsvg-convert eller ImageMagick - installerer rsvg-convert..."
            sudo pacman -S --needed --noconfirm librsvg
            rsvg-convert -w 64 -h 64 /tmp/google-calendar.svg -o "$HOME/Nedlastinger/google-calendar64.png"
        fi
        print_success "Kalender-ikon konvertert til $HOME/Nedlastinger/google-calendar64.png"

        # Ice-ssb sin egen ikon-mappe - legg ikonet her også, slik at det er
        # rett tilgjengelig i ice-ssb sin fil-dialog uten å måtte lete på nettet.
        mkdir -p "$HOME/.local/share/ice/icons"
        cp "$HOME/Nedlastinger/google-calendar64.png" "$HOME/.local/share/ice/icons/$CAL_APP_NAME.png"
        print_success "Ikon også lagt i ~/.local/share/ice/icons/$CAL_APP_NAME.png"

        echo ""
        echo -e "${YELLOW}--- MANUELT STEG ---${NC}"
        echo "ice-ssb åpnes nå. Opprett en nettapp med EKSAKT dette navnet"
        echo "(ice-ssb bruker navnet du skriver rett av som mappenavn/ID,"
        echo "ingen tilfeldige tall lagt til - viktig at det matcher):"
        echo ""
        echo "  Navn:      $CAL_APP_NAME"
        echo "  Adresse:   https://calendar.google.com/calendar/u/0/r?pli=1"
        echo "  Ikon:      $HOME/.local/share/ice/icons/$CAL_APP_NAME.png"
        echo "             (ligger i ice-ssb sin egen ikon-mappe - bør dukke"
        echo "             opp rett i fil-dialogen uten at du må lete)"
        echo "  Nettleser: Firefox"
        echo ""
        ice-ssb &> /dev/null &
        read -rp "Trykk Enter når du har opprettet nettappen og lukket ice-ssb-vinduet..."

        if [ -d "$HOME/.local/share/ice/firefox/$CAL_APP_NAME" ]; then
            print_success "Bekreftet: ~/.local/share/ice/firefox/$CAL_APP_NAME finnes"
            sed -i "s/__CALENDAR_APP_ID__/$CAL_APP_NAME/g" "$QS_CONFIG_DIR/bar/widgets/Bar.qml"
            print_success "Bar.qml oppdatert med kalender-navnet"
            MANUAL_LINES="${MANUAL_LINES}
# --- KALENDER: windowrule for blå kant (legg til i hyprland.lua) ---
hl.window_rule({
    name  = \"float-googlekalender\",
    match = { class = \"^($CAL_APP_NAME)\$\" },
    float = true,
    size  = \"1000 750\",
    center = true,
    animation = \"slide\",
    border_color = \"rgba(2e92dbff)\",
})
"
        else
            print_error "Fant ikke ~/.local/share/ice/firefox/$CAL_APP_NAME - het nettappen noe annet enn '$CAL_APP_NAME'?"
            print_warning "Sjekk manuelt: ls ~/.local/share/ice/firefox/"
            print_warning "Bytt deretter __CALENDAR_APP_ID__ i Bar.qml manuelt til riktig navn (3 forekomster, linje ~243)."
        fi
    else
        print_warning "Kalender ikke valgt - klokke-klikk gjør ingenting (tom kommando satt inn)"
        sed -i 's|command: \["sh", "-c", "XAPP_FORCE_GTKWINDOW_ICON.*__CALENDAR_APP_ID__.*"\]|command: ["true"]|' "$QS_CONFIG_DIR/bar/widgets/Bar.qml"
    fi

    print_success "bar installert i $QS_CONFIG_DIR/bar/"
    MANUAL_LINES="${MANUAL_LINES}
# --- BAR: autostart-linje (i hl.on(\"hyprland.start\", function() ... end)) ---
    hl.exec_cmd(\"qs -c bar\")
"
fi

# ------------------------------------------------------------
# OVERVIEW-modul
# ------------------------------------------------------------
if [ "$INSTALL_OVERVIEW" = true ]; then
    print_step "Installerer overview-modulen..."

    if [ -d "$QS_CONFIG_DIR/overview" ]; then
        BACKUP_NAME="overview-backup-$(date +%Y%m%d-%H%M%S)"
        print_warning "Eksisterende overview funnet, lager backup..."
        mv "$QS_CONFIG_DIR/overview" "$QS_CONFIG_DIR/$BACKUP_NAME"
        print_success "Backup lagret til $QS_CONFIG_DIR/$BACKUP_NAME"
    fi

    print_step "Cloner quickshell-overview..."
    if git clone --quiet https://github.com/Shanu-Kumawat/quickshell-overview "$QS_CONFIG_DIR/overview"; then
        print_success "quickshell-overview clonet"
    else
        print_error "Feil under cloning av overview - hopper over resten"
        INSTALL_OVERVIEW=false
    fi
fi

if [ "$INSTALL_OVERVIEW" = true ]; then
    cat > "$QS_CONFIG_DIR/overview/config.json" << 'CFGEOF'
{
  "overview": {
    "rows": 2,
    "columns": 5,
    "scale": 0.16,
    "showSpecialWorkspaces": true,
    "emptyWorkspaceWallpaper": "$HOME/.config/hypr/wallpapers/ARCHRUUD_1920x1200.png"
  }
}
CFGEOF
    print_success "config.json opprettet (showSpecialWorkspaces: true)"

    CONFIG_FILE="$QS_CONFIG_DIR/overview/common/Config.qml"
    if [ -f "$CONFIG_FILE" ] && grep -q "property bool hideEmptyRows:" "$CONFIG_FILE"; then
        sed -i 's/property bool hideEmptyRows:.*/property bool hideEmptyRows: false  \/\/ Vis alle workspaces/' "$CONFIG_FILE"
    fi

    print_success "overview installert i $QS_CONFIG_DIR/overview/"
    MANUAL_LINES="${MANUAL_LINES}
# --- OVERVIEW: autostart-linje ---
    hl.exec_cmd(\"qs -c overview\")

# --- OVERVIEW: keybind for å toggle ---
hl.bind(\"CTRL + Tab\", hl.dsp.exec_cmd(\"qs ipc -c overview call overview toggle\"))
"
fi

# ------------------------------------------------------------
# WVKBD-NORSK-modul (virtuelt tastatur med norsk layout)
# ------------------------------------------------------------
if [ "$INSTALL_WVKBD" = true ]; then
    print_step "Installerer wvkbd-norsk (virtuelt tastatur)..."

    sudo pacman -S --needed --noconfirm wayland libxkbcommon pango cairo scdoc base-devel

    WVKBD_BUILD_DIR="$HOME/Prosjekter/Norsk-tastatur"
    mkdir -p "$WVKBD_BUILD_DIR"

    if [ ! -d "$WVKBD_BUILD_DIR/.git" ]; then
        git clone --quiet https://github.com/jjsullivan5196/wvkbd.git "$WVKBD_BUILD_DIR"
    fi
    cd "$WVKBD_BUILD_DIR"

    cat > "$WVKBD_BUILD_DIR/keymap.norsk.h" << 'WVEOF'
#define NUMKEYMAPS 2

static const char *keymap_names[] = {"latin", "cyrillic"};

static const char *keymaps[NUMKEYMAPS] = {

  // LATIN
  "xkb_keymap {\
xkb_keycodes \"(unnamed)\" {\
        minimum = 8;\
        maximum = 255;\
        <ESC>                = 9;\
        <AE01>               = 10;\
        <AE02>               = 11;\
        <AE03>               = 12;\
        <AE04>               = 13;\
        <AE05>               = 14;\
        <AE06>               = 15;\
        <AE07>               = 16;\
        <AE08>               = 17;\
        <AE09>               = 18;\
        <AE10>               = 19;\
        <AE11>               = 20;\
        <AE12>               = 21;\
        <BKSP>               = 22;\
        <TAB>                = 23;\
        <AD01>               = 24;\
        <AD02>               = 25;\
        <AD03>               = 26;\
        <AD04>               = 27;\
        <AD05>               = 28;\
        <AD06>               = 29;\
        <AD07>               = 30;\
        <AD08>               = 31;\
        <AD09>               = 32;\
        <AD10>               = 33;\
        <AD11>               = 34;\
        <AD12>               = 35;\
        <RTRN>               = 36;\
        <LCTL>               = 37;\
        <AC01>               = 38;\
        <AC02>               = 39;\
        <AC03>               = 40;\
        <AC04>               = 41;\
        <AC05>               = 42;\
        <AC06>               = 43;\
        <AC07>               = 44;\
        <AC08>               = 45;\
        <AC09>               = 46;\
        <AC10>               = 47;\
        <AC11>               = 48;\
        <TLDE>               = 49;\
        <LFSH>               = 50;\
        <BKSL>               = 51;\
        <AB01>               = 52;\
        <AB02>               = 53;\
        <AB03>               = 54;\
        <AB04>               = 55;\
        <AB05>               = 56;\
        <AB06>               = 57;\
        <AB07>               = 58;\
        <AB08>               = 59;\
        <AB09>               = 60;\
        <AB10>               = 61;\
        <RTSH>               = 62;\
        <KPMU>               = 63;\
        <LALT>               = 64;\
        <SPCE>               = 65;\
        <CAPS>               = 66;\
        <FK01>               = 67;\
        <FK02>               = 68;\
        <FK03>               = 69;\
        <FK04>               = 70;\
        <FK05>               = 71;\
        <FK06>               = 72;\
        <FK07>               = 73;\
        <FK08>               = 74;\
        <FK09>               = 75;\
        <FK10>               = 76;\
        <NMLK>               = 77;\
        <SCLK>               = 78;\
        <KP7>                = 79;\
        <KP8>                = 80;\
        <KP9>                = 81;\
        <KPSU>               = 82;\
        <KP4>                = 83;\
        <KP5>                = 84;\
        <KP6>                = 85;\
        <KPAD>               = 86;\
        <KP1>                = 87;\
        <KP2>                = 88;\
        <KP3>                = 89;\
        <KP0>                = 90;\
        <KPDL>               = 91;\
        <LVL3>               = 92;\
        <LSGT>               = 94;\
        <FK11>               = 95;\
        <FK12>               = 96;\
        <AB11>               = 97;\
        <KATA>               = 98;\
        <HIRA>               = 99;\
        <HENK>               = 100;\
        <HKTG>               = 101;\
        <MUHE>               = 102;\
        <JPCM>               = 103;\
        <KPEN>               = 104;\
        <RCTL>               = 105;\
        <KPDV>               = 106;\
        <PRSC>               = 107;\
        <RALT>               = 108;\
        <LNFD>               = 109;\
        <HOME>               = 110;\
        <UP>                 = 111;\
        <PGUP>               = 112;\
        <LEFT>               = 113;\
        <RGHT>               = 114;\
        <END>                = 115;\
        <DOWN>               = 116;\
        <PGDN>               = 117;\
        <INS>                = 118;\
        <DELE>               = 119;\
        <I120>               = 120;\
        <MUTE>               = 121;\
        <VOL->               = 122;\
        <VOL+>               = 123;\
        <POWR>               = 124;\
        <KPEQ>               = 125;\
        <I126>               = 126;\
        <PAUS>               = 127;\
        <I128>               = 128;\
        <I129>               = 129;\
        <HNGL>               = 130;\
        <HJCV>               = 131;\
        <AE13>               = 132;\
        <LWIN>               = 133;\
        <RWIN>               = 134;\
        <COMP>               = 135;\
        <STOP>               = 136;\
        <AGAI>               = 137;\
        <PROP>               = 138;\
        <UNDO>               = 139;\
        <FRNT>               = 140;\
        <COPY>               = 141;\
        <OPEN>               = 142;\
        <PAST>               = 143;\
        <FIND>               = 144;\
        <CUT>                = 145;\
        <HELP>               = 146;\
        <I147>               = 147;\
        <I148>               = 148;\
        <I149>               = 149;\
        <I150>               = 150;\
        <I151>               = 151;\
        <I152>               = 152;\
        <I153>               = 153;\
        <I154>               = 154;\
        <I155>               = 155;\
        <I156>               = 156;\
        <I157>               = 157;\
        <I158>               = 158;\
        <I159>               = 159;\
        <I160>               = 160;\
        <I161>               = 161;\
        <I162>               = 162;\
        <I163>               = 163;\
        <I164>               = 164;\
        <I165>               = 165;\
        <I166>               = 166;\
        <I167>               = 167;\
        <I168>               = 168;\
        <I169>               = 169;\
        <I170>               = 170;\
        <I171>               = 171;\
        <I172>               = 172;\
        <I173>               = 173;\
        <I174>               = 174;\
        <I175>               = 175;\
        <I176>               = 176;\
        <I177>               = 177;\
        <I178>               = 178;\
        <I179>               = 179;\
        <I180>               = 180;\
        <I181>               = 181;\
        <I182>               = 182;\
        <I183>               = 183;\
        <I184>               = 184;\
        <I185>               = 185;\
        <I186>               = 186;\
        <I187>               = 187;\
        <I188>               = 188;\
        <I189>               = 189;\
        <I190>               = 190;\
        <FK13>               = 191;\
        <FK14>               = 192;\
        <FK15>               = 193;\
        <FK16>               = 194;\
        <FK17>               = 195;\
        <FK18>               = 196;\
        <FK19>               = 197;\
        <FK20>               = 198;\
        <FK21>               = 199;\
        <FK22>               = 200;\
        <FK23>               = 201;\
        <FK24>               = 202;\
        <MDSW>               = 203;\
        <ALT>                = 204;\
        <META>               = 205;\
        <SUPR>               = 206;\
        <HYPR>               = 207;\
        <I208>               = 208;\
        <I209>               = 209;\
        <I210>               = 210;\
        <I211>               = 211;\
        <I212>               = 212;\
        <I213>               = 213;\
        <I214>               = 214;\
        <I215>               = 215;\
        <I216>               = 216;\
        <I217>               = 217;\
        <I218>               = 218;\
        <I219>               = 219;\
        <I220>               = 220;\
        <I221>               = 221;\
        <I222>               = 222;\
        <I223>               = 223;\
        <I224>               = 224;\
        <I225>               = 225;\
        <I226>               = 226;\
        <I227>               = 227;\
        <I228>               = 228;\
        <I229>               = 229;\
        <I230>               = 230;\
        <I231>               = 231;\
        <I232>               = 232;\
        <I233>               = 233;\
        <I234>               = 234;\
        <I235>               = 235;\
        <I236>               = 236;\
        <I237>               = 237;\
        <I238>               = 238;\
        <I239>               = 239;\
        <I240>               = 240;\
        <I241>               = 241;\
        <I242>               = 242;\
        <I243>               = 243;\
        <I244>               = 244;\
        <I245>               = 245;\
        <I246>               = 246;\
        <I247>               = 247;\
        <I248>               = 248;\
        <I249>               = 249;\
        <I250>               = 250;\
        <I251>               = 251;\
        <I252>               = 252;\
        <I253>               = 253;\
        <I254>               = 254;\
        <I255>               = 255;\
        indicator 1 = \"Caps Lock\";\
        indicator 2 = \"Num Lock\";\
        indicator 3 = \"Scroll Lock\";\
        indicator 4 = \"Compose\";\
        indicator 5 = \"Kana\";\
        indicator 6 = \"Sleep\";\
        indicator 7 = \"Suspend\";\
        indicator 8 = \"Mute\";\
        indicator 9 = \"Misc\";\
        indicator 10 = \"Mail\";\
        indicator 11 = \"Charging\";\
        indicator 12 = \"Shift Lock\";\
        indicator 13 = \"Group 2\";\
        indicator 14 = \"Mouse Keys\";\
        alias <AC12>         = <BKSL>;\
        alias <MENU>         = <COMP>;\
        alias <HZTG>         = <TLDE>;\
        alias <LMTA>         = <LWIN>;\
        alias <RMTA>         = <RWIN>;\
        alias <ALGR>         = <RALT>;\
        alias <KPPT>         = <I129>;\
        alias <LatQ>         = <AD01>;\
        alias <LatW>         = <AD02>;\
        alias <LatE>         = <AD03>;\
        alias <LatR>         = <AD04>;\
        alias <LatT>         = <AD05>;\
        alias <LatY>         = <AD06>;\
        alias <LatU>         = <AD07>;\
        alias <LatI>         = <AD08>;\
        alias <LatO>         = <AD09>;\
        alias <LatP>         = <AD10>;\
        alias <LatA>         = <AC01>;\
        alias <LatS>         = <AC02>;\
        alias <LatD>         = <AC03>;\
        alias <LatF>         = <AC04>;\
        alias <LatG>         = <AC05>;\
        alias <LatH>         = <AC06>;\
        alias <LatJ>         = <AC07>;\
        alias <LatK>         = <AC08>;\
        alias <LatL>         = <AC09>;\
        alias <LatZ>         = <AB01>;\
        alias <LatX>         = <AB02>;\
        alias <LatC>         = <AB03>;\
        alias <LatV>         = <AB04>;\
        alias <LatB>         = <AB05>;\
        alias <LatN>         = <AB06>;\
        alias <LatM>         = <AB07>;\
};\
\
xkb_types \"(unnamed)\" {\
        virtual_modifiers NumLock,Alt,LevelThree,LAlt,RAlt,RControl,LControl,ScrollLock,LevelFive,AltGr,Meta,Super,Hyper;\
\
        type \"ONE_LEVEL\" {\
                modifiers= none;\
                level_name[Level1]= \"Any\";\
        };\
        type \"TWO_LEVEL\" {\
                modifiers= Shift;\
                map[Shift]= Level2;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
        };\
        type \"ALPHABETIC\" {\
                modifiers= Shift+Lock;\
                map[Shift]= Level2;\
                map[Lock]= Level2;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Caps\";\
        };\
        type \"SHIFT+ALT\" {\
                modifiers= Shift+Alt;\
                map[Shift+Alt]= Level2;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift+Alt\";\
        };\
        type \"PC_SUPER_LEVEL2\" {\
                modifiers= Mod4;\
                map[Mod4]= Level2;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Super\";\
        };\
        type \"PC_CONTROL_LEVEL2\" {\
                modifiers= Control;\
                map[Control]= Level2;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Control\";\
        };\
        type \"PC_LCONTROL_LEVEL2\" {\
                modifiers= LControl;\
                map[LControl]= Level2;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"LControl\";\
        };\
        type \"PC_RCONTROL_LEVEL2\" {\
                modifiers= RControl;\
                map[RControl]= Level2;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"RControl\";\
        };\
        type \"PC_ALT_LEVEL2\" {\
                modifiers= Alt;\
                map[Alt]= Level2;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Alt\";\
        };\
        type \"PC_LALT_LEVEL2\" {\
                modifiers= LAlt;\
                map[LAlt]= Level2;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"LAlt\";\
        };\
        type \"PC_RALT_LEVEL2\" {\
                modifiers= RAlt;\
                map[RAlt]= Level2;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"RAlt\";\
        };\
        type \"CTRL+ALT\" {\
                modifiers= Shift+Control+Alt+LevelThree;\
                map[Shift]= Level2;\
                preserve[Shift]= Shift;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                preserve[Shift+LevelThree]= Shift;\
                map[Control+Alt]= Level5;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Shift Alt\";\
                level_name[Level5]= \"Ctrl+Alt\";\
        };\
        type \"LOCAL_EIGHT_LEVEL\" {\
                modifiers= Shift+Lock+Control+LevelThree;\
                map[Shift]= Level2;\
                map[Lock]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+Lock+LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[Lock+LevelThree]= Level4;\
                map[Control]= Level5;\
                map[Shift+Lock+Control]= Level5;\
                map[Shift+Control]= Level6;\
                map[Lock+Control]= Level6;\
                map[Control+LevelThree]= Level7;\
                map[Shift+Lock+Control+LevelThree]= Level7;\
                map[Shift+Control+LevelThree]= Level8;\
                map[Lock+Control+LevelThree]= Level8;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Level3\";\
                level_name[Level4]= \"Shift Level3\";\
                level_name[Level5]= \"Ctrl\";\
                level_name[Level6]= \"Shift Ctrl\";\
                level_name[Level7]= \"Level3 Ctrl\";\
                level_name[Level8]= \"Shift Level3 Ctrl\";\
        };\
        type \"THREE_LEVEL\" {\
                modifiers= Shift+LevelThree;\
                map[Shift]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level3;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Level3\";\
        };\
        type \"EIGHT_LEVEL\" {\
                modifiers= Shift+LevelThree+LevelFive;\
                map[Shift]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[LevelFive]= Level5;\
                map[Shift+LevelFive]= Level6;\
                map[LevelThree+LevelFive]= Level7;\
                map[Shift+LevelThree+LevelFive]= Level8;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Shift Alt\";\
                level_name[Level5]= \"X\";\
                level_name[Level6]= \"X Shift\";\
                level_name[Level7]= \"X Alt Base\";\
                level_name[Level8]= \"X Shift Alt\";\
        };\
        type \"EIGHT_LEVEL_ALPHABETIC\" {\
                modifiers= Shift+Lock+LevelThree+LevelFive;\
                map[Shift]= Level2;\
                map[Lock]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[Lock+LevelThree]= Level4;\
                map[Shift+Lock+LevelThree]= Level3;\
                map[LevelFive]= Level5;\
                map[Shift+LevelFive]= Level6;\
                map[Lock+LevelFive]= Level6;\
                map[LevelThree+LevelFive]= Level7;\
                map[Shift+LevelThree+LevelFive]= Level8;\
                map[Lock+LevelThree+LevelFive]= Level8;\
                map[Shift+Lock+LevelThree+LevelFive]= Level7;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Shift Alt\";\
                level_name[Level5]= \"X\";\
                level_name[Level6]= \"X Shift\";\
                level_name[Level7]= \"X Alt Base\";\
                level_name[Level8]= \"X Shift Alt\";\
        };\
        type \"EIGHT_LEVEL_LEVEL_FIVE_LOCK\" {\
                modifiers= Shift+Lock+NumLock+LevelThree+LevelFive;\
                map[Shift]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[LevelFive]= Level5;\
                map[Shift+LevelFive]= Level6;\
                preserve[Shift+LevelFive]= Shift;\
                map[LevelThree+LevelFive]= Level7;\
                map[Shift+LevelThree+LevelFive]= Level8;\
                map[NumLock]= Level5;\
                map[Shift+NumLock]= Level6;\
                preserve[Shift+NumLock]= Shift;\
                map[NumLock+LevelThree]= Level7;\
                map[Shift+NumLock+LevelThree]= Level8;\
                map[Shift+NumLock+LevelFive]= Level2;\
                map[NumLock+LevelThree+LevelFive]= Level3;\
                map[Shift+NumLock+LevelThree+LevelFive]= Level4;\
                map[Shift+Lock]= Level2;\
                map[Lock+LevelThree]= Level3;\
                map[Shift+Lock+LevelThree]= Level4;\
                map[Lock+LevelFive]= Level5;\
                map[Shift+Lock+LevelFive]= Level6;\
                preserve[Shift+Lock+LevelFive]= Shift;\
                map[Lock+LevelThree+LevelFive]= Level7;\
                map[Shift+Lock+LevelThree+LevelFive]= Level8;\
                map[Lock+NumLock]= Level5;\
                map[Shift+Lock+NumLock]= Level6;\
                preserve[Shift+Lock+NumLock]= Shift;\
                map[Lock+NumLock+LevelThree]= Level7;\
                map[Shift+Lock+NumLock+LevelThree]= Level8;\
                map[Shift+Lock+NumLock+LevelFive]= Level2;\
                map[Lock+NumLock+LevelThree+LevelFive]= Level3;\
                map[Shift+Lock+NumLock+LevelThree+LevelFive]= Level4;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Shift Alt\";\
                level_name[Level5]= \"X\";\
                level_name[Level6]= \"X Shift\";\
                level_name[Level7]= \"X Alt Base\";\
                level_name[Level8]= \"X Shift Alt\";\
        };\
        type \"EIGHT_LEVEL_ALPHABETIC_LEVEL_FIVE_LOCK\" {\
                modifiers= Shift+Lock+NumLock+LevelThree+LevelFive;\
                map[Shift]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[LevelFive]= Level5;\
                map[Shift+LevelFive]= Level6;\
                preserve[Shift+LevelFive]= Shift;\
                map[LevelThree+LevelFive]= Level7;\
                map[Shift+LevelThree+LevelFive]= Level8;\
                map[NumLock]= Level5;\
                map[Shift+NumLock]= Level6;\
                preserve[Shift+NumLock]= Shift;\
                map[NumLock+LevelThree]= Level7;\
                map[Shift+NumLock+LevelThree]= Level8;\
                map[Shift+NumLock+LevelFive]= Level2;\
                map[NumLock+LevelThree+LevelFive]= Level3;\
                map[Shift+NumLock+LevelThree+LevelFive]= Level4;\
                map[Lock]= Level2;\
                map[Lock+LevelThree]= Level3;\
                map[Shift+Lock+LevelThree]= Level4;\
                map[Lock+LevelFive]= Level5;\
                map[Shift+Lock+LevelFive]= Level6;\
                map[Lock+LevelThree+LevelFive]= Level7;\
                map[Shift+Lock+LevelThree+LevelFive]= Level8;\
                map[Lock+NumLock]= Level5;\
                map[Shift+Lock+NumLock]= Level6;\
                map[Lock+NumLock+LevelThree]= Level7;\
                map[Shift+Lock+NumLock+LevelThree]= Level8;\
                map[Lock+NumLock+LevelFive]= Level2;\
                map[Lock+NumLock+LevelThree+LevelFive]= Level4;\
                map[Shift+Lock+NumLock+LevelThree+LevelFive]= Level3;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Shift Alt\";\
                level_name[Level5]= \"X\";\
                level_name[Level6]= \"X Shift\";\
                level_name[Level7]= \"X Alt Base\";\
                level_name[Level8]= \"X Shift Alt\";\
        };\
        type \"EIGHT_LEVEL_SEMIALPHABETIC\" {\
                modifiers= Shift+Lock+LevelThree+LevelFive;\
                map[Shift]= Level2;\
                map[Lock]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[Lock+LevelThree]= Level3;\
                preserve[Lock+LevelThree]= Lock;\
                map[Shift+Lock+LevelThree]= Level4;\
                preserve[Shift+Lock+LevelThree]= Lock;\
                map[LevelFive]= Level5;\
                map[Shift+LevelFive]= Level6;\
                map[Lock+LevelFive]= Level6;\
                preserve[Lock+LevelFive]= Lock;\
                map[Shift+Lock+LevelFive]= Level6;\
                preserve[Shift+Lock+LevelFive]= Lock;\
                map[LevelThree+LevelFive]= Level7;\
                map[Shift+LevelThree+LevelFive]= Level8;\
                map[Lock+LevelThree+LevelFive]= Level7;\
                preserve[Lock+LevelThree+LevelFive]= Lock;\
                map[Shift+Lock+LevelThree+LevelFive]= Level8;\
                preserve[Shift+Lock+LevelThree+LevelFive]= Lock;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Shift Alt\";\
                level_name[Level5]= \"X\";\
                level_name[Level6]= \"X Shift\";\
                level_name[Level7]= \"X Alt Base\";\
                level_name[Level8]= \"X Shift Alt\";\
        };\
        type \"FOUR_LEVEL\" {\
                modifiers= Shift+LevelThree;\
                map[Shift]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Shift Alt\";\
        };\
        type \"FOUR_LEVEL_ALPHABETIC\" {\
                modifiers= Shift+Lock+LevelThree;\
                map[Shift]= Level2;\
                map[Lock]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[Lock+LevelThree]= Level4;\
                map[Shift+Lock+LevelThree]= Level3;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Shift Alt\";\
        };\
        type \"FOUR_LEVEL_SEMIALPHABETIC\" {\
                modifiers= Shift+Lock+LevelThree;\
                map[Shift]= Level2;\
                map[Lock]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[Lock+LevelThree]= Level3;\
                preserve[Lock+LevelThree]= Lock;\
                map[Shift+Lock+LevelThree]= Level4;\
                preserve[Shift+Lock+LevelThree]= Lock;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Shift Alt\";\
        };\
        type \"FOUR_LEVEL_MIXED_KEYPAD\" {\
                modifiers= Shift+NumLock+LevelThree;\
                map[NumLock]= Level2;\
                map[Shift]= Level2;\
                map[LevelThree]= Level3;\
                map[NumLock+LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[Shift+NumLock+LevelThree]= Level4;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Number\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Shift Alt\";\
        };\
        type \"FOUR_LEVEL_X\" {\
                modifiers= Shift+Control+Alt+LevelThree;\
                map[LevelThree]= Level2;\
                map[Shift+LevelThree]= Level3;\
                map[Control+Alt]= Level4;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Alt Base\";\
                level_name[Level3]= \"Shift Alt\";\
                level_name[Level4]= \"Ctrl+Alt\";\
        };\
        type \"SEPARATE_CAPS_AND_SHIFT_ALPHABETIC\" {\
                modifiers= Shift+Lock+LevelThree;\
                map[Shift]= Level2;\
                map[Lock]= Level4;\
                preserve[Lock]= Lock;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[Lock+LevelThree]= Level3;\
                preserve[Lock+LevelThree]= Lock;\
                map[Shift+Lock+LevelThree]= Level3;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"AltGr Base\";\
                level_name[Level4]= \"Shift AltGr\";\
        };\
        type \"FOUR_LEVEL_PLUS_LOCK\" {\
                modifiers= Shift+Lock+LevelThree;\
                map[Shift]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[Lock]= Level5;\
                map[Shift+Lock]= Level2;\
                map[Lock+LevelThree]= Level3;\
                map[Shift+Lock+LevelThree]= Level4;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Shift Alt\";\
                level_name[Level5]= \"Lock\";\
        };\
        type \"KEYPAD\" {\
                modifiers= Shift+NumLock;\
                map[Shift]= Level2;\
                map[NumLock]= Level2;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Number\";\
        };\
        type \"FOUR_LEVEL_KEYPAD\" {\
                modifiers= Shift+NumLock+LevelThree;\
                map[Shift]= Level2;\
                map[NumLock]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[NumLock+LevelThree]= Level4;\
                map[Shift+NumLock+LevelThree]= Level3;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Number\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Alt Number\";\
        };\
};\
\
xkb_compatibility \"(unnamed)\" {\
        virtual_modifiers NumLock,Alt,LevelThree,LAlt,RAlt,RControl,LControl,ScrollLock,LevelFive,AltGr,Meta,Super,Hyper;\
\
        interpret.useModMapMods= AnyLevel;\
        interpret.repeat= False;\
        interpret ISO_Level2_Latch+Exactly(Shift) {\
                useModMapMods=level1;\
                action= LatchMods(modifiers=Shift,clearLocks,latchToLock);\
        };\
        interpret Shift_Lock+AnyOf(Shift+Lock) {\
                action= LockMods(modifiers=Shift);\
        };\
        interpret Num_Lock+AnyOf(all) {\
                virtualModifier= NumLock;\
                action= LockMods(modifiers=NumLock);\
        };\
        interpret ISO_Level3_Shift+AnyOf(all) {\
                virtualModifier= LevelThree;\
                useModMapMods=level1;\
                action= SetMods(modifiers=LevelThree,clearLocks);\
        };\
        interpret ISO_Level3_Latch+AnyOf(all) {\
                virtualModifier= LevelThree;\
                useModMapMods=level1;\
                action= LatchMods(modifiers=LevelThree,clearLocks,latchToLock);\
        };\
        interpret ISO_Level3_Lock+AnyOf(all) {\
                virtualModifier= LevelThree;\
                useModMapMods=level1;\
                action= LockMods(modifiers=LevelThree);\
        };\
        interpret Alt_L+AnyOf(all) {\
                virtualModifier= Alt;\
                action= SetMods(modifiers=modMapMods,clearLocks);\
        };\
        interpret Alt_R+AnyOf(all) {\
                virtualModifier= Alt;\
                action= SetMods(modifiers=modMapMods,clearLocks);\
        };\
        interpret Meta_L+AnyOf(all) {\
                virtualModifier= Meta;\
                action= SetMods(modifiers=modMapMods,clearLocks);\
        };\
        interpret Meta_R+AnyOf(all) {\
                virtualModifier= Meta;\
                action= SetMods(modifiers=modMapMods,clearLocks);\
        };\
        interpret Super_L+AnyOf(all) {\
                virtualModifier= Super;\
                action= SetMods(modifiers=modMapMods,clearLocks);\
        };\
        interpret Super_R+AnyOf(all) {\
                virtualModifier= Super;\
                action= SetMods(modifiers=modMapMods,clearLocks);\
        };\
        interpret Hyper_L+AnyOf(all) {\
                virtualModifier= Hyper;\
                action= SetMods(modifiers=modMapMods,clearLocks);\
        };\
        interpret Hyper_R+AnyOf(all) {\
                virtualModifier= Hyper;\
                action= SetMods(modifiers=modMapMods,clearLocks);\
        };\
        interpret Scroll_Lock+AnyOf(all) {\
                virtualModifier= ScrollLock;\
                action= LockMods(modifiers=modMapMods);\
        };\
        interpret ISO_Level5_Shift+AnyOf(all) {\
                virtualModifier= LevelFive;\
                useModMapMods=level1;\
                action= SetMods(modifiers=LevelFive,clearLocks);\
        };\
        interpret ISO_Level5_Latch+AnyOf(all) {\
                virtualModifier= LevelFive;\
                useModMapMods=level1;\
                action= LatchMods(modifiers=LevelFive,clearLocks,latchToLock);\
        };\
        interpret ISO_Level5_Lock+AnyOf(all) {\
                virtualModifier= LevelFive;\
                useModMapMods=level1;\
                action= LockMods(modifiers=LevelFive);\
        };\
        interpret Mode_switch+AnyOfOrNone(all) {\
                virtualModifier= AltGr;\
                useModMapMods=level1;\
                action= SetGroup(group=+1);\
        };\
        interpret ISO_Level3_Shift+AnyOfOrNone(all) {\
                action= SetMods(modifiers=LevelThree,clearLocks);\
        };\
        interpret ISO_Level3_Latch+AnyOfOrNone(all) {\
                action= LatchMods(modifiers=LevelThree,clearLocks,latchToLock);\
        };\
        interpret ISO_Level3_Lock+AnyOfOrNone(all) {\
                action= LockMods(modifiers=LevelThree);\
        };\
        interpret ISO_Group_Latch+AnyOfOrNone(all) {\
                virtualModifier= AltGr;\
                useModMapMods=level1;\
                action= LatchGroup(group=2);\
        };\
        interpret ISO_Next_Group+AnyOfOrNone(all) {\
                virtualModifier= AltGr;\
                useModMapMods=level1;\
                action= LockGroup(group=+1);\
        };\
        interpret ISO_Prev_Group+AnyOfOrNone(all) {\
                virtualModifier= AltGr;\
                useModMapMods=level1;\
                action= LockGroup(group=-1);\
        };\
        interpret ISO_First_Group+AnyOfOrNone(all) {\
                action= LockGroup(group=1);\
        };\
        interpret ISO_Last_Group+AnyOfOrNone(all) {\
                action= LockGroup(group=2);\
        };\
        interpret KP_1+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=-1,y=+1);\
        };\
        interpret KP_End+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=-1,y=+1);\
        };\
        interpret KP_2+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+0,y=+1);\
        };\
        interpret KP_Down+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+0,y=+1);\
        };\
        interpret KP_3+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+1,y=+1);\
        };\
        interpret KP_Next+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+1,y=+1);\
        };\
        interpret KP_4+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=-1,y=+0);\
        };\
        interpret KP_Left+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=-1,y=+0);\
        };\
        interpret KP_6+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+1,y=+0);\
        };\
        interpret KP_Right+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+1,y=+0);\
        };\
        interpret KP_7+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=-1,y=-1);\
        };\
        interpret KP_Home+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=-1,y=-1);\
        };\
        interpret KP_8+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+0,y=-1);\
        };\
        interpret KP_Up+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+0,y=-1);\
        };\
        interpret KP_9+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+1,y=-1);\
        };\
        interpret KP_Prior+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+1,y=-1);\
        };\
        interpret KP_5+AnyOfOrNone(all) {\
                repeat= True;\
                action= PtrBtn(button=default);\
        };\
        interpret KP_Begin+AnyOfOrNone(all) {\
                repeat= True;\
                action= PtrBtn(button=default);\
        };\
        interpret KP_F2+AnyOfOrNone(all) {\
                repeat= True;\
                action= SetPtrDflt(affect=button,button=1);\
        };\
        interpret KP_Divide+AnyOfOrNone(all) {\
                repeat= True;\
                action= SetPtrDflt(affect=button,button=1);\
        };\
        interpret KP_F3+AnyOfOrNone(all) {\
                repeat= True;\
                action= SetPtrDflt(affect=button,button=2);\
        };\
        interpret KP_Multiply+AnyOfOrNone(all) {\
                repeat= True;\
                action= SetPtrDflt(affect=button,button=2);\
        };\
        interpret KP_F4+AnyOfOrNone(all) {\
                repeat= True;\
                action= SetPtrDflt(affect=button,button=3);\
        };\
        interpret KP_Subtract+AnyOfOrNone(all) {\
                repeat= True;\
                action= SetPtrDflt(affect=button,button=3);\
        };\
        interpret KP_Separator+AnyOfOrNone(all) {\
                repeat= True;\
                action= PtrBtn(button=default,count=2);\
        };\
        interpret KP_Add+AnyOfOrNone(all) {\
                repeat= True;\
                action= PtrBtn(button=default,count=2);\
        };\
        interpret KP_0+AnyOfOrNone(all) {\
                repeat= True;\
                action= LockPtrBtn(button=default,affect=lock);\
        };\
        interpret KP_Insert+AnyOfOrNone(all) {\
                repeat= True;\
                action= LockPtrBtn(button=default,affect=lock);\
        };\
        interpret KP_Decimal+AnyOfOrNone(all) {\
                repeat= True;\
                action= LockPtrBtn(button=default,affect=unlock);\
        };\
        interpret KP_Delete+AnyOfOrNone(all) {\
                repeat= True;\
                action= LockPtrBtn(button=default,affect=unlock);\
        };\
        interpret F25+AnyOfOrNone(all) {\
                repeat= True;\
                action= SetPtrDflt(affect=button,button=1);\
        };\
        interpret F26+AnyOfOrNone(all) {\
                repeat= True;\
                action= SetPtrDflt(affect=button,button=2);\
        };\
        interpret F27+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=-1,y=-1);\
        };\
        interpret F29+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+1,y=-1);\
        };\
        interpret F31+AnyOfOrNone(all) {\
                repeat= True;\
                action= PtrBtn(button=default);\
        };\
        interpret F33+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=-1,y=+1);\
        };\
        interpret F35+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+1,y=+1);\
        };\
        interpret Pointer_Button_Dflt+AnyOfOrNone(all) {\
                action= PtrBtn(button=default);\
        };\
        interpret Pointer_Button1+AnyOfOrNone(all) {\
                action= PtrBtn(button=1);\
        };\
        interpret Pointer_Button2+AnyOfOrNone(all) {\
                action= PtrBtn(button=2);\
        };\
        interpret Pointer_Button3+AnyOfOrNone(all) {\
                action= PtrBtn(button=3);\
        };\
        interpret Pointer_DblClick_Dflt+AnyOfOrNone(all) {\
                action= PtrBtn(button=default,count=2);\
        };\
        interpret Pointer_DblClick1+AnyOfOrNone(all) {\
                action= PtrBtn(button=1,count=2);\
        };\
        interpret Pointer_DblClick2+AnyOfOrNone(all) {\
                action= PtrBtn(button=2,count=2);\
        };\
        interpret Pointer_DblClick3+AnyOfOrNone(all) {\
                action= PtrBtn(button=3,count=2);\
        };\
        interpret Pointer_Drag_Dflt+AnyOfOrNone(all) {\
                action= LockPtrBtn(button=default);\
        };\
        interpret Pointer_Drag1+AnyOfOrNone(all) {\
                action= LockPtrBtn(button=1);\
        };\
        interpret Pointer_Drag2+AnyOfOrNone(all) {\
                action= LockPtrBtn(button=2);\
        };\
        interpret Pointer_Drag3+AnyOfOrNone(all) {\
                action= LockPtrBtn(button=3);\
        };\
        interpret Pointer_EnableKeys+AnyOfOrNone(all) {\
                action= LockControls(controls=MouseKeys);\
        };\
        interpret Pointer_Accelerate+AnyOfOrNone(all) {\
                action= LockControls(controls=MouseKeysAccel);\
        };\
        interpret Pointer_DfltBtnNext+AnyOfOrNone(all) {\
                action= SetPtrDflt(affect=button,button=+1);\
        };\
        interpret Pointer_DfltBtnPrev+AnyOfOrNone(all) {\
                action= SetPtrDflt(affect=button,button=-1);\
        };\
        interpret AccessX_Enable+AnyOfOrNone(all) {\
                action= LockControls(controls=AccessXKeys);\
        };\
        interpret AccessX_Feedback_Enable+AnyOfOrNone(all) {\
                action= LockControls(controls=AccessXFeedback);\
        };\
        interpret RepeatKeys_Enable+AnyOfOrNone(all) {\
                action= LockControls(controls=RepeatKeys);\
        };\
        interpret SlowKeys_Enable+AnyOfOrNone(all) {\
                action= LockControls(controls=SlowKeys);\
        };\
        interpret BounceKeys_Enable+AnyOfOrNone(all) {\
                action= LockControls(controls=BounceKeys);\
        };\
        interpret StickyKeys_Enable+AnyOfOrNone(all) {\
                action= LockControls(controls=StickyKeys);\
        };\
        interpret MouseKeys_Enable+AnyOfOrNone(all) {\
                action= LockControls(controls=MouseKeys);\
        };\
        interpret MouseKeys_Accel_Enable+AnyOfOrNone(all) {\
                action= LockControls(controls=MouseKeysAccel);\
        };\
        interpret Overlay1_Enable+AnyOfOrNone(all) {\
                action= LockControls(controls=none);\
        };\
        interpret Overlay2_Enable+AnyOfOrNone(all) {\
                action= LockControls(controls=none);\
        };\
        interpret AudibleBell_Enable+AnyOfOrNone(all) {\
                action= LockControls(controls=AudibleBell);\
        };\
        interpret Terminate_Server+AnyOfOrNone(all) {\
                action= Terminate();\
        };\
        interpret Alt_L+AnyOfOrNone(all) {\
                action= SetMods(modifiers=Alt,clearLocks);\
        };\
        interpret Alt_R+AnyOfOrNone(all) {\
                action= SetMods(modifiers=Alt,clearLocks);\
        };\
        interpret Meta_L+AnyOfOrNone(all) {\
                action= SetMods(modifiers=Meta,clearLocks);\
        };\
        interpret Meta_R+AnyOfOrNone(all) {\
                action= SetMods(modifiers=Meta,clearLocks);\
        };\
        interpret Super_L+AnyOfOrNone(all) {\
                action= SetMods(modifiers=Super,clearLocks);\
        };\
        interpret Super_R+AnyOfOrNone(all) {\
                action= SetMods(modifiers=Super,clearLocks);\
        };\
        interpret Hyper_L+AnyOfOrNone(all) {\
                action= SetMods(modifiers=Hyper,clearLocks);\
        };\
        interpret Hyper_R+AnyOfOrNone(all) {\
                action= SetMods(modifiers=Hyper,clearLocks);\
        };\
        interpret Shift_L+AnyOfOrNone(all) {\
                action= SetMods(modifiers=Shift,clearLocks);\
        };\
        interpret XF86Switch_VT_1+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=1,!same);\
        };\
        interpret XF86Switch_VT_2+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=2,!same);\
        };\
        interpret XF86Switch_VT_3+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=3,!same);\
        };\
        interpret XF86Switch_VT_4+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=4,!same);\
        };\
        interpret XF86Switch_VT_5+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=5,!same);\
        };\
        interpret XF86Switch_VT_6+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=6,!same);\
        };\
        interpret XF86Switch_VT_7+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=7,!same);\
        };\
        interpret XF86Switch_VT_8+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=8,!same);\
        };\
        interpret XF86Switch_VT_9+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=9,!same);\
        };\
        interpret XF86Switch_VT_10+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=10,!same);\
        };\
        interpret XF86Switch_VT_11+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=11,!same);\
        };\
        interpret XF86Switch_VT_12+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=12,!same);\
        };\
        interpret XF86LogGrabInfo+AnyOfOrNone(all) {\
                repeat= True;\
                action= Private(type=0x86,data[0]=0x50,data[1]=0x72,data[2]=0x47,data[3]=0x72,data[4]=0x62,data[5]=0x73,data[6]=0x00);\
        };\
        interpret XF86LogWindowTree+AnyOfOrNone(all) {\
                repeat= True;\
                action= Private(type=0x86,data[0]=0x50,data[1]=0x72,data[2]=0x57,data[3]=0x69,data[4]=0x6e,data[5]=0x73,data[6]=0x00);\
        };\
        interpret XF86Next_VMode+AnyOfOrNone(all) {\
                repeat= True;\
                action= Private(type=0x86,data[0]=0x2b,data[1]=0x56,data[2]=0x4d,data[3]=0x6f,data[4]=0x64,data[5]=0x65,data[6]=0x00);\
        };\
        interpret XF86Prev_VMode+AnyOfOrNone(all) {\
                repeat= True;\
                action= Private(type=0x86,data[0]=0x2d,data[1]=0x56,data[2]=0x4d,data[3]=0x6f,data[4]=0x64,data[5]=0x65,data[6]=0x00);\
        };\
        interpret ISO_Level5_Shift+AnyOfOrNone(all) {\
                action= SetMods(modifiers=LevelFive,clearLocks);\
        };\
        interpret ISO_Level5_Latch+AnyOfOrNone(all) {\
                action= LatchMods(modifiers=LevelFive,clearLocks,latchToLock);\
        };\
        interpret ISO_Level5_Lock+AnyOfOrNone(all) {\
                action= LockMods(modifiers=LevelFive);\
        };\
        interpret Caps_Lock+AnyOfOrNone(all) {\
                action= LockMods(modifiers=Lock);\
        };\
        interpret Any+Exactly(Lock) {\
                action= LockMods(modifiers=Lock);\
        };\
        interpret Any+AnyOf(all) {\
                action= SetMods(modifiers=modMapMods,clearLocks);\
        };\
        indicator \"Caps Lock\" {\
                whichModState= locked;\
                modifiers= Lock;\
        };\
        indicator \"Num Lock\" {\
                whichModState= locked;\
                modifiers= NumLock;\
        };\
        indicator \"Scroll Lock\" {\
                whichModState= locked;\
                modifiers= ScrollLock;\
        };\
        indicator \"Shift Lock\" {\
                whichModState= locked;\
                modifiers= Shift;\
        };\
        indicator \"Group 2\" {\
                groups= 0xfe;\
        };\
        indicator \"Mouse Keys\" {\
                controls= MouseKeys;\
        };\
};\
\
xkb_symbols \"(unnamed)\" {\
        name[group1]=\"wvkbd\";\
\
        key <ESC>                {	[          Escape ] };\
        key <AE01>               {	[               1,          exclam, F1 ] };\
        key <AE02>               {	[               2,              at, F2 ] };\
        key <AE03>               {	[               3,      numbersign, F3 ] };\
        key <AE04>               {	[               4,          dollar, F4 ] };\
        key <AE05>               {	[               5,         percent, F5 ] };\
        key <AE06>               {	[               6,     asciicircum, F6 ] };\
        key <AE07>               {	[               7,       ampersand, F7 ] };\
        key <AE08>               {	[               8,        asterisk, F8 ] };\
        key <AE09>               {	[               9,       parenleft, F9 ] };\
        key <AE10>               {	[               0,      parenright, F10 ] };\
        key <AE11>               {	[           minus,      underscore, EuroSign ] };\
        key <AE12>               {	[           equal,            plus, sterling ] };\
        key <BKSP>               {	[       BackSpace,       BackSpace ] };\
        key <TAB>                {	[             Tab,    ISO_Left_Tab ] };\
        key <AD01>               {	[               q,               Q, 1 ] };\
        key <AD02>               {	[               w,               W, 2 ] };\
        key <AD03>               {	[               e,               E, 3 ] };\
        key <AD04>               {	[               r,               R, 4 ] };\
        key <AD05>               {	[               t,               T, 5 ] };\
        key <AD06>               {	[               y,               Y, 6 ] };\
        key <AD07>               {	[               u,               U, 7 ] };\
        key <AD08>               {	[               i,               I, 8 ] };\
        key <AD09>               {	[               o,               O, 9 ] };\
        key <AD10>               {	[               p,               P, 0 ] };\
        key <AD11>               {	[               aring,           Aring ] };\
        key <AD12>               {	[    bracketright,      braceright ] };\
        key <RTRN>               {	[          Return ] };\
        key <LCTL>               {	[       Control_L ] };\
        key <AC01>               {	[               a,               A, minus ] };\
        key <AC02>               {	[               s,               S, at ] };\
        key <AC03>               {	[               d,               D, asterisk ] };\
        key <AC04>               {	[               f,               F, asciicircum ] };\
        key <AC05>               {	[               g,               G, colon ] };\
        key <AC06>               {	[               h,               H, semicolon ] };\
        key <AC07>               {	[               j,               J, parenleft ] };\
        key <AC08>               {	[               k,               K, parenright ] };\
        key <AC09>               {	[               l,               L, asciitilde ] };\
        key <AC10>               {	[                  ae,              AE ] };\
        key <AC11>               {	[              oslash,        Ooblique ] };\
        key <TLDE>               {	[           grave,      asciitilde ] };\
        key <LFSH>               {	[         Shift_L ] };\
        key <BKSL>               {	[       backslash,             bar ] };\
        key <AB01>               {	[               z,               Z, slash ] };\
        key <AB02>               {	[               x,               X, apostrophe ] };\
        key <AB03>               {	[               c,               C, quotedbl ] };\
        key <AB04>               {	[               v,               V, plus ] };\
        key <AB05>               {	[               b,               B, equal ] };\
        key <AB06>               {	[               n,               N, question ] };\
        key <AB07>               {	[               m,               M, exclam ] };\
        key <AB08>               {	[           comma,            less, backslash] };\
        key <AB09>               {	[          period,         greater, bar ] };\
        key <AB10>               {	[           slash,        question ] };\
        key <I147>               {  [      exclamdown,   questiondown, exclamdown ] };\
        key <RTSH>               {	[         Shift_R ] };\
        key <KPMU>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [     KP_Multiply,     KP_Multiply,     KP_Multiply,     KP_Multiply,   XF86ClearGrab ]\
        };\
        key <LALT>               {	[           Alt_L,          Meta_L ] };\
        key <SPCE>               {	[           space ] };\
        key <CAPS>               {	[       Caps_Lock ] };\
        key <FK01>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [              F1,              F1,              F1,              F1, XF86Switch_VT_1 ]\
        };\
        key <FK02>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [              F2,              F2,              F2,              F2, XF86Switch_VT_2 ]\
        };\
        key <FK03>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [              F3,              F3,              F3,              F3, XF86Switch_VT_3 ]\
        };\
        key <FK04>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [              F4,              F4,              F4,              F4, XF86Switch_VT_4 ]\
        };\
        key <FK05>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [              F5,              F5,              F5,              F5, XF86Switch_VT_5 ]\
        };\
        key <FK06>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [              F6,              F6,              F6,              F6, XF86Switch_VT_6 ]\
        };\
        key <FK07>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [              F7,              F7,              F7,              F7, XF86Switch_VT_7 ]\
        };\
        key <FK08>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [              F8,              F8,              F8,              F8, XF86Switch_VT_8 ]\
        };\
        key <FK09>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [              F9,              F9,              F9,              F9, XF86Switch_VT_9 ]\
        };\
        key <FK10>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [             F10,             F10,             F10,             F10, XF86Switch_VT_10 ]\
        };\
        key <NMLK>               {	[        Num_Lock ] };\
        key <SCLK>               {	[     Scroll_Lock ] };\
        key <KP7>                {	[         KP_Home,            KP_7 ] };\
        key <KP8>                {	[           KP_Up,            KP_8 ] };\
        key <KP9>                {	[        KP_Prior,            KP_9 ] };\
        key <KPSU>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [     KP_Subtract,     KP_Subtract,     KP_Subtract,     KP_Subtract,  XF86Prev_VMode ]\
        };\
        key <KP4>                {	[         KP_Left,            KP_4 ] };\
        key <KP5>                {	[        KP_Begin,            KP_5 ] };\
        key <KP6>                {	[        KP_Right,            KP_6 ] };\
        key <KPAD>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [          KP_Add,          KP_Add,          KP_Add,          KP_Add,  XF86Next_VMode ]\
        };\
        key <KP1>                {	[          KP_End,            KP_1 ] };\
        key <KP2>                {	[         KP_Down,            KP_2 ] };\
        key <KP3>                {	[         KP_Next,            KP_3 ] };\
        key <KP0>                {	[       KP_Insert,            KP_0 ] };\
        key <KPDL>               {	[       KP_Delete,      KP_Decimal ] };\
        key <LVL3>               {	[ ISO_Level3_Shift ] };\
        key <LSGT>               {	[            less,         greater,             bar,       brokenbar ] };\
        key <FK11>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [             F11,             F11,             F11,             F11, XF86Switch_VT_11 ]\
        };\
        key <FK12>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [             F12,             F12,             F12,             F12, XF86Switch_VT_12 ]\
        };\
        key <KATA>               {	[        Katakana ] };\
        key <HIRA>               {	[        Hiragana ] };\
        key <HENK>               {	[     Henkan_Mode ] };\
        key <HKTG>               {	[ Hiragana_Katakana ] };\
        key <MUHE>               {	[        Muhenkan ] };\
        key <KPEN>               {	[        KP_Enter ] };\
        key <RCTL>               {	[       Control_R ] };\
        key <KPDV>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [       KP_Divide,       KP_Divide,       KP_Divide,       KP_Divide,      XF86Ungrab ]\
        };\
        key <PRSC>               {\
                type= \"PC_ALT_LEVEL2\",\
                symbols[Group1]= [           Print,         Sys_Req ]\
        };\
        key <RALT>               {\
                type= \"TWO_LEVEL\",\
                symbols[Group1]= [           Alt_R,          Meta_R ]\
        };\
        key <LNFD>               {	[        Linefeed ] };\
        key <HOME>               {	[            Home ] };\
        key <UP>                 {	[              Up ] };\
        key <PGUP>               {	[           Prior ] };\
        key <LEFT>               {	[            Left ] };\
        key <RGHT>               {	[           Right ] };\
        key <END>                {	[             End ] };\
        key <DOWN>               {	[            Down ] };\
        key <PGDN>               {	[            Next ] };\
        key <INS>                {	[          Insert ] };\
        key <DELE>               {	[          Delete ] };\
        key <MUTE>               {	[   XF86AudioMute ] };\
        key <VOL->               {	[ XF86AudioLowerVolume ] };\
        key <VOL+>               {	[ XF86AudioRaiseVolume ] };\
        key <POWR>               {	[    XF86PowerOff ] };\
        key <KPEQ>               {	[        KP_Equal ] };\
        key <I126>               {	[       plusminus ] };\
        key <PAUS>               {\
                type= \"PC_CONTROL_LEVEL2\",\
                symbols[Group1]= [           Pause,           Break ]\
        };\
        key <I128>               {	[     XF86LaunchA ] };\
        key <I129>               {	[      KP_Decimal,      KP_Decimal ] };\
        key <HNGL>               {	[          Hangul ] };\
        key <HJCV>               {	[    Hangul_Hanja ] };\
        key <LWIN>               {	[         Super_L ] };\
        key <RWIN>               {	[         Super_R ] };\
        key <COMP>               {	[       U%08X, U%08X ] };\
        key <STOP>               {	[          Cancel ] };\
        key <AGAI>               {	[            Redo ] };\
        key <PROP>               {	[        SunProps ] };\
        key <UNDO>               {	[            Undo ] };\
        key <FRNT>               {	[        SunFront ] };\
        key <COPY>               {	[        XF86Copy ] };\
        key <OPEN>               {	[        XF86Open ] };\
        key <PAST>               {	[       XF86Paste ] };\
        key <FIND>               {	[            Find ] };\
        key <CUT>                {	[         XF86Cut ] };\
        key <HELP>               {	[            Help ] };\
        key <I147>               {	[      XF86MenuKB ] };\
        key <I148>               {	[  XF86Calculator ] };\
        key <I150>               {	[       XF86Sleep ] };\
        key <I151>               {	[      XF86WakeUp ] };\
        key <I152>               {	[    XF86Explorer ] };\
        key <I153>               {	[        XF86Send ] };\
        key <I155>               {	[        XF86Xfer ] };\
        key <I156>               {	[     XF86Launch1 ] };\
        key <I157>               {	[     XF86Launch2 ] };\
        key <I158>               {	[         XF86WWW ] };\
        key <I159>               {	[         XF86DOS ] };\
        key <I160>               {	[ XF86ScreenSaver ] };\
        key <I161>               {	[ XF86RotateWindows ] };\
        key <I162>               {	[    XF86TaskPane ] };\
        key <I163>               {	[        XF86Mail ] };\
        key <I164>               {	[   XF86Favorites ] };\
        key <I165>               {	[  XF86MyComputer ] };\
        key <I166>               {	[        XF86Back ] };\
        key <I167>               {	[     XF86Forward ] };\
        key <I169>               {	[       XF86Eject ] };\
        key <I170>               {	[       XF86Eject,       XF86Eject ] };\
        key <I171>               {	[   XF86AudioNext ] };\
        key <I172>               {	[   XF86AudioPlay,  XF86AudioPause ] };\
        key <I173>               {	[   XF86AudioPrev ] };\
        key <I174>               {	[   XF86AudioStop,       XF86Eject ] };\
        key <I175>               {	[ XF86AudioRecord ] };\
        key <I176>               {	[ XF86AudioRewind ] };\
        key <I177>               {	[       XF86Phone ] };\
        key <I179>               {	[       XF86Tools ] };\
        key <I180>               {	[    XF86HomePage ] };\
        key <I181>               {	[      XF86Reload ] };\
        key <I182>               {	[       XF86Close ] };\
        key <I185>               {	[    XF86ScrollUp ] };\
        key <I186>               {	[  XF86ScrollDown ] };\
        key <I187>               {	[       parenleft ] };\
        key <I188>               {	[      parenright ] };\
        key <I189>               {	[         XF86New ] };\
        key <I190>               {	[            Redo ] };\
        key <FK13>               {	[       XF86Tools ] };\
        key <FK14>               {	[     XF86Launch5 ] };\
        key <FK15>               {	[     XF86Launch6 ] };\
        key <FK16>               {	[     XF86Launch7 ] };\
        key <FK17>               {	[     XF86Launch8 ] };\
        key <FK18>               {	[     XF86Launch9 ] };\
        key <FK20>               {	[ XF86AudioMicMute ] };\
        key <FK21>               {	[ XF86TouchpadToggle ] };\
        key <FK22>               {	[  XF86TouchpadOn ] };\
        key <FK23>               {	[ XF86TouchpadOff ] };\
        key <MDSW>               {	[     Mode_switch ] };\
        key <ALT>                {	[        NoSymbol,           Alt_L ] };\
        key <META>               {	[        NoSymbol,          Meta_L ] };\
        key <SUPR>               {	[        NoSymbol,         Super_L ] };\
        key <HYPR>               {	[        NoSymbol,         Hyper_L ] };\
        key <I208>               {	[   XF86AudioPlay ] };\
        key <I209>               {	[  XF86AudioPause ] };\
        key <I210>               {	[     XF86Launch3 ] };\
        key <I211>               {	[     XF86Launch4 ] };\
        key <I212>               {	[     XF86LaunchB ] };\
        key <I213>               {	[     XF86Suspend ] };\
        key <I214>               {	[       XF86Close ] };\
        key <I215>               {	[   XF86AudioPlay ] };\
        key <I216>               {	[ XF86AudioForward ] };\
        key <I218>               {	[           Print ] };\
        key <I220>               {	[      XF86WebCam ] };\
        key <I221>               {	[ XF86AudioPreset ] };\
        key <I223>               {	[        XF86Mail ] };\
        key <I224>               {	[   XF86Messenger ] };\
        key <I225>               {	[      XF86Search ] };\
        key <I226>               {	[          XF86Go ] };\
        key <I227>               {	[     XF86Finance ] };\
        key <I228>               {	[        XF86Game ] };\
        key <I229>               {	[        XF86Shop ] };\
        key <I231>               {	[          Cancel ] };\
        key <I232>               {	[ XF86MonBrightnessDown ] };\
        key <I233>               {	[ XF86MonBrightnessUp ] };\
        key <I234>               {	[  XF86AudioMedia ] };\
        key <I235>               {	[     XF86Display ] };\
        key <I236>               {	[ XF86KbdLightOnOff ] };\
        key <I237>               {	[ XF86KbdBrightnessDown ] };\
        key <I238>               {	[ XF86KbdBrightnessUp ] };\
        key <I239>               {	[        XF86Send ] };\
        key <I240>               {	[       XF86Reply ] };\
        key <I241>               {	[ XF86MailForward ] };\
        key <I242>               {	[        XF86Save ] };\
        key <I243>               {	[   XF86Documents ] };\
        key <I244>               {	[     XF86Battery ] };\
        key <I245>               {	[   XF86Bluetooth ] };\
        key <I246>               {	[        XF86WLAN ] };\
        key <I247>               {	[         XF86UWB ] };\
        key <I254>               {	[        XF86WWAN ] };\
        key <I255>               {	[      XF86RFKill ] };\
        modifier_map Shift { <LFSH>, <RTSH> };\
        modifier_map Lock { <CAPS> };\
        modifier_map Control { <LCTL>, <RCTL> };\
        modifier_map Mod1 { <LALT>, <RALT>, <META> };\
        modifier_map Mod2 { <NMLK> };\
        modifier_map Mod4 { <LWIN>, <RWIN>, <SUPR>, <HYPR> };\
        modifier_map Mod5 { <LVL3>, <MDSW> };\
};\
\
};\
",  // CYRILLIC
"xkb_keymap {\
xkb_keycodes \"(unnamed)\" {\
        minimum = 8;\
        maximum = 255;\
        <ESC>                = 9;\
        <AE01>               = 10;\
        <AE02>               = 11;\
        <AE03>               = 12;\
        <AE04>               = 13;\
        <AE05>               = 14;\
        <AE06>               = 15;\
        <AE07>               = 16;\
        <AE08>               = 17;\
        <AE09>               = 18;\
        <AE10>               = 19;\
        <AE11>               = 20;\
        <AE12>               = 21;\
        <BKSP>               = 22;\
        <TAB>                = 23;\
        <AD01>               = 24;\
        <AD02>               = 25;\
        <AD03>               = 26;\
        <AD04>               = 27;\
        <AD05>               = 28;\
        <AD06>               = 29;\
        <AD07>               = 30;\
        <AD08>               = 31;\
        <AD09>               = 32;\
        <AD10>               = 33;\
        <AD11>               = 34;\
        <AD12>               = 35;\
        <RTRN>               = 36;\
        <LCTL>               = 37;\
        <AC01>               = 38;\
        <AC02>               = 39;\
        <AC03>               = 40;\
        <AC04>               = 41;\
        <AC05>               = 42;\
        <AC06>               = 43;\
        <AC07>               = 44;\
        <AC08>               = 45;\
        <AC09>               = 46;\
        <AC10>               = 47;\
        <AC11>               = 48;\
        <TLDE>               = 49;\
        <LFSH>               = 50;\
        <BKSL>               = 51;\
        <AB01>               = 52;\
        <AB02>               = 53;\
        <AB03>               = 54;\
        <AB04>               = 55;\
        <AB05>               = 56;\
        <AB06>               = 57;\
        <AB07>               = 58;\
        <AB08>               = 59;\
        <AB09>               = 60;\
        <AB10>               = 61;\
        <RTSH>               = 62;\
        <KPMU>               = 63;\
        <LALT>               = 64;\
        <SPCE>               = 65;\
        <CAPS>               = 66;\
        <FK01>               = 67;\
        <FK02>               = 68;\
        <FK03>               = 69;\
        <FK04>               = 70;\
        <FK05>               = 71;\
        <FK06>               = 72;\
        <FK07>               = 73;\
        <FK08>               = 74;\
        <FK09>               = 75;\
        <FK10>               = 76;\
        <NMLK>               = 77;\
        <SCLK>               = 78;\
        <KP7>                = 79;\
        <KP8>                = 80;\
        <KP9>                = 81;\
        <KPSU>               = 82;\
        <KP4>                = 83;\
        <KP5>                = 84;\
        <KP6>                = 85;\
        <KPAD>               = 86;\
        <KP1>                = 87;\
        <KP2>                = 88;\
        <KP3>                = 89;\
        <KP0>                = 90;\
        <KPDL>               = 91;\
        <LVL3>               = 92;\
        <LSGT>               = 94;\
        <FK11>               = 95;\
        <FK12>               = 96;\
        <AB11>               = 97;\
        <KATA>               = 98;\
        <HIRA>               = 99;\
        <HENK>               = 100;\
        <HKTG>               = 101;\
        <MUHE>               = 102;\
        <JPCM>               = 103;\
        <KPEN>               = 104;\
        <RCTL>               = 105;\
        <KPDV>               = 106;\
        <PRSC>               = 107;\
        <RALT>               = 108;\
        <LNFD>               = 109;\
        <HOME>               = 110;\
        <UP>                 = 111;\
        <PGUP>               = 112;\
        <LEFT>               = 113;\
        <RGHT>               = 114;\
        <END>                = 115;\
        <DOWN>               = 116;\
        <PGDN>               = 117;\
        <INS>                = 118;\
        <DELE>               = 119;\
        <I120>               = 120;\
        <MUTE>               = 121;\
        <VOL->               = 122;\
        <VOL+>               = 123;\
        <POWR>               = 124;\
        <KPEQ>               = 125;\
        <I126>               = 126;\
        <PAUS>               = 127;\
        <I128>               = 128;\
        <I129>               = 129;\
        <HNGL>               = 130;\
        <HJCV>               = 131;\
        <AE13>               = 132;\
        <LWIN>               = 133;\
        <RWIN>               = 134;\
        <COMP>               = 135;\
        <STOP>               = 136;\
        <AGAI>               = 137;\
        <PROP>               = 138;\
        <UNDO>               = 139;\
        <FRNT>               = 140;\
        <COPY>               = 141;\
        <OPEN>               = 142;\
        <PAST>               = 143;\
        <FIND>               = 144;\
        <CUT>                = 145;\
        <HELP>               = 146;\
        <I147>               = 147;\
        <I148>               = 148;\
        <I149>               = 149;\
        <I150>               = 150;\
        <I151>               = 151;\
        <I152>               = 152;\
        <I153>               = 153;\
        <I154>               = 154;\
        <I155>               = 155;\
        <I156>               = 156;\
        <I157>               = 157;\
        <I158>               = 158;\
        <I159>               = 159;\
        <I160>               = 160;\
        <I161>               = 161;\
        <I162>               = 162;\
        <I163>               = 163;\
        <I164>               = 164;\
        <I165>               = 165;\
        <I166>               = 166;\
        <I167>               = 167;\
        <I168>               = 168;\
        <I169>               = 169;\
        <I170>               = 170;\
        <I171>               = 171;\
        <I172>               = 172;\
        <I173>               = 173;\
        <I174>               = 174;\
        <I175>               = 175;\
        <I176>               = 176;\
        <I177>               = 177;\
        <I178>               = 178;\
        <I179>               = 179;\
        <I180>               = 180;\
        <I181>               = 181;\
        <I182>               = 182;\
        <I183>               = 183;\
        <I184>               = 184;\
        <I185>               = 185;\
        <I186>               = 186;\
        <I187>               = 187;\
        <I188>               = 188;\
        <I189>               = 189;\
        <I190>               = 190;\
        <FK13>               = 191;\
        <FK14>               = 192;\
        <FK15>               = 193;\
        <FK16>               = 194;\
        <FK17>               = 195;\
        <FK18>               = 196;\
        <FK19>               = 197;\
        <FK20>               = 198;\
        <FK21>               = 199;\
        <FK22>               = 200;\
        <FK23>               = 201;\
        <FK24>               = 202;\
        <MDSW>               = 203;\
        <ALT>                = 204;\
        <META>               = 205;\
        <SUPR>               = 206;\
        <HYPR>               = 207;\
        <I208>               = 208;\
        <I209>               = 209;\
        <I210>               = 210;\
        <I211>               = 211;\
        <I212>               = 212;\
        <I213>               = 213;\
        <I214>               = 214;\
        <I215>               = 215;\
        <I216>               = 216;\
        <I217>               = 217;\
        <I218>               = 218;\
        <I219>               = 219;\
        <I220>               = 220;\
        <I221>               = 221;\
        <I222>               = 222;\
        <I223>               = 223;\
        <I224>               = 224;\
        <I225>               = 225;\
        <I226>               = 226;\
        <I227>               = 227;\
        <I228>               = 228;\
        <I229>               = 229;\
        <I230>               = 230;\
        <I231>               = 231;\
        <I232>               = 232;\
        <I233>               = 233;\
        <I234>               = 234;\
        <I235>               = 235;\
        <I236>               = 236;\
        <I237>               = 237;\
        <I238>               = 238;\
        <I239>               = 239;\
        <I240>               = 240;\
        <I241>               = 241;\
        <I242>               = 242;\
        <I243>               = 243;\
        <I244>               = 244;\
        <I245>               = 245;\
        <I246>               = 246;\
        <I247>               = 247;\
        <I248>               = 248;\
        <I249>               = 249;\
        <I250>               = 250;\
        <I251>               = 251;\
        <I252>               = 252;\
        <I253>               = 253;\
        <I254>               = 254;\
        <I255>               = 255;\
        indicator 1 = \"Caps Lock\";\
        indicator 2 = \"Num Lock\";\
        indicator 3 = \"Scroll Lock\";\
        indicator 4 = \"Compose\";\
        indicator 5 = \"Kana\";\
        indicator 6 = \"Sleep\";\
        indicator 7 = \"Suspend\";\
        indicator 8 = \"Mute\";\
        indicator 9 = \"Misc\";\
        indicator 10 = \"Mail\";\
        indicator 11 = \"Charging\";\
        indicator 12 = \"Shift Lock\";\
        indicator 13 = \"Group 2\";\
        indicator 14 = \"Mouse Keys\";\
        alias <AC12>         = <BKSL>;\
        alias <MENU>         = <COMP>;\
        alias <HZTG>         = <TLDE>;\
        alias <LMTA>         = <LWIN>;\
        alias <RMTA>         = <RWIN>;\
        alias <ALGR>         = <RALT>;\
        alias <KPPT>         = <I129>;\
        alias <LatQ>         = <AD01>;\
        alias <LatW>         = <AD02>;\
        alias <LatE>         = <AD03>;\
        alias <LatR>         = <AD04>;\
        alias <LatT>         = <AD05>;\
        alias <LatY>         = <AD06>;\
        alias <LatU>         = <AD07>;\
        alias <LatI>         = <AD08>;\
        alias <LatO>         = <AD09>;\
        alias <LatP>         = <AD10>;\
        alias <LatA>         = <AC01>;\
        alias <LatS>         = <AC02>;\
        alias <LatD>         = <AC03>;\
        alias <LatF>         = <AC04>;\
        alias <LatG>         = <AC05>;\
        alias <LatH>         = <AC06>;\
        alias <LatJ>         = <AC07>;\
        alias <LatK>         = <AC08>;\
        alias <LatL>         = <AC09>;\
        alias <LatZ>         = <AB01>;\
        alias <LatX>         = <AB02>;\
        alias <LatC>         = <AB03>;\
        alias <LatV>         = <AB04>;\
        alias <LatB>         = <AB05>;\
        alias <LatN>         = <AB06>;\
        alias <LatM>         = <AB07>;\
};\
\
xkb_types \"(unnamed)\" {\
        virtual_modifiers NumLock,Alt,LevelThree,LAlt,RAlt,RControl,LControl,ScrollLock,LevelFive,AltGr,Meta,Super,Hyper;\
\
        type \"ONE_LEVEL\" {\
                modifiers= none;\
                level_name[Level1]= \"Any\";\
        };\
        type \"TWO_LEVEL\" {\
                modifiers= Shift;\
                map[Shift]= Level2;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
        };\
        type \"ALPHABETIC\" {\
                modifiers= Shift+Lock;\
                map[Shift]= Level2;\
                map[Lock]= Level2;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Caps\";\
        };\
        type \"SHIFT+ALT\" {\
                modifiers= Shift+Alt;\
                map[Shift+Alt]= Level2;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift+Alt\";\
        };\
        type \"PC_SUPER_LEVEL2\" {\
                modifiers= Mod4;\
                map[Mod4]= Level2;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Super\";\
        };\
        type \"PC_CONTROL_LEVEL2\" {\
                modifiers= Control;\
                map[Control]= Level2;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Control\";\
        };\
        type \"PC_LCONTROL_LEVEL2\" {\
                modifiers= LControl;\
                map[LControl]= Level2;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"LControl\";\
        };\
        type \"PC_RCONTROL_LEVEL2\" {\
                modifiers= RControl;\
                map[RControl]= Level2;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"RControl\";\
        };\
        type \"PC_ALT_LEVEL2\" {\
                modifiers= Alt;\
                map[Alt]= Level2;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Alt\";\
        };\
        type \"PC_LALT_LEVEL2\" {\
                modifiers= LAlt;\
                map[LAlt]= Level2;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"LAlt\";\
        };\
        type \"PC_RALT_LEVEL2\" {\
                modifiers= RAlt;\
                map[RAlt]= Level2;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"RAlt\";\
        };\
        type \"CTRL+ALT\" {\
                modifiers= Shift+Control+Alt+LevelThree;\
                map[Shift]= Level2;\
                preserve[Shift]= Shift;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                preserve[Shift+LevelThree]= Shift;\
                map[Control+Alt]= Level5;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Shift Alt\";\
                level_name[Level5]= \"Ctrl+Alt\";\
        };\
        type \"LOCAL_EIGHT_LEVEL\" {\
                modifiers= Shift+Lock+Control+LevelThree;\
                map[Shift]= Level2;\
                map[Lock]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+Lock+LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[Lock+LevelThree]= Level4;\
                map[Control]= Level5;\
                map[Shift+Lock+Control]= Level5;\
                map[Shift+Control]= Level6;\
                map[Lock+Control]= Level6;\
                map[Control+LevelThree]= Level7;\
                map[Shift+Lock+Control+LevelThree]= Level7;\
                map[Shift+Control+LevelThree]= Level8;\
                map[Lock+Control+LevelThree]= Level8;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Level3\";\
                level_name[Level4]= \"Shift Level3\";\
                level_name[Level5]= \"Ctrl\";\
                level_name[Level6]= \"Shift Ctrl\";\
                level_name[Level7]= \"Level3 Ctrl\";\
                level_name[Level8]= \"Shift Level3 Ctrl\";\
        };\
        type \"THREE_LEVEL\" {\
                modifiers= Shift+LevelThree;\
                map[Shift]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level3;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Level3\";\
        };\
        type \"EIGHT_LEVEL\" {\
                modifiers= Shift+LevelThree+LevelFive;\
                map[Shift]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[LevelFive]= Level5;\
                map[Shift+LevelFive]= Level6;\
                map[LevelThree+LevelFive]= Level7;\
                map[Shift+LevelThree+LevelFive]= Level8;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Shift Alt\";\
                level_name[Level5]= \"X\";\
                level_name[Level6]= \"X Shift\";\
                level_name[Level7]= \"X Alt Base\";\
                level_name[Level8]= \"X Shift Alt\";\
        };\
        type \"EIGHT_LEVEL_ALPHABETIC\" {\
                modifiers= Shift+Lock+LevelThree+LevelFive;\
                map[Shift]= Level2;\
                map[Lock]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[Lock+LevelThree]= Level4;\
                map[Shift+Lock+LevelThree]= Level3;\
                map[LevelFive]= Level5;\
                map[Shift+LevelFive]= Level6;\
                map[Lock+LevelFive]= Level6;\
                map[LevelThree+LevelFive]= Level7;\
                map[Shift+LevelThree+LevelFive]= Level8;\
                map[Lock+LevelThree+LevelFive]= Level8;\
                map[Shift+Lock+LevelThree+LevelFive]= Level7;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Shift Alt\";\
                level_name[Level5]= \"X\";\
                level_name[Level6]= \"X Shift\";\
                level_name[Level7]= \"X Alt Base\";\
                level_name[Level8]= \"X Shift Alt\";\
        };\
        type \"EIGHT_LEVEL_LEVEL_FIVE_LOCK\" {\
                modifiers= Shift+Lock+NumLock+LevelThree+LevelFive;\
                map[Shift]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[LevelFive]= Level5;\
                map[Shift+LevelFive]= Level6;\
                preserve[Shift+LevelFive]= Shift;\
                map[LevelThree+LevelFive]= Level7;\
                map[Shift+LevelThree+LevelFive]= Level8;\
                map[NumLock]= Level5;\
                map[Shift+NumLock]= Level6;\
                preserve[Shift+NumLock]= Shift;\
                map[NumLock+LevelThree]= Level7;\
                map[Shift+NumLock+LevelThree]= Level8;\
                map[Shift+NumLock+LevelFive]= Level2;\
                map[NumLock+LevelThree+LevelFive]= Level3;\
                map[Shift+NumLock+LevelThree+LevelFive]= Level4;\
                map[Shift+Lock]= Level2;\
                map[Lock+LevelThree]= Level3;\
                map[Shift+Lock+LevelThree]= Level4;\
                map[Lock+LevelFive]= Level5;\
                map[Shift+Lock+LevelFive]= Level6;\
                preserve[Shift+Lock+LevelFive]= Shift;\
                map[Lock+LevelThree+LevelFive]= Level7;\
                map[Shift+Lock+LevelThree+LevelFive]= Level8;\
                map[Lock+NumLock]= Level5;\
                map[Shift+Lock+NumLock]= Level6;\
                preserve[Shift+Lock+NumLock]= Shift;\
                map[Lock+NumLock+LevelThree]= Level7;\
                map[Shift+Lock+NumLock+LevelThree]= Level8;\
                map[Shift+Lock+NumLock+LevelFive]= Level2;\
                map[Lock+NumLock+LevelThree+LevelFive]= Level3;\
                map[Shift+Lock+NumLock+LevelThree+LevelFive]= Level4;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Shift Alt\";\
                level_name[Level5]= \"X\";\
                level_name[Level6]= \"X Shift\";\
                level_name[Level7]= \"X Alt Base\";\
                level_name[Level8]= \"X Shift Alt\";\
        };\
        type \"EIGHT_LEVEL_ALPHABETIC_LEVEL_FIVE_LOCK\" {\
                modifiers= Shift+Lock+NumLock+LevelThree+LevelFive;\
                map[Shift]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[LevelFive]= Level5;\
                map[Shift+LevelFive]= Level6;\
                preserve[Shift+LevelFive]= Shift;\
                map[LevelThree+LevelFive]= Level7;\
                map[Shift+LevelThree+LevelFive]= Level8;\
                map[NumLock]= Level5;\
                map[Shift+NumLock]= Level6;\
                preserve[Shift+NumLock]= Shift;\
                map[NumLock+LevelThree]= Level7;\
                map[Shift+NumLock+LevelThree]= Level8;\
                map[Shift+NumLock+LevelFive]= Level2;\
                map[NumLock+LevelThree+LevelFive]= Level3;\
                map[Shift+NumLock+LevelThree+LevelFive]= Level4;\
                map[Lock]= Level2;\
                map[Lock+LevelThree]= Level3;\
                map[Shift+Lock+LevelThree]= Level4;\
                map[Lock+LevelFive]= Level5;\
                map[Shift+Lock+LevelFive]= Level6;\
                map[Lock+LevelThree+LevelFive]= Level7;\
                map[Shift+Lock+LevelThree+LevelFive]= Level8;\
                map[Lock+NumLock]= Level5;\
                map[Shift+Lock+NumLock]= Level6;\
                map[Lock+NumLock+LevelThree]= Level7;\
                map[Shift+Lock+NumLock+LevelThree]= Level8;\
                map[Lock+NumLock+LevelFive]= Level2;\
                map[Lock+NumLock+LevelThree+LevelFive]= Level4;\
                map[Shift+Lock+NumLock+LevelThree+LevelFive]= Level3;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Shift Alt\";\
                level_name[Level5]= \"X\";\
                level_name[Level6]= \"X Shift\";\
                level_name[Level7]= \"X Alt Base\";\
                level_name[Level8]= \"X Shift Alt\";\
        };\
        type \"EIGHT_LEVEL_SEMIALPHABETIC\" {\
                modifiers= Shift+Lock+LevelThree+LevelFive;\
                map[Shift]= Level2;\
                map[Lock]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[Lock+LevelThree]= Level3;\
                preserve[Lock+LevelThree]= Lock;\
                map[Shift+Lock+LevelThree]= Level4;\
                preserve[Shift+Lock+LevelThree]= Lock;\
                map[LevelFive]= Level5;\
                map[Shift+LevelFive]= Level6;\
                map[Lock+LevelFive]= Level6;\
                preserve[Lock+LevelFive]= Lock;\
                map[Shift+Lock+LevelFive]= Level6;\
                preserve[Shift+Lock+LevelFive]= Lock;\
                map[LevelThree+LevelFive]= Level7;\
                map[Shift+LevelThree+LevelFive]= Level8;\
                map[Lock+LevelThree+LevelFive]= Level7;\
                preserve[Lock+LevelThree+LevelFive]= Lock;\
                map[Shift+Lock+LevelThree+LevelFive]= Level8;\
                preserve[Shift+Lock+LevelThree+LevelFive]= Lock;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Shift Alt\";\
                level_name[Level5]= \"X\";\
                level_name[Level6]= \"X Shift\";\
                level_name[Level7]= \"X Alt Base\";\
                level_name[Level8]= \"X Shift Alt\";\
        };\
        type \"FOUR_LEVEL\" {\
                modifiers= Shift+LevelThree;\
                map[Shift]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Shift Alt\";\
        };\
        type \"FOUR_LEVEL_ALPHABETIC\" {\
                modifiers= Shift+Lock+LevelThree;\
                map[Shift]= Level2;\
                map[Lock]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[Lock+LevelThree]= Level4;\
                map[Shift+Lock+LevelThree]= Level3;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Shift Alt\";\
        };\
        type \"FOUR_LEVEL_SEMIALPHABETIC\" {\
                modifiers= Shift+Lock+LevelThree;\
                map[Shift]= Level2;\
                map[Lock]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[Lock+LevelThree]= Level3;\
                preserve[Lock+LevelThree]= Lock;\
                map[Shift+Lock+LevelThree]= Level4;\
                preserve[Shift+Lock+LevelThree]= Lock;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Shift Alt\";\
        };\
        type \"FOUR_LEVEL_MIXED_KEYPAD\" {\
                modifiers= Shift+NumLock+LevelThree;\
                map[NumLock]= Level2;\
                map[Shift]= Level2;\
                map[LevelThree]= Level3;\
                map[NumLock+LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[Shift+NumLock+LevelThree]= Level4;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Number\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Shift Alt\";\
        };\
        type \"FOUR_LEVEL_X\" {\
                modifiers= Shift+Control+Alt+LevelThree;\
                map[LevelThree]= Level2;\
                map[Shift+LevelThree]= Level3;\
                map[Control+Alt]= Level4;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Alt Base\";\
                level_name[Level3]= \"Shift Alt\";\
                level_name[Level4]= \"Ctrl+Alt\";\
        };\
        type \"SEPARATE_CAPS_AND_SHIFT_ALPHABETIC\" {\
                modifiers= Shift+Lock+LevelThree;\
                map[Shift]= Level2;\
                map[Lock]= Level4;\
                preserve[Lock]= Lock;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[Lock+LevelThree]= Level3;\
                preserve[Lock+LevelThree]= Lock;\
                map[Shift+Lock+LevelThree]= Level3;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"AltGr Base\";\
                level_name[Level4]= \"Shift AltGr\";\
        };\
        type \"FOUR_LEVEL_PLUS_LOCK\" {\
                modifiers= Shift+Lock+LevelThree;\
                map[Shift]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[Lock]= Level5;\
                map[Shift+Lock]= Level2;\
                map[Lock+LevelThree]= Level3;\
                map[Shift+Lock+LevelThree]= Level4;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Shift\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Shift Alt\";\
                level_name[Level5]= \"Lock\";\
        };\
        type \"KEYPAD\" {\
                modifiers= Shift+NumLock;\
                map[Shift]= Level2;\
                map[NumLock]= Level2;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Number\";\
        };\
        type \"FOUR_LEVEL_KEYPAD\" {\
                modifiers= Shift+NumLock+LevelThree;\
                map[Shift]= Level2;\
                map[NumLock]= Level2;\
                map[LevelThree]= Level3;\
                map[Shift+LevelThree]= Level4;\
                map[NumLock+LevelThree]= Level4;\
                map[Shift+NumLock+LevelThree]= Level3;\
                level_name[Level1]= \"Base\";\
                level_name[Level2]= \"Number\";\
                level_name[Level3]= \"Alt Base\";\
                level_name[Level4]= \"Alt Number\";\
        };\
};\
\
xkb_compatibility \"(unnamed)\" {\
        virtual_modifiers NumLock,Alt,LevelThree,LAlt,RAlt,RControl,LControl,ScrollLock,LevelFive,AltGr,Meta,Super,Hyper;\
\
        interpret.useModMapMods= AnyLevel;\
        interpret.repeat= False;\
        interpret ISO_Level2_Latch+Exactly(Shift) {\
                useModMapMods=level1;\
                action= LatchMods(modifiers=Shift,clearLocks,latchToLock);\
        };\
        interpret Shift_Lock+AnyOf(Shift+Lock) {\
                action= LockMods(modifiers=Shift);\
        };\
        interpret Num_Lock+AnyOf(all) {\
                virtualModifier= NumLock;\
                action= LockMods(modifiers=NumLock);\
        };\
        interpret ISO_Level3_Shift+AnyOf(all) {\
                virtualModifier= LevelThree;\
                useModMapMods=level1;\
                action= SetMods(modifiers=LevelThree,clearLocks);\
        };\
        interpret ISO_Level3_Latch+AnyOf(all) {\
                virtualModifier= LevelThree;\
                useModMapMods=level1;\
                action= LatchMods(modifiers=LevelThree,clearLocks,latchToLock);\
        };\
        interpret ISO_Level3_Lock+AnyOf(all) {\
                virtualModifier= LevelThree;\
                useModMapMods=level1;\
                action= LockMods(modifiers=LevelThree);\
        };\
        interpret Alt_L+AnyOf(all) {\
                virtualModifier= Alt;\
                action= SetMods(modifiers=modMapMods,clearLocks);\
        };\
        interpret Alt_R+AnyOf(all) {\
                virtualModifier= Alt;\
                action= SetMods(modifiers=modMapMods,clearLocks);\
        };\
        interpret Meta_L+AnyOf(all) {\
                virtualModifier= Meta;\
                action= SetMods(modifiers=modMapMods,clearLocks);\
        };\
        interpret Meta_R+AnyOf(all) {\
                virtualModifier= Meta;\
                action= SetMods(modifiers=modMapMods,clearLocks);\
        };\
        interpret Super_L+AnyOf(all) {\
                virtualModifier= Super;\
                action= SetMods(modifiers=modMapMods,clearLocks);\
        };\
        interpret Super_R+AnyOf(all) {\
                virtualModifier= Super;\
                action= SetMods(modifiers=modMapMods,clearLocks);\
        };\
        interpret Hyper_L+AnyOf(all) {\
                virtualModifier= Hyper;\
                action= SetMods(modifiers=modMapMods,clearLocks);\
        };\
        interpret Hyper_R+AnyOf(all) {\
                virtualModifier= Hyper;\
                action= SetMods(modifiers=modMapMods,clearLocks);\
        };\
        interpret Scroll_Lock+AnyOf(all) {\
                virtualModifier= ScrollLock;\
                action= LockMods(modifiers=modMapMods);\
        };\
        interpret ISO_Level5_Shift+AnyOf(all) {\
                virtualModifier= LevelFive;\
                useModMapMods=level1;\
                action= SetMods(modifiers=LevelFive,clearLocks);\
        };\
        interpret ISO_Level5_Latch+AnyOf(all) {\
                virtualModifier= LevelFive;\
                useModMapMods=level1;\
                action= LatchMods(modifiers=LevelFive,clearLocks,latchToLock);\
        };\
        interpret ISO_Level5_Lock+AnyOf(all) {\
                virtualModifier= LevelFive;\
                useModMapMods=level1;\
                action= LockMods(modifiers=LevelFive);\
        };\
        interpret Mode_switch+AnyOfOrNone(all) {\
                virtualModifier= AltGr;\
                useModMapMods=level1;\
                action= SetGroup(group=+1);\
        };\
        interpret ISO_Level3_Shift+AnyOfOrNone(all) {\
                action= SetMods(modifiers=LevelThree,clearLocks);\
        };\
        interpret ISO_Level3_Latch+AnyOfOrNone(all) {\
                action= LatchMods(modifiers=LevelThree,clearLocks,latchToLock);\
        };\
        interpret ISO_Level3_Lock+AnyOfOrNone(all) {\
                action= LockMods(modifiers=LevelThree);\
        };\
        interpret ISO_Group_Latch+AnyOfOrNone(all) {\
                virtualModifier= AltGr;\
                useModMapMods=level1;\
                action= LatchGroup(group=2);\
        };\
        interpret ISO_Next_Group+AnyOfOrNone(all) {\
                virtualModifier= AltGr;\
                useModMapMods=level1;\
                action= LockGroup(group=+1);\
        };\
        interpret ISO_Prev_Group+AnyOfOrNone(all) {\
                virtualModifier= AltGr;\
                useModMapMods=level1;\
                action= LockGroup(group=-1);\
        };\
        interpret ISO_First_Group+AnyOfOrNone(all) {\
                action= LockGroup(group=1);\
        };\
        interpret ISO_Last_Group+AnyOfOrNone(all) {\
                action= LockGroup(group=2);\
        };\
        interpret KP_1+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=-1,y=+1);\
        };\
        interpret KP_End+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=-1,y=+1);\
        };\
        interpret KP_2+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+0,y=+1);\
        };\
        interpret KP_Down+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+0,y=+1);\
        };\
        interpret KP_3+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+1,y=+1);\
        };\
        interpret KP_Next+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+1,y=+1);\
        };\
        interpret KP_4+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=-1,y=+0);\
        };\
        interpret KP_Left+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=-1,y=+0);\
        };\
        interpret KP_6+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+1,y=+0);\
        };\
        interpret KP_Right+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+1,y=+0);\
        };\
        interpret KP_7+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=-1,y=-1);\
        };\
        interpret KP_Home+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=-1,y=-1);\
        };\
        interpret KP_8+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+0,y=-1);\
        };\
        interpret KP_Up+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+0,y=-1);\
        };\
        interpret KP_9+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+1,y=-1);\
        };\
        interpret KP_Prior+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+1,y=-1);\
        };\
        interpret KP_5+AnyOfOrNone(all) {\
                repeat= True;\
                action= PtrBtn(button=default);\
        };\
        interpret KP_Begin+AnyOfOrNone(all) {\
                repeat= True;\
                action= PtrBtn(button=default);\
        };\
        interpret KP_F2+AnyOfOrNone(all) {\
                repeat= True;\
                action= SetPtrDflt(affect=button,button=1);\
        };\
        interpret KP_Divide+AnyOfOrNone(all) {\
                repeat= True;\
                action= SetPtrDflt(affect=button,button=1);\
        };\
        interpret KP_F3+AnyOfOrNone(all) {\
                repeat= True;\
                action= SetPtrDflt(affect=button,button=2);\
        };\
        interpret KP_Multiply+AnyOfOrNone(all) {\
                repeat= True;\
                action= SetPtrDflt(affect=button,button=2);\
        };\
        interpret KP_F4+AnyOfOrNone(all) {\
                repeat= True;\
                action= SetPtrDflt(affect=button,button=3);\
        };\
        interpret KP_Subtract+AnyOfOrNone(all) {\
                repeat= True;\
                action= SetPtrDflt(affect=button,button=3);\
        };\
        interpret KP_Separator+AnyOfOrNone(all) {\
                repeat= True;\
                action= PtrBtn(button=default,count=2);\
        };\
        interpret KP_Add+AnyOfOrNone(all) {\
                repeat= True;\
                action= PtrBtn(button=default,count=2);\
        };\
        interpret KP_0+AnyOfOrNone(all) {\
                repeat= True;\
                action= LockPtrBtn(button=default,affect=lock);\
        };\
        interpret KP_Insert+AnyOfOrNone(all) {\
                repeat= True;\
                action= LockPtrBtn(button=default,affect=lock);\
        };\
        interpret KP_Decimal+AnyOfOrNone(all) {\
                repeat= True;\
                action= LockPtrBtn(button=default,affect=unlock);\
        };\
        interpret KP_Delete+AnyOfOrNone(all) {\
                repeat= True;\
                action= LockPtrBtn(button=default,affect=unlock);\
        };\
        interpret F25+AnyOfOrNone(all) {\
                repeat= True;\
                action= SetPtrDflt(affect=button,button=1);\
        };\
        interpret F26+AnyOfOrNone(all) {\
                repeat= True;\
                action= SetPtrDflt(affect=button,button=2);\
        };\
        interpret F27+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=-1,y=-1);\
        };\
        interpret F29+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+1,y=-1);\
        };\
        interpret F31+AnyOfOrNone(all) {\
                repeat= True;\
                action= PtrBtn(button=default);\
        };\
        interpret F33+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=-1,y=+1);\
        };\
        interpret F35+AnyOfOrNone(all) {\
                repeat= True;\
                action= MovePtr(x=+1,y=+1);\
        };\
        interpret Pointer_Button_Dflt+AnyOfOrNone(all) {\
                action= PtrBtn(button=default);\
        };\
        interpret Pointer_Button1+AnyOfOrNone(all) {\
                action= PtrBtn(button=1);\
        };\
        interpret Pointer_Button2+AnyOfOrNone(all) {\
                action= PtrBtn(button=2);\
        };\
        interpret Pointer_Button3+AnyOfOrNone(all) {\
                action= PtrBtn(button=3);\
        };\
        interpret Pointer_DblClick_Dflt+AnyOfOrNone(all) {\
                action= PtrBtn(button=default,count=2);\
        };\
        interpret Pointer_DblClick1+AnyOfOrNone(all) {\
                action= PtrBtn(button=1,count=2);\
        };\
        interpret Pointer_DblClick2+AnyOfOrNone(all) {\
                action= PtrBtn(button=2,count=2);\
        };\
        interpret Pointer_DblClick3+AnyOfOrNone(all) {\
                action= PtrBtn(button=3,count=2);\
        };\
        interpret Pointer_Drag_Dflt+AnyOfOrNone(all) {\
                action= LockPtrBtn(button=default);\
        };\
        interpret Pointer_Drag1+AnyOfOrNone(all) {\
                action= LockPtrBtn(button=1);\
        };\
        interpret Pointer_Drag2+AnyOfOrNone(all) {\
                action= LockPtrBtn(button=2);\
        };\
        interpret Pointer_Drag3+AnyOfOrNone(all) {\
                action= LockPtrBtn(button=3);\
        };\
        interpret Pointer_EnableKeys+AnyOfOrNone(all) {\
                action= LockControls(controls=MouseKeys);\
        };\
        interpret Pointer_Accelerate+AnyOfOrNone(all) {\
                action= LockControls(controls=MouseKeysAccel);\
        };\
        interpret Pointer_DfltBtnNext+AnyOfOrNone(all) {\
                action= SetPtrDflt(affect=button,button=+1);\
        };\
        interpret Pointer_DfltBtnPrev+AnyOfOrNone(all) {\
                action= SetPtrDflt(affect=button,button=-1);\
        };\
        interpret AccessX_Enable+AnyOfOrNone(all) {\
                action= LockControls(controls=AccessXKeys);\
        };\
        interpret AccessX_Feedback_Enable+AnyOfOrNone(all) {\
                action= LockControls(controls=AccessXFeedback);\
        };\
        interpret RepeatKeys_Enable+AnyOfOrNone(all) {\
                action= LockControls(controls=RepeatKeys);\
        };\
        interpret SlowKeys_Enable+AnyOfOrNone(all) {\
                action= LockControls(controls=SlowKeys);\
        };\
        interpret BounceKeys_Enable+AnyOfOrNone(all) {\
                action= LockControls(controls=BounceKeys);\
        };\
        interpret StickyKeys_Enable+AnyOfOrNone(all) {\
                action= LockControls(controls=StickyKeys);\
        };\
        interpret MouseKeys_Enable+AnyOfOrNone(all) {\
                action= LockControls(controls=MouseKeys);\
        };\
        interpret MouseKeys_Accel_Enable+AnyOfOrNone(all) {\
                action= LockControls(controls=MouseKeysAccel);\
        };\
        interpret Overlay1_Enable+AnyOfOrNone(all) {\
                action= LockControls(controls=none);\
        };\
        interpret Overlay2_Enable+AnyOfOrNone(all) {\
                action= LockControls(controls=none);\
        };\
        interpret AudibleBell_Enable+AnyOfOrNone(all) {\
                action= LockControls(controls=AudibleBell);\
        };\
        interpret Terminate_Server+AnyOfOrNone(all) {\
                action= Terminate();\
        };\
        interpret Alt_L+AnyOfOrNone(all) {\
                action= SetMods(modifiers=Alt,clearLocks);\
        };\
        interpret Alt_R+AnyOfOrNone(all) {\
                action= SetMods(modifiers=Alt,clearLocks);\
        };\
        interpret Meta_L+AnyOfOrNone(all) {\
                action= SetMods(modifiers=Meta,clearLocks);\
        };\
        interpret Meta_R+AnyOfOrNone(all) {\
                action= SetMods(modifiers=Meta,clearLocks);\
        };\
        interpret Super_L+AnyOfOrNone(all) {\
                action= SetMods(modifiers=Super,clearLocks);\
        };\
        interpret Super_R+AnyOfOrNone(all) {\
                action= SetMods(modifiers=Super,clearLocks);\
        };\
        interpret Hyper_L+AnyOfOrNone(all) {\
                action= SetMods(modifiers=Hyper,clearLocks);\
        };\
        interpret Hyper_R+AnyOfOrNone(all) {\
                action= SetMods(modifiers=Hyper,clearLocks);\
        };\
        interpret Shift_L+AnyOfOrNone(all) {\
                action= SetMods(modifiers=Shift,clearLocks);\
        };\
        interpret XF86Switch_VT_1+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=1,!same);\
        };\
        interpret XF86Switch_VT_2+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=2,!same);\
        };\
        interpret XF86Switch_VT_3+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=3,!same);\
        };\
        interpret XF86Switch_VT_4+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=4,!same);\
        };\
        interpret XF86Switch_VT_5+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=5,!same);\
        };\
        interpret XF86Switch_VT_6+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=6,!same);\
        };\
        interpret XF86Switch_VT_7+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=7,!same);\
        };\
        interpret XF86Switch_VT_8+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=8,!same);\
        };\
        interpret XF86Switch_VT_9+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=9,!same);\
        };\
        interpret XF86Switch_VT_10+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=10,!same);\
        };\
        interpret XF86Switch_VT_11+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=11,!same);\
        };\
        interpret XF86Switch_VT_12+AnyOfOrNone(all) {\
                repeat= True;\
                action= SwitchScreen(screen=12,!same);\
        };\
        interpret XF86LogGrabInfo+AnyOfOrNone(all) {\
                repeat= True;\
                action= Private(type=0x86,data[0]=0x50,data[1]=0x72,data[2]=0x47,data[3]=0x72,data[4]=0x62,data[5]=0x73,data[6]=0x00);\
        };\
        interpret XF86LogWindowTree+AnyOfOrNone(all) {\
                repeat= True;\
                action= Private(type=0x86,data[0]=0x50,data[1]=0x72,data[2]=0x57,data[3]=0x69,data[4]=0x6e,data[5]=0x73,data[6]=0x00);\
        };\
        interpret XF86Next_VMode+AnyOfOrNone(all) {\
                repeat= True;\
                action= Private(type=0x86,data[0]=0x2b,data[1]=0x56,data[2]=0x4d,data[3]=0x6f,data[4]=0x64,data[5]=0x65,data[6]=0x00);\
        };\
        interpret XF86Prev_VMode+AnyOfOrNone(all) {\
                repeat= True;\
                action= Private(type=0x86,data[0]=0x2d,data[1]=0x56,data[2]=0x4d,data[3]=0x6f,data[4]=0x64,data[5]=0x65,data[6]=0x00);\
        };\
        interpret ISO_Level5_Shift+AnyOfOrNone(all) {\
                action= SetMods(modifiers=LevelFive,clearLocks);\
        };\
        interpret ISO_Level5_Latch+AnyOfOrNone(all) {\
                action= LatchMods(modifiers=LevelFive,clearLocks,latchToLock);\
        };\
        interpret ISO_Level5_Lock+AnyOfOrNone(all) {\
                action= LockMods(modifiers=LevelFive);\
        };\
        interpret Caps_Lock+AnyOfOrNone(all) {\
                action= LockMods(modifiers=Lock);\
        };\
        interpret Any+Exactly(Lock) {\
                action= LockMods(modifiers=Lock);\
        };\
        interpret Any+AnyOf(all) {\
                action= SetMods(modifiers=modMapMods,clearLocks);\
        };\
        indicator \"Caps Lock\" {\
                whichModState= locked;\
                modifiers= Lock;\
        };\
        indicator \"Num Lock\" {\
                whichModState= locked;\
                modifiers= NumLock;\
        };\
        indicator \"Scroll Lock\" {\
                whichModState= locked;\
                modifiers= ScrollLock;\
        };\
        indicator \"Shift Lock\" {\
                whichModState= locked;\
                modifiers= Shift;\
        };\
        indicator \"Group 2\" {\
                groups= 0xfe;\
        };\
        indicator \"Mouse Keys\" {\
                controls= MouseKeys;\
        };\
};\
\
xkb_symbols \"(unnamed)\" {\
        name[group1]=\"wvkbd cyrillic\";\
\
        key <ESC>  { [          Escape ] };\
        key <AE01> { [               1,          exclam, exclam ] };\
        key <AE02> { [               2,        quotedbl, at ] };\
        key <AE03> { [               3,      numbersign, numbersign ] };\
        key <AE04> { [               4,       asterisk, dollar ] };\
        key <AE05> { [               5,         colon, percent ] };\
        key <AE06> { [               6,          comma, asciicircum ] };\
        key <AE07> { [               7,       period, ampersand ] };\
        key <AE08> { [               8,        semicolon, asterisk ] };\
        key <AE09> { [               9,       parenleft, bracketleft, braceleft ] };\
        key <AE10> { [               0,      parenright, bracketright, braceright ] };\
		key <AE11> { [       minus,  underscore, less  ] };\
		key <AE12> { [       equal,     plus , greater ] };\
        key <BKSP>               {	[       BackSpace,       BackSpace ] };\
        key <TAB>                {	[             Tab,    ISO_Left_Tab ] };\
		key <TLDE> { [       Cyrillic_io,       Cyrillic_IO  ] };\
		key <AD01> { [   Cyrillic_shorti,   Cyrillic_SHORTI  ] };\
		key <AD02> { [      Cyrillic_tse,      Cyrillic_TSE  ] };\
		key <AD03> { [        Cyrillic_u,        Cyrillic_U  ] };\
		key <AD04> { [       Cyrillic_ka,       Cyrillic_KA  ] };\
		key <AD05> { [       Cyrillic_ie,       Cyrillic_IE  ] };\
		key <AD06> { [       Cyrillic_en,       Cyrillic_EN  ] };\
		key <AD07> { [      Cyrillic_ghe,      Cyrillic_GHE  ] };\
		key <AD08> { [      Cyrillic_sha,      Cyrillic_SHA  ] };\
		key <AD09> { [    Cyrillic_shcha,    Cyrillic_SHCHA  ] };\
		key <AD10> { [       Cyrillic_ze,       Cyrillic_ZE  ] };\
		key <AD11> { [       Cyrillic_ha,       Cyrillic_HA  ] };\
		key <AD12> { [ Cyrillic_hardsign, Cyrillic_HARDSIGN  ] };\
        key <BKSL>               {	[       backslash,             bar ] };\
        key <RTRN>               {	[          Return ] };\
        key <LCTL>               {	[       Control_L ] };\
		key <AC01> { [       Cyrillic_ef,       Cyrillic_EF  ] };\
		key <AC02> { [     Cyrillic_yeru,     Cyrillic_YERU  ] };\
		key <AC03> { [       Cyrillic_ve,       Cyrillic_VE  ] };\
		key <AC04> { [        Cyrillic_a,        Cyrillic_A  ] };\
		key <AC05> { [       Cyrillic_pe,       Cyrillic_PE  ] };\
		key <AC06> { [       Cyrillic_er,       Cyrillic_ER  ] };\
		key <AC07> { [        Cyrillic_o,        Cyrillic_O  ] };\
		key <AC08> { [       Cyrillic_el,       Cyrillic_EL  ] };\
		key <AC09> { [       Cyrillic_de,       Cyrillic_DE  ] };\
		key <AC10> { [      Cyrillic_zhe,      Cyrillic_ZHE  ] };\
		key <AC11> { [        Cyrillic_e,        Cyrillic_E, apostrophe  ] };\
        key <LFSH>               {	[         Shift_L ] };\
		key <AB01> { [       Cyrillic_ya,       Cyrillic_YA  ] };\
		key <AB02> { [      Cyrillic_che,      Cyrillic_CHE  ] };\
		key <AB03> { [       Cyrillic_es,       Cyrillic_ES  ] };\
		key <AB04> { [       Cyrillic_em,       Cyrillic_EM  ] };\
		key <AB05> { [        Cyrillic_i,        Cyrillic_I  ] };\
		key <AB06> { [       Cyrillic_te,       Cyrillic_TE  ] };\
		key <AB07> { [ Cyrillic_softsign, Cyrillic_SOFTSIGN  ] };\
		key <AB08> { [       Cyrillic_be,       Cyrillic_BE, comma, less  ] };\
		key <AB09> { [       Cyrillic_yu,       Cyrillic_YU, period, greater ] };\
        key <AB10>               {	[           slash,        question, apostrophe ] };\
        key <I147>               {  [      exclamdown,   questiondown, exclamdown ] };\
        key <RTSH>               {	[         Shift_R ] };\
        key <KPMU>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [     KP_Multiply,     KP_Multiply,     KP_Multiply,     KP_Multiply,   XF86ClearGrab ]\
        };\
        key <LALT>               {	[           Alt_L,          Meta_L ] };\
        key <SPCE>               {	[           space ] };\
        key <CAPS>               {	[       Caps_Lock ] };\
        key <FK01>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [              F1,              F1,              F1,              F1, XF86Switch_VT_1 ]\
        };\
        key <FK02>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [              F2,              F2,              F2,              F2, XF86Switch_VT_2 ]\
        };\
        key <FK03>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [              F3,              F3,              F3,              F3, XF86Switch_VT_3 ]\
        };\
        key <FK04>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [              F4,              F4,              F4,              F4, XF86Switch_VT_4 ]\
        };\
        key <FK05>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [              F5,              F5,              F5,              F5, XF86Switch_VT_5 ]\
        };\
        key <FK06>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [              F6,              F6,              F6,              F6, XF86Switch_VT_6 ]\
        };\
        key <FK07>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [              F7,              F7,              F7,              F7, XF86Switch_VT_7 ]\
        };\
        key <FK08>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [              F8,              F8,              F8,              F8, XF86Switch_VT_8 ]\
        };\
        key <FK09>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [              F9,              F9,              F9,              F9, XF86Switch_VT_9 ]\
        };\
        key <FK10>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [             F10,             F10,             F10,             F10, XF86Switch_VT_10 ]\
        };\
        key <NMLK>               {	[        Num_Lock ] };\
        key <SCLK>               {	[     Scroll_Lock ] };\
        key <KP7>                {	[         KP_Home,            KP_7 ] };\
        key <KP8>                {	[           KP_Up,            KP_8 ] };\
        key <KP9>                {	[        KP_Prior,            KP_9 ] };\
        key <KPSU>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [     KP_Subtract,     KP_Subtract,     KP_Subtract,     KP_Subtract,  XF86Prev_VMode ]\
        };\
        key <KP4>                {	[         KP_Left,            KP_4 ] };\
        key <KP5>                {	[        KP_Begin,            KP_5 ] };\
        key <KP6>                {	[        KP_Right,            KP_6 ] };\
        key <KPAD>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [          KP_Add,          KP_Add,          KP_Add,          KP_Add,  XF86Next_VMode ]\
        };\
        key <KP1>                {	[          KP_End,            KP_1 ] };\
        key <KP2>                {	[         KP_Down,            KP_2 ] };\
        key <KP3>                {	[         KP_Next,            KP_3 ] };\
        key <KP0>                {	[       KP_Insert,            KP_0 ] };\
        key <KPDL>               {	[       KP_Delete,      KP_Decimal ] };\
        key <LVL3>               {	[ ISO_Level3_Shift ] };\
        key <LSGT>               {	[            less,         greater,             bar,       brokenbar ] };\
        key <FK11>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [             F11,             F11,             F11,             F11, XF86Switch_VT_11 ]\
        };\
        key <FK12>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [             F12,             F12,             F12,             F12, XF86Switch_VT_12 ]\
        };\
        key <KATA>               {	[        Katakana ] };\
        key <HIRA>               {	[        Hiragana ] };\
        key <HENK>               {	[     Henkan_Mode ] };\
        key <HKTG>               {	[ Hiragana_Katakana ] };\
        key <MUHE>               {	[        Muhenkan ] };\
        key <KPEN>               {	[        KP_Enter ] };\
        key <RCTL>               {	[       Control_R ] };\
        key <KPDV>               {\
                type= \"CTRL+ALT\",\
                symbols[Group1]= [       KP_Divide,       KP_Divide,       KP_Divide,       KP_Divide,      XF86Ungrab ]\
        };\
        key <PRSC>               {\
                type= \"PC_ALT_LEVEL2\",\
                symbols[Group1]= [           Print,         Sys_Req ]\
        };\
        key <RALT>               {\
                type= \"TWO_LEVEL\",\
                symbols[Group1]= [           Alt_R,          Meta_R ]\
        };\
        key <LNFD>               {	[        Linefeed ] };\
        key <HOME>               {	[            Home ] };\
        key <UP>                 {	[              Up ] };\
        key <PGUP>               {	[           Prior ] };\
        key <LEFT>               {	[            Left ] };\
        key <RGHT>               {	[           Right ] };\
        key <END>                {	[             End ] };\
        key <DOWN>               {	[            Down ] };\
        key <PGDN>               {	[            Next ] };\
        key <INS>                {	[          Insert ] };\
        key <DELE>               {	[          Delete ] };\
        key <MUTE>               {	[   XF86AudioMute ] };\
        key <VOL->               {	[ XF86AudioLowerVolume ] };\
        key <VOL+>               {	[ XF86AudioRaiseVolume ] };\
        key <POWR>               {	[    XF86PowerOff ] };\
        key <KPEQ>               {	[        KP_Equal ] };\
        key <I126>               {	[       plusminus ] };\
        key <PAUS>               {\
                type= \"PC_CONTROL_LEVEL2\",\
                symbols[Group1]= [           Pause,           Break ]\
        };\
        key <I128>               {	[     XF86LaunchA ] };\
        key <I129>               {	[      KP_Decimal,      KP_Decimal ] };\
        key <HNGL>               {	[          Hangul ] };\
        key <HJCV>               {	[    Hangul_Hanja ] };\
        key <LWIN>               {	[         Super_L ] };\
        key <RWIN>               {	[         Super_R ] };\
        key <COMP>               {	[       U%08X, U%08X ] };\
        key <STOP>               {	[          Cancel ] };\
        key <AGAI>               {	[            Redo ] };\
        key <PROP>               {	[        SunProps ] };\
        key <UNDO>               {	[            Undo ] };\
        key <FRNT>               {	[        SunFront ] };\
        key <COPY>               {	[        XF86Copy ] };\
        key <OPEN>               {	[        XF86Open ] };\
        key <PAST>               {	[       XF86Paste ] };\
        key <FIND>               {	[            Find ] };\
        key <CUT>                {	[         XF86Cut ] };\
        key <HELP>               {	[            Help ] };\
        key <I147>               {	[      XF86MenuKB ] };\
        key <I148>               {	[  XF86Calculator ] };\
        key <I150>               {	[       XF86Sleep ] };\
        key <I151>               {	[      XF86WakeUp ] };\
        key <I152>               {	[    XF86Explorer ] };\
        key <I153>               {	[        XF86Send ] };\
        key <I155>               {	[        XF86Xfer ] };\
        key <I156>               {	[     XF86Launch1 ] };\
        key <I157>               {	[     XF86Launch2 ] };\
        key <I158>               {	[         XF86WWW ] };\
        key <I159>               {	[         XF86DOS ] };\
        key <I160>               {	[ XF86ScreenSaver ] };\
        key <I161>               {	[ XF86RotateWindows ] };\
        key <I162>               {	[    XF86TaskPane ] };\
        key <I163>               {	[        XF86Mail ] };\
        key <I164>               {	[   XF86Favorites ] };\
        key <I165>               {	[  XF86MyComputer ] };\
        key <I166>               {	[        XF86Back ] };\
        key <I167>               {	[     XF86Forward ] };\
        key <I169>               {	[       XF86Eject ] };\
        key <I170>               {	[       XF86Eject,       XF86Eject ] };\
        key <I171>               {	[   XF86AudioNext ] };\
        key <I172>               {	[   XF86AudioPlay,  XF86AudioPause ] };\
        key <I173>               {	[   XF86AudioPrev ] };\
        key <I174>               {	[   XF86AudioStop,       XF86Eject ] };\
        key <I175>               {	[ XF86AudioRecord ] };\
        key <I176>               {	[ XF86AudioRewind ] };\
        key <I177>               {	[       XF86Phone ] };\
        key <I179>               {	[       XF86Tools ] };\
        key <I180>               {	[    XF86HomePage ] };\
        key <I181>               {	[      XF86Reload ] };\
        key <I182>               {	[       XF86Close ] };\
        key <I185>               {	[    XF86ScrollUp ] };\
        key <I186>               {	[  XF86ScrollDown ] };\
        key <I187>               {	[       parenleft ] };\
        key <I188>               {	[      parenright ] };\
        key <I189>               {	[         XF86New ] };\
        key <I190>               {	[            Redo ] };\
        key <FK13>               {	[       XF86Tools ] };\
        key <FK14>               {	[     XF86Launch5 ] };\
        key <FK15>               {	[     XF86Launch6 ] };\
        key <FK16>               {	[     XF86Launch7 ] };\
        key <FK17>               {	[     XF86Launch8 ] };\
        key <FK18>               {	[     XF86Launch9 ] };\
        key <FK20>               {	[ XF86AudioMicMute ] };\
        key <FK21>               {	[ XF86TouchpadToggle ] };\
        key <FK22>               {	[  XF86TouchpadOn ] };\
        key <FK23>               {	[ XF86TouchpadOff ] };\
        key <MDSW>               {	[     Mode_switch ] };\
        key <ALT>                {	[        NoSymbol,           Alt_L ] };\
        key <META>               {	[        NoSymbol,          Meta_L ] };\
        key <SUPR>               {	[        NoSymbol,         Super_L ] };\
        key <HYPR>               {	[        NoSymbol,         Hyper_L ] };\
        key <I208>               {	[   XF86AudioPlay ] };\
        key <I209>               {	[  XF86AudioPause ] };\
        key <I210>               {	[     XF86Launch3 ] };\
        key <I211>               {	[     XF86Launch4 ] };\
        key <I212>               {	[     XF86LaunchB ] };\
        key <I213>               {	[     XF86Suspend ] };\
        key <I214>               {	[       XF86Close ] };\
        key <I215>               {	[   XF86AudioPlay ] };\
        key <I216>               {	[ XF86AudioForward ] };\
        key <I218>               {	[           Print ] };\
        key <I220>               {	[      XF86WebCam ] };\
        key <I221>               {	[ XF86AudioPreset ] };\
        key <I223>               {	[        XF86Mail ] };\
        key <I224>               {	[   XF86Messenger ] };\
        key <I225>               {	[      XF86Search ] };\
        key <I226>               {	[          XF86Go ] };\
        key <I227>               {	[     XF86Finance ] };\
        key <I228>               {	[        XF86Game ] };\
        key <I229>               {	[        XF86Shop ] };\
        key <I231>               {	[          Cancel ] };\
        key <I232>               {	[ XF86MonBrightnessDown ] };\
        key <I233>               {	[ XF86MonBrightnessUp ] };\
        key <I234>               {	[  XF86AudioMedia ] };\
        key <I235>               {	[     XF86Display ] };\
        key <I236>               {	[ XF86KbdLightOnOff ] };\
        key <I237>               {	[ XF86KbdBrightnessDown ] };\
        key <I238>               {	[ XF86KbdBrightnessUp ] };\
        key <I239>               {	[        XF86Send ] };\
        key <I240>               {	[       XF86Reply ] };\
        key <I241>               {	[ XF86MailForward ] };\
        key <I242>               {	[        XF86Save ] };\
        key <I243>               {	[   XF86Documents ] };\
        key <I244>               {	[     XF86Battery ] };\
        key <I245>               {	[   XF86Bluetooth ] };\
        key <I246>               {	[        XF86WLAN ] };\
        key <I247>               {	[         XF86UWB ] };\
        key <I254>               {	[        XF86WWAN ] };\
        key <I255>               {	[      XF86RFKill ] };\
        modifier_map Shift { <LFSH>, <RTSH> };\
        modifier_map Lock { <CAPS> };\
        modifier_map Control { <LCTL>, <RCTL> };\
        modifier_map Mod1 { <LALT>, <RALT>, <META> };\
        modifier_map Mod2 { <NMLK> };\
        modifier_map Mod4 { <LWIN>, <RWIN>, <SUPR>, <HYPR> };\
        modifier_map Mod5 { <LVL3>, <MDSW> };\
};\
\
};\
"
};
WVEOF

    cat > "$WVKBD_BUILD_DIR/layout.norsk.h" << 'WVEOF'
/* constants */
/* how tall the keyboard should be by default (can be overriden) */
#define KBD_PIXEL_HEIGHT 400

/* how tall the keyboard should be by default (can be overriden) */
#define KBD_PIXEL_LANDSCAPE_HEIGHT 400

/* spacing around each key */
#define KBD_KEY_BORDER 2

/* layout declarations */
enum layout_id {
	Full = 0,
	Special,
	Cyrillic,
	ComposeA,
	ComposeE,
	ComposeY,
	ComposeU,
	ComposeI,
	ComposeO,
	ComposeW,
	ComposeR,
	ComposeT,
	ComposeP,
	ComposeS,
	ComposeD,
	ComposeF,
	ComposeG,
	ComposeH,
	ComposeJ,
	ComposeK,
	ComposeL,
	ComposeZ,
	ComposeX,
	ComposeC,
	ComposeV,
	ComposeB,
	ComposeN,
	ComposeM,
	ComposeMath,
	ComposePunctuation,
	ComposeBracket,
	ComposeCyrI,
	ComposeCyrJ,
	ComposeCyrE,
	ComposeCyrL,
	ComposeCyrU,
	ComposeCyrN,
	ComposeCyrTse,
	ComposeCyrChe,
	ComposeCyrG,
	ComposeCyrK,
	Index,
	NumLayouts,
};

static struct key keys_full[], keys_special[], keys_cyrillic[],
  keys_compose_a[],
  keys_compose_e[], keys_compose_y[], keys_compose_u[], keys_compose_i[],
  keys_compose_o[], keys_compose_w[], keys_compose_r[], keys_compose_t[],
  keys_compose_p[], keys_compose_s[], keys_compose_d[], keys_compose_f[],
  keys_compose_g[], keys_compose_h[], keys_compose_j[], keys_compose_k[],
  keys_compose_l[], keys_compose_z[], keys_compose_x[], keys_compose_c[],
  keys_compose_v[], keys_compose_b[], keys_compose_n[], keys_compose_m[],
  keys_compose_math[], keys_compose_punctuation[], keys_compose_bracket[],
  keys_compose_cyr_i[], keys_compose_cyr_j[], keys_compose_cyr_e[],
  keys_compose_cyr_u[], keys_compose_cyr_l[], keys_compose_cyr_n[],
  keys_compose_cyr_tse[], keys_compose_cyr_che[], keys_compose_cyr_g[],
  keys_compose_cyr_k[], keys_index[];

static struct layout layouts[NumLayouts] = {
  [Full] = {keys_full, "latin", "full", true}, // second parameter is the keymap name
                                         // third parameter is the layout name
										 // last parameter indicates if it's an alphabetical/primary layout
  [Special] = {keys_special, "latin", "special", false},
  [Cyrillic] = {keys_cyrillic, "cyrillic", "cyrillic", true},
  [ComposeA] = {keys_compose_a, "latin"},
  [ComposeE] = {keys_compose_e, "latin"},
  [ComposeY] = {keys_compose_y, "latin"},
  [ComposeU] = {keys_compose_u, "latin"},
  [ComposeI] = {keys_compose_i, "latin"},
  [ComposeO] = {keys_compose_o, "latin"},
  [ComposeW] = {keys_compose_w, "latin"},
  [ComposeR] = {keys_compose_r, "latin"},
  [ComposeT] = {keys_compose_t, "latin"},
  [ComposeP] = {keys_compose_p, "latin"},
  [ComposeS] = {keys_compose_s, "latin"},
  [ComposeD] = {keys_compose_d, "latin"},
  [ComposeF] = {keys_compose_f, "latin"},
  [ComposeG] = {keys_compose_g, "latin"},
  [ComposeH] = {keys_compose_h, "latin"},
  [ComposeJ] = {keys_compose_j, "latin"},
  [ComposeK] = {keys_compose_k, "latin"},
  [ComposeL] = {keys_compose_l, "latin"},
  [ComposeZ] = {keys_compose_z, "latin"},
  [ComposeX] = {keys_compose_x, "latin"},
  [ComposeC] = {keys_compose_c, "latin"},
  [ComposeV] = {keys_compose_v, "latin"},
  [ComposeB] = {keys_compose_b, "latin"},
  [ComposeN] = {keys_compose_n, "latin"},
  [ComposeM] = {keys_compose_m, "latin"},
  [ComposeMath] = {keys_compose_math, "latin"},
  [ComposePunctuation] = {keys_compose_punctuation, "latin"},
  [ComposeBracket] = {keys_compose_bracket, "latin"},
  [ComposeCyrI] = {keys_compose_cyr_i, "cyrillic"},
  [ComposeCyrJ] = {keys_compose_cyr_j, "cyrillic"},
  [ComposeCyrE] = {keys_compose_cyr_e, "cyrillic"},
  [ComposeCyrU] = {keys_compose_cyr_u, "cyrillic"},
  [ComposeCyrL] = {keys_compose_cyr_l, "cyrillic"},
  [ComposeCyrN] = {keys_compose_cyr_n, "cyrillic"},
  [ComposeCyrTse] = {keys_compose_cyr_tse, "cyrillic"},
  [ComposeCyrChe] = {keys_compose_cyr_che, "cyrillic"},
  [ComposeCyrG] = {keys_compose_cyr_g, "cyrillic"},
  [ComposeCyrK] = {keys_compose_cyr_k, "cyrillic"},

  [Index] = {keys_index,"latin","index", false},
};

/* key layouts
 *
 * define keys like:
 *
 *  `{
 *     "label",
 *     "SHIFT_LABEL",
 *     1,
 *     [Code, Mod, Layout, EndRow, Last],
 *     [KEY_CODE, Modifier],
 *     [&layout]
 *  },`
 *
 * - label: normal label for key
 *
 * - shift_label: label for key in shifted (uppercase) layout
 *
 * - width: column width of key
 *
 * - type: what kind of action this key peforms (emit keycode, toggle modifier,
 *   switch layout, or end the layout)
 *
 * - code: key scancode or modifier name (see
 *   `/usr/include/linux/input-event-codes.h` for scancode names, and
 *   `keyboard.h` for modifiers)
 *
 * - layout: layout to switch to when key is pressed
 */
static struct key keys_full[] = {
  {"Esc", "Esc", 1.25, Code, KEY_ESC, .scheme = 1},
  {"F1", "F1", 1.0, Code, KEY_F1, .scheme = 1},
  {"F2", "F2", 1.0, Code, KEY_F2, .scheme = 1},
  {"F3", "F3", 1.0, Code, KEY_F3, .scheme = 1},
  {"F4", "F4", 1.0, Code, KEY_F4, .scheme = 1},
  {"F5", "F5", 1.0, Code, KEY_F5, .scheme = 1},
  {"F6", "F6", 1.0, Code, KEY_F6, .scheme = 1},
  {"F7", "F7", 1.0, Code, KEY_F7, .scheme = 1},
  {"F8", "F8", 1.0, Code, KEY_F8, .scheme = 1},
  {"F9", "F9", 1.0, Code, KEY_F9, .scheme = 1},
  {"F10", "F10", 1.0, Code, KEY_F10, .scheme = 1},
  {"F11", "F11", 1.0, Code, KEY_F11, .scheme = 1},
  {"F12", "F12", 1.0, Code, KEY_F12, .scheme = 1},
  {"Del", "Del", 1.25, Code, KEY_DELETE, .scheme = 1},
  {"", "", 0.0, EndRow},

  {"`", "~", 1.0, Code, KEY_GRAVE},
  {"1", "!", 1.0, Code, KEY_1},
  {"2", "@", 1.0, Code, KEY_2},
  {"3", "#", 1.0, Code, KEY_3},
  {"4", "$", 1.0, Code, KEY_4},
  {"5", "%", 1.0, Code, KEY_5},
  {"6", "^", 1.0, Code, KEY_6},
  {"7", "&", 1.0, Code, KEY_7},
  {"8", "*", 1.0, Code, KEY_8},
  {"9", "(", 1.0, Code, KEY_9, &layouts[ComposeBracket]},
  {"0", ")", 1.0, Code, KEY_0, &layouts[ComposeBracket]},
  {"-", "_", 1.0, Code, KEY_MINUS, &layouts[ComposeBracket]},
  {"=", "+", 1.0, Code, KEY_EQUAL, &layouts[ComposeBracket]},
  {"⌫", "⌫", 1.5, Code, KEY_BACKSPACE, .scheme = 1},
  {"", "", 0.0, EndRow},

  {"Tab", "Tab", 1.5, Code, KEY_TAB, .scheme = 1},
  {"q", "Q", 1.0, Code, KEY_Q},
  {"w", "W", 1.0, Code, KEY_W, &layouts[ComposeW]},
  {"e", "E", 1.0, Code, KEY_E, &layouts[ComposeE]},
  {"r", "R", 1.0, Code, KEY_R, &layouts[ComposeR]},
  {"t", "T", 1.0, Code, KEY_T, &layouts[ComposeT]},
  {"y", "Y", 1.0, Code, KEY_Y, &layouts[ComposeY]},
  {"u", "U", 1.0, Code, KEY_U, &layouts[ComposeU]},
  {"i", "I", 1.0, Code, KEY_I, &layouts[ComposeI]},
  {"o", "O", 1.0, Code, KEY_O, &layouts[ComposeO]},
  {"p", "P", 1.0, Code, KEY_P, &layouts[ComposeP]},
  {"å", "Å", 1.0, Code, KEY_LEFTBRACE},
  {"]", "}", 1.0, Code, KEY_RIGHTBRACE},
  {"\\", "|", 1.0, Code, KEY_BACKSLASH},
  {"", "", 0.0, EndRow},

  {"Cmp", "Cmp", 1.0, Compose, .scheme = 1},
  {"Caps", "Caps", 1.0, Mod, CapsLock, .scheme = 1},
  {"a", "A", 1.0, Code, KEY_A, &layouts[ComposeA]},
  {"s", "S", 1.0, Code, KEY_S, &layouts[ComposeS]},
  {"d", "D", 1.0, Code, KEY_D, &layouts[ComposeD]},
  {"f", "F", 1.0, Code, KEY_F, &layouts[ComposeF]},
  {"g", "G", 1.0, Code, KEY_G, &layouts[ComposeG]},
  {"h", "H", 1.0, Code, KEY_H, &layouts[ComposeH]},
  {"j", "J", 1.0, Code, KEY_J, &layouts[ComposeJ]},
  {"k", "K", 1.0, Code, KEY_K, &layouts[ComposeK]},
  {"l", "L", 1.0, Code, KEY_L, &layouts[ComposeL]},
  {"æ", "Æ", 1.0, Code, KEY_SEMICOLON},
  {"ø", "Ø", 1.0, Code, KEY_APOSTROPHE, &layouts[ComposeBracket]},
  {"Enter", "Enter", 1.5, Code, KEY_ENTER, .scheme = 1},
  {"", "", 0.0, EndRow},

  {"⇧", "⇫", 2.5, Mod, Shift, .scheme = 1},
  {"z", "Z", 1.0, Code, KEY_Z, &layouts[ComposeZ]},
  {"x", "X", 1.0, Code, KEY_X, &layouts[ComposeX]},
  {"c", "C", 1.0, Code, KEY_C, &layouts[ComposeC]},
  {"v", "V", 1.0, Code, KEY_V, &layouts[ComposeV]},
  {"b", "B", 1.0, Code, KEY_B, &layouts[ComposeB]},
  {"n", "N", 1.0, Code, KEY_N, &layouts[ComposeN]},
  {"m", "M", 1.0, Code, KEY_M, &layouts[ComposeM]},
  {",", "<", 1.0, Code, KEY_COMMA, &layouts[ComposeMath]},
  {".", ">", 1.0, Code, KEY_DOT, &layouts[ComposePunctuation]},
  {"/", "?", 1.0, Code, KEY_SLASH},
  {"↑", "↑", 1.0, Code, KEY_UP, .scheme = 1},
  {"⇧", "⇫", 1.0, Mod, Shift, .scheme = 1},
  {"", "", 0.0, EndRow},

  {"⌨͕", "⌨͔", 1.5, NextLayer, .scheme = 1},
  {"Ctr", "Ctr", 1.0, Mod, Ctrl, .scheme = 1},
  {"Sup", "Sup", 1.0, Mod, Super, .scheme = 1},
  {"Alt", "Alt", 1.0, Mod, Alt, .scheme = 1},
  {"", "", 5.0, Code, KEY_SPACE},
  {"AGr", "AGr", 1.0, Mod, AltGr, .scheme = 1},
  {"Ctr", "Ctr", 1.0, Mod, Ctrl, .scheme = 1},
  {"←", "←", 1.0, Code, KEY_LEFT, .scheme = 1},
  {"↓", "↓", 1.0, Code, KEY_DOWN, .scheme = 1},
  {"→", "→", 1.0, Code, KEY_RIGHT, .scheme = 1},
  /* end of layout */
  {"", "", 0.0, Last},
};

static struct key keys_special[] = {
  {"", "", 13.25, Pad},
  {"Ins", "Ins", 1.25, Code, KEY_INSERT, .scheme = 1},
  {"", "", 0.0, EndRow},

  {"", "", 14.5, Pad},
  {"", "", 0.0, EndRow},

  {"", "", 14.5, Pad},
  {"", "", 0.0, EndRow},

  {"", "", 14.5, Pad},
  {"", "", 0.0, EndRow},

  {"⇧", "⇫", 2.5, Mod, Shift, .scheme = 1},
  {"", "", 10.0, Pad},
  {"PgUp", "PgUp", 1.0, Code, KEY_PAGEUP, .scheme = 1},
  {"⇧", "⇫", 1.0, Mod, Shift, .scheme = 1},
  {"", "", 0.0, EndRow},

  {"⌨͕", "⌨͔", 0.75, NextLayer, .scheme = 1},
  {"Abc", "Abc", 0.75, BackLayer, .scheme = 1},

  {"Ctr", "Ctr", 1.0, Mod, Ctrl, .scheme = 1},
  {"Sup", "Sup", 1.0, Mod, Super, .scheme = 1},
  {"Alt", "Alt", 1.0, Mod, Alt, .scheme = 1},
  {"", "", 5.0, Pad},
  {"AGr", "AGr", 1.0, Mod, AltGr, .scheme = 1},
  {"Ctr", "Ctr", 1.0, Mod, Ctrl, .scheme = 1},
  {"Home", "Home", 1.0, Code, KEY_HOME, .scheme = 1},
  {"PgDn", "PgDn", 1.0, Code, KEY_PAGEDOWN, .scheme = 1},
  {"End", "End", 1.0, Code, KEY_END, .scheme = 1},
  /* end of layout */
  {"", "", 0.0, Last},
};

static struct key keys_cyrillic[] = {
  {"Esc", "Esc", 1.25, Code, KEY_ESC, .scheme = 1},
  {"F1", "F1", 1.0, Code, KEY_F1, .scheme = 1},
  {"F2", "F2", 1.0, Code, KEY_F2, .scheme = 1},
  {"F3", "F3", 1.0, Code, KEY_F3, .scheme = 1},
  {"F4", "F4", 1.0, Code, KEY_F4, .scheme = 1},
  {"F5", "F5", 1.0, Code, KEY_F5, .scheme = 1},
  {"F6", "F6", 1.0, Code, KEY_F6, .scheme = 1},
  {"F7", "F7", 1.0, Code, KEY_F7, .scheme = 1},
  {"F8", "F8", 1.0, Code, KEY_F8, .scheme = 1},
  {"F9", "F9", 1.0, Code, KEY_F9, .scheme = 1},
  {"F10", "F10", 1.0, Code, KEY_F10, .scheme = 1},
  {"F11", "F11", 1.0, Code, KEY_F11, .scheme = 1},
  {"F12", "F12", 1.0, Code, KEY_F12, .scheme = 1},
  {"Del", "Del", 1.25, Code, KEY_DELETE, .scheme = 1},
  {"", "", 0.0, EndRow},

  {"ё", "Ё", 1.0, Code, KEY_GRAVE},
  {"1", "!", 1.0, Code, KEY_1},
  {"2", "\"", 1.0, Code, KEY_2},
  {"3", "#", 1.0, Code, KEY_3},
  {"4", "*", 1.0, Code, KEY_4},
  {"5", ":", 1.0, Code, KEY_5},
  {"6", ",", 1.0, Code, KEY_6},
  {"7", ".", 1.0, Code, KEY_7},
  {"8", ";", 1.0, Code, KEY_8},
  {"9", "(", 1.0, Code, KEY_9, &layouts[ComposeBracket]},
  {"0", ")", 1.0, Code, KEY_0, &layouts[ComposeBracket]},
  {"-", "_", 1.0, Code, KEY_MINUS, &layouts[ComposeBracket]},
  {"=", "+", 1.0, Code, KEY_EQUAL, &layouts[ComposeBracket]},
  {"⌫", "⌫", 1.5, Code, KEY_BACKSPACE, .scheme = 1},
  {"", "", 0.0, EndRow},

  {"Tab", "Tab", 1.5, Code, KEY_TAB, .scheme = 1},
  {"й", "Й", 1.0, Code, KEY_Q, &layouts[ComposeCyrJ]},
  {"ц", "Ц", 1.0, Code, KEY_W, &layouts[ComposeCyrTse]},
  {"у", "У", 1.0, Code, KEY_E},
  {"к", "К", 1.0, Code, KEY_R, &layouts[ComposeCyrK]},
  {"е", "Е", 1.0, Code, KEY_T, &layouts[ComposeCyrE]},
  {"н", "Н", 1.0, Code, KEY_Y},
  {"г", "Г", 1.0, Code, KEY_U, &layouts[ComposeCyrG]},
  {"ш", "ш", 1.0, Code, KEY_I},
  {"щ", "щ", 1.0, Code, KEY_O},
  {"з", "з", 1.0, Code, KEY_P},
  {"х", "Х", 1.0, Code, KEY_LEFTBRACE},
  {"ъ", "Ъ", 1.0, Code, KEY_RIGHTBRACE},
  {"\\", "|", 1.0, Code, KEY_BACKSLASH},
  {"", "", 0.0, EndRow},

  {"Cmp", "Cmp", 1.0, Compose, .scheme = 1},
  {"Caps", "Caps", 1.0, Mod, CapsLock, .scheme = 1},
  {"ф", "Ф", 1.0, Code, KEY_A},
  {"ы", "Ы", 1.0, Code, KEY_S, &layouts[ComposeCyrI]},
  {"в", "В", 1.0, Code, KEY_D},
  {"а", "А", 1.0, Code, KEY_F},
  {"п", "П", 1.0, Code, KEY_G},
  {"р", "Р", 1.0, Code, KEY_H},
  {"о", "О", 1.0, Code, KEY_J},
  {"л", "Л", 1.0, Code, KEY_K, &layouts[ComposeCyrL]},
  {"д", "Д", 1.0, Code, KEY_L},
  {"ж", "Ж", 1.0, Code, KEY_SEMICOLON},
  {"э","Э", 1.0, Code, KEY_APOSTROPHE, &layouts[ComposeCyrE]},
  {"Enter", "Enter", 1.5, Code, KEY_ENTER, .scheme = 1},
  {"", "", 0.0, EndRow},

  {"⇧", "⇫", 2.5, Mod, Shift, .scheme = 1},
  {"я", "Я", 1.0, Code, KEY_Z},
  {"ч", "Ч", 1.0, Code, KEY_X, &layouts[ComposeCyrChe]},
  {"c", "С", 1.0, Code, KEY_C},
  {"м", "М", 1.0, Code, KEY_V},
  {"и", "И", 1.0, Code, KEY_B, &layouts[ComposeCyrI]},
  {"т", "Т", 1.0, Code, KEY_N},
  {"ь", "Ь", 1.0, Code, KEY_M},
  {"б", "Б", 1.0, Code, KEY_COMMA},
  {"ю", "Ю", 1.0, Code, KEY_DOT},
  {"/", "?", 1.0, Code, KEY_SLASH, &layouts[ComposePunctuation]},
  {"↑", "↑", 1.0, Code, KEY_UP, .scheme = 1},
  {"⇧", "⇫", 1.0, Mod, Shift, .scheme = 1},
  {"", "", 0.0, EndRow},

  {"⌨͕", "⌨͔", 1.5, NextLayer, .scheme = 1},
  {"Ctr", "Ctr", 1.0, Mod, Ctrl, .scheme = 1},
  {"Sup", "Sup", 1.0, Mod, Super, .scheme = 1},
  {"Alt", "Alt", 1.0, Mod, Alt, .scheme = 1},
  {"", "", 5.0, Code, KEY_SPACE},
  {"AGr", "AGr", 1.0, Mod, AltGr, .scheme = 1},
  {"Ctr", "Ctr", 1.0, Mod, Ctrl, .scheme = 1},
  {"←", "←", 1.0, Code, KEY_LEFT, .scheme = 1},
  {"↓", "↓", 1.0, Code, KEY_DOWN, .scheme = 1},
  {"→", "→", 1.0, Code, KEY_RIGHT, .scheme = 1},
  /* end of layout */
  {"", "", 0.0, Last},
};

static struct key keys_compose_a[] = {
  {"à", "À", 1.0, Copy, 0x00E0, 0, 0x00C0},
  {"á", "Á", 1.0, Copy, 0x00E1, 0, 0x00C1},
  {"â", "Â", 1.0, Copy, 0x00E2, 0, 0x00C2},
  {"ã", "Ã", 1.0, Copy, 0x00E3, 0, 0x00C3},
  {"ä", "Ä", 1.0, Copy, 0x00E4, 0, 0x00C4},
  {"å", "Å", 1.0, Copy, 0x00E5, 0, 0x00C5},
  {"æ", "Æ", 1.0, Copy, 0x00E7, 0, 0x00C6},
  {"ā", "Ā", 1.0, Copy, 0x0101, 0, 0x0100},
  {"ă", "Ă", 1.0, Copy, 0x0103, 0, 0x0102},
  {"ą", "Ą", 1.0, Copy, 0x0105, 0, 0x0104},
  {"", "", 0.0, EndRow},
  {"α", "Α", 1.0, Copy, 0x03B1, 0, 0x0391},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_e[] = {
  {"è", "È", 1.0, Copy, 0x00E8, 0, 0x00C8},
  {"é", "É", 1.0, Copy, 0x00E9, 0, 0x00C9},
  {"ê", "Ê", 1.0, Copy, 0x00EA, 0, 0x00CA},
  {"ë", "Ë", 1.0, Copy, 0x00EB, 0, 0x00CB},
  {"ē", "Ē", 1.0, Copy, 0x0113, 0, 0x0112},
  {"ĕ", "Ĕ", 1.0, Copy, 0x0115, 0, 0x0114},
  {"ė", "Ė", 1.0, Copy, 0x0117, 0, 0x0116},
  {"ę", "Ę", 1.0, Copy, 0x0119, 0, 0x0118},
  {"ě", "Ě", 1.0, Copy, 0x011B, 0, 0x011A},
  {"", "", 1.0, Pad},
  {"", "", 0.0, EndRow},
  {"ε", "Ε", 1.0, Copy, 0x03B5, 0, 0x0395},
  {"ǝ", "Ə", 1.0, Copy, 0x0259, 0, 0x018F},
  {"", "", 8.0, Pad},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_y[] = {
  {"ý", "Ý", 1.0, Copy, 0x00FD, 0, 0x00DD},
  {"ÿ", "Ÿ", 1.0, Copy, 0x00FF, 0, 0x0178},
  {"ŷ", "Ŷ", 1.0, Copy, 0x0177, 0, 0x0176},
  {"", "", 7.0, Pad},
  {"", "", 0.0, EndRow},
  {"υ", "Υ", 1.0, Copy, 0x03C5, 0, 0x03A5},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_u[] = {
  {"ù", "Ù", 1.0, Copy, 0x00F9, 0, 0x00D9},
  {"ú", "Ú", 1.0, Copy, 0x00FA, 0, 0x00DA},
  {"û", "Û", 1.0, Copy, 0x00FB, 0, 0x00DB},
  {"ü", "Ü", 1.0, Copy, 0x00FC, 0, 0x00DC},
  {"ũ", "Ũ", 1.0, Copy, 0x0169, 0, 0x0168},
  {"ū", "Ū", 1.0, Copy, 0x016B, 0, 0x016A},
  {"ŭ", "Ŭ", 1.0, Copy, 0x016D, 0, 0x016C},
  {"ů", "Ů", 1.0, Copy, 0x016F, 0, 0x016E},
  {"ű", "Ű", 1.0, Copy, 0x0171, 0, 0x0170},
  {"ų", "Ų", 1.0, Copy, 0x0173, 0, 0x0172},
  {"", "", 0.0, EndRow},
  {"υ", "Υ", 1.0, Copy, 0x03C5, 0, 0x03A5},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_o[] = {
  {"ò", "Ò", 1.0, Copy, 0x00F2, 0, 0x00D2},
  {"ó", "Ó", 1.0, Copy, 0x00F3, 0, 0x00D3},
  {"ô", "Ô", 1.0, Copy, 0x00F4, 0, 0x00D4},
  {"õ", "Õ", 1.0, Copy, 0x00F5, 0, 0x00D5},
  {"ö", "Ö", 1.0, Copy, 0x00F6, 0, 0x00D6},
  {"ø", "Ø", 1.0, Copy, 0x00F8, 0, 0x00D8},
  {"ō", "Ō", 1.0, Copy, 0x014D, 0, 0x014C},
  {"ŏ", "Ŏ", 1.0, Copy, 0x014F, 0, 0x014E},
  {"ő", "Ő", 1.0, Copy, 0x0151, 0, 0x0150},
  {"œ", "Œ", 1.0, Copy, 0x0153, 0, 0x0152},
  {"", "", 0.0, EndRow},
  {"ο", "Ο", 1.0, Copy, 0x03BF, 0, 0x039F},
  {"ω", "Ο", 1.0, Copy, 0x03C9, 0, 0x03A9},
  {"", "", 8.0, Pad},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_i[] = {
  {"ì", "Ì", 1.0, Copy, 0x00EC, 0, 0x00CC},
  {"í", "Í", 1.0, Copy, 0x00ED, 0, 0x00CD},
  {"î", "Î", 1.0, Copy, 0x00EE, 0, 0x00CE},
  {"ï", "Ï", 1.0, Copy, 0x00EF, 0, 0x00CF},
  {"ĩ", "Ĩ", 1.0, Copy, 0x0129, 0, 0x0128},
  {"ī", "Ī", 1.0, Copy, 0x012B, 0, 0x012A},
  {"ĭ", "Ĭ", 1.0, Copy, 0x012D, 0, 0x012C},
  {"į", "Į", 1.0, Copy, 0x012F, 0, 0x012E},
  {"ı", "I", 1.0, Copy, 0x0131, 0, 0x0049},
  {"i", "İ", 1.0, Copy, 0x0069, 0, 0x0130},
  {"", "", 0.0, EndRow},
  {"ι", "Ι", 1.0, Copy, 0x03B9, 0, 0x0399},
  {"η", "Η", 1.0, Copy, 0x03B7, 0, 0x0397},
  {"", "", 8.0, Pad},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_index[] = {
  {"Full", "Full", 1.0, Layout, 0, &layouts[Full], .scheme = 1},
  {"Special", "Special", 1.0, Layout, 0, &layouts[Special], .scheme = 1},
  {"Абв", "Абв", 1.0, Layout, 0, &layouts[Cyrillic], .scheme = 1},
  {"", "", 0.0, Last},
};

static struct key keys_compose_w[] = {
  {"ŵ", "Ŵ", 1.0, Copy, 0x0175, 0, 0x0174},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_r[] = {
  {"ŕ", "Ŕ", 1.0, Copy, 0x0155, 0, 0x0154},
  {"ŗ", "Ŗ", 1.0, Copy, 0x0157, 0, 0x0156},
  {"ř", "Ř", 1.0, Copy, 0x0159, 0, 0x0158},
  {"", "", 7.0, Pad},
  {"", "", 0.0, EndRow},
  {"ρ", "Ρ", 1.0, Copy, 0x03C1, 0, 0x03A1},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_t[] = {
  {"ț", "Ț", 1.0, Copy, 0x021B, 0, 0x021A},
  {"ť", "Ť", 1.0, Copy, 0x0165, 0, 0x0164},
  {"ŧ", "Ŧ", 1.0, Copy, 0x0167, 0, 0x0166},
  {"þ", "Þ", 1.0, Copy, 0x00FE, 0, 0x00DE},
  {"", "", 6.0, Pad},
  {"", "", 0.0, EndRow},
  {"τ", "Τ", 1.0, Copy, 0x03C4, 0, 0x03A4},
  {"θ", "Θ", 1.0, Copy, 0x03B8, 0, 0x0398},
  {"", "", 8.0, Pad},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_p[] = {
  {"π", "Π", 1.0, Copy, 0x03C0, 0, 0x03A0},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_s[] = {
  {"ś", "Ś", 1.0, Copy, 0x015B, 0, 0x015A},
  {"ŝ", "Ŝ", 1.0, Copy, 0x015D, 0, 0x015C},
  {"ş", "Ş", 1.0, Copy, 0x015F, 0, 0x015E},
  {"š", "Š", 1.0, Copy, 0x0161, 0, 0x0160},
  {"ß", "ẞ", 1.0, Copy, 0x00DF, 0, 0x1E9E},
  {"", "", 5.0, Pad},
  {"", "", 0.0, EndRow},
  {"σ", "Σ", 1.0, Copy, 0x03C3, 0, 0x03A3},
  {"ς", "Σ", 1.0, Copy, 0x03C2, 0, 0x03A3},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_d[] = {
  {"ð", "Ð", 1.0, Copy, 0x00F0, 0, 0x00D0},
  {"ď", "Ď", 1.0, Copy, 0x010F, 0, 0x010E},
  {"đ", "Đ", 1.0, Copy, 0x0111, 0, 0x0110},
  {"", "", 7.0, Pad},
  {"", "", 0.0, EndRow},
  {"δ", "Δ", 1.0, Copy, 0x03B4, 0, 0x0394},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_f[] = {
  {"φ", "Φ", 1.0, Copy, 0x03C6, 0, 0x03A6},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_g[] = {
  {"ĝ", "Ĝ", 1.0, Copy, 0x011D, 0, 0x011C},
  {"ğ", "Ğ", 1.0, Copy, 0x011F, 0, 0x011E},
  {"", "", 8.0, Pad},
  {"", "", 0.0, EndRow},
  {"γ", "Γ", 1.0, Copy, 0x03B3, 0, 0x0393},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_h[] = {
  {"ĥ", "Ĥ", 1.0, Copy, 0x0125, 0, 0x0124},
  {"ħ", "Ħ", 1.0, Copy, 0x0127, 0, 0x0126},
  {"", "", 8.0, Pad},
  {"", "", 0.0, EndRow},
  {"η", "Η", 1.0, Copy, 0x03B7, 0, 0x0397},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_j[] = {
  {"ĵ", "Ĵ", 1.0, Copy, 0x0135, 0, 0x0134},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"", "", 10.0, Pad},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_k[] = {
  {"ķ", "Ķ", 1.0, Copy, 0x0137, 0, 0x0136},
  {"ǩ", "Ǩ", 1.0, Copy, 0x01E9, 0, 0x01E8},
  {"", "", 8.0, Pad},
  {"", "", 0.0, EndRow},
  {"κ", "Κ", 1.0, Copy, 0x03BA, 0, 0x039A},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_l[] = {
  {"ľ", "Ľ", 1.0, Copy, 0x013E, 0, 0x013D},
  {"ŀ", "Ŀ", 1.0, Copy, 0x0140, 0, 0x013F},
  {"ł", "Ł", 1.0, Copy, 0x0142, 0, 0x0141},
  {"", "", 7.0, Pad},
  {"", "", 0.0, EndRow},
  {"λ", "Λ", 1.0, Copy, 0x03BB, 0, 0x039B},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_z[] = {
  {"ź", "Ź", 1.0, Copy, 0x017A, 0, 0x0179},
  {"ż", "Ż", 1.0, Copy, 0x017C, 0, 0x017B},
  {"ž", "Ž", 1.0, Copy, 0x017E, 0, 0x017D},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"ζ", "Ζ", 1.0, Copy, 0x03B6, 0, 0x0396},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_x[] = {
  {"χ", "Χ", 1.0, Copy, 0x03C7, 0, 0x03A7},
  {"ξ", "Ξ", 1.0, Copy, 0x03BE, 0, 0x039E},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_c[] = {
  {"ç", "Ç", 1.0, Copy, 0x00E7, 0, 0x00C7},
  {"ć", "Ć", 1.0, Copy, 0x0107, 0, 0x0106},
  {"ĉ", "Ĉ", 1.0, Copy, 0x0109, 0, 0x0108},
  {"ċ", "Ċ", 1.0, Copy, 0x010B, 0, 0x010A},
  {"č", "Č", 1.0, Copy, 0x010D, 0, 0x010C},
  {"", "", 5.0, Pad},
  {"", "", 0.0, EndRow},
  {"χ", "Χ", 1.0, Copy, 0x03C7, 0, 0x03A7},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_v[] = {
  {"", "", 0.0, EndRow},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_b[] = {
  {"β", "Β", 1.0, Copy, 0x03B2, 0, 0x0392},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_n[] = {
  {"ñ", "Ñ", 1.0, Copy, 0x00F1, 0, 0x00D1},
  {"ń", "Ń", 1.0, Copy, 0x0144, 0, 0x0143},
  {"ņ", "Ņ", 1.0, Copy, 0x0146, 0, 0x0145},
  {"ň", "Ň", 1.0, Copy, 0x0148, 0, 0x0147},
  {"ŋ", "Ŋ", 1.0, Copy, 0x014B, 0, 0x014A},
  {"", "", 5.0, Pad},
  {"", "", 0.0, EndRow},
  {"ν", "Ν", 1.0, Copy, 0x03BD, 0, 0x039D},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_m[] = {
  {"μ", "Μ", 1.0, Copy, 0x03BC, 0, 0x039C},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_math[] = {
  {"", "", 0.0, EndRow},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"+", "+", 1, Code, KEY_EQUAL, 0, Shift},
  {"/", "/", 1, Code, KEY_SLASH},
  {"*", "*", 1, Code, KEY_8, 0, Shift},
  {"-", "-", 1, Code, KEY_MINUS},
  {"=", "=", 1, Code, KEY_EQUAL},
  {"_", "_", 1, Code, KEY_MINUS, 0, Shift},
  {"—", "—", 1, Copy, 0x2014, 0, 0x2014},
  {"", "", 1.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_punctuation[] = {
  {"", "", 0.0, EndRow},
  {"", "", 4.5, Pad},
  {".", ".", 1, Code, KEY_DOT},
  {"…", "…", 1, Copy, 0x2026, 0, 0x2026},
  {":", ":", 1, Code, KEY_SEMICOLON, 0, Shift},
  {";", ";", 1, Code, KEY_SEMICOLON, 0},
  {"⍽", "⍽", 1, Copy, 0x202F, 0, 0x00A0},
  {"", "", 0.5, Pad},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 3, Pad},
  {"!", "!", 1, Code, KEY_1, 0, Shift},
  {"?", "?", 1, Code, KEY_DOT, 0, Shift},
  {"·", "·", 1, Copy, 0x2027, 0, 0x2027},
  {",", ",", 1, Code, KEY_COMMA},
  {"", "", 1.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_bracket[] = {
  {"", "", 0, EndRow},
  {"", "", 1.5, Pad},
  {"{", "{", 1, Code, KEY_LEFTBRACE, 0, Shift},
  {"}", "}", 1, Code, KEY_RIGHTBRACE, 0, Shift},
  {"[", "[", 1, Code, KEY_LEFTBRACE},
  {"]", "]", 1, Code, KEY_RIGHTBRACE},
  {"", "", 4.5, Pad},
  {"", "", 0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"<", "<", 1, Code, KEY_COMMA, 0, AltGr},
  {">", ">", 1, Code, KEY_SLASH, 0, Shift},
  {"`", "`", 1, Code, KEY_GRAVE},
  {"\"", "\"", 1, Code, KEY_APOSTROPHE, 0, Shift},
  {"'", "'", 1, Code, KEY_APOSTROPHE},
  {"", "", 3.5, Pad},
  {"", "", 0.0, EndRow},
  {"Abc", "Abc", 1.0, BackLayer, .scheme = 1},
  {"Ctr", "Ctr", 1.0, Mod, Ctrl, .scheme = 1},
  {"", "", 8, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_cyr_i[] = {
  {"і", "І", 1.0, Copy, 0x0456, 0, 0x0406},
  {"ї", "Ї", 1.0, Copy, 0x0457, 0, 0x0407},
  {"", "", 8.0, Pad},
  {"", "", 0.0, EndRow},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Абв", "Абв", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_cyr_j[] = {
  {"ј", "Ј", 1.0, Copy, 0x0458, 0, 0x0408},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Абв", "Абв", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_cyr_e[] = {
  {"є", "Є", 1.0, Copy, 0x0454, 0, 0x0404},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Абв", "Абв", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_cyr_u[] = {
  {"ў", "Ў", 1.0, Copy, 0x045E, 0, 0x040E},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Абв", "Абв", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_cyr_l[] = {
  {"љ", "Љ", 1.0, Copy, 0x0459, 0, 0x0409},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Абв", "Абв", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_cyr_n[] = {
  {"њ", "Њ", 1.0, Copy, 0x045A, 0, 0x040A},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Абв", "Абв", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_cyr_che[] = {
  {"ћ", "Ћ", 1.0, Copy, 0x045B, 0, 0x040B},
  {"ђ", "Ђ", 1.0, Copy, 0x0452, 0, 0x0402},
  {"", "", 8.0, Pad},
  {"", "", 0.0, EndRow},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Абв", "Абв", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_cyr_tse[] = {
  {"џ", "Џ", 1.0, Copy, 0x045F, 0, 0x040F},
  {"ѕ", "Ѕ", 1.0, Copy, 0x0455, 0, 0x0405},
  {"", "", 8.0, Pad},
  {"", "", 0.0, EndRow},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Абв", "Абв", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_cyr_g[] = {
  {"ѓ", "Ѓ", 1.0, Copy, 0x0453, 0, 0x0403},
  {"ґ", "Ґ", 1.0, Copy, 0x0491, 0, 0x0490},
  {"", "", 8.0, Pad},
  {"", "", 0.0, EndRow},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Абв", "Абв", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};

static struct key keys_compose_cyr_k[] = {
  {"ќ", "Ќ", 1.0, Copy, 0x0453, 0, 0x040C},
  {"", "", 9.0, Pad},
  {"", "", 0.0, EndRow},
  {"", "", 0.0, EndRow},
  {"⇧", "⇫", 1.5, Mod, Shift, .scheme = 1},
  {"", "", 8.5, Pad},
  {"", "", 0.0, EndRow},
  {"Абв", "Абв", 1.0, BackLayer, .scheme = 1},
  {"", "", 9, Pad},
  {"", "", 0.0, Last},
};
WVEOF

    cat > "$WVKBD_BUILD_DIR/config.norsk.h" << 'WVEOF'
#ifndef config_h_INCLUDED
#define config_h_INCLUDED

#define DEFAULT_FONT "Sans 18"
#define DEFAULT_ROUNDING 5
static const int transparency = 255;

struct clr_scheme schemes[] = {
{
  /* colors */
  .bg = {.bgra = {15, 15, 15, transparency}},
  .fg = {.bgra = {45, 45, 45, transparency}},
  .high = {.bgra = {100, 100, 100, transparency}},
  .swipe = {.bgra = {100, 255, 100, 64}},
  .text = {.color = UINT32_MAX},
  .text_press = {.color = UINT32_MAX},
  .text_swipe = {.color = UINT32_MAX},
  .font = DEFAULT_FONT,
  .rounding = DEFAULT_ROUNDING,
},
{
  /* colors */
  .bg = {.bgra = {15, 15, 15, transparency}},
  .fg = {.bgra = {32, 32, 32, transparency}},
  .high = {.bgra = {100, 100, 100, transparency}},
  .swipe = {.bgra = {100, 255, 100, 64}},
  .text_press = {.color = UINT32_MAX},
  .text_swipe = {.color = UINT32_MAX},
  .text = {.color = UINT32_MAX},
  .font = DEFAULT_FONT,
  .rounding = DEFAULT_ROUNDING,
}
};

/* layers is an ordered list of layouts, used to cycle through */
static enum layout_id layers[] = {
  Full, // First layout is the default layout on startup
  Special,
  NumLayouts // signals the last item, may not be omitted
};

/* layers is an ordered list of layouts, used to cycle through */
static enum layout_id landscape_layers[] = {
  Full, // First layout is the default layout on startup
  Special,
  NumLayouts // signals the last item, may not be omitted
};

#endif // config_h_INCLUDED
WVEOF

    print_step "Bygger wvkbd-norsk (dette tar litt tid)..."
    if make LAYOUT=norsk; then
        print_success "Bygget uten feil"
        sudo make LAYOUT=norsk install
        print_success "wvkbd-norsk installert i /usr/local/bin/"
    else
        print_error "Bygging feilet - se feilmelding over"
        INSTALL_WVKBD=false
    fi
fi

if [ "$INSTALL_WVKBD" = true ]; then
    MANUAL_LINES="${MANUAL_LINES}
# --- WVKBD-NORSK: autostart-linje (juster -L <tall> for høyde) ---
    hl.exec_cmd(\"wvkbd-norsk -L 320 --hidden\")

# --- WVKBD-NORSK: SUPER+T toggle-bind ---
hl.bind(mainMod .. \" + T\", hl.dsp.exec_cmd(\"pkill --signal SIGRTMIN wvkbd-norsk\"))

# --- WVKBD-NORSK: sprett opp fra bunnen av skjermen ved toggle ---
hl.layer_rule({
    match = { namespace = \"wvkbd\" },
    animation = \"slide\",
})
"
fi

# ------------------------------------------------------------
# Oppsummering
# ------------------------------------------------------------
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                  Installasjon fullført! ✓                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
print_warning "hyprland.lua er IKKE endret - legg til disse linjene manuelt:"
echo ""
echo -e "${BLUE}------------------------------------------------------------${NC}"
echo -e "${YELLOW}${MANUAL_LINES}${NC}"
echo -e "${BLUE}------------------------------------------------------------${NC}"
echo ""
echo "Etter du har lagt inn linjene: hyprctl reload (eller ditt eget reload-bind)."
echo ""
[ "$INSTALL_BAR" = true ]      && echo "Test bar direkte:       qs -c bar"
[ "$INSTALL_OVERVIEW" = true ] && echo "Test overview direkte:  qs -c overview"
[ "$INSTALL_WVKBD" = true ]    && echo "Test tastatur direkte:  wvkbd-norsk -L 320"
echo ""
print_success "God fornøyelse!"
