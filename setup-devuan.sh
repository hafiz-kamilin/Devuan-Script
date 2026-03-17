#!/bin/bash
set -e

########################################
# Update
########################################

echo "[1/8] Updating system"

apt update && apt upgrade -y

sleep 10

########################################
# OpenRC
########################################

echo "[2/8] Installing OpenRC"

apt install -y openrc
echo 'export PATH="$PATH:/sbin:/usr/sbin"' >> ~/.bashrc
source ~/.bashrc

sleep 10

########################################
# ZRAM
########################################

echo "[3/8] Installing ZRAM tools"

apt install -y zram-tools

echo "[*] OpenRC zram service"

tee /etc/init.d/zramswap >/dev/null << 'EOF'
#!/sbin/openrc-run
description="ZRAM swap management using zram-tools"
depend() {
    need checkroot
}
start() {
    ebegin "Starting zramswap"
    /sbin/zramswap start
    eend $?
}
stop() {
    ebegin "Stopping zramswap"
    /sbin/zramswap stop
    /sbin/zramswap stop
    eend $?
}
status() {
    /sbin/zramswap status
}
EOF
chmod +x /etc/init.d/zramswap
echo -e "ALGO=zstd\nPERCENT=75" | tee /etc/default/zramswap >/dev/null
rc-update add zramswap default
rc-service zramswap start

sleep 10

########################################
# Desktop
########################################

echo "[4/8] Installing XFCE desktop"

apt install -y xfce4 xfce4-goodies lightdm synaptic

sleep 10

########################################
# Consumer Apps
########################################

echo "[5/8] Installing consumer applications"

apt install -y firefox-esr vlc libreoffice

sleep 10

########################################
# Developer Tools
########################################

echo "[6/8] Installing developer tools"

echo "[*] Microsoft VS Code"

apt install -y wget gpg
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | tee /etc/apt/sources.list.d/vscode.list > /dev/null
rm -f packages.microsoft.gpg
apt install -y apt-transport-https
apt update
apt install -y code

echo "[*] C/C++ environment"

apt install -y build-essential

echo "[*] Miniforge (Python) environment"

wget "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh"
bash Miniforge3-$(uname)-$(uname -m).sh -b
~/miniforge3/bin/conda init
source ~/.bashrc

sleep 10

########################################
# Cleanup
########################################

echo "[7/8] Cleaning up"
apt autoremove -y
apt autoremove --purge -y
apt autoclean
apt clean

sleep 10

########################################
# Reboot
########################################

echo "[8/8] Rebooting now"

echo b > /proc/sysrq-trigger
