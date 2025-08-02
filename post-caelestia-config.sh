#!/bin/bash
# 🔧 Post-Caelestia Configuration Script 🔧 #
# Konfigurer Hyprland for passordbehandling og auto-mounting etter Caelestia installasjon

# Set some colors for output
OK="$(tput setaf 2)[OK]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
ACTION="$(tput setaf 6)[ACTION]$(tput sgr0)"
GREEN="$(tput setaf 2)"
BLUE="$(tput setaf 4)"
YELLOW="$(tput setaf 3)"
RESET="$(tput sgr0)"

# Log file
LOG="post-caelestia-config-$(date +%d-%H%M%S).log"
mkdir -p ~/Install-Logs

printf "\n%s ${GREEN}Starting Post-Caelestia Configuration...${RESET}\n" "${INFO}"

# Backup original Hyprland config
if [ -f ~/.config/hypr/hyprland.conf ]; then
    printf "%s Backing up original Hyprland configuration...\n" "${ACTION}"
    cp ~/.config/hypr/hyprland.conf ~/.config/hypr/hyprland.conf.backup-$(date +%Y%m%d-%H%M%S)
    printf "%s ${GREEN}Backup created${RESET}\n" "${OK}"
fi

# Function to add configuration if not already present
add_config_if_missing() {
    local config_file="$1"
    local config_line="$2"
    local description="$3"
    
    if ! grep -Fq "$config_line" "$config_file" 2>/dev/null; then
        printf "%s Adding $description to Hyprland config...\n" "${ACTION}"
        echo "$config_line" >> "$config_file"
        printf "%s ${GREEN}Added: $description${RESET}\n" "${OK}"
    else
        printf "%s ${YELLOW}Already configured: $description${RESET}\n" "${INFO}"
    fi
}

# Configure Hyprland for security and auto-mounting
printf "\n%s Configuring Hyprland for passordbehandling og auto-mounting...\n" "${NOTE}"

HYPR_CONFIG="$HOME/.config/hypr/hyprland.conf"

# Add environment variables for better app compatibility
printf "%s Adding environment variables...\n" "${ACTION}"
cat >> "$HYPR_CONFIG" << 'EOF'

# ===== SECURITY AND COMPATIBILITY CONFIGURATION =====
# Environment variables for better desktop integration
env = XDG_CURRENT_DESKTOP,GNOME
env = XDG_SESSION_DESKTOP,gnome
env = XDG_SESSION_TYPE,wayland
env = QT_QPA_PLATFORM,wayland
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env = GDK_BACKEND,wayland,x11

EOF

# Add authentication and security services
printf "%s Adding authentication services...\n" "${ACTION}"
cat >> "$HYPR_CONFIG" << 'EOF'
# ===== AUTHENTICATION AND SECURITY =====
# Polkit authentication agent (choose one based on availability)
exec-once = hyprpolkitagent || exec-once = lxqt-policykit || exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1

# Gnome keyring for password management
exec-once = gnome-keyring-daemon --start --components=secrets,ssh
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE

EOF

# Add auto-mounting and file management
printf "%s Adding auto-mounting services...\n" "${ACTION}"
cat >> "$HYPR_CONFIG" << 'EOF'
# ===== AUTO-MOUNTING AND FILE MANAGEMENT =====
# Auto-mounting daemon with system tray integration
exec-once = udiskie --tray --notify --automount --file-manager=dolphin

# Desktop portal for file dialogs and integration
exec-once = /usr/lib/xdg-desktop-portal-hyprland
exec-once = /usr/lib/xdg-desktop-portal

EOF

# Add notification daemon if not already configured
if ! grep -q "dunst" "$HYPR_CONFIG"; then
    printf "%s Adding notification daemon...\n" "${ACTION}"
    cat >> "$HYPR_CONFIG" << 'EOF'
# ===== NOTIFICATIONS =====
# Notification daemon
exec-once = dunst

EOF
fi

# Create desktop entry for password manager
printf "\n%s Creating desktop entry for Seahorse (password manager)...\n" "${ACTION}"
mkdir -p ~/.local/share/applications

# Create enhanced Seahorse desktop entry
cat > ~/.local/share/applications/seahorse-passwords.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Passwords and Keys
Name[nb]=Passord og nøkler
Comment=Manage your passwords and encryption keys
Comment[nb]=Håndter passord og krypteringsnøkler
Icon=seahorse
Exec=seahorse
Categories=System;Security;
Keywords=Password;Security;Key;Certificate;
StartupNotify=true
EOF

# Create autostart entry for udiskie (backup method)
printf "%s Creating autostart entry for udiskie...\n" "${ACTION}"
mkdir -p ~/.config/autostart

cat > ~/.config/autostart/udiskie.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Udiskie
Comment=Automounter for removable media
Icon=drive-removable-media
Exec=udiskie --tray --notify --automount --file-manager=dolphin
Hidden=false
X-GNOME-Autostart-enabled=true
StartupNotify=false
EOF

# Configure Dolphin for better Wayland support
printf "\n%s Configuring Dolphin for Wayland...\n" "${ACTION}"
mkdir -p ~/.config

# Create Dolphin config for better integration
cat > ~/.config/kdeglobals << 'EOF'
[General]
BrowserApplication=firefox

[KFileDialog Settings]
Recent Files[$e]=
Recent URLs[$e]=
detailViewIconSize=16

[PreviewSettings]
Plugins=imagethumbnail,jpegthumbnail,svgthumbnail,textthumbnail,directorythumbnail
EOF

# Configure dunst for notifications
printf "%s Configuring notification settings...\n" "${ACTION}"
mkdir -p ~/.config/dunst

if [ ! -f ~/.config/dunst/dunstrc ]; then
    cat > ~/.config/dunst/dunstrc << 'EOF'
[global]
    monitor = 0
    follow = none
    width = 300
    height = 300
    origin = top-right
    offset = 10x50
    scale = 0
    notification_limit = 0
    progress_bar = true
    progress_bar_height = 10
    progress_bar_frame_width = 1
    progress_bar_min_width = 150
    progress_bar_max_width = 300
    indicate_hidden = yes
    transparency = 0
    separator_height = 2
    padding = 8
    horizontal_padding = 8
    text_icon_padding = 0
    frame_width = 3
    frame_color = "#aaaaaa"
    separator_color = frame
    sort = yes
    font = Monospace 8
    line_height = 0
    markup = full
    format = "<b>%s</b>\n%b"
    alignment = left
    vertical_alignment = center
    show_age_threshold = 60
    ellipsize = middle
    ignore_newline = no
    stack_duplicates = true
    hide_duplicate_count = false
    show_indicators = yes
    icon_position = left
    min_icon_size = 0
    max_icon_size = 32
    sticky_history = yes
    history_length = 20
    always_run_script = true
    title = Dunst
    class = Dunst
    corner_radius = 0
    ignore_dbusclose = false
    force_xwayland = false
    force_xinerama = false
    mouse_left_click = close_current
    mouse_middle_click = do_action, close_current
    mouse_right_click = close_all

[experimental]
    per_monitor_dpi = false

[urgency_low]
    background = "#222222"
    foreground = "#888888"
    timeout = 10

[urgency_normal]
    background = "#285577"
    foreground = "#ffffff"
    timeout = 10

[urgency_critical]
    background = "#900000"
    foreground = "#ffffff"
    frame_color = "#ff0000"
    timeout = 0
EOF
fi

# Create script for mounting Data disk
printf "\n%s Creating Data disk mounting script...\n" "${ACTION}"
cat > ~/mount-data-disk.sh << 'EOF'
#!/bin/bash
# Script for mounting Data disk from Data.txt

# Colors for output
OK="$(tput setaf 2)[OK]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
INFO="$(tput setaf 4)[INFO]$(tput sgr0)"

# Create mounting point
if [ ! -d ~/Data ]; then
    mkdir ~/Data
    echo "$INFO Created ~/Data directory"
fi

# Check if fstab entry exists
UUID="ae626e33-a4d6-4dc5-8c60-238edfeb1649"
MOUNT_POINT="/home/$USER/Data"
FSTAB_LINE="UUID=$UUID    $MOUNT_POINT    ext4    defaults,rw,user    0    2"

if ! grep -q "$UUID" /etc/fstab; then
    echo "$INFO Adding entry to /etc/fstab..."
    echo "$FSTAB_LINE" | sudo tee -a /etc/fstab
    echo "$OK Added fstab entry"
else
    echo "$INFO Fstab entry already exists"
fi

# Mount the disk
echo "$INFO Mounting Data disk..."
sudo mount -a

# Set permissions
sudo chown -R $USER:$USER $MOUNT_POINT
sudo chmod -R 755 $MOUNT_POINT

# Verify mount
if mountpoint -q $MOUNT_POINT; then
    echo "$OK Data disk mounted successfully at $MOUNT_POINT"
    df -h $MOUNT_POINT
else
    echo "$ERROR Failed to mount Data disk"
fi
EOF

chmod +x ~/mount-data-disk.sh

# Final system check
printf "\n%s Performing final system checks...\n" "${NOTE}"

# Check if keyring is working
printf "%s Checking gnome-keyring status...\n" "${ACTION}"
if pgrep -x gnome-keyring-d > /dev/null; then
    printf "%s ${GREEN}Gnome-keyring is running${RESET}\n" "${OK}"
else
    printf "%s ${YELLOW}Gnome-keyring not running yet (will start on next login)${RESET}\n" "${INFO}"
fi

# Check if SDDM is enabled
printf "%s Checking SDDM service status...\n" "${ACTION}"
if systemctl is-enabled sddm.service > /dev/null 2>&1; then
    printf "%s ${GREEN}SDDM is enabled${RESET}\n" "${OK}"
else
    printf "%s ${ERROR}SDDM is not enabled!${RESET}\n"
fi

# Check if Bluetooth is enabled
printf "%s Checking Bluetooth service status...\n" "${ACTION}"
if systemctl is-enabled bluetooth.service > /dev/null 2>&1; then
    printf "%s ${GREEN}Bluetooth is enabled${RESET}\n" "${OK}"
else
    printf "%s ${ERROR}Bluetooth is not enabled!${RESET}\n"
fi

# Move log file
mv "$LOG" ~/Install-Logs/ 2>/dev/null

printf "\n%s ${GREEN}Post-configuration completed successfully!${RESET}\n" "${OK}"
printf "\n%s ${BLUE}Summary of changes made:${RESET}\n" "${INFO}"
printf "   • Added environment variables for better app compatibility\n"
printf "   • Configured authentication agents (polkit)\n"
printf "   • Set up gnome-keyring for password management\n"
printf "   • Enabled auto-mounting with udiskie\n"
printf "   • Configured Dolphin for Wayland\n"
printf "   • Set up notification daemon (dunst)\n"
printf "   • Created desktop entries and autostart files\n"
printf "   • Prepared Data disk mounting script\n"

printf "\n%s ${BLUE}Final steps:${RESET}\n" "${INFO}"
printf "   1. ${YELLOW}Run the Data disk mounting script: ./mount-data-disk.sh${RESET}\n"
printf "   2. ${YELLOW}Reboot the system to activate all changes${RESET}\n"
printf "   3. ${YELLOW}At SDDM login, select 'Hyprland' session${RESET}\n"
printf "   4. ${YELLOW}After login, open Seahorse to configure password management${RESET}\n"

printf "\n%s ${GREEN}Ready to reboot? Your setup should be complete!${RESET}\n" "${OK}"

printf "\n%s ${BLUE}Want to mount the Data disk now? (y/n):${RESET} " "${INFO}"
read -r mount_now

if [[ $mount_now =~ ^[Yy]$ ]]; then
    printf "\n%s Running Data disk mounting script...\n" "${ACTION}"
    ./mount-data-disk.sh
fi

printf "\n%s ${GREEN}Configuration completed! Logs saved to ~/Install-Logs/${RESET}\n" "${OK}"