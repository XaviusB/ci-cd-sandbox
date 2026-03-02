#!/usr/bin/env bash
set -e

source "$(dirname "$0")/common/apt-update.sh"

PROXY_PORT=3128
PROXY_USER="squid"
SQUID_CERT_DIR="/etc/squid/ssl_cert"
CA_CERT="/etc/haproxy/certs/devops-active-CA.crt"
CA_KEY="/etc/haproxy/certs/devops-active-CA.key"

echo "==> Starting HTTP Proxy (Squid) setup with SSL-Bump"

echo "==> Installing dependencies"

apt_update
apt-get install -y squid-openssl net-tools ssl-cert

echo "==> Setting up SSL certificates for Squid"

mkdir -p ${SQUID_CERT_DIR}

cp "${CA_CERT}" "${SQUID_CERT_DIR}/ca.crt"
cp "${CA_KEY}" "${SQUID_CERT_DIR}/ca.key"
chmod 600 "${SQUID_CERT_DIR}/ca.key"
chown -R proxy:proxy "${SQUID_CERT_DIR}"
echo "    Using existing HAProxy CA for SSL-Bump"

echo "==> Initializing SSL certificate database"
mkdir -p /var/lib/squid
chown -R proxy:proxy /var/lib/squid
rm -rf /var/lib/squid/ssl_db
sudo -u proxy /usr/lib/squid/security_file_certgen -c -s /var/lib/squid/ssl_db -M 20MB


echo "==> Creating Squid configuration"
cat > /etc/squid/squid.conf <<EOF
# HTTP port with SSL-Bump support
http_port ${PROXY_PORT} ssl-bump \
    cert=${SQUID_CERT_DIR}/ca.crt \
    key=${SQUID_CERT_DIR}/ca.key \
    generate-host-certificates=on \
    dynamic_cert_mem_cache_size=4MB

# SSL certificate generator
sslcrtd_program /usr/lib/squid/security_file_certgen -s /var/lib/squid/ssl_db -M 20MB
sslcrtd_children 5

# Access Control Lists
acl localnet src 192.168.0.0/16
acl localnet src 10.0.0.0/8
acl localnet src 172.16.0.0/12
acl localnet src fc00::/7
acl localnet src fe80::/10

acl k8s_api dstdomain k8s.devops.active
acl devops_domains dstdomain .devops.active
acl SSL_ports port 443
acl SSL_ports port 6443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777

acl CONNECT method CONNECT

# SSL-Bump configuration
# Bump (intercept) devops.active domains to add X-Forwarded-For
# Splice (passthrough) everything else
acl step1 at_step SslBump1
acl step2 at_step SslBump2
acl step3 at_step SslBump3

ssl_bump peek step1 all
ssl_bump bump devops_domains
ssl_bump splice all

# TLS settings
tls_outgoing_options flags=DONT_VERIFY_PEER

# Allow rules
http_access allow localhost manager
http_access deny manager
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localnet
http_access allow localhost
http_access deny all

# Forward client IP information (works for HTTP and bumped HTTPS)
forwarded_for on
follow_x_forwarded_for allow localnet
request_header_access X-Forwarded-For allow all

# Logging
access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log
logfile_rotate 10

# Memory cache
cache_mem 256 MB
maximum_object_size_in_memory 512 KB

# Disk cache
cache_dir ufs /var/spool/squid 1000 16 256
maximum_object_size 512 MB

# Performance tuning
workers 1
max_filedescriptors 65535

# DNS
dns_nameservers 192.168.56.10

# Refresh patterns
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320
EOF

echo "==> Stopping Squid service if running"
systemctl stop squid || true

echo "==> Initializing Squid cache"
squid -z -F

echo "==> Enable and start Squid service"
systemctl enable squid
systemctl restart squid

echo "==> Validating Squid configuration"
squid -k check

echo
echo "=========================================="
echo " HTTP Proxy (Squid) setup complete"
echo
echo " Proxy URL: squid:${PROXY_PORT}"
echo " Access Log: /var/log/squid/access.log"
echo " Cache Log:  /var/log/squid/cache.log"
echo " Config:     /etc/squid/squid.conf"
echo "=========================================="
