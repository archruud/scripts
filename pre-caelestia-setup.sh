#!/bin/bash
# 🌟 Pre-Caelestia Setup Script 🌟 #
# Installer alle nødvendige pakker før Caelestia dots installasjon
# Passordbehandling, auto-mounting, og systemkonfigurasjon

# Set some colors for output
OK="$(tput setaf 2)[OK]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
ACTION="$(tput setaf 6)[ACTION]$(tput sgr0)"
GREEN="$(tput setaf 2)"
BLUE="$(tput setaf 4)"
RESET="$(tput sgr0)"

# Log file
LOG="pre-caelestia-setup-$(date +%d-%H%M%S).log"

# Create log directory
mkdir -p ~/Install-Logs

printf "\n%s ${GREEN}Starting Pre-Caelestia Setup...${RESET}\n" "${INFO}"

# Function to check if package is installed
check_package() {
    if pacman -Qs "$1" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to install packages
install_packages() {
    local packages=("$@")
    for package in "${packages[@]}"; do
        if ! check_package "$package"; then
            printf "%s Installing ${BLUE}$package${RESET}...\n" "${ACTION}"
            sudo pacman -S --noconfirm "$package" 2>&1 | tee -a "$LOG"
            if [ $? -eq 0 ]; then
                printf "%s ${BLUE}$package${RESET} installed successfully\n" "${OK}"
            else
                printf "%s Failed to install ${BLUE}$package${RESET}\n" "${ERROR}"
            fi
        else
            printf "%s ${BLUE}$package${RESET} already installed\n" "${OK}"
        fi
    done
}

# Essential base packages for Caelestia requirements
printf "\n%s Installing base packages required for Caelestia...\n" "${NOTE}"
BASE_PACKAGES=(
    "git"
    "wget" 
    "curl"
    "gcc"
    "make"
    "cmake"
    "nano"
    "fish"
    "bluez"
    "bluez-utils"
    "sddm"
)

install_packages "${BASE_PACKAGES[@]}"

# Password management and security packages
printf "\n%s Installing password management and security packages...\n" "${NOTE}"
SECURITY_PACKAGES=(
    "gnome-keyring"
    "libsecret"
    "seahorse"              # GUI for gnome-keyring
    "polkit"
    "polkit-gnome"
    "lxqt-policykit"        # Backup polkit agent
)

install_packages "${SECURITY_PACKAGES[@]}"

# Auto-mounting and file management packages
printf "\n%s Installing auto-mounting and file management packages...\n" "${NOTE}"
MOUNT_PACKAGES=(
    "udisks2"
    "udiskie"
    "gvfs"
    "gvfs-mtp"              # For Android devices
    "gvfs-gphoto2"          # For cameras
    "gvfs-afc"              # For iOS devices
    "dolphin"               # Du vil bruke Dolphin
    "dolphin-plugins"
    "kde-cli-tools"         # For Dolphin integrasjon
    "ffmpegthumbs"          # Video thumbnails i Dolphin
)

install_packages "${MOUNT_PACKAGES[@]}"

# Notification and system packages
printf "\n%s Installing notification and system packages...\n" "${NOTE}"
SYSTEM_PACKAGES=(
    "dunst"                 # Notification daemon
    "libnotify"             # Notification library
    "xdg-utils"             # Desktop integration
    "xdg-user-dirs"         # User directories
)

install_packages "${SYSTEM_PACKAGES[@]}"

# Check for AUR helper
printf "\n%s Checking for AUR helper...\n" "${NOTE}"
ISAUR=$(command -v yay || command -v paru)
if [ -z "$ISAUR" ]; then
    printf "%s No AUR helper found. You should install yay first!\n" "${WARN}"
    printf "%s Run your yay installation script before this one.\n" "${INFO}"
else
    printf "%s ${BLUE}AUR helper${RESET} found: $ISAUR\n" "${OK}"
    
    # Install AUR packages
    printf "\n%s Installing AUR packages...\n" "${NOTE}"
    AUR_PACKAGES=(
        "hyprpolkitagent"   # Hyprland-specific polkit agent
    )
    
    for package in "${AUR_PACKAGES[@]}"; do
        printf "%s Installing ${BLUE}$package${RESET} from AUR...\n" "${ACTION}"
        $ISAUR -S --noconfirm "$package" 2>&1 | tee -a "$LOG"
        if [ $? -eq 0 ]; then
            printf "%s ${BLUE}$package${RESET} installed successfully\n" "${OK}"
        else
            printf "%s Failed to install ${BLUE}$package${RESET}\n" "${ERROR}"
        fi
    done
fi

# Enable and configure services
printf "\n%s Configuring services...\n" "${NOTE}"

# Enable Bluetooth
printf "%s Enabling Bluetooth service...\n" "${ACTION}"
sudo systemctl enable bluetooth.service 2>&1 | tee -a "$LOG"
sudo systemctl start bluetooth.service 2>&1 | tee -a "$LOG"

# Enable SDDM
printf "%s Enabling SDDM display manager...\n" "${ACTION}"
sudo systemctl enable sddm.service 2>&1 | tee -a "$LOG"

# Configure PAM for automatic keyring unlock
printf "\n%s Configuring PAM for automatic keyring unlock...\n" "${NOTE}"

# Backup original PAM files
sudo cp /etc/pam.d/login /etc/pam.d/login.backup 2>/dev/null
sudo cp /etc/pam.d/sddm /etc/pam.d/sddm.backup 2>/dev/null

# Add gnome-keyring to PAM login
if ! grep -q "pam_gnome_keyring.so" /etc/pam.d/login; then
    printf "%s Adding gnome-keyring to PAM login configuration...\n" "${ACTION}"
    echo "auth       optional     pam_gnome_keyring.so" | sudo tee -a /etc/pam.d/login
    echo "session    optional     pam_gnome_keyring.so auto_start" | sudo tee -a /etc/pam.d/login
fi

# Add gnome-keyring to PAM sddm
if ! grep -q "pam_gnome_keyring.so" /etc/pam.d/sddm; then
    printf "%s Adding gnome-keyring to PAM SDDM configuration...\n" "${ACTION}"
    echo "auth       optional     pam_gnome_keyring.so" | sudo tee -a /etc/pam.d/sddm
    echo "session    optional     pam_gnome_keyring.so auto_start" | sudo tee -a /etc/pam.d/sddm
fi

# Create directories for user configs
printf "\n%s Creating configuration directories...\n" "${NOTE}"
mkdir -p ~/.config/{hypr,dunst,autostart}

# Create basic udiskie config
printf "%s Creating udiskie configuration...\n" "${ACTION}"
cat > ~/.config/udiskie/config.yml << 'EOF'
program_options:
  udisks_version: 2
  tray: true
  automount: true
  notify: true
  notify_command: notify-send
  file_manager: dolphin
  password_cache: 300

device_config:
  - id_uuid: "*"
    automount: true
    notify: true

notification_actions:
  device_mounted:
    - "notify-send 'Device mounted' '{device_presentation}'"
  device_unmounted:
    - "notify-send 'Device unmounted' '{device_presentation}'"
EOF

# Move log to proper directory
mv "$LOG" ~/Install-Logs/

printf "\n%s ${GREEN}Pre-installation setup completed!${RESET}\n" "${OK}"
printf "\n%s ${BLUE}Next steps:${RESET}\n" "${INFO}"
printf "   1. Run the Caelestia dots installation:\n"
printf "      ${GREEN}curl -fsSL https://raw.githubusercontent.com/caelestia-dots/caelestia/main/install.sh | bash${RESET}\n"
printf "   2. After Caelestia installation, run the post-configuration script\n"
printf "   3. Reboot to start SDDM\n"
printf "   4. Select Hyprland session at login\n"

printf "\n%s ${BLUE}Ready to install Caelestia dots? (y/n):${RESET} " "${INFO}"
read -r install_caelestia

if [[ $install_caelestia =~ ^[Yy]$ ]]; then
    printf "\n%s Starting Caelestia dots installation...\n" "${ACTION}"
    curl -fsSL https://raw.githubusercontent.com/caelestia-dots/caelestia/main/install.sh | bash
    
    if [ $? -eq 0 ]; then
        printf "\n%s ${GREEN}Caelestia dots installed successfully!${RESET}\n" "${OK}"
        printf "%s ${BLUE}Run the post-configuration script next.${RESET}\n" "${INFO}"
    else
        printf "\n%s ${ERROR}Caelestia installation failed. Check the logs.${RESET}\n"
    fi
else
    printf "\n%s You can install Caelestia dots manually later with:\n" "${INFO}"
    printf "   ${GREEN}curl -fsSL https://raw.githubusercontent.com/caelestia-dots/caelestia/main/install.sh | bash${RESET}\n"
fi

printf "\n%s ${GREEN}Setup completed! Check ~/Install-Logs/ for detailed logs.${RESET}\n" "${OK}"