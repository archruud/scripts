#!/bin/bash
# 14-screenshots/install-screenshot.sh
# Screenshot Setup for Hyprland - grim, slurp, swappy, jq, wl-clipboard

echo "================================================"
echo "  Screenshot Setup for Hyprland"
echo "================================================"
echo ""

echo "Installerer grim, slurp, swappy, jq og wl-clipboard..."
sudo pacman -S --needed --noconfirm grim slurp swappy jq wl-clipboard

echo ""
echo "Oppretter mapper..."
mkdir -p ~/.config/swappy
mkdir -p ~/.config/hypr/scripts
mkdir -p ~/Bilder/Screenshots

echo ""
echo "Setter opp swappy config..."
cat > ~/.config/swappy/config << EOF
[Default]
save_dir=$HOME/Bilder/Screenshots
save_filename_format=screenshot-%Y%m%d-%H%M%S.png
show_panel=false
line_size=5
text_size=20
text_font=sans-serif
EOF

echo ""
echo "Lager screenshot-window.sh script..."
cat > ~/.config/hypr/scripts/screenshot-window.sh << 'EOF'
#!/bin/bash
geometry=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
grim -g "$geometry" - | swappy -f -
EOF
chmod +x ~/.config/hypr/scripts/screenshot-window.sh

# ── Hyprland keybinds ──────────────────────────────────────────────────────
# hyprland.conf brukes ikke lenger etter Lua-migreringen - skriver ALDRI
# dit blindt. Sjekker om bindingene finnes i hyprland.lua, printer dem hvis ikke.
echo ""
HYPR_LUA="$HOME/.config/hypr/hyprland.lua"
if [ -f "$HYPR_LUA" ] && grep -q "screenshot-window.sh" "$HYPR_LUA"; then
    echo "✓ Screenshot-bindinger finnes allerede i hyprland.lua"
else
    echo "⚠ Screenshot-bindinger mangler i hyprland.lua - legg inn manuelt:"
    cat << 'LUABINDS'

    -- Screenshot shortcuts
    hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | swappy -f -"))
    hl.bind(mainMod .. " + CTRL + S",  hl.dsp.exec_cmd("sh -c \"grim - | swappy -f -\""))
    hl.bind(mainMod .. " + ALT + S",   hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot-window.sh"))
LUABINDS
    echo ""
fi

echo ""
echo "================================================"
echo "  Installasjon fullført!"
echo "================================================"
echo ""
echo "Screenshot-shortcuts:"
echo "  Super + Shift + S  = Velg område"
echo "  Super + Ctrl + S   = Hele skjermen"
echo "  Super + Alt + S    = Aktivt vindu"
echo ""
echo "Screenshots lagres i: ~/Bilder/Screenshots"
echo ""
echo "Swappy-funksjonalitet:"
echo "  Save-knapp   = Lagrer til ~/Bilder/Screenshots"
echo "  Copy-knapp   = Kopierer til utklippstavle (kan limes inn her i chatten)"
echo "  Verktøy      = Tegne, tekst, piler, osv."
echo ""
