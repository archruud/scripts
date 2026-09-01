#!/usr/bin/env bash
# 02-quickshell-modules/install-quickshell-modules.sh
#
# Steg 2: Quickshell (bar + overview) + Ice SSB (Google Kalender-nettapp)
#
# Detaljert dokumentasjon per widget (allerede på docs-serveren fra før):
#   quickshell-bar.md, quickshell-oversikt.md, quickshell-kalender.md,
#   wvkbd-norsk.md
# Dette scriptet dekker kun SELVE INSTALLASJONEN - se quickshell-modules-
# setup.md for helheten.
#
# Kjør fra mappen der denne fila ligger, sammen med quickshell/ og icons/:
#   chmod +x install-quickshell-modules.sh
#   ./install-quickshell-modules.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QS_SRC="$SCRIPT_DIR/quickshell"
ICONS_SRC="$SCRIPT_DIR/icons"

QS_CONFIG_DIR="$HOME/.config/quickshell"
ICE_DIR="$HOME/.local/share/ice"
ICE_ICONS_DIR="$ICE_DIR/icons"
ICE_FF_PROFILES_DIR="$ICE_DIR/firefox"
APPS_DIR="$HOME/.local/share/applications"

CALENDAR_PROFILE="Kallender3092"
CALENDAR_CLASS="WebApp-Kallender3092"

echo "==> Sjekker AUR-hjelper"
if command -v yay &>/dev/null; then
    AUR_HELPER="yay"
elif command -v paru &>/dev/null; then
    AUR_HELPER="paru"
else
    echo "Ingen yay/paru funnet - installerer yay først."
    sudo pacman -S --needed --noconfirm git base-devel
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
    AUR_HELPER="yay"
fi
echo "    Bruker: $AUR_HELPER"

echo "==> Installerer Quickshell"
"$AUR_HELPER" -S --needed --noconfirm quickshell-git

echo "==> Installerer Ice SSB (nettapp-verktøy for Firefox)"
"$AUR_HELPER" -S --needed --noconfirm ice-ssb

echo "==> Kopierer Quickshell-moduler (bar + overview) til $QS_CONFIG_DIR"
mkdir -p "$QS_CONFIG_DIR"
cp -r "$QS_SRC/bar" "$QS_CONFIG_DIR/"
cp -r "$QS_SRC/overview" "$QS_CONFIG_DIR/"

echo "==> Klargjør Ice sine mapper"
mkdir -p "$ICE_ICONS_DIR" "$ICE_FF_PROFILES_DIR" "$APPS_DIR" "$ICE_DIR/profiles" "$ICE_DIR/epiphany"

echo "==> Legger inn kalender-ikon"
if [ -f "$ICONS_SRC/$CALENDAR_PROFILE.png" ]; then
    cp "$ICONS_SRC/$CALENDAR_PROFILE.png" "$ICE_ICONS_DIR/$CALENDAR_PROFILE.png"
    echo "    Ikon på plass: $ICE_ICONS_DIR/$CALENDAR_PROFILE.png"
else
    echo "    ADVARSEL: fant ikke $ICONS_SRC/$CALENDAR_PROFILE.png - se icons/README.txt"
fi

echo "==> Setter opp Google Kalender som Ice-nettapp ($CALENDAR_PROFILE)"
CHROME_DIR="$ICE_FF_PROFILES_DIR/$CALENDAR_PROFILE/chrome"
mkdir -p "$CHROME_DIR"
cat > "$CHROME_DIR/userChrome.css" << 'CSS_EOF'
#nav-bar, #identity-box, #tabbrowser-tabs, #TabsToolbar {
    visibility: collapse !important;
}
CSS_EOF

cat > "$APPS_DIR/$CALENDAR_PROFILE.desktop" << DESKTOP_EOF
[Desktop Entry]
Type=Application
Name=Google Kalender
Comment=Google Kalender (Ice SSB)
Exec=sh -c "firefox --class $CALENDAR_CLASS --name $CALENDAR_CLASS --profile $ICE_FF_PROFILES_DIR/$CALENDAR_PROFILE --no-remote 'http://calendar.google.com'"
Icon=$ICE_ICONS_DIR/$CALENDAR_PROFILE.png
Categories=Office;Calendar;
StartupWMClass=$CALENDAR_CLASS
Terminal=false
DESKTOP_EOF

echo ""
echo "==> Ferdig."
echo "    Quickshell bar:      $QS_CONFIG_DIR/bar"
echo "    Quickshell overview: $QS_CONFIG_DIR/overview"
echo "    Kalender-profil:     $ICE_FF_PROFILES_DIR/$CALENDAR_PROFILE"
echo ""
echo "Legg til i hyprland.lua (autostart):"
echo '    hl.exec_cmd("qs -c bar")'
echo '    hl.exec_cmd("qs -c overview")'
