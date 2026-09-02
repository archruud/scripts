#!/bin/bash
# 03-sddm/install-sddm-theme.sh
#
# Installerer "archruud" SDDM-temaet - basert på Elarun (innlogging på
# venstre side, som ønsket), med din egen bakgrunn satt inn.
#
# ROTÅRSAK til at bakgrunnen forsvant: SDDM kjører som sin egen systembruker
# "sddm", som IKKE har lesetilgang inn i /home/archruud (normalt 700-
# rettigheter). En bakgrunn som peker til $HOME virker for deg lokalt, men
# SDDM-greeteren finner den aldri - kjent, dokumentert SDDM-oppførsel, ikke
# noe som er spesifikt endret i en oppdatering. SDDM bruker uansett IKKE
# hyprland.lua eller noen Lua-config i det hele tatt; det er et helt separat
# system som starter FØR Hyprland-sesjonen din i det hele tatt kjører.
#
# Løsningen: bakgrunnen kopieres inn i selve temamappen under
# /usr/share/sddm/themes/archruud/images/background.png - en mappe alle
# brukere (inkl. sddm) kan lese.
#
# Config-plassering (bekreftet mot sddm.conf(5) man-side):
#   /usr/lib/sddm/sddm.conf.d/   - systemstandard, IKKE rediger denne
#   /etc/sddm.conf.d/            - lokale endringer, HER skal vi skrive
#   /etc/sddm.conf               - eldre enkeltfil, fungerer men mindre ryddig
#
# Kjør fra mappen der denne fila ligger, sammen med theme/:
#   chmod +x install-sddm-theme.sh
#   ./install-sddm-theme.sh

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_SRC="$SCRIPT_DIR/theme/archruud"
THEME_DEST="/usr/share/sddm/themes/archruud"
WALLPAPER="$HOME/.config/hypr/wallpapers/ARCHRUUD_2560x1440.png"

echo -e "${GREEN}=== SDDM: archruud-tema ===${NC}"
echo ""

echo "==> Installerer sddm hvis den mangler"
sudo pacman -S --needed --noconfirm sddm qt6-svg qt6-declarative

echo "==> Kopierer temaet til $THEME_DEST"
sudo mkdir -p "$THEME_DEST"
sudo cp -r "$THEME_SRC"/* "$THEME_DEST/"

echo "==> Setter inn din bakgrunn"
if [ -f "$WALLPAPER" ]; then
    sudo cp "$WALLPAPER" "$THEME_DEST/images/background.png"
    echo -e "${GREEN}✓ Bakgrunn kopiert fra $WALLPAPER${NC}"
else
    echo -e "${YELLOW}⚠ Fant ikke $WALLPAPER${NC}"
    echo "  Kjør 02-awww først, eller kopier ønsket bilde manuelt til:"
    echo "  $THEME_DEST/images/background.png"
fi

echo "==> Setter globale lese-rettigheter på bildet (kritisk - dette var trolig det som brøt)"
sudo chmod 644 "$THEME_DEST/images/background.png" 2>/dev/null || true
sudo chmod -R a+rX "$THEME_DEST"

echo "==> Aktiverer temaet i /etc/sddm.conf.d/"
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/theme.conf > /dev/null << 'EOF'
[Theme]
Current=archruud
EOF
echo -e "${GREEN}✓ /etc/sddm.conf.d/theme.conf skrevet${NC}"

echo "==> Aktiverer sddm som display manager (om ikke allerede gjort)"
sudo systemctl enable sddm.service

echo ""
echo -e "${GREEN}=== Ferdig ===${NC}"
echo "Test uten å logge ut: sudo sddm-greeter-qt6 --test-mode --theme $THEME_DEST"
echo "(pakkenavn på greeter-testverktøyet kan hete sddm-greeter eller sddm-greeter-qt6"
echo " avhengig av SDDM-versjon - 'sudo pacman -Qi sddm' viser hvilken)"
echo ""
echo -e "${YELLOW}For å oppdatere bakgrunnen senere (f.eks. etter ny awww-wallpaper):${NC}"
echo "  sudo cp \$HOME/.config/hypr/wallpapers/ARCHRUUD_2560x1440.png $THEME_DEST/images/background.png"
