#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/common/apt-update.sh"

CERT_DIR="/etc/haproxy/certs"
DOMAIN="devops.active"
WILDCARD="*.${DOMAIN}"
DAYS=3650

echo "==> Starting HAProxy SSL setup"

echo "==> Installing dependencies"
apt_update
apt-get install -y haproxy openssl net-tools nmap

echo "==> Creating cert directory"
mkdir -p ${CERT_DIR}
chmod 700 ${CERT_DIR}

cd ${CERT_DIR}

echo "==> Generating CA private key"
if [ ! -f devops-active-CA.key ]; then
  openssl genrsa -out devops-active-CA.key 4096
else
  echo "    CA key already exists, skipping"
fi

echo "==> Generating CA certificate"
if [ ! -f devops-active-CA.crt ]; then
  openssl req -x509 -new -nodes \
    -key devops-active-CA.key \
    -sha256 \
    -days ${DAYS} \
    -out devops-active-CA.crt \
    -subj "/C=US/ST=DevOps/L=Lab/O=DevOps Local/OU=CA/CN=DevOps Local CA"
else
  echo "    CA certificate already exists, skipping"
fi

echo "==> Generating server private key"
if [ ! -f ${DOMAIN}.key ]; then
  openssl genrsa -out ${DOMAIN}.key 4096
else
  echo "    Server key already exists, skipping"
fi

echo "==> Creating OpenSSL config for SAN"
cat > san.cnf <<EOF
[req]
default_bits       = 4096
prompt             = no
default_md         = sha256
distinguished_name = dn
req_extensions     = req_ext

[dn]
C  = US
ST = DevOps
L  = Lab
O  = DevOps Local
OU = HAProxy
CN = ${DOMAIN}

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
DNS.2 = *.${DOMAIN}
DNS.3 = localhost
EOF

echo "==> Generating certificate signing request"
# Force regeneration if CN needs to be updated
if [ -f ${DOMAIN}.crt ]; then
  CURRENT_CN=$(openssl x509 -in ${DOMAIN}.crt -noout -subject | grep -oP 'CN\s*=\s*\K[^,]*' || echo "")
  if [ "${CURRENT_CN}" != "${DOMAIN}" ]; then
    echo "    CN mismatch detected (old: ${CURRENT_CN}, new: ${DOMAIN}), regenerating certificate"
    rm -f ${DOMAIN}.crt ${DOMAIN}.csr
  fi
fi

if [ ! -f ${DOMAIN}.csr ]; then
  openssl req -new \
    -key ${DOMAIN}.key \
    -out ${DOMAIN}.csr \
    -config san.cnf
else
  echo "    CSR already exists, skipping"
fi

echo "==> Signing certificate with CA"
if [ ! -f ${DOMAIN}.crt ]; then
  openssl x509 -req \
    -in ${DOMAIN}.csr \
    -CA devops-active-CA.crt \
    -CAkey devops-active-CA.key \
    -CAcreateserial \
    -out ${DOMAIN}.crt \
    -days ${DAYS} \
    -sha256 \
    -extensions req_ext \
    -extfile san.cnf
else
  echo "    Signed certificate already exists, skipping"
fi

echo "==> Creating HAProxy PEM bundle"
if [ ! -f ${DOMAIN}.pem ]; then
  cat ${DOMAIN}.crt ${DOMAIN}.key > ${DOMAIN}.pem
  chmod 600 ${DOMAIN}.pem
else
  echo "    PEM bundle already exists, skipping"
fi

echo "==> Copy certificat to artifact folder"
cp "${CERT_DIR}/devops-active-CA.crt" /artifacts

echo "==> Cleaning up CSR and config"
rm -f "${DOMAIN}.csr" san.cnf

echo "==> Create HAProxy configuration"
cat > /etc/haproxy/haproxy.cfg <<EOF
global
	log /dev/log	local0
	log /dev/log	local1 notice
	chroot /var/lib/haproxy
	stats socket /run/haproxy/admin.sock mode 660 level admin
	stats timeout 30s
	user haproxy
	group haproxy
	daemon

	# Default SSL material locations
	ca-base /etc/ssl/certs
	crt-base /etc/ssl/private

	# See: https://ssl-config.mozilla.org/#server=haproxy&server-version=2.0.3&config=intermediate
        ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
        ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets

defaults
	log	global
	mode	http
	option	httplog
	option	dontlognull
        timeout connect 5000
        timeout client  50000
        timeout server  50000
	errorfile 400 /etc/haproxy/errors/400.http
	errorfile 403 /etc/haproxy/errors/403.http
	errorfile 408 /etc/haproxy/errors/408.http
	errorfile 500 /etc/haproxy/errors/500.http
	errorfile 502 /etc/haproxy/errors/502.http
	errorfile 503 /etc/haproxy/errors/503.http
	errorfile 504 /etc/haproxy/errors/504.http

frontend main
    mode http
    bind :80
		# Bind to the generated domain PEM bundle to avoid HAProxy
		# attempting to load CA certs which don't contain private keys.
		bind :443 ssl crt /etc/haproxy/certs/devops.active.pem
        http-request redirect scheme https code 301 unless { ssl_fc }
        use_backend nexus         if { req.hdr(host) -i nexus.devops.active }
        use_backend giteaweb      if { req.hdr(host) -i gitea.devops.active }
        default_backend kube

frontend k8s_api
    mode http
    bind :6443
    default_backend k8s_api

backend k8s_api
        mode http
        server k8s1 192.168.56.14:6443

backend giteaweb
        option forwardfor
        mode http
        server gitea 192.168.56.11:3000

frontend giteassh
        mode tcp
        bind :2222
        default_backend giteassh
        option tcplog

backend giteassh
        mode tcp
        server gitea 192.168.56.11:2222

frontend browser_proxy
        mode http
        bind :8080
        option httplog
        option forwardfor

        # Route based on Host header
        use_backend giteaweb      if { req.hdr(host) -i gitea.devops.active }

        # Default backend
        default_backend giteaweb

backend kube
        mode http
        option forwardfor
        server k8s1 192.168.56.14:30080 check

backend nexus
        mode http
        option forwardfor
        server nexus 192.168.56.12:8081 check

EOF

echo "==> Validating HAProxy configuration"
haproxy -c -f /etc/haproxy/haproxy.cfg

echo "==> Enable haproxy service"
systemctl enable haproxy

echo "==> Restarting HAPproxy"
systemctl restart haproxy


echo
echo "=========================================="
echo " HAProxy SSL setup complete"
echo
echo " CA cert to import into browser:"
echo "   ${CERT_DIR}/devops-active-CA.crt"
echo
echo " HAProxy cert bundle:"
echo "   ${CERT_DIR}/${DOMAIN}.pem"
echo "=========================================="
