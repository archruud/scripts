#!/bin/bash
# ===========================================
# Make Executable Script
# Gjør .sh filer kjørbare
#
# Bruk:
#   run /path/to/folder    - Alle .sh i mappen
#   run /path/to/file.sh   - Bare én fil
#   run                    - Alle .sh i nåværende mappe
# ===========================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

TARGET="${1:-.}"

if [ ! -e "$TARGET" ]; then
    echo -e "${RED}✗ Feil: $TARGET eksisterer ikke${NC}"
    exit 1
fi

if [ -f "$TARGET" ]; then
    if [[ "$TARGET" == *.sh ]]; then
        chmod +x "$TARGET"
        echo -e "${GREEN}✓${NC} $(basename "$TARGET") er nå kjørbar"
    else
        echo -e "${YELLOW}⚠${NC} $(basename "$TARGET") er ikke en .sh fil"
        # BUG FIKSET: samme problem som i install-run-alias.sh - spurte
        # aldri egentlig, hardkodet "j". Nå leses faktisk svaret ditt.
        read -rp "Vil du gjøre den kjørbar likevel? (j/n): " answer
        if [[ "$answer" =~ ^[jJ]$ ]]; then
            chmod +x "$TARGET"
            echo -e "${GREEN}✓${NC} $(basename "$TARGET") er nå kjørbar"
        fi
    fi
    exit 0
fi

if [ -d "$TARGET" ]; then
    echo -e "${BLUE}Søker etter .sh filer i $TARGET${NC}\n"
    COUNT=0
    while IFS= read -r -d '' file; do
        chmod +x "$file"
        rel_path="${file#$TARGET/}"
        echo -e "${GREEN}✓${NC} $rel_path"
        COUNT=$((COUNT + 1))
    done < <(find "$TARGET" -type f -name "*.sh" -print0)

    if [ $COUNT -eq 0 ]; then
        echo -e "${YELLOW}⚠ Ingen .sh filer funnet${NC}"
    else
        echo -e "\n${GREEN}Ferdig!${NC} Gjorde $COUNT script kjørbare."
    fi
    exit 0
fi

echo -e "${RED}✗ Ukjent type: $TARGET${NC}"
exit 1
