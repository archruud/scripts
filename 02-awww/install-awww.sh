#!/bin/bash
# 02-awww/install-awww.sh
# AWWW - Wayland wallpaper daemon for Hyprland (tidligere swww, omdøpt
# oktober 2025). Kilde: https://codeberg.org/LGFae/awww
#
# Standard: 2560x1440 (archmini/NUC - Lenovo Legion 27Q-10 via HDMI-A-1)
# Andre oppløsninger tilgjengelig for gjenbruk på laptop.

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${GREEN}=== AWWW Setup - Wayland Wallpaper Daemon ===${NC}"
echo ""

WALLPAPER_DIR="$HOME/.config/hypr/wallpapers"
SCRIPTS_DIR="$HOME/.config/hypr/scripts"
AWWW_SCRIPT="$SCRIPTS_DIR/awww-wallpaper.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Installer awww ───────────────────────────────────────────────────────────
if ! command -v awww &> /dev/null; then
    echo -e "${YELLOW}AWWW er ikke installert. Installerer...${NC}"
    if command -v yay &> /dev/null; then
        yay -S --needed --noconfirm awww
    elif command -v paru &> /dev/null; then
        paru -S --needed --noconfirm awww
    else
        echo -e "${RED}Installer awww manuelt: yay -S awww${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ AWWW er allerede installert${NC}"
fi

mkdir -p "$WALLPAPER_DIR" "$SCRIPTS_DIR"

# ── Kopier wallpaper-filer ────────────────────────────────────────────────────
echo -e "${GREEN}Kopierer wallpaper-filer...${NC}"
WALLPAPERS=("ARCHRUUD_2560x1440.png" "ARCHRUUD_1920x1200.png" "ARCHRUUD_2560x1600.png")

for WP in "${WALLPAPERS[@]}"; do
    if [ -f "$SCRIPT_DIR/wallpapers/$WP" ]; then
        cp "$SCRIPT_DIR/wallpapers/$WP" "$WALLPAPER_DIR/"
        echo -e "${GREEN}✓ Kopiert: $WP${NC}"
    elif [ -f "$WALLPAPER_DIR/$WP" ]; then
        echo -e "${CYAN}ℹ Finnes allerede: $WP${NC}"
    else
        echo -e "${YELLOW}⚠ Ikke funnet: $WP (legg den manuelt i $WALLPAPER_DIR)${NC}"
    fi
done

# ── Velg standard wallpaper ──────────────────────────────────────────────────
# BUG FIKSET: spurte aldri egentlig - hardkodet valget uten å lese input.
echo ""
echo -e "${CYAN}Hvilken oppløsning vil du bruke som standard?${NC}"
echo "  1) 2560x1440 (archmini / Lenovo Legion 27Q-10 via HDMI - anbefalt)"
echo "  2) 1920x1200 (laptop)"
echo "  3) 2560x1600 (andre store skjermer)"
read -rp "Valg [1]: " resolution_choice
resolution_choice=${resolution_choice:-1}

case $resolution_choice in
    2) WALLPAPER_FILE="ARCHRUUD_1920x1200.png" ;;
    3) WALLPAPER_FILE="ARCHRUUD_2560x1600.png" ;;
    *) WALLPAPER_FILE="ARCHRUUD_2560x1440.png" ;;
esac

# ── Startup script ────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}Setter opp awww startup script: $AWWW_SCRIPT${NC}"
cat > "$AWWW_SCRIPT" << EOF
#!/bin/bash
WALLPAPER_DIR="\$HOME/.config/hypr/wallpapers"
WALLPAPER_FILE="$WALLPAPER_FILE"
WALLPAPER_PATH="\$WALLPAPER_DIR/\$WALLPAPER_FILE"
SOCKET_FILE="\${XDG_RUNTIME_DIR}/awww-\${WAYLAND_DISPLAY}.socket"
if ! pgrep -x awww-daemon > /dev/null; then awww-daemon & fi
TIMEOUT=10; COUNT=0
until [ -S "\$SOCKET_FILE" ] || [ \$COUNT -ge \$TIMEOUT ]; do sleep 0.5; COUNT=\$((COUNT+1)); done
[ -f "\$WALLPAPER_PATH" ] && awww img "\$WALLPAPER_PATH" --transition-type fade --transition-duration 2 --transition-fps 60
EOF
chmod +x "$AWWW_SCRIPT"
echo -e "${GREEN}✓ Startup script klar${NC}"

# ── Hyprland autostart ────────────────────────────────────────────────────────
# hyprland.conf brukes ikke lenger etter Lua-migreringen - skriver ALDRI dit.
# hyprland.lua har allerede en hl.on("hyprland.start", function() ... end)
# blokk (fra tidligere quickshell/wvkbd-oppsett) - awww-linjen må inn i DEN
# blokken, ikke som en løs toppnivå-linje. Sjekker og gir beskjed.
echo ""
HYPR_LUA="$HOME/.config/hypr/hyprland.lua"
if [ -f "$HYPR_LUA" ] && grep -q "awww-wallpaper.sh" "$HYPR_LUA"; then
    echo -e "${GREEN}✓ awww-wallpaper.sh er allerede i hyprland.lua sin autostart-blokk${NC}"
else
    echo -e "${YELLOW}⚠ Legg denne linjen inn i hl.on(\"hyprland.start\", function() ... end)-blokken din:${NC}"
    echo '    hl.exec_cmd("~/.config/hypr/scripts/awww-wallpaper.sh")'
fi

# ── Test nå ────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}Starter awww nå...${NC}"
bash "$AWWW_SCRIPT"
sleep 2
if pgrep -x awww-daemon > /dev/null; then
    echo -e "${GREEN}✓ AWWW daemon kjører! Wallpaper: $WALLPAPER_FILE${NC}"
else
    echo -e "${RED}✗ AWWW startet ikke. Prøv manuelt: awww-daemon &${NC}"
fi

echo ""
echo -e "${GREEN}=== Setup fullført! ===${NC}"
echo -e "${YELLOW}Kommandoer:${NC}"
echo "  Bytt wallpaper : awww img $WALLPAPER_DIR/ARCHRUUD_2560x1440.png --transition-type fade"
echo "  Stop daemon    : pkill awww-daemon"
