#!/usr/bin/env bash
set -e

DNS_SERVER="192.168.56.10"
NETPLAN_FILE="/etc/netplan/50-vagrant.yaml"

echo "==> Starting DNS client setup"

echo "==> Detecting primary network interface"
IFACE=$(ip route get 192.168.56.0/32 | awk '{print $3}' | head -n1)

if [ -z "$IFACE" ]; then
  echo "ERROR: Could not detect network interface"
  exit 1
fi

echo "==> Using interface: ${IFACE}"

echo "==> Installing yq for YAML manipulation"
if ! command -v yq &> /dev/null; then
  echo "yq not found, installing..."
  curl -sSL -o /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.52.2/yq_linux_amd64
  chmod +x /usr/local/bin/yq
else
  echo "yq is already installed, skipping installation."
fi

if [ ! -f "${NETPLAN_FILE}" ]; then
  echo "ERROR: netplan file ${NETPLAN_FILE} not found"
  exit 1
fi

echo "==> Backing up ${NETPLAN_FILE} to ${NETPLAN_FILE}.bak"
cp -a "${NETPLAN_FILE}" "${NETPLAN_FILE}.bak"

echo "==> Updating netplan with DNS configuration using yq"

# Merge DNS into the detected interface (handles names with dashes/periods)
yq eval ".network.ethernets.\"${IFACE}\".nameservers.addresses = [\"${DNS_SERVER}\"]" -i ${NETPLAN_FILE}
chmod 600 "${NETPLAN_FILE}"

echo "==> Applying netplan"
netplan apply

echo
echo "======================================"
echo " DNS client configuration complete"
echo
echo " Primary DNS : ${DNS_SERVER}"
echo
echo " Verify with:"
echo "   resolvectl status"
echo "   dig gitea.devops.local"
echo "======================================"
