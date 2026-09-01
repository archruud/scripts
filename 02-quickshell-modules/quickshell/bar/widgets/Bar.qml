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
                    command: ["sh", "-c", "XAPP_FORCE_GTKWINDOW_ICON=\"/home/archruud/Nedlastinger/google-calendar64.png\" firefox --class WebApp-Kallender3092 --name WebApp-Kallender3092 --profile /home/archruud/.local/share/ice/firefox/Kallender3092 --no-remote \"http://calendar.google.com\""]
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
