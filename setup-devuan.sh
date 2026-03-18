#!/bin/bash
set -e

RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[36m"
RESET="\e[0m"

########################################
# Update
########################################

echo -e "${BLUE}[1/9] Updating system${RESET}"

apt update && apt upgrade -y

sleep 10

########################################
# OpenRC
########################################

echo -e "${BLUE}[2/9] Installing OpenRC${RESET}"

apt install -y openrc
echo 'export PATH="$PATH:/sbin:/usr/sbin"' >> ~/.bashrc
source ~/.bashrc

sleep 10

########################################
# ZRAM
########################################

echo -e "${BLUE}[3/9] Installing ZRAM tools${RESET}"

apt install -y zram-tools

echo -e "${GREEN}[*] OpenRC zram service${RESET}"

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
chmod +x /etc/init.d/zramswap
echo -e "ALGO=zstd\nPERCENT=75" | tee /etc/default/zramswap >/dev/null
rc-update add zramswap default
rc-service zramswap start

sleep 10

########################################
# Desktop
########################################

echo -e "${BLUE}[4/9] Installing XFCE desktop${RESET}"

apt install -y xfce4 xfce4-goodies lightdm synaptic

sleep 10

########################################
# Consumer Apps
########################################

echo -e "${BLUE}[5/9] Installing consumer applications${RESET}"

apt install -y firefox-esr vlc libreoffice

sleep 10

########################################
# Developer Tools
########################################

echo -e "${BLUE}[6/9] Installing developer tools${RESET}"

echo -e "${GREEN}[*] Microsoft VS Code${RESET}"

apt install -y wget gpg
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | tee /etc/apt/sources.list.d/vscode.list > /dev/null
rm -f packages.microsoft.gpg
apt install -y apt-transport-https
apt update
apt install -y code

echo -e "${GREEN}[*] C/C++ environment${RESET}"

apt install -y build-essential

echo -e "${GREEN}[*] Miniforge (Python) environment${RESET}"

#!/usr/bin/env bash
# Install Miniforge globally (multi-user) on Linux
# - Global install: /opt/miniforge3
# - Available to all users' terminals
# - Per-user envs/pkgs in ~/.conda
# - Detectable by VS Code Python extension
set -euo pipefail

# --- settings ---
INSTALL_PREFIX="${INSTALL_PREFIX:-/opt/miniforge3}"
PROFILED_FILE="/etc/profile.d/miniforge.sh"
CONDARC_DIR="/etc/conda"
CONDARC_FILE="${CONDARC_DIR}/condarc"
USRBIN_CONDA="/usr/local/bin/conda"

# --- root check ---
if [[ "${EUID}" -ne 0 ]]; then
  echo "This script must be run as root. Try: sudo $0"
  exit 1
fi

# --- detect platform/arch and build URL ---
OS="$(uname)"
ARCH="$(uname -m)"
INSTALLER_URL="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-${OS}-${ARCH}.sh"

# --- idempotency: skip if already installed ---
if [[ -x "${INSTALL_PREFIX}/bin/conda" ]]; then
  echo "Miniforge already appears to be installed at ${INSTALL_PREFIX}"
else
  # --- download installer ---
  TMPDIR="$(mktemp -d)"
  trap 'rm -rf "$TMPDIR"' EXIT
  INSTALLER="${TMPDIR}/Miniforge3.sh"

  echo "Downloading Miniforge installer for ${OS} ${ARCH} ..."
  wget -q --show-progress -O "${INSTALLER}" "${INSTALLER_URL}"

  echo "Running installer to ${INSTALL_PREFIX} ..."
  bash "${INSTALLER}" -b -p "${INSTALL_PREFIX}"

  # lock down ownership to root; users will keep envs in ~/.conda
  chown -R root:root "${INSTALL_PREFIX}"
  chmod -R a+rX "${INSTALL_PREFIX}"
fi

# --- make conda available in all user shells ---
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

# --- global conda configuration for multi-user layout ---
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

sleep 10

########################################
# Security
########################################

echo -e "${BLUE}[7/9] Installing firewall${RESET}"

sudo apt install ufw gufw

sleep 10

########################################
# Cleanup
########################################

echo -e "${BLUE}[8/9] Cleaning up${RESET}"

apt autoremove -y
apt autoremove --purge -y
apt autoclean
apt clean

sleep 10

########################################
# Reboot
########################################

echo -e "${RED}[9/9] Rebooting in 10 seconds${RESET}"

sleep 10

/sbin/reboot
