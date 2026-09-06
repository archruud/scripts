#!/bin/bash
# ============================================================
# 20-gpu-drivers — install-intel-panther-lake.sh
# Komplett driver-stack for Intel Core Ultra Series 3 (Panther Lake)
# Dekker: Xe3 iGPU (grafikk + compute) + NPU5 (50 TOPS AI) + media
#
# Maskin: NUC 16 Pro, Intel Core Ultra Series 3 (Panther Lake, PTL-H484)
# Kalles fra install-gpu-driver.sh når Panther Lake er detektert,
# eller kjøres frittstående: ./install-intel-panther-lake.sh
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
info() { echo -e "${CYAN}[i]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN} Intel Panther Lake — GPU + NPU driver-install${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""

# ── Steg 0: Bekreft at dette faktisk er Panther Lake ────────────────────────
if ! lspci | grep -qi "Panther Lake"; then
    err "Fant ikke 'Panther Lake' i lspci — dette scriptet er laget for den CPU-en."
    warn "Fortsetter likevel om 5 sekunder (Ctrl+C for å avbryte)..."
    sleep 5
fi
log "Panther Lake (Core Ultra Series 3) detektert"

# ── Steg 1: Fjern pakker som gir konflikt/er overflødige ────────────────────
info "Fjerner gammel i965 VA-API-driver (irrelevant for Xe3, kan forvirre auto-valg)..."
if pacman -Qi libva-intel-driver &>/dev/null; then
    sudo pacman -Rns --noconfirm libva-intel-driver
    log "libva-intel-driver fjernet"
else
    log "libva-intel-driver var ikke installert — ingenting å fjerne"
fi

# ── Steg 2: Installer komplett stack ────────────────────────────────────────
info "Installerer GPU-compute, NPU-driver og AI-rammeverk..."
sudo pacman -S --needed --noconfirm \
    intel-npu-driver \
    intel-npu-compiler \
    intel-compute-runtime \
    openvino \
    openvino-intel-npu-plugin \
    libva-utils \
    vulkan-tools

log "Pakker installert"

# ── Steg 3: Verifiser kernel-driver ─────────────────────────────────────────
echo ""
info "Verifiserer oppsett..."

GPU_PCI=$(lspci | grep "VGA compatible controller: Intel" | awk '{print $1}' | head -1)
if [[ -n "$GPU_PCI" ]]; then
    DRIVER=$(readlink "/sys/bus/pci/devices/0000:${GPU_PCI}/driver" 2>/dev/null | xargs basename 2>/dev/null || echo "ukjent")
    if [[ "$DRIVER" == "xe" ]]; then
        log "GPU kjører på 'xe'-driveren (riktig for Xe3/Panther Lake)"
    else
        warn "GPU kjører på '$DRIVER', ikke 'xe' — sjekk at kernel er 6.17+ og at i915 ikke er tvunget via kernel-parametre"
    fi
fi

NEEDS_REBOOT=false

if [[ -e /dev/accel/accel0 ]]; then
    log "NPU-enhet funnet: /dev/accel/accel0"
    NPU_GROUP=$(stat -c '%G' /dev/accel/accel0)
    if id -nG "$USER" | grep -qw "$NPU_GROUP"; then
        log "Du er allerede medlem av gruppen '$NPU_GROUP' som eier NPU-enheten"
    else
        info "Legger deg til gruppen '$NPU_GROUP' (kreves for NPU-tilgang uten sudo)..."
        sudo usermod -aG "$NPU_GROUP" "$USER"
        NEEDS_REBOOT=true
    fi
else
    err "/dev/accel/accel0 finnes ikke. Sjekk 'sudo dmesg | grep -i vpu' for firmware-feil."
fi

# intel-npu-driver krever alltid reboot for at kernel-modulen (intel_vpu)
# skal registrere seg riktig med det nyinstallerte userspace-laget.
NEEDS_REBOOT=true

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN} Ferdig. Test med (ETTER reboot):${NC}"
echo "   vainfo                        # VA-API / video-akselerasjon"
echo "   vulkaninfo | grep deviceName  # Vulkan ser GPU-en"
echo "   sudo dmesg | grep -i vpu      # NPU-firmware lastet ok"
echo "   groups                        # bekreft gruppemedlemskap"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"

if $NEEDS_REBOOT; then
    echo ""
    warn "REBOOT KREVES: intel_vpu-kernelmodulen og eventuelt nytt gruppemedlemskap"
    warn "trer først i kraft etter omstart — testkommandoene over gir feil/tomt svar før det."
    echo ""
    read -rp "Reboote nå? [J/n] " ans
    case "$ans" in
        n|N|nei|Nei) info "Husk å reboote manuelt før du tester." ;;
        *) info "Rebooter om 5 sekunder (Ctrl+C for å avbryte)..."; sleep 5; sudo reboot ;;
    esac
fi
echo ""
