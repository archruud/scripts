#!/bin/bash

# ═════════════════════════════════════════════════════════════
# KITTY BASH SETUP - INSTALLSCRIPT
# Setter opp kitty med bash, minimal prompt og aliaser
# ═════════════════════════════════════════════════════════════

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        KITTY BASH SETUP - MINIMAL PROMPT + ALIASES          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Installer nødvendige pakker
echo "📦 Sjekker og installerer nødvendige pakker..."
echo ""

PACKAGES_NEEDED=()

# Sjekk eza
if ! command -v eza &> /dev/null; then
    echo "  • eza - Ikke installert"
    PACKAGES_NEEDED+=("eza")
else
    echo "  ✅ eza - Allerede installert"
fi

# Sjekk bat
if ! command -v bat &> /dev/null; then
    echo "  • bat - Ikke installert"
    PACKAGES_NEEDED+=("bat")
else
    echo "  ✅ bat - Allerede installert"
fi

# Installer manglende pakker
if [ ${#PACKAGES_NEEDED[@]} -gt 0 ]; then
    echo ""
    echo "📦 Installerer: ${PACKAGES_NEEDED[*]}"
    sudo pacman -S --needed --noconfirm "${PACKAGES_NEEDED[@]}"
    echo "✅ Pakker installert!"
else
    echo ""
    echo "✅ Alle nødvendige pakker er allerede installert!"
fi

echo ""

# Backup eksisterende .bashrc
if [ -f ~/.bashrc ]; then
    echo "📦 Backup av eksisterende .bashrc..."
    cp ~/.bashrc ~/.bashrc.backup-$(date +%Y%m%d-%H%M%S)
    echo "✅ Backup lagret som ~/.bashrc.backup-$(date +%Y%m%d-%H%M%S)"
fi

# Lag ny .bashrc
echo ""
echo "📝 Lager ny .bashrc med minimal prompt og aliaser..."

cat > ~/.bashrc << 'BASHRC_END'
# ~/.bashrc
# Arch Linux Bash Configuration
# Prompt med kun mappnavn + Aliaser fra zshrc

# ═════════════════════════════════════════════════════════════
# BASH CONFIGURATION
# ═════════════════════════════════════════════════════════════

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# History settings
HISTCONTROL=ignoredups:erasedups
shopt -s histappend
HISTSIZE=10000
HISTFILESIZE=20000

# Check window size after each command
shopt -s checkwinsize

# Enable color support
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi

# ═════════════════════════════════════════════════════════════
# BASH PROMPT - Kun mappnavn (ikke full sti)
# ═════════════════════════════════════════════════════════════

# Kun mappnavn: Documents $
# \W = kun siste mappe, \w = full sti
PS1='\[\033[01;34m\]\W\[\033[00m\]\$ '

# ═════════════════════════════════════════════════════════════
# ALIASES - Komplett liste fra din .zshrc
# ═════════════════════════════════════════════════════════════

# ──────────────────────────────────────────────────────────────────────────
# FILVISNING MED EXA (moderne ls med farger og ikoner)
# ──────────────────────────────────────────────────────────────────────────
alias ls='eza -a --icons'                      # Vis alt som standard med ikoner
alias l='eza -la --icons --git'                # Detaljert visning av alt + Git-status
alias lt='eza --tree -a --icons --level=2'     # Trevisning med alt, begrenset dybde
alias lh='eza -la --icons --git --header'      # Detaljert + kolonnenavn øverst

# ──────────────────────────────────────────────────────────────────────────
# PAKKEBEHANDLING - YAY (søker i official + AUR)
# ──────────────────────────────────────────────────────────────────────────
alias i='yay -S --needed'                      # Installer fra ALT (official + AUR)
alias r='yay -Rns'                             # Fjern pakker komplett (med dependencies)
alias u='yay -Syu'                             # Oppdater hele systemet (official + AUR)
alias s='yay -Ss'                              # Søk i ALT (official + AUR)
alias q='yay -Q'                               # Alle installerte pakker
alias qe='yay -Qe'                             # Eksplisitt installerte pakker
alias qm='yay -Qm'                             # AUR/uoffisielle pakker (yay-installerte)
alias qn='yay -Qn'                             # Offisielle pakker (pacman repositories)

# ──────────────────────────────────────────────────────────────────────────
# PAKKEBEHANDLING - PACMAN (søker KUN i official repos)
# ──────────────────────────────────────────────────────────────────────────
alias ii='sudo pacman -S --needed'             # Installer KUN fra official repos
alias rr='sudo pacman -Rns'                    # Fjern med pacman
alias ss='pacman -Ss'                          # Søk KUN i official repos (ingen AUR)
alias uu='sudo pacman -Syu'                    # Oppdater KUN official pakker

# ──────────────────────────────────────────────────────────────────────────
# GIT SHORTCUTS
# ──────────────────────────────────────────────────────────────────────────
alias gc='git clone'                           # Git clone snarvei
alias gs='git status'                          # Git status
alias ga='git add'                             # Git add
alias gp='git push'                            # Git push
alias gl='git log --oneline'                   # Git log (kort format)

# ──────────────────────────────────────────────────────────────────────────
# NANO TEKSTEDITOR
# ──────────────────────────────────────────────────────────────────────────
alias n='nano -l'                              # Nano med linjenummer
alias nn='nano -liT 4'                         # Nano med linjenummer + auto-indent + pene tabs

# ──────────────────────────────────────────────────────────────────────────
# ANDRE NYTTIGE ALIASES
# ──────────────────────────────────────────────────────────────────────────
alias cat='bat'                                # Bat (bedre cat med syntax highlighting)
alias grep='grep --color=auto'                 # Grep med farger
alias ..='cd ..'                               # Opp én mappe
alias ...='cd ../..'                           # Opp to mapper
alias ....='cd ../../..'                       # Opp tre mapper
alias cls='clear'                              # Tøm terminal (Windows-stil)
alias h='history'                              # Vis kommando-historikk

# ──────────────────────────────────────────────────────────────────────────
# HYPRLAND/SYSTEM SHORTCUTS
# ──────────────────────────────────────────────────────────────────────────
alias hyprconf='nano ~/.config/hypr/hyprland.lua'               # Rediger Hyprland config
alias barconf='nano ~/.config/quickshell/bar/widgets/Bar.qml'   # Rediger Quickshell bar (erstatter gammel Waybar)
alias kitconf='nano ~/.config/kitty/kitty.conf'                 # Rediger Kitty config
alias bashconf='nano ~/.bashrc'                                 # Rediger bashrc
alias hyprrules='hyprctl clients'                               # Se window rules
alias hyprlayers='hyprctl layers'                               # Se layers
alias hyprinfo='hyprctl systeminfo'                             # Hyprland info
alias reload='source ~/.bashrc'                                 # Last inn bashrc på nytt

# ──────────────────────────────────────────────────────────────────────────
# SIKKERHETSKOPIERING OG SYSTEM
# ──────────────────────────────────────────────────────────────────────────
alias backup='rsync -avh --progress'           # Rsync med progress
alias df='df -h'                               # Disk usage human-readable
alias free='free -h'                           # Memory usage human-readable
alias ports='netstat -tulanp'                  # Vis åpne porter

# ═════════════════════════════════════════════════════════════
# SLUTT PÅ .BASHRC
# ═════════════════════════════════════════════════════════════
BASHRC_END

echo "✅ .bashrc opprettet!"

# Lag kitty konfigurasjon
echo ""
echo "📝 Setter opp kitty konfigurasjon..."

# Lag kitty config mappe hvis den ikke finnes
mkdir -p ~/.config/kitty

# Backup eksisterende kitty.conf hvis den finnes
if [ -f ~/.config/kitty/kitty.conf ]; then
    cp ~/.config/kitty/kitty.conf ~/.config/kitty/kitty.conf.backup-$(date +%Y%m%d-%H%M%S)
    echo "📦 Backup av kitty.conf lagret"
fi

# Lag ny kitty.conf med god lesbar font
cat > ~/.config/kitty/kitty.conf << 'KITTY_CONF_END'
# ═════════════════════════════════════════════════════════════
# KITTY KONFIGURASJON
# ═════════════════════════════════════════════════════════════

# Font konfigurasjon
# JetBrainsMono Nerd Font er optimal for programmering
# Gode alternativer: FiraCode Nerd Font, Hack Nerd Font, CascadiaCode
font_family      JetBrainsMono Nerd Font
bold_font        auto
italic_font      auto
bold_italic_font auto

# Font størrelse - god lesbar størrelse
font_size 18.0

# Font features
disable_ligatures never

# Cursor
cursor_shape block
cursor_blink_interval 0

# Scrollback
scrollback_lines 10000

# Mouse
mouse_hide_wait 3.0
url_color #0087bd
url_style curly

# Performance
repaint_delay 10
input_delay 3
sync_to_monitor yes

# Window
remember_window_size  yes
initial_window_width  1200
initial_window_height 800
window_padding_width 10

# Tab bar
tab_bar_edge bottom
tab_bar_style powerline
tab_powerline_style slanted

# Color scheme - god kontrast for svart bakgrunn
background_opacity 0.95
background #000000
foreground #ffffff

# Keyboard shortcuts
map ctrl+shift+c copy_to_clipboard
map ctrl+shift+v paste_from_clipboard
map ctrl+shift+t new_tab
map ctrl+shift+w close_tab
map ctrl+shift+right next_tab
map ctrl+shift+left previous_tab
map ctrl+shift+equal change_font_size all +2.0
map ctrl+shift+minus change_font_size all -2.0
map ctrl+shift+0 change_font_size all 0

# Shell
shell bash
KITTY_CONF_END

echo "✅ kitty.conf opprettet med lesbar font (size 18)!"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    INSTALLASJON FULLFØRT!                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "✅ Bash er nå konfigurert med:"
echo "   • Prompt med kun mappnavn: Documents \$"
echo "   • Alle dine siste aliaser fra zshrc"
echo "   • Fungerer i både kitty og andre terminaler"
echo ""
echo "✅ Kitty er nå konfigurert med:"
echo "   • God lesbar font (size 18)"
echo "   • JetBrainsMono Nerd Font"
echo "   • Svart bakgrunn med høy kontrast"
echo "   • Opacity 0.95"
echo ""
echo "⚡ VIKTIG - Last inn ny konfigurasjon:"
echo ""
echo "   source ~/.bashrc"
echo ""
echo "   Åpne ny kitty terminal for å se endringene!"
echo ""
echo "📝 Viktige aliaser:"
echo "   • 'ls'       - Liste filer med ikoner (eza -a)"
echo "   • 'l'        - Detaljert visning med git"
echo "   • 'i <pakke>' - Installer pakke (yay)"
echo "   • 's <pakke>' - Søk etter pakke"
echo "   • 'q'        - Vis alle installerte pakker"
echo "   • 'gc <url>' - Git clone"
echo "   • 'kitconf'  - Rediger kitty.conf"
echo "   • 'reload'   - Last inn bashrc på nytt"
echo ""
echo "🔧 Endre font størrelse (i ~/.config/kitty/kitty.conf):"
echo "   font_size 18.0   # Gjeldende (god lesbar størrelse)"
echo "   font_size 16.0   # Litt mindre"
echo "   font_size 20.0   # Litt større"
echo "   font_size 14.0   # Kompakt"
echo ""
echo "   Eller bruk shortcuts i kitty:"
echo "   • CTRL + SHIFT + =  (gjør større)"
echo "   • CTRL + SHIFT + -  (gjør mindre)"
echo "   • CTRL + SHIFT + 0  (tilbakestill til 18)"
echo ""
echo "💾 Backup:"
echo "   • Bash: ~/.bashrc.backup-[timestamp]"
echo "   • Kitty: ~/.config/kitty/kitty.conf.backup-[timestamp]"
echo ""
