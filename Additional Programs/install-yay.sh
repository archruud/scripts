# Slett all lokal yay-cache og config
rm -rf ~/.cache/yay ~/.config/yay

# Erstatt yay med yay-bin
git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-build
cd /tmp/yay-build
makepkg -si