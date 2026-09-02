#!/bin/bash

################################################################################
#  NETTVERKS & SAMBA CLIENT INSTALLASJON
#  Arch Linux + Hyprland + Dolphin
#  GitHub: https://github.com/archruud/arch-hypr-dots
#
#  FIKSET (2026):
#  - Reparert ødelagt shebang (nbtscan på linje 1)
#  - Fjernet: gvfs-google, gvfs-goa, gvfs-dnssd (ikke i Arch-repoene)
#  - Fjernet: exfat-utils (erstattet av exfatprogs), p7zip (erstattet av 7zip)
#  - Fjernet: curlftpfs (ikke lenger vedlikeholdt)
#  - Lagt til: automatisk loggfil
#  - set -e fjernet — installer fortsetter selv om enkeltpakker feiler
################################################################################

# ── Loggfil — all output lagres automatisk ───────────────────────────────────
LOGFILE="$HOME/install-18-network-$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOGFILE") 2>&1
echo "════════════════════════════════════════════════════"
echo " 18-network installasjonslogg"
echo " Startet: $(date)"
echo " Logg: $LOGFILE"
echo "════════════════════════════════════════════════════"
echo ""

# ── Farger ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'
YELLOW='\033[1;33m'; NC='\033[0m'

log()     { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[ADVARSEL]${NC} $1"; }
error()   { echo -e "${RED}[FEIL]${NC} $1"; }

# ── Sjekk root ────────────────────────────────────────────────────────────────
if [ "$EUID" -eq 0 ]; then error "Ikke kjør som root!"; exit 1; fi

echo "=== Komplett Nettverks & Samba Client Script ==="
echo "Konfigurerer: Samba client, NFS, SSH, Avahi, Dolphin integrasjon"
echo ""

# ── 1. Oppdater pakkedatabaser ────────────────────────────────────────────────
log "Oppdaterer pakkedatabaser..."
sudo pacman -Sy --noconfirm

# ── 2. Pakkelister ────────────────────────────────────────────────────────────

# Pakker som finnes i Arch-repoene (verifisert 2026)
PACMAN_PACKAGES=(
    # SMB/CIFS
    "smbclient"              # SMB protocol driver
    "cifs-utils"             # CIFS filesystem driver
    "gvfs-smb"               # GVFS SMB backend for Dolphin

    # Network discovery
    "avahi"                  # mDNS/Bonjour protocol driver
    "nss-mdns"               # Name resolution via mDNS

    # NFS
    "nfs-utils"              # NFS protocol driver
    "gvfs-nfs"               # GVFS NFS backend for Dolphin

    # SSH/SFTP
    "openssh"                # SSH/SFTP protocol driver

    # Mobile enheter
    "gvfs-mtp"               # Android MTP protocol
    "gvfs-afc"               # iOS AFC protocol
    "gvfs-gphoto2"           # Kamera/telefon protocol

    # Bluetooth
    "bluez"                  # Bluetooth protocol stack
    "bluez-utils"            # Bluetooth utilities
    "pipewire-pulse"         # PipeWire Bluetooth audio

    # KDE/Dolphin integrasjon
    "kio-extras"             # Extra KIO protocols for Dolphin
    "kdeconnect"             # KDE Connect for mobil

    # Nettverksverktøy
    "wget"
    "curl"
    "rsync"
    "nmap"                   # Nettverksskanning
    "nbtscan"                # NetBIOS scanner (installeres FØR bruk!)

    # Filsystem-støtte
    "ntfs-3g"                # NTFS
    "exfatprogs"             # exFAT (erstatter exfat-utils)
    "dosfstools"             # FAT

    # Arkiv
    "unzip"
    "7zip"                   # Erstatter p7zip

    # Filbehandler
    "dolphin"
)

# AUR-pakker (valgfritt)
AUR_PACKAGES=(
    "kio-gdrive"             # Google Drive i Dolphin (erstatter gvfs-google)
)

# ── 3. Installer pacman-pakker ────────────────────────────────────────────────
echo ""
log "Installerer ${#PACMAN_PACKAGES[@]} nettverkspakker..."
echo "📦 Fokus: Maksimal protokoll-støtte i Dolphin"
echo ""

FAILED_PACKAGES=()
for pkg in "${PACMAN_PACKAGES[@]}"; do
    if sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null; then
        success "$pkg"
    else
        warning "$pkg — ikke funnet, hopper over"
        FAILED_PACKAGES+=("$pkg")
    fi
done

if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
    echo ""
    warning "Disse pakkene feilet: ${FAILED_PACKAGES[*]}"
fi

# ── 4. AUR-pakker (hvis yay finnes) ──────────────────────────────────────────
echo ""
if command -v yay &>/dev/null; then
    log "Installerer AUR-pakker..."
    for pkg in "${AUR_PACKAGES[@]}"; do
        if yay -S --needed --noconfirm "$pkg" 2>/dev/null; then
            success "$pkg (AUR)"
        else
            warning "$pkg (AUR) — ikke funnet, hopper over"
        fi
    done
else
    warning "yay ikke installert — hopper over AUR-pakker"
    echo "   Installer manuelt for Google Drive i Dolphin: yay -S kio-gdrive"
fi

# ── 5. Avahi/mDNS ─────────────────────────────────────────────────────────────
echo ""
log "Konfigurerer Avahi og mDNS..."

sudo systemctl enable --now avahi-daemon.service && \
    success "Avahi daemon aktivert" || warning "Avahi daemon feilet"

if ! grep -q "mdns_minimal" /etc/nsswitch.conf; then
    sudo sed -i 's/hosts: files dns/hosts: files mdns_minimal [NOTFOUND=return] dns/' \
        /etc/nsswitch.conf && success "NSS konfigurert for mDNS" || warning "nsswitch.conf feilet"
else
    success "NSS allerede konfigurert for mDNS"
fi

# ── 6. SMB CLIENT konfigurasjon ───────────────────────────────────────────────
echo ""
log "Konfigurerer SMB CLIENT (ikke server)..."

sudo mkdir -p /etc/samba

cat << 'SMBCONF' | sudo tee /etc/samba/smb.conf > /dev/null
[global]
   # PURE CLIENT - INGEN server funksjoner
   workgroup = WORKGROUP
   server string = Arch Linux SMB Client
   netbios name = ARCHRUUD-LAPTOP

   security = user
   client min protocol = NT1
   client max protocol = SMB3

   name resolve order = lmhosts wins bcast host
   dns proxy = no

   local master = no
   domain master = no
   preferred master = no
   os level = 0

   socket options = TCP_NODELAY SO_RCVBUF=131072 SO_SNDBUF=131072

   load printers = no
   disable spoolss = yes

   log file = /var/log/samba/client.log
   max log size = 1000
   log level = 1
SMBCONF

success "SMB CLIENT-only konfigurert"

# ── 7. Mount points ───────────────────────────────────────────────────────────
echo ""
log "Oppretter mount points..."
for dir in /mnt/network /mnt/smb /mnt/nfs /mnt/ftp; do
    sudo mkdir -p "$dir"
    sudo chown "$USER:$USER" "$dir"
done
success "Mount points opprettet"

# ── 8. Dolphin nettverksplasser ───────────────────────────────────────────────
echo ""
log "Konfigurerer Dolphin nettverksplasser..."

mkdir -p "$HOME/.local/share/kio"
mkdir -p "$HOME/.local/share/dolphin"

cat << 'XBEL' > "$HOME/.local/share/user-places.xbel"
<?xml version="1.0" encoding="UTF-8"?>
<xbel xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks"
      xmlns:mime="http://www.freedesktop.org/standards/shared-mime-info">
 <bookmark href="network:/">
  <title>Network</title>
  <info><metadata owner="http://freedesktop.org">
   <bookmark:icon name="folder-remote"/>
  </metadata></info>
 </bookmark>
 <bookmark href="smb:/">
  <title>Windows Network (SMB)</title>
  <info><metadata owner="http://freedesktop.org">
   <bookmark:icon name="folder-network"/>
  </metadata></info>
 </bookmark>
 <bookmark href="ftp:/">
  <title>FTP Servere</title>
  <info><metadata owner="http://freedesktop.org">
   <bookmark:icon name="folder-download"/>
  </metadata></info>
 </bookmark>
 <bookmark href="remote:/">
  <title>Remote Resources</title>
  <info><metadata owner="http://freedesktop.org">
   <bookmark:icon name="folder-remote"/>
  </metadata></info>
 </bookmark>
</xbel>
XBEL

success "Dolphin nettverksplasser konfigurert"

# ── 9. Helper scripts ─────────────────────────────────────────────────────────
echo ""
log "Oppretter helper scripts i ~/.local/bin/..."
mkdir -p "$HOME/.local/bin"

# scan-network
cat << 'SCANSCRIPT' > "$HOME/.local/bin/scan-network"
#!/bin/bash
echo "=== Nettverksskanning ==="
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)
CURRENT_NETWORK=$(ip addr show "$INTERFACE" 2>/dev/null | grep "inet " | awk '{print $2}' | head -1)

echo "Interface: $INTERFACE | Gateway: $GATEWAY | Nettverk: $CURRENT_NETWORK"
echo ""

echo "🔍 Skanner alle VLANer (10, 20, 30, 40, 50, 75):"
for vlan in 10 20 30 40 50 75; do
    echo ""
    echo "VLAN $vlan — 192.168.$vlan.0/24:"
    hosts=$(nmap -sn "192.168.$vlan.0/24" 2>/dev/null | grep "Nmap scan report" | wc -l)
    if [ "$hosts" -gt 0 ]; then
        nmap -sn "192.168.$vlan.0/24" 2>/dev/null | grep "Nmap scan report" | sed 's/Nmap scan report for /  ✅ /'
    else
        echo "  ❌ Ingen enheter funnet"
    fi
done

echo ""
echo "🔍 mDNS/Avahi Discovery:"
if command -v avahi-browse &>/dev/null; then
    for svc in _http._tcp _smb._tcp _ssh._tcp _ftp._tcp; do
        echo "$svc:"; timeout 3 avahi-browse -rt "$svc" 2>/dev/null | grep "hostname" | sort -u || true
    done
fi

echo ""
echo "🔍 NetBIOS skanning:"
if command -v nbtscan &>/dev/null; then
    nbtscan "$CURRENT_NETWORK" 2>/dev/null | grep -v "^$" || true
fi

echo ""
echo "🎯 Tips:"
echo "  smbclient -L //IP        # List SMB shares"
echo "  mount-smb //server/share /mnt/smb/share"
echo "  dolphin smb:/            # Åpne i Dolphin"
SCANSCRIPT
chmod +x "$HOME/.local/bin/scan-network"

# mount-smb
cat << 'MOUNTSCRIPT' > "$HOME/.local/bin/mount-smb"
#!/bin/bash
if [ $# -lt 2 ]; then
    echo "Bruk: mount-smb //server/share mountpoint [bruker] [passord]"
    exit 1
fi

SHARE="$1"; MOUNTPOINT="$2"
USERNAME="${3:-guest}"; PASSWORD="$4"

sudo mkdir -p "$MOUNTPOINT"
OPTS="uid=$UID,gid=$GID,iocharset=utf8,file_mode=0644,dir_mode=0755"
[ "$USERNAME" = "guest" ] && OPTS="$OPTS,guest" || OPTS="$OPTS,username=$USERNAME"
[ -n "$PASSWORD" ] && OPTS="$OPTS,password=$PASSWORD"

for VER in "3.0" "2.1" "2.0"; do
    echo "Prøver SMB $VER..."
    if sudo mount -t cifs "$SHARE" "$MOUNTPOINT" -o "$OPTS,vers=$VER" 2>/dev/null; then
        echo "✓ Montert med SMB $VER → $MOUNTPOINT"
        echo "Avmonter: sudo umount $MOUNTPOINT"
        exit 0
    fi
done
echo "❌ Montering feilet — prøv: sudo mount -t cifs $SHARE $MOUNTPOINT -o username=BRUKER"
MOUNTSCRIPT
chmod +x "$HOME/.local/bin/mount-smb"

# test-protocols
cat << 'TESTSCRIPT' > "$HOME/.local/bin/test-protocols"
#!/bin/bash
echo "=== Protokoll-test ==="
check() { command -v "$2" &>/dev/null && echo "✓ $1" || echo "✗ $1 mangler"; }
check_svc() { systemctl is-active "$2" &>/dev/null && echo "✓ $1 kjører" || echo "✗ $1 kjører ikke"; }

check "SMB client"  smbclient
check "NFS client"  mount.nfs
check "SSH"         ssh
check "nmap"        nmap
check "nbtscan"     nbtscan
check_svc "Avahi"   avahi-daemon
check_svc "NetworkManager" NetworkManager

echo ""
echo "🐬 Dolphin URL-er å teste:"
echo "  smb:/    ftp://server    sftp://server"
echo "  mtp:/    afc:/           remote:/"
TESTSCRIPT
chmod +x "$HOME/.local/bin/test-protocols"

success "Helper scripts opprettet"

# ── 10. Hyprland keybinds ─────────────────────────────────────────────────────
# hyprland.conf brukes ikke lenger etter Lua-migreringen - keybinds skrives
# ALDRI dit blindt. I stedet: sjekk om hl.bind for nettverk allerede finnes
# i hyprland.lua, og hvis ikke, print de fire linjene du selv legger inn.
echo ""
HYPR_LUA="$HOME/.config/hypr/hyprland.lua"
if [ -f "$HYPR_LUA" ] && grep -q "dolphin smb:/" "$HYPR_LUA"; then
    success "Network keybinds finnes allerede i hyprland.lua"
else
    warning "Network keybinds mangler i hyprland.lua - legg inn manuelt:"
    cat << 'LUABINDS'

    -- Network keybinds
    hl.bind(mainMod .. " + N",         hl.dsp.exec_cmd("dolphin smb:/"))
    hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("dolphin remote:/"))
    hl.bind(mainMod .. " + CTRL + N",  hl.dsp.exec_cmd("dolphin mtp:/"))
    hl.bind(mainMod .. " + ALT + N",   hl.dsp.exec_cmd("~/.local/bin/scan-network"))
LUABINDS
    echo ""
fi

# ── 11. Stopp server-tjenester ────────────────────────────────────────────────
echo ""
log "Sikrer CLIENT-only konfigurasjon..."
for svc in smbd nmbd winbind vsftpd; do
    if systemctl is-enabled "$svc" &>/dev/null 2>&1; then
        sudo systemctl stop "$svc" 2>/dev/null || true
        sudo systemctl disable "$svc" 2>/dev/null || true
        warning "$svc stoppet og deaktivert"
    fi
done
success "Kun CLIENT-tjenester aktive"

# ── 12. Verifisering ──────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════════"
echo " Verifisering"
echo "══════════════════════════════════════════════════════════════"
"$HOME/.local/bin/test-protocols"

# ── 13. Ferdig ────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════════"
echo " ✅ 18-network installasjon fullført!"
echo "══════════════════════════════════════════════════════════════"
echo ""
echo "🐬 Dolphin støtter nå:"
echo "   smb:/  nfs:/  sftp://  mtp:/  afc:/  remote:/"
if command -v kio-gdrive &>/dev/null 2>&1 || pacman -Qi kio-gdrive &>/dev/null 2>&1; then
    echo "   gdrive:/  (Google Drive via kio-gdrive)"
else
    echo "   Google Drive: installer med  yay -S kio-gdrive"
fi
echo ""
echo "⌨️  Keybinds:  Super+N=SMB  Super+Shift+N=Remote  Super+Alt+N=Skanning"
echo ""
echo "📋 Full logg lagret: $LOGFILE"
echo ""

# Tilby nettverksskanning
read -rp "Vil du kjøre nettverksskanning nå? [j/N]: " SVAR
if [[ "$SVAR" =~ ^[jJ]$ ]]; then
    "$HOME/.local/bin/scan-network"
fi

read -rp "Åpne SMB browser i Dolphin? [j/N]: " SVAR2
if [[ "$SVAR2" =~ ^[jJ]$ ]]; then
    dolphin smb:/ &
fi

success "18-network ferdig!"
