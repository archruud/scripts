#!/bin/bash
# install-kvm-qemu.sh
#
# KVM/QEMU + virt-manager for engangs-testing av nye løsninger på archmini -
# IKKE noe som skal stå og kjøre permanent. Samme bekreftede oppsett som
# ble verifisert fungerende på Medion Erazer (24. feb 2026):
#
#   - NAT via virbr0 (dnsmasq), subnet 192.168.122.0/24
#   - VM-ene får egen intern IP, all trafikk ut går via archminis egen
#     tilkobling - ingen egen IP på VLAN 50, ingenting synlig for resten
#     av nettet
#   - Ingen bridge-konfigurasjon nødvendig

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${GREEN}=== KVM/QEMU testmiljø (NAT, ikke-permanent) ===${NC}"
echo ""

echo -e "${GREEN}Installerer pakker...${NC}"
sudo pacman -S --needed --noconfirm \
    qemu-desktop libvirt virt-manager virt-viewer \
    dnsmasq iptables-nft edk2-ovmf bridge-utils dmidecode

echo -e "${GREEN}Aktiverer libvirt...${NC}"
sudo systemctl enable --now libvirtd.socket

echo -e "${GREEN}Legger til $(whoami) i libvirt + kvm-gruppene...${NC}"
sudo usermod -aG libvirt,kvm "$(whoami)"

echo -e "${GREEN}Starter default NAT-nettverk (virbr0)...${NC}"
if ! sudo virsh net-list --all | grep -q default; then
    echo -e "${YELLOW}Fant ikke default-nettverket - noe uventet, sjekk manuelt med: sudo virsh net-list --all${NC}"
else
    sudo virsh net-start default 2>/dev/null || true
    sudo virsh net-autostart default
fi

mkdir -p "$HOME/.local/share/libvirt/images" "$HOME/.local/share/libvirt/iso"

echo ""
echo -e "${GREEN}=== Ferdig ===${NC}"
echo -e "${YELLOW}VIKTIG:${NC} logg helt ut og inn igjen (eller reboot) for at gruppemedlemskap trer i kraft."
echo ""
echo "Nettverk:  NAT via virbr0, subnet 192.168.122.0/24 - VM-er usynlige for resten av LAN-et"
echo "ISO-er:    legg i ~/.local/share/libvirt/iso/ - dukker opp i Virt-Manager sin filvelger"
echo "Start GUI: virt-manager"
echo ""
echo -e "${YELLOW}Etter en testperiode - fjern alt sporløst igjen:${NC}"
echo "  virsh undefine <vm-navn> --remove-all-storage   # fjern selve VM-en + disk"
echo "  sudo pacman -Rns qemu-desktop libvirt virt-manager virt-viewer dnsmasq edk2-ovmf"
