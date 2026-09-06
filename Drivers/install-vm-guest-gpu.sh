#!/bin/bash
# install-vm-guest-gpu.sh
#
# Kjøres INNI Arch/Hyprland-gjesten (ikke på NUC-verten!) etter arch-
# install med "All open-source" som grafikkdriver-valg.
# Gir Venus-akselerert Vulkan/OpenGL via virtio-gpu + virt-manager sitt
# Spice+OpenGL-oppsett på vertsiden (se vm-gpu-setup.md for vertsiden).

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${GREEN}=== VM-gjest: GPU-akselerasjon (Venus/virtio-gpu) ===${NC}"
echo ""

# ── Sjekk at vi faktisk kjører i en VM ────────────────────────────────────────
if command -v systemd-detect-virt &>/dev/null; then
    VIRT=$(systemd-detect-virt || true)
    if [ "$VIRT" = "none" ]; then
        echo -e "${RED}Dette ser IKKE ut som en VM (systemd-detect-virt sier 'none').${NC}"
        echo -e "${YELLOW}Kjører du dette på selve NUC-verten ved en feiltakelse? Avbryter.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Kjører i: $VIRT${NC}"
fi

echo -e "${CYAN}Installerer Vulkan/OpenGL-laget (virtio-gpu-driveren er allerede i kernel)...${NC}"
sudo pacman -S --needed --noconfirm \
    mesa \
    vulkan-icd-loader \
    vulkan-virtio \
    vulkan-mesa-implicit-layers \
    qemu-guest-agent

echo -e "${GREEN}✓ Pakker installert${NC}"

echo -e "${CYAN}Aktiverer qemu-guest-agent (trygg avslutning/status fra virt-manager)...${NC}"
sudo systemctl enable --now qemu-guest-agent
echo -e "${GREEN}✓ qemu-guest-agent kjører${NC}"

echo ""
echo -e "${CYAN}=== Verifisering ===${NC}"
if command -v vulkaninfo &>/dev/null; then
    DEVICE=$(vulkaninfo 2>&1 | grep -m1 "deviceName" || true)
    if [ -z "$DEVICE" ]; then
        echo -e "${RED}✗ Fant ingen deviceName i det hele tatt - vulkaninfo feilet fullstendig.${NC}"
        echo -e "${YELLOW}  Vanligste årsak: 'vulkan-virtio'-pakken manglet (gir selve ICD-fila for${NC}"
        echo -e "${YELLOW}  virtio-gpu). Nå installert av dette scriptet - kjør 'vulkaninfo | grep deviceName' på nytt.${NC}"
        echo -e "${YELLOW}  Hvis den fortsatt feiler: sjekk vertsiden (Video=Virtio+3D accel, Display=Spice+OpenGL).${NC}"
    else
        echo "deviceName: $DEVICE"
        if echo "$DEVICE" | grep -qi "llvmpipe"; then
            echo -e "${RED}✗ Kjører på llvmpipe = ren software-rendering, INGEN GPU-akselerasjon.${NC}"
            echo -e "${YELLOW}  Sjekk vertsiden: Video=Virtio+3D acceleration og Display=Spice+OpenGL må være på,${NC}"
            echo -e "${YELLOW}  se vm-gpu-setup.md. Vanligste årsak: OpenGL-boksen i Display Spice er ikke krysset av.${NC}"
        else
            echo -e "${GREEN}✓ Venus/GPU-akselerasjon virker${NC}"
        fi
    fi
else
    echo -e "${YELLOW}vulkan-tools er ikke installert - installer den for å teste: sudo pacman -S vulkan-tools${NC}"
fi

echo ""
echo -e "${GREEN}=== Ferdig ===${NC}"
echo "Test manuelt når som helst med:"
echo "  vulkaninfo | grep deviceName"
echo "  glxinfo | grep 'OpenGL renderer'   # krever mesa-utils"
