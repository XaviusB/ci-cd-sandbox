#!/usr/bin/env bash
set -e

source "$(dirname "$0")/common/apt-update.sh"

DOMAIN="devops.active"
DNS_IP="192.168.56.10"
BRIDGE_IP="192.168.0.252"
INTERNAL_NET="192.168.56.0/24"
BRIDGE_NET="192.168.0.0/24"
ZONE_FILE_INTERNAL="/etc/bind/db.${DOMAIN}.internal"
ZONE_FILE_BRIDGE="/etc/bind/db.${DOMAIN}.bridge"

echo "==> Starting DNS server setup"

echo "==> Installing Bind9"

apt_update
apt-get install -y bind9 bind9utils dnsutils

echo "==> Configuring Bind options (forwarding)"
cat >/etc/bind/named.conf.options <<EOF
options {
    directory "/var/cache/bind";

    recursion yes;
    allow-recursion { any; };
    allow-query { any; };

    forwarders {
        8.8.8.8;
    };

    forward only;

    dnssec-validation auto;

    listen-on { any; };
    listen-on-v6 { any; };
};
EOF

echo "==> Configuring Bind main config (views only)"
cat >/etc/bind/named.conf <<EOF
include "/etc/bind/named.conf.options";
include "/etc/bind/named.conf.local";
EOF

echo "==> Configuring local views and zones"
cat >/etc/bind/named.conf.local <<EOF
acl "internal_net" { ${INTERNAL_NET}; };
acl "bridge_net" { ${BRIDGE_NET}; };

view "internal" {
    match-clients { "internal_net"; };
    recursion yes;

    include "/etc/bind/named.conf.default-zones";

    zone "${DOMAIN}" {
        type master;
        file "${ZONE_FILE_INTERNAL}";
    };
};

view "bridge" {
    match-clients { "bridge_net"; };
    recursion yes;

    include "/etc/bind/named.conf.default-zones";

    zone "${DOMAIN}" {
        type master;
        file "${ZONE_FILE_BRIDGE}";
    };
};
EOF

echo "==> Creating internal zone file for ${DOMAIN}"
cat >${ZONE_FILE_INTERNAL} <<EOF
\$TTL 604800
@   IN  SOA ns1.${DOMAIN}. admin.${DOMAIN}. (
        2026020401 ; Serial
        604800     ; Refresh
        86400      ; Retry
        2419200    ; Expire
        604800 )   ; Negative Cache TTL

; Name server
@       IN  NS  ns1.${DOMAIN}.
ns1     IN  A   ${DNS_IP}

; Records
@       IN  A   ${DNS_IP}
haproxy IN  A   ${DNS_IP}
gitea   IN  A   ${DNS_IP}
nexus   IN  A   ${DNS_IP}
runner  IN  A   ${DNS_IP}
kube    IN  A   ${DNS_IP}
k8s     IN  A   ${DNS_IP}

; Wildcard
*       IN  A   ${DNS_IP}
EOF

echo "==> Creating bridge zone file for ${DOMAIN}"
cat >${ZONE_FILE_BRIDGE} <<EOF
\$TTL 604800
@   IN  SOA ns1.${DOMAIN}. admin.${DOMAIN}. (
    2026020401 ; Serial
    604800     ; Refresh
    86400      ; Retry
    2419200    ; Expire
    604800 )   ; Negative Cache TTL

; Name server
@       IN  NS  ns1.${DOMAIN}.
ns1     IN  A   ${BRIDGE_IP}

; Records
@       IN  A   ${BRIDGE_IP}
haproxy IN  A   ${BRIDGE_IP}
gitea   IN  A   ${BRIDGE_IP}
nexus   IN  A   ${BRIDGE_IP}
runner  IN  A   ${BRIDGE_IP}
kube    IN  A   ${BRIDGE_IP}
k8s     IN  A   ${BRIDGE_IP}

; Wildcard
*       IN  A   ${BRIDGE_IP}
EOF

echo "==> Fixing permissions"
chown root:bind ${ZONE_FILE_INTERNAL} ${ZONE_FILE_BRIDGE}
chmod 644 ${ZONE_FILE_INTERNAL} ${ZONE_FILE_BRIDGE}

echo "==> Validating configuration"
named-checkconf
named-checkzone ${DOMAIN} ${ZONE_FILE_INTERNAL}
named-checkzone ${DOMAIN} ${ZONE_FILE_BRIDGE}

echo "==> Daemon reload"
systemctl daemon-reload

echo "==> Restarting Bind9"
systemctl restart named
systemctl enable named

echo
echo "======================================"
echo " DNS forwarding setup complete"
echo
echo " Authoritative zone : ${DOMAIN}"
echo " Forwarder          : 8.8.8.8"
echo " DNS server IP      : ${DNS_IP}"
echo
echo " Test:"
echo "   dig gitea.${DOMAIN} @${DNS_IP}"
echo "   dig google.com @${DNS_IP}"
echo "======================================"
