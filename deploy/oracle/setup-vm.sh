#!/bin/sh
# Prepara una VM Ubuntu 22.04/24.04 de Oracle Cloud: Docker, swap y firewall.
# Uso: sudo sh deploy/oracle/setup-vm.sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "Corre con sudo." >&2
  exit 1
fi

# 1. Docker + compose plugin (script oficial).
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi
TARGET_USER="${SUDO_USER:-ubuntu}"
usermod -aG docker "$TARGET_USER"

# 2. Swap de 4 GB: el build de Next.js no cabe en 1 GB de RAM (E2.1.Micro).
if ! swapon --show | grep -q /swapfile; then
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# 3. Firewall del sistema: las imágenes Ubuntu de Oracle bloquean todo salvo
#    SSH con iptables. Abrimos 80 y 443 (además de la Security List en la consola).
for port in 80 443; do
  if ! iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null; then
    iptables -I INPUT 6 -m state --state NEW -p tcp --dport "$port" -j ACCEPT
  fi
done
if command -v netfilter-persistent >/dev/null 2>&1; then
  netfilter-persistent save
else
  apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
  netfilter-persistent save
fi

# 4. Actualizaciones de seguridad automáticas.
DEBIAN_FRONTEND=noninteractive apt-get install -y unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades

echo "VM lista. Cierra sesión SSH y vuelve a entrar para usar docker sin sudo."
