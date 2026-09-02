#!/bin/bash
# 09-hypridle/install-hypridle.sh
# Hypridle - automatisk dimming/lås/suspend ved inaktivitet

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${GREEN}=== Hypridle Setup ===${NC}"

HYPRIDLE_CONFIG="$HOME/.config/hypr/hypridle.conf"

# ── Installer hypridle ────────────────────────────────────────────────────────
if ! command -v hypridle &> /dev/null; then
    echo -e "${YELLOW}Hypridle er ikke installert. Installerer...${NC}"
    if command -v yay &> /dev/null; then
        yay -S --needed --noconfirm hypridle
    elif command -v paru &> /dev/null; then
        paru -S --needed --noconfirm hypridle
    else
        echo -e "${RED}Feil: Kan ikke finne yay eller paru${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Hypridle er allerede installert${NC}"
fi

# ── Avhengigheter ────────────────────────────────────────────────────────────
if ! command -v hyprlock &> /dev/null; then
    echo -e "${YELLOW}Installerer hyprlock (trengs for locking)...${NC}"
    command -v yay &> /dev/null && yay -S --needed --noconfirm hyprlock
fi
if ! command -v brightnessctl &> /dev/null; then
    echo -e "${YELLOW}Installerer brightnessctl (trengs for dimming)...${NC}"
    sudo pacman -S --needed --noconfirm brightnessctl
fi

mkdir -p "$HOME/.config/hypr"

# ── hypridle.conf ─────────────────────────────────────────────────────────────
echo -e "${GREEN}Oppretter hypridle-konfigurasjon...${NC}"
cat > "$HYPRIDLE_CONFIG" << 'EOF'
general {
    lock_cmd = pidof hyprlock || hyprlock       # Kjør hyprlock hvis den ikke kjører allerede
    before_sleep_cmd = loginctl lock-session    # Lås før suspend
    after_sleep_cmd = hyprctl dispatch dpms on  # Skru på skjerm etter suspend
    ignore_dbus_inhibit = false                 # Ignorer om program blokkerer idle
}

listener {
    timeout = 300                               # 5 minutter
    on-timeout = brightnessctl -s set 10%       # Dimme til 10%
    on-resume = brightnessctl -r                # Gjenopprett lysstyrke
}

listener {
    timeout = 600                               # 10 minutter
    on-timeout = hyprctl dispatch dpms off      # Skru av skjerm
    on-resume = hyprctl dispatch dpms on        # Skru på skjerm
}

listener {
    timeout = 900                               # 15 minutter
    on-timeout = loginctl lock-session          # Lås session
}

listener {
    timeout = 1800                              # 30 minutter
    on-timeout = systemctl suspend              # Suspend system
}
EOF
echo -e "${GREEN}✓ Konfigurasjon opprettet: $HYPRIDLE_CONFIG${NC}"

# ── Hyprland autostart ────────────────────────────────────────────────────────
# hyprland.conf finnes ikke lenger etter Lua-migreringen - scriptet skrev
# tidligere blindt dit med sed, og krasjet med exit 1 hvis filen manglet.
# Sjekker nå hyprland.lua sin autostart-blokk i stedet.
echo ""
HYPR_LUA="$HOME/.config/hypr/hyprland.lua"
if [ -f "$HYPR_LUA" ] && grep -q "hypridle" "$HYPR_LUA"; then
    echo -e "${GREEN}✓ hypridle er allerede i hyprland.lua sin autostart-blokk${NC}"
else
    echo -e "${YELLOW}⚠ Legg denne linjen inn i hl.on(\"hyprland.start\", function() ... end)-blokken din:${NC}"
    echo '    hl.exec_cmd("hypridle")'
fi

echo ""
echo -e "${GREEN}=== Hypridle setup fullført! ===${NC}"
echo -e "${YELLOW}Tips:${NC}"
echo "  - Start nå:   hypridle &"
echo "  - Stopp:      pkill hypridle"
echo "  - Rediger tider: $HYPRIDLE_CONFIG"
echo ""
echo -e "${YELLOW}Timeouts:${NC}"
echo "  300s  (5 min)  - Dimme skjerm til 10%"
echo "  600s  (10 min) - Skru av skjerm"
echo "  900s  (15 min) - Lås skjerm"
echo "  1800s (30 min) - Suspend system"
