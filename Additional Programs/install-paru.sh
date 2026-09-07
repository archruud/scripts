rm -rf /tmp/paru-source
git clone https://aur.archlinux.org/paru.git /tmp/paru-source
cd /tmp/paru-source
makepkg -si --noconfirm
cd ~ && rm -rf /tmp/paru-source