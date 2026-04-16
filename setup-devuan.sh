#!/bin/bash
# Exit on first error to prevent partial configuration
set -e

# Define ANSIcolor codes for user-friendly output
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[36m"
RESET="\e[0m"

# ----------------------------- [1/10] Update System -----------------------------
clear
echo -e "${BLUE}########################################${RESET}"
echo -e "${BLUE}#        [1/10] Update System          #${RESET}"
echo -e "${BLUE}########################################${RESET}"
echo 
echo 
echo
# Pause briefly to let user read output
sleep 3 

# Refresh package indexes and upgrade all packages non-interactively
apt update && apt upgrade -y

# Add non-free-firmware (keep your mirror lines; just add the components)
sed -i 's/ main$/ main contrib non-free non-free-firmware/' /etc/apt/sources.list
sed -i 's/ main$/ main contrib non-free non-free-firmware/' /etc/apt/sources.list.d/*.list 2>/dev/null || true
apt update
# Intel microcode + generic firmware bundles
apt install -y intel-microcode firmware-misc-nonfree
# Automatic time update from the internet
apt install chrony
cat > /etc/conf.d/chrony <<'EOF'
# Local OpenRC overrides for chrony
# Ensure chrony only starts after Wi-Fi networking is up

rc_need="net"
rc_after="wireless"
EOF


# Pause briefly to let user read output
sleep 10

# ------------------------------ [2/10] OpenRC Init ------------------------------
clear
echo -e "${BLUE}########################################${RESET}"
echo -e "${BLUE}#         [2/10] OpenRC Init           #${RESET}"
echo -e "${BLUE}########################################${RESET}"
echo 
echo 
echo
# Pause briefly to let user read output
sleep 3 

# Install OpenRC components on Devuan (OpenRC as Init)
apt install -y openrc
# Ensure sbin paths are in the shell path for convenience
echo 'export PATH="$PATH:/sbin:/usr/sbin"' >> ~/.bashrc
# Reload updated shell configuration for current session
source ~/.bashrc

# Pause briefly to let user read output
sleep 10

# ------------------------------ [3/10] SSD Trim Sechedule ------------------------
clear
echo -e "${BLUE}########################################${RESET}"
echo -e "${BLUE}#       [3/10] SSD Trim Schedule       #${RESET}"
echo -e "${BLUE}########################################${RESET}"
echo 
echo 
echo
# Pause briefly to let user read output
sleep 3 

# Schedule weekly TRIM of all supported mounts with OpenRC
printf '#!/bin/sh\n/usr/sbin/fstrim -A -v || true\n' > /etc/cron.weekly/fstrim
chmod +x /etc/cron.weekly/fstrim

# Pause briefly to let user read output
sleep 10

# --------------------------- [4/10] ZRAM Optimization ---------------------------
clear
echo -e "${BLUE}########################################${RESET}"
echo -e "${BLUE}#       [4/10] ZRAM Optimization       #${RESET}"
echo -e "${BLUE}########################################${RESET}"
echo 
echo 
echo
# Pause briefly to let user read output
sleep 3 

# Install zram-tools for compressed swap in RAM
apt install -y zram-tools
# Inform that the OpenRC zram service will be configured
echo -e "${GREEN}[*] OpenRC zram service${RESET}"
# Create OpenRC service script for zramswap
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
    eend $?
}
status() {
    /sbin/zramswap status
}
EOF
# Make the zramswap Init script executable
chmod +x /etc/init.d/zramswap
# Configure compression algorithm and zram size percentage
echo -e "ALGO=zstd\nPERCENT=50\nPRIORITY=100" | tee /etc/default/zramswap >/dev/null
# Configure the swapppiness and VFS cache pressure
echo -e "vm.swappiness=60\nvm.vfs_cache_pressure=50" | tee /etc/sysctl.d/99-custom.conf
# Enable zramswap service at default runlevel and start it now
rc-update add zramswap default
rc-service zramswap start

SWAPFILE="/swapfile"
SWAPSIZE="4G"

## Only create swapfile if it does not already exist
if [ ! -f "$SWAPFILE" ]; then
    echo "Creating $SWAPSIZE disk swapfile at $SWAPFILE"

    ## Allocate swapfile (fallocate is fast; dd fallback handled by kernel)
    fallocate -l "$SWAPSIZE" "$SWAPFILE" 2>/dev/null || \
        dd if=/dev/zero of="$SWAPFILE" bs=1M count=4096

    ## Secure permissions
    chmod 600 "$SWAPFILE"

    ## Make swap area
    mkswap "$SWAPFILE"

    ## Enable swap immediately with lower priority than zram
    swapon -p 10 "$SWAPFILE"

    ## Persist across reboots
    echo "$SWAPFILE none swap sw,pri=10 0 0" >> /etc/fstab
else
    echo "Swapfile already exists — skipping creation"
    swapon "$SWAPFILE" || true
fi

## Show active swap devices
swapon --show

# Pause briefly to let user read output
sleep 10

# ----------------------------- [5/10] XFCE Desktop ------------------------------
clear
echo -e "${BLUE}########################################${RESET}"
echo -e "${BLUE}#         [5/10] XFCE Desktop          #${RESET}"
echo -e "${BLUE}########################################${RESET}"
echo 
echo 
echo
# Pause briefly to let user read output
sleep 3 

# Install desktop, extras, calculator, internet connection manager, display manager, and package manager
apt install -y xfce4 xfce4-goodies galculator internet-manager internet-manager-gnome lightdm synaptic

# Pause briefly to let user read output
sleep 10

# ----------------------- [6/10] Consumer Application ---------------------------
clear
echo -e "${BLUE}########################################${RESET}"
echo -e "${BLUE}#     [6/10] Consumer Application      #${RESET}"
echo -e "${BLUE}########################################${RESET}"
echo 
echo 
echo
# Pause briefly to let user read output
sleep 3 

# Install common applications (web browser, media player, office suite)
apt install -y firefox-esr vlc libreoffice evince
# Install IME (use IBUS for simplicity):
apt-get install -y ibus-mozc
# Install Japanese fonts and Libreoffice addons for Japanese
apt install -y fonts-noto-cjk fonts-noto-cjk-extra fonts-noto-color-emoji libreoffice-l10n-ja

# Pause briefly to let user read output
sleep 10

# --------------------------- [7/10] Developer Tools -----------------------------
clear
echo -e "${BLUE}########################################${RESET}"
echo -e "${BLUE}#       [7/10] Developer Tools         #${RESET}"
echo -e "${BLUE}########################################${RESET}"
echo 
echo 
echo
# Pause briefly to let user read output
sleep 3 

# Announce VS Code installation
echo -e "${GREEN}[*] Microsoft VS Code${RESET}"
# Install prerequisites for adding external repositories
apt install -y wget gpg
# Add Microsoft signing key and VS Code repository
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | tee /etc/apt/sources.list.d/vscode.list > /dev/null
rm -f packages.microsoft.gpg
# Ensure HTTPS transport, refresh index, and install VS Code
apt install -y apt-transport-https
apt update
apt install -y code

# Announce C/C++ environment installation
echo -e "${GREEN}[*] C/C++ environment${RESET}"
# Install build essentials (compiler, linker, make, and headers)
apt install -y build-essential cmake ninja-build gdb valgrind pkgconf manpages-dev

# Announce Miniforge (Python) environment installation
echo -e "${GREEN}[*] Miniforge (Python) environment${RESET}"
# Begin Miniforge global installer block (Standalone Script Embedded Intentionally)
#!/usr/bin/env bash
# Install Miniforge globally (multi-user) on Linux
# - Global install: /opt/miniforge3
# - Available to all users' terminals
# - Per-user envs/pkgs in ~/.conda
# - Detectable by VS Code Python extension
set -euo pipefail
# --- Settings ---
INSTALL_PREFIX="${INSTALL_PREFIX:-/opt/miniforge3}"
PROFILED_FILE="/etc/profile.d/miniforge.sh"
CONDARC_DIR="/etc/conda"
CONDARC_FILE="${CONDARC_DIR}/condarc"
USRBIN_CONDA="/usr/local/bin/conda"
# --- Detect platform/arch and build URL ---
OS="$(uname)"
ARCH="$(uname -m)"
INSTALLER_URL="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-${OS}-${ARCH}.sh"
# --- Idempotency: skip if already installed ---
if [[ -x "${INSTALL_PREFIX}/bin/conda" ]]; then
  echo "Miniforge already appears to be installed at ${INSTALL_PREFIX}"
else
  # --- Download installer ---
  TMPDIR="$(mktemp -d)"
  trap 'rm -rf "$TMPDIR"' EXIT
  INSTALLER="${TMPDIR}/Miniforge3.sh"
  echo "Downloading Miniforge installer for ${OS} ${ARCH} ..."
  wget -q --show-progress -O "${INSTALLER}" "${INSTALLER_URL}"
  echo "Running installer to ${INSTALL_PREFIX} ..."
  bash "${INSTALLER}" -b -p "${INSTALL_PREFIX}"
  # Lock down ownership to root; users will keep envs in ~/.conda
  chown -R root:root "${INSTALL_PREFIX}"
  chmod -R a+rX "${INSTALL_PREFIX}"
fi
# --- Make conda available in all user shells ---
# Provide PATH and shell functions via /etc/profile.d
echo "Configuring ${PROFILED_FILE} ..."
cat > "${PROFILED_FILE}" <<EOF
# Added by Miniforge global installer
# Put miniforge bin on PATH for all users
export PATH="${INSTALL_PREFIX}/bin:\$PATH"
# Load conda shell helpers if available (enables 'conda activate')
if [ -f "${INSTALL_PREFIX}/etc/profile.d/conda.sh" ]; then
    . "${INSTALL_PREFIX}/etc/profile.d/conda.sh"
fi
# Do not auto-activate base for new shells
export CONDA_AUTO_ACTIVATE_BASE=false
EOF
chmod 0644 "${PROFILED_FILE}"
# Also place a stable 'conda' entry in a globally searched location for tools (e.g., VS Code)
# VS Code often invokes 'conda' directly; this symlink helps detection without sourcing shells.
if [[ ! -e "${USRBIN_CONDA}" ]]; then
  ln -s "${INSTALL_PREFIX}/condabin/conda" "${USRBIN_CONDA}"
fi
# --- Global conda configuration for multi-user layout ---
# Ensure each user keeps envs/pkgs in their own home directory
echo "Writing system-wide .condarc at ${CONDARC_FILE} ..."
mkdir -p "${CONDARC_DIR}"
cat > "${CONDARC_FILE}" <<'YAML'
channels:
  - conda-forge
channel_priority: strict
auto_activate_base: false
envs_dirs:
  - ~/.conda/envs
pkgs_dirs:
  - ~/.conda/pkgs
YAML
chmod 0644 "${CONDARC_FILE}"
echo
echo "✅ Miniforge installed globally at: ${INSTALL_PREFIX}"
echo "➡  'conda' symlink: ${USRBIN_CONDA}"
echo "➡  Profile script:  ${PROFILED_FILE}"
echo "➡  System .condarc: ${CONDARC_FILE}"
echo
echo "Next steps for users:"
echo "  - Open a NEW terminal (or source ${PROFILED_FILE})"
echo "  - Create your own environment, e.g.:"
echo "        conda create -n py311 python=3.11"
echo "        conda activate py311"
echo
echo "Notes:"
echo "  • Each user’s envs and package cache will be under ~/.conda/{envs,pkgs}."
echo "  • The base environment is not auto-activated."
echo "  • VS Code’s Python extension will detect 'conda' via /usr/local/bin/conda and PATH."
echo
echo "Uninstall (as root):"
echo "  rm -rf '${INSTALL_PREFIX}'"
echo "  rm -f  '${PROFILED_FILE}' '${USRBIN_CONDA}'"
echo "  rm -rf '${CONDARC_DIR}'   # if you no longer need the global config"
# End Miniforge global installer block

# Pause briefly to let user read output
sleep 10

# ---------------------------- [8/10] Security Setup -----------------------------
clear
echo -e "${BLUE}########################################${RESET}"
echo -e "${BLUE}#        [8/10] Security Setup         #${RESET}"
echo -e "${BLUE}########################################${RESET}"
echo 
echo 
echo
# Pause briefly to let user read output
sleep 3 

# Announce firewall installation
echo "Firewall setup"
# Install and configure the firewall
apt install -y ufw gufw
# Optional: basic policy.
ufw default deny incoming
ufw default allow outgoing
ufw --force enable

# Announce unattended upgrades installation
echo "Unattended upgrades setup"
# Install and configure the unattended upgrades
apt install -y unattended-upgrades
# Enable the daily unattended-upgrades job (cron-based on Debian/Devuan)
cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
# (Optional) A sane default 50unattended-upgrades for security-only updates.
# Adjust the "Origins-Pattern" if your system reports different origins
# (check with: apt-cache policy | sed -n '1,120p').
cat >/etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
// Auto-install only security updates by default.
Unattended-Upgrade::Origins-Pattern {
    "o=Debian,a=stable-security";
    // On Devuan, security updates often come from Debian security.
    // If your system shows different origins, add them here.
    // Example for stable updates too (optional):
    // "o=Debian,a=stable";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
// // Reboot only if needed, at a safe time (optional).
// Unattended-Upgrade::Automatic-Reboot "true";
// Unattended-Upgrade::Automatic-Reboot-Time "02:00";
// // Package blacklist example:
// Unattended-Upgrade::Package-Blacklist {
//  "nvidia-driver";
//  "docker*";
// };
EOF
# Quick dry run to verify configuration (won’t actually install):
unattended-upgrade --dry-run --debug || true

# Pause briefly to let user read output
sleep 10

# ------------------------ [9/10] Cleanup Installation ---------------------------
clear
echo -e "${BLUE}########################################${RESET}"
echo -e "${BLUE}#     [9/10] Cleanup Installation      #${RESET}"
echo -e "${BLUE}########################################${RESET}"
echo 
echo 
echo
# Pause briefly to let user read output
sleep 3 

# Remove unused packages and clean apt caches
apt autoremove -y
apt autoremove --purge -y
apt autoclean
apt clean

# Pause briefly to let user read output
sleep 10

# --------------------------- [10/10] Reboot System -------------------------------
clear
echo -e "${BLUE}########################################${RESET}"
echo -e "${BLUE}#        [10/10] Reboot System         #${RESET}"
echo -e "${BLUE}########################################${RESET}"
echo 
echo 
echo
# Pause briefly to let user read output
sleep 3 

# Pause briefly before rebooting to apply all changes
sleep 10

# Reboot
/sbin/reboot

# TODO
# check "post‑install lock‑down" setup 
