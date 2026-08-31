#!/bin/bash
# 01-base-system/install-base-system.sh
#
# Steg 1: Grunninstallasjon for Arch Linux / Hyprland
# Slår sammen det som tidligere var 01-base + 02-post-install til ett
# samlet script:
#   1) Installerer yay (AUR-hjelper) om den mangler
#   2) Installerer alle pacman-pakker fra pacman-packages.txt
#   3) Installerer alle AUR-pakker fra aur-packages.txt
#   4) Post-install-fikser: Dolphin-terminal (kitty), "open with", og
#      duplikate XDG-mapper (norsk + engelsk samtidig)
#
# Full dokumentasjon: se base-system-setup.md (docs-server)
#
# Bruk:
#   chmod +x install-base-system.sh
#   ./install-base-system.sh
#
# INSTALL_MODE=interaktiv ./install-base-system.sh   (spør før hver del)

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

INSTALL_MODE="${INSTALL_MODE:-auto}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACMAN_LIST="$SCRIPT_DIR/pacman-packages.txt"
AUR_LIST="$SCRIPT_DIR/aur-packages.txt"

echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo -e "${GREEN}  01-base-system — grunninstallasjon${NC}"
echo -e "${CYAN}  Modus: ${INSTALL_MODE^^}${NC}"
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo ""

read_package_list() {
    local file="$1"
    [ ! -f "$file" ] && return
    grep -v '^#' "$file" | grep -v '^[[:space:]]*$' | awk '{print $1}'
}

spor() {
    local sporsmal="$1"
    if [ "$INSTALL_MODE" = "interaktiv" ]; then
        read -rp "$sporsmal [J/n]: " svar
        svar=${svar:-J}
        [[ "$svar" =~ ^[JjYy]$ ]]
    else
        return 0
    fi
}

# ══════════════════════════════════════════════════════════════
# DEL 1: PAKKER
# ══════════════════════════════════════════════════════════════

# ── Sjekk / installer yay FØRST (AUR-pakkene trenger den) ──────────────────
if ! command -v yay &> /dev/null && ! command -v paru &> /dev/null; then
    echo -e "${YELLOW}Ingen AUR-hjelper (yay/paru) funnet${NC}"
    if spor "Installer yay (AUR-hjelper)?"; then
        echo -e "${GREEN}Installerer yay...${NC}"
        sudo pacman -S --needed --noconfirm base-devel git
        tmpdir=$(mktemp -d)
        git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
        (cd "$tmpdir/yay" && makepkg -si --noconfirm)
        rm -rf "$tmpdir"
        if command -v yay &> /dev/null; then
            echo -e "${GREEN}✓ yay installert${NC}"
        else
            echo -e "${RED}✗ yay installasjon feilet — hopper over AUR-pakker${NC}"
        fi
    fi
fi
echo ""

# ── Pacman-pakker ────────────────────────────────────────────────────────────
if [ -f "$PACMAN_LIST" ]; then
    echo -e "${CYAN}=== Installerer Pacman-pakker ===${NC}"
    echo ""
    PACMAN_PKGS=$(read_package_list "$PACMAN_LIST")

    if [ -n "$PACMAN_PKGS" ]; then
        echo -e "${YELLOW}Pakker som vil bli installert:${NC}"
        echo "$PACMAN_PKGS" | tr '\n' ' '; echo ""; echo ""

        if spor "Installer alle pacman-pakker?"; then
            PKG_STRING=$(echo "$PACMAN_PKGS" | tr '\n' ' ')
            echo -e "${GREEN}Installerer...${NC}"
            if sudo pacman -S --needed --noconfirm $PKG_STRING; then
                echo -e "${GREEN}✓ Pacman-pakker installert${NC}"
            else
                echo -e "${RED}✗ Noen pakker feilet${NC}"
            fi
        else
            echo -e "${YELLOW}Hoppet over pacman-pakker${NC}"
        fi
    else
        echo -e "${YELLOW}Ingen pacman-pakker å installere${NC}"
    fi
else
    echo -e "${YELLOW}Ingen pacman-packages.txt funnet${NC}"
fi
echo ""

# ── AUR-pakker ────────────────────────────────────────────────────────────────
if [ -f "$AUR_LIST" ]; then
    echo -e "${CYAN}=== Installerer AUR-pakker ===${NC}"
    echo ""
    AUR_PKGS=$(read_package_list "$AUR_LIST")

    if [ -n "$AUR_PKGS" ]; then
        echo -e "${YELLOW}Pakker som vil bli installert:${NC}"
        echo "$AUR_PKGS" | tr '\n' ' '; echo ""; echo ""

        if spor "Installer alle AUR-pakker?"; then
            while IFS= read -r pkg; do
                [ -z "$pkg" ] && continue
                echo ""
                echo -e "${GREEN}Installerer: $pkg${NC}"
                if command -v yay &> /dev/null; then
                    yay -S --needed --noconfirm --answerdiff=None --answerclean=None --answeredit=None --answerupgrade=None "$pkg"
                elif command -v paru &> /dev/null; then
                    paru -S --needed --noconfirm "$pkg"
                fi
            done <<< "$AUR_PKGS"
            echo ""
            echo -e "${GREEN}✓ AUR-pakker installert${NC}"
        else
            echo -e "${YELLOW}Hoppet over AUR-pakker${NC}"
        fi
    else
        echo -e "${YELLOW}Ingen AUR-pakker å installere${NC}"
    fi
else
    echo -e "${YELLOW}Ingen aur-packages.txt funnet${NC}"
fi
echo ""

# ══════════════════════════════════════════════════════════════
# DEL 2: POST-INSTALL FIKSER
# ══════════════════════════════════════════════════════════════

echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo -e "${GREEN}  Post-install fikser${NC}"
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo ""

# ── Dolphin-terminal (kitty) ──────────────────────────────────────────────────
echo -e "${BLUE}[1/3] Fikser Dolphin-terminal...${NC}"
sudo ln -sf /usr/share/applications/kitty.desktop /usr/share/applications/org.kde.konsole.desktop

mkdir -p ~/.config
if [ ! -f ~/.config/kdeglobals ]; then
    printf '[General]\nTerminalApplication=kitty\n' > ~/.config/kdeglobals
elif grep -q "TerminalApplication=" ~/.config/kdeglobals; then
    sed -i 's/TerminalApplication=.*/TerminalApplication=kitty/' ~/.config/kdeglobals
elif grep -q "\[General\]" ~/.config/kdeglobals; then
    sed -i '/\[General\]/a TerminalApplication=kitty' ~/.config/kdeglobals
else
    printf '[General]\nTerminalApplication=kitty\n' >> ~/.config/kdeglobals
fi
echo -e "${GREEN}✓ Dolphin-terminal konfigurert${NC}"
echo ""

# ── XDG standardmapper - riktig locale FØR opprettelse, + slå sammen ────────
#       eventuelle duplikater fra en tidligere feilkjøring.
echo -e "${BLUE}[2/3] Oppretter XDG standardmapper (norsk locale)...${NC}"
TARGET_LOCALE="nb_NO.UTF-8"

if ! locale -a 2>/dev/null | grep -qi "^nb_NO.utf8$"; then
    echo -e "${YELLOW}⚠ $TARGET_LOCALE er ikke generert på dette systemet.${NC}"
    echo "  Legg til 'nb_NO.UTF-8 UTF-8' i /etc/locale.gen, kjør 'sudo locale-gen',"
    echo "  og kjør dette scriptet på nytt for at mappenavnene skal bli riktige."
else
    declare -A OLD_PATHS
    for key in DESKTOP DOWNLOAD TEMPLATES PUBLICSHARE DOCUMENTS MUSIC PICTURES VIDEOS; do
        OLD_PATHS[$key]="$(xdg-user-dir "$key" 2>/dev/null || true)"
    done

    LC_ALL="$TARGET_LOCALE" xdg-user-dirs-update --force

    echo -e "${GREEN}✓ Standardmapper (re)generert med $TARGET_LOCALE:${NC}"
    MERGED_ANY=0
    for key in DESKTOP DOWNLOAD TEMPLATES PUBLICSHARE DOCUMENTS MUSIC PICTURES VIDEOS; do
        new_path="$(xdg-user-dir "$key" 2>/dev/null || true)"
        old_path="${OLD_PATHS[$key]}"
        echo "  $key -> $new_path"

        if [ -n "$old_path" ] && [ -n "$new_path" ] && [ "$old_path" != "$new_path" ] && [ -d "$old_path" ]; then
            echo -e "    ${YELLOW}Fant duplikat: $old_path${NC}"
            mkdir -p "$new_path"
            if find "$old_path" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
                mv -n "$old_path"/* "$old_path"/.[!.]* "$new_path"/ 2>/dev/null || true
                MERGED_ANY=1
            fi
            if [ -z "$(ls -A "$old_path" 2>/dev/null)" ]; then
                rmdir "$old_path"
                echo -e "    ${GREEN}Flyttet innhold og fjernet duplikatmappen${NC}"
            else
                echo -e "    ${RED}Kunne ikke fjerne $old_path - noe filnavn kolliderte, sjekk manuelt${NC}"
            fi
        fi
    done
    [ "$MERGED_ANY" -eq 0 ] && echo "  (ingen duplikater å slå sammen)"
fi
echo ""

# ── "Open with" i Dolphin ──────────────────────────────────────────────────
echo -e "${BLUE}[3/3] Fikser 'open with' i Dolphin...${NC}"
sudo pacman -S --needed --noconfirm archlinux-xdg-menu
XDG_MENU_PREFIX=arch- kbuildsycoca6 --noincremental

HYPR_LUA="$HOME/.config/hypr/hyprland.lua"
if [ -f "$HYPR_LUA" ] && grep -q 'hl.env("XDG_MENU_PREFIX"' "$HYPR_LUA"; then
    echo -e "${GREEN}✓ XDG_MENU_PREFIX er allerede satt riktig i hyprland.lua${NC}"
else
    echo -e "${YELLOW}⚠ Fant ikke hl.env(\"XDG_MENU_PREFIX\", \"arch-\") i hyprland.lua${NC}"
    echo "  Legg til denne linjen manuelt:"
    echo '    hl.env("XDG_MENU_PREFIX", "arch-")'
fi
echo ""

echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo -e "${GREEN}  01-base-system fullført!${NC}"
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}VIKTIG:${NC} Logg helt ut av Hyprland og inn igjen (ikke bare hyprctl reload) -"
echo "XDG_MENU_PREFIX og kbuildsycoca6-cachen leses kun ved sesjonsstart."
echo ""
echo -e "${YELLOW}Tips:${NC}"
echo "  - Rediger pacman-packages.txt / aur-packages.txt for å endre pakkevalg"
echo "  - Kjør scriptet igjen for å installere nye pakker (--needed hopper over ferdige)"
