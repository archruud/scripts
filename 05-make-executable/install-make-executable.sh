#!/bin/bash
# ===========================================
# Installer make-executable script og alias
# ===========================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}  Installer make-executable script${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}\n"

SCRIPT_DIR="$HOME/.config/hypr/scripts"
SCRIPT_NAME="make-executable.sh"
SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_NAME"

if [ ! -d "$SCRIPT_DIR" ]; then
    echo -e "${YELLOW}Oppretter mappe: $SCRIPT_DIR${NC}"
    mkdir -p "$SCRIPT_DIR"
fi

echo -e "${BLUE}Kopierer script...${NC}"
cp "$(dirname "${BASH_SOURCE[0]}")/make-executable.sh" "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"
echo -e "${GREEN}✓${NC} Script installert: $SCRIPT_PATH\n"

SHELL_NAME=$(basename "$SHELL")
echo -e "${BLUE}Oppdaget shell: $SHELL_NAME${NC}\n"

ALIAS_LINE="alias run='$SCRIPT_PATH'"

case "$SHELL_NAME" in
    bash) CONFIG_FILE="$HOME/.bashrc" ;;
    zsh)  CONFIG_FILE="$HOME/.zshrc" ;;
    fish) CONFIG_FILE="$HOME/.config/fish/config.fish"; mkdir -p "$HOME/.config/fish" ;;
    *)
        echo -e "${YELLOW}⚠ Ukjent shell: $SHELL_NAME${NC}"
        echo -e "Legg til manuelt i din shell config:"
        echo -e "$ALIAS_LINE\n"
        exit 0
        ;;
esac

if grep -q "alias run=" "$CONFIG_FILE" 2>/dev/null; then
    echo -e "${YELLOW}⚠ Alias 'run' finnes allerede i $CONFIG_FILE${NC}"
    # BUG FIKSET: spurte aldri egentlig - hardkodet svaret til "j" uten å lese
    # input. Nå leses faktisk svaret ditt.
    read -rp "Vil du overskrive? (j/n): " answer
    if [[ ! "$answer" =~ ^[jJ]$ ]]; then
        echo -e "\n${GREEN}✓ Installasjon fullført (uten alias)${NC}"
        echo -e "Du kan legge til alias manuelt:"
        echo -e "$ALIAS_LINE\n"
        exit 0
    fi
    sed -i "/alias run=/d" "$CONFIG_FILE"
fi

echo -e "${BLUE}Legger til alias i $CONFIG_FILE${NC}"
echo "" >> "$CONFIG_FILE"
echo "# make-executable script alias" >> "$CONFIG_FILE"
echo "$ALIAS_LINE" >> "$CONFIG_FILE"
echo -e "${GREEN}✓${NC} Alias lagt til\n"

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}  Installasjon fullført!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}\n"
echo -e "For å aktivere alias, kjør:"
echo -e "${GREEN}source $CONFIG_FILE${NC}"
echo -e "\nEller start en ny terminal."
echo -e "\n${YELLOW}Bruk:${NC}"
echo -e "  run /path/to/folder    - Alle .sh i mappen"
echo -e "  run /path/to/file.sh   - Bare én fil"
echo -e "  run                    - Alle .sh i nåværende mappe"
echo ""
