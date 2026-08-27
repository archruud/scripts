#!/usr/bin/env bash
#
# bluetooth-arch-hyprland.sh
# Installerer og konfigurerer Bluetooth (CLI + GUI) på Arch Linux / Hyprland.
# Se tilhørende dokumentasjon: bluetooth-arch-hyprland.md
#
# Kjør som vanlig bruker (skriptet bruker sudo der det trengs):
#   chmod +x bluetooth-arch-hyprland.sh
#   ./bluetooth-arch-hyprland.sh
#
set -euo pipefail

HYPR_CONF="${HYPR_CONF:-$HOME/.config/hypr/hyprland.conf}"
MAIN_CONF="/etc/bluetooth/main.conf"

log()  { printf '\033[1;32m[+]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$1"; }
err()  { printf '\033[1;31m[x]\033[0m %s\n' "$1" >&2; }

require_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# 1. Pakker
# ---------------------------------------------------------------------------
log "Installerer bluez, bluez-utils og blueman..."
sudo pacman -S --needed --noconfirm bluez bluez-utils blueman

# ---------------------------------------------------------------------------
# 2. Lyd — sjekk om PipeWire eller PulseAudio kjører
# ---------------------------------------------------------------------------
if require_cmd pactl; then
    SERVER=$(pactl info 2>/dev/null | grep "Server Name" || true)
    if echo "$SERVER" | grep -qi "pipewire"; then
        log "PipeWire funnet — installerer pipewire-pulse og wireplumber (om de mangler)..."
        sudo pacman -S --needed --noconfirm pipewire pipewire-pulse wireplumber
    elif echo "$SERVER" | grep -qi "pulseaudio"; then
        warn "Ren PulseAudio funnet — installerer pulseaudio-bluetooth..."
        sudo pacman -S --needed --noconfirm pulseaudio-bluetooth
    else
        warn "Fant ikke en kjørende lydserver. Hopper over lyd-pakker — installer manuelt om nødvendig."
    fi
else
    warn "pactl ikke funnet. Hopper over lyd-oppsett."
fi

# ---------------------------------------------------------------------------
# 3. Tjeneste
# ---------------------------------------------------------------------------
log "Aktiverer og starter bluetooth.service..."
sudo systemctl enable --now bluetooth.service

if systemctl is-active --quiet bluetooth.service; then
    log "bluetooth.service kjører."
else
    err "bluetooth.service kjører IKKE — sjekk 'systemctl status bluetooth.service'."
fi

# ---------------------------------------------------------------------------
# 4. Kernelmodul og rfkill
# ---------------------------------------------------------------------------
log "Sjekker btusb-modul..."
if lsmod | grep -q btusb; then
    log "btusb er lastet."
else
    warn "btusb er IKKE lastet. Adapteren blir kanskje ikke gjenkjent (sjekk hardware/firmware)."
fi

if require_cmd rfkill; then
    if rfkill list bluetooth | grep -q "Soft blocked: yes"; then
        warn "Bluetooth er soft-blocked. Fjerner blokkering..."
        sudo rfkill unblock bluetooth
    else
        log "Bluetooth er ikke blokkert av rfkill."
    fi
fi

# ---------------------------------------------------------------------------
# 5. AutoEnable i main.conf
# ---------------------------------------------------------------------------
log "Setter AutoEnable=true i $MAIN_CONF..."
if [ -f "$MAIN_CONF" ]; then
    if grep -q "^AutoEnable" "$MAIN_CONF"; then
        sudo sed -i 's/^AutoEnable.*/AutoEnable=true/' "$MAIN_CONF"
    elif grep -q "^\[Policy\]" "$MAIN_CONF"; then
        sudo sed -i '/^\[Policy\]/a AutoEnable=true' "$MAIN_CONF"
    else
        printf '\n[Policy]\nAutoEnable=true\n' | sudo tee -a "$MAIN_CONF" >/dev/null
    fi
else
    warn "$MAIN_CONF finnes ikke — hopper over AutoEnable."
fi

# ---------------------------------------------------------------------------
# 6. Blueman-applet i Hyprland
# ---------------------------------------------------------------------------
if [ -f "$HYPR_CONF" ]; then
    if grep -q "blueman-applet" "$HYPR_CONF"; then
        log "blueman-applet er allerede i $HYPR_CONF."
    else
        log "Legger til 'exec-once = blueman-applet' i $HYPR_CONF..."
        printf '\nexec-once = blueman-applet\n' >> "$HYPR_CONF"
    fi
else
    warn "Fant ikke $HYPR_CONF. Legg til dette manuelt i din Hyprland-config:"
    echo "    exec-once = blueman-applet"
fi

# ---------------------------------------------------------------------------
# Oppsummering
# ---------------------------------------------------------------------------
echo
log "Ferdig. Oppsummering:"
echo "  - Pakker installert: bluez, bluez-utils, blueman (+ evt. lyd-pakker)"
echo "  - bluetooth.service: $(systemctl is-active bluetooth.service 2>/dev/null || echo ukjent)"
echo "  - btusb lastet: $(lsmod | grep -q btusb && echo ja || echo nei)"
echo "  - AutoEnable satt i $MAIN_CONF"
echo "  - blueman-applet lagt til i Hyprland-config (om funnet)"
echo
echo "Restart Hyprland-sesjonen (eller kjør 'blueman-applet &' manuelt) for å se systray-ikonet."
echo "Test parring med: bluetoothctl -> power on -> scan on -> pair <MAC> -> trust <MAC> -> connect <MAC>"
