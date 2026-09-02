#!/bin/bash
# 10-hyprlock/install-hyprlock.sh
# Hyprlock - låseskjerm med Archruud-bakgrunn, klokke og dato

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${GREEN}=== Hyprlock Setup ===${NC}"
echo ""

HYPRLOCK_CONFIG="$HOME/.config/hypr/hyprlock.conf"
WALLPAPER_DIR="$HOME/.config/hypr/wallpapers"

# ── Installer hyprlock ────────────────────────────────────────────────────────
if ! command -v hyprlock &> /dev/null; then
    echo -e "${YELLOW}Hyprlock er ikke installert. Installerer...${NC}"
    if command -v yay &> /dev/null; then
        yay -S --needed --noconfirm hyprlock
    elif command -v paru &> /dev/null; then
        paru -S --needed --noconfirm hyprlock
    else
        echo -e "${RED}Installer hyprlock manuelt: yay -S hyprlock${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Hyprlock er allerede installert${NC}"
fi

mkdir -p "$HOME/.config/hypr" "$WALLPAPER_DIR"

# ── Velg wallpaper - bruker samme fil som 02-awww allerede har lagt der ────────
# BUG FIKSET: spurte aldri egentlig - hardkodet valget uten å lese input.
echo -e "${CYAN}Hvilken bakgrunn vil du bruke på låseskjermen?${NC}"
echo "  1) ARCHRUUD_2560x1440.png (archmini / NUC - anbefalt)"
echo "  2) ARCHRUUD_1920x1200.png (laptop)"
echo "  3) ARCHRUUD_2560x1600.png (andre store skjermer)"
read -rp "Valg [1]: " resolution_choice
resolution_choice=${resolution_choice:-1}

case $resolution_choice in
    2) WALLPAPER_FILE="ARCHRUUD_1920x1200.png" ;;
    3) WALLPAPER_FILE="ARCHRUUD_2560x1600.png" ;;
    *) WALLPAPER_FILE="ARCHRUUD_2560x1440.png" ;;
esac

if [ ! -f "$WALLPAPER_DIR/$WALLPAPER_FILE" ]; then
    echo -e "${YELLOW}⚠ Fant ikke $WALLPAPER_DIR/$WALLPAPER_FILE${NC}"
    echo "  Kjør 02-awww først (den legger wallpaper-filene på plass), eller"
    echo "  kopier ønsket bilde dit manuelt. Hyprlock bruker fallback-farge inntil da."
fi

# ── hyprlock.conf ─────────────────────────────────────────────────────────────
echo -e "${GREEN}Oppretter hyprlock-konfigurasjon...${NC}"
cat > "$HYPRLOCK_CONFIG" << EOF
# Hyprlock Configuration - Archruud

general {
    grace = 5
    hide_cursor = true
    no_fade_in = false
    no_fade_out = false
}

background {
    monitor =
    path = $WALLPAPER_DIR/$WALLPAPER_FILE
    color = rgba(25, 20, 20, 1.0)
    blur_passes = 3
    blur_size = 7
    brightness = 0.5
    contrast = 0.8
}

input-field {
    monitor =
    size = 300, 50
    outline_thickness = 2
    dots_size = 0.25
    dots_spacing = 0.3
    dots_center = true
    outer_color = rgb(b8e6fd)
    inner_color = rgb(1e1e2e)
    font_color = rgb(cdd6f4)
    fade_on_empty = false
    placeholder_text = <span foreground="##cdd6f4">Skriv passord...</span>
    hide_input = false
    position = 0, -120
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:1000] echo "\$(date +'%H:%M')"
    color = rgba(255, 255, 255, 1.0)
    font_size = 120
    font_family = JetBrains Mono Bold
    position = 0, 200
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:1000] echo "\$(date +'%A, %d %B %Y')"
    color = rgba(255, 255, 255, 0.8)
    font_size = 24
    font_family = JetBrains Mono
    position = 0, 80
    halign = center
    valign = center
}

label {
    monitor =
    text = \$USER
    color = rgba(184, 230, 253, 1.0)
    font_size = 18
    font_family = JetBrains Mono
    position = 0, -180
    halign = center
    valign = center
}
EOF
echo -e "${GREEN}✓ Hyprlock-config opprettet${NC}"

# ── Keybind ────────────────────────────────────────────────────────────────
# hyprland.conf finnes ikke lenger etter Lua-migreringen.
echo ""
HYPR_LUA="$HOME/.config/hypr/hyprland.lua"
if [ -f "$HYPR_LUA" ] && grep -q "exec_cmd(\"hyprlock\")" "$HYPR_LUA"; then
    echo -e "${GREEN}✓ SUPER+L-bind for hyprlock finnes allerede i hyprland.lua${NC}"
else
    echo -e "${YELLOW}⚠ Legg denne linjen inn blant dine andre keybinds:${NC}"
    echo '    hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))'
fi

echo ""
echo -e "${GREEN}=== Hyprlock setup fullført! ===${NC}"
echo -e "${YELLOW}Test:${NC} hyprlock"
echo -e "${YELLOW}Config:${NC} $HYPRLOCK_CONFIG"
echo -e "${YELLOW}Bakgrunn:${NC} $WALLPAPER_DIR/$WALLPAPER_FILE"
echo ""
echo -e "${CYAN}Tips: Hyprlock brukes automatisk av hypridle (09) ved inaktivitet${NC}"
