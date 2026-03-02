#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/common/apt-update.sh"

VPN_USER_FILE="/artifacts/vpn-credentials.txt"
OPENVPN_DIR="/etc/openvpn"
SERVER_DIR="/etc/openvpn/server"
EASYRSA_DIR="/etc/openvpn/easy-rsa"
VPN_USER_DEFAULT="vpnuser"
VPN_NET="10.8.0.0 255.255.255.0"

apt_update

echo "==> Installing VPN dependencies"

DEBIAN_FRONTEND=noninteractive apt-get install -y openvpn easy-rsa iptables-persistent

mkdir -p "${SERVER_DIR}"

if [ ! -d "${EASYRSA_DIR}" ]; then
  mkdir -p "${EASYRSA_DIR}"
  cp -r /usr/share/easy-rsa/* "${EASYRSA_DIR}"
fi

cd "${EASYRSA_DIR}"

if [ ! -d "${EASYRSA_DIR}/pki" ]; then
  ./easyrsa init-pki
fi

if [ ! -f "${EASYRSA_DIR}/pki/ca.crt" ]; then
  EASYRSA_BATCH=1 ./easyrsa build-ca nopass
fi

if [ ! -f "${EASYRSA_DIR}/pki/issued/server.crt" ]; then
  EASYRSA_BATCH=1 ./easyrsa build-server-full server nopass
fi

if [ ! -f "${EASYRSA_DIR}/pki/dh.pem" ]; then
  ./easyrsa gen-dh
fi

install -m 600 "${EASYRSA_DIR}/pki/ca.crt" "${SERVER_DIR}/ca.crt"
install -m 600 "${EASYRSA_DIR}/pki/issued/server.crt" "${SERVER_DIR}/server.crt"
install -m 600 "${EASYRSA_DIR}/pki/private/server.key" "${SERVER_DIR}/server.key"
install -m 600 "${EASYRSA_DIR}/pki/dh.pem" "${SERVER_DIR}/dh.pem"

if [ ! -f "${VPN_USER_FILE}" ]; then
  VPN_PASSWORD=$(openssl rand -base64 18 | tr -d "\n")
  cat > "${VPN_USER_FILE}" <<EOF
username=${VPN_USER_DEFAULT}
password=${VPN_PASSWORD}
EOF
  chmod 600 "${VPN_USER_FILE}"
fi

VPN_USER=$(grep -E "^username=" "${VPN_USER_FILE}" | cut -d"=" -f2)
VPN_PASSWORD=$(grep -E "^password=" "${VPN_USER_FILE}" | cut -d"=" -f2)

if ! id "${VPN_USER}" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "${VPN_USER}"
fi

echo "${VPN_USER}:${VPN_PASSWORD}" | chpasswd

cat > "${SERVER_DIR}/server.conf" <<EOF
port 1194
proto udp
dev tun
user nobody
group nogroup
persist-key
persist-tun
topology subnet
server ${VPN_NET}
ifconfig-pool-persist /var/log/openvpn/ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 192.168.56.10"
push "route 192.168.56.0 255.255.255.0"
keepalive 10 120
cipher AES-256-GCM
auth SHA256
data-ciphers AES-256-GCM:AES-128-GCM
explicit-exit-notify 1
verb 3
ca ${SERVER_DIR}/ca.crt
cert ${SERVER_DIR}/server.crt
key ${SERVER_DIR}/server.key
dh ${SERVER_DIR}/dh.pem
plugin /usr/lib/openvpn/openvpn-plugin-auth-pam.so login
verify-client-cert none
username-as-common-name
EOF

cat > /etc/sysctl.d/99-openvpn.conf <<EOF
net.ipv4.ip_forward=1
EOF
sysctl -w net.ipv4.ip_forward=1

WAN_IF=$(ip route get 1.1.1.1 | awk '{for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1); exit}}')
PRIV_IF=$(ip -o -4 addr show | awk '$4 ~ /192\.168\.56\./ {print $2; exit}')

if [ -n "${WAN_IF}" ]; then
  iptables -t nat -C POSTROUTING -s 10.8.0.0/24 -o "${WAN_IF}" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "${WAN_IF}" -j MASQUERADE
  iptables -C FORWARD -s 10.8.0.0/24 -o "${WAN_IF}" -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -s 10.8.0.0/24 -o "${WAN_IF}" -j ACCEPT
  iptables -C FORWARD -d 10.8.0.0/24 -i "${WAN_IF}" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -d 10.8.0.0/24 -i "${WAN_IF}" -m state --state RELATED,ESTABLISHED -j ACCEPT
fi

if [ -n "${PRIV_IF}" ]; then
  iptables -C FORWARD -i tun0 -o "${PRIV_IF}" -s 10.8.0.0/24 -d 192.168.56.0/24 -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -i tun0 -o "${PRIV_IF}" -s 10.8.0.0/24 -d 192.168.56.0/24 -j ACCEPT
  iptables -C FORWARD -i "${PRIV_IF}" -o tun0 -s 192.168.56.0/24 -d 10.8.0.0/24 -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -i "${PRIV_IF}" -o tun0 -s 192.168.56.0/24 -d 10.8.0.0/24 -j ACCEPT
fi

netfilter-persistent save

cat > /artifacts/vpn-client.ovpn <<EOF
client
dev tun
proto udp
remote 192.168.0.252 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth-user-pass
cipher AES-256-GCM
auth SHA256
data-ciphers AES-256-GCM:AES-128-GCM
verb 3
<ca>
$(cat ${SERVER_DIR}/ca.crt)
</ca>
EOF

systemctl enable openvpn-server@server
systemctl restart openvpn-server@server

echo
echo "=========================================="
echo " OpenVPN setup complete"
echo " Credentials: ${VPN_USER_FILE}"
echo " Client profile: /artifacts/vpn-client.ovpn"
echo "=========================================="
