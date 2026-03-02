#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/common/apt-update.sh"

TUNNEL_USER="tunnel"
TUNNEL_HOME="/home/${TUNNEL_USER}"
CHROOT_DIR="/var/jail/sshtunnel"
KEY_PRIVATE_ARTIFACT="/artifacts/ssh-tunnel-key"
KEY_PUBLIC_ARTIFACT="/artifacts/ssh-tunnel-key.pub"
INFO_ARTIFACT="/artifacts/ssh-tunnel-info.txt"
SSHD_CONFIG="/etc/ssh/sshd_config"

copy_binary() {
  local bin_path="$1"
  local target_dir="${CHROOT_DIR}"
  if [ -x "${bin_path}" ]; then
    install -D -m 755 "${bin_path}" "${target_dir}${bin_path}"
    ldd "${bin_path}" | awk '{for (i=1; i<=NF; i++) if ($i ~ /^\//) print $i}' | sort -u | while read -r lib; do
      install -D -m 755 "${lib}" "${target_dir}${lib}"
    done
  fi
}

echo "==> Disable MOTD"
chmod -x /etc/update-motd.d/*

echo "==> Installing SSH server"
apt_update

DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server

if ! id "${TUNNEL_USER}" >/dev/null 2>&1; then
  useradd -m -d "${TUNNEL_HOME}" -s /bin/bash "${TUNNEL_USER}"
fi

if [ ! -f "${KEY_PRIVATE_ARTIFACT}" ]; then
  ssh-keygen -t ed25519 -f "${KEY_PRIVATE_ARTIFACT}" -N "" -C "${TUNNEL_USER}@haproxy"
  chmod 600 "${KEY_PRIVATE_ARTIFACT}"
  chmod 644 "${KEY_PUBLIC_ARTIFACT}"
fi

mkdir -p "${CHROOT_DIR}"
chmod 755 "${CHROOT_DIR}"
chown root:root "${CHROOT_DIR}"

mkdir -p "${CHROOT_DIR}/home/${TUNNEL_USER}"
chown -R "${TUNNEL_USER}:${TUNNEL_USER}" "${CHROOT_DIR}/home/${TUNNEL_USER}"
chown -R "${TUNNEL_USER}:${TUNNEL_USER}" "/home/${TUNNEL_USER}"
chmod 700 "${CHROOT_DIR}/home/${TUNNEL_USER}"

mkdir -p "${CHROOT_DIR}/tmp"
chmod 1777 "${CHROOT_DIR}/tmp"

mkdir -p "${CHROOT_DIR}/dev"
if [ ! -e "${CHROOT_DIR}/dev/null" ]; then
  mknod -m 666 "${CHROOT_DIR}/dev/null" c 1 3
fi
if [ ! -e "${CHROOT_DIR}/dev/zero" ]; then
  mknod -m 666 "${CHROOT_DIR}/dev/zero" c 1 5
fi
if [ ! -e "${CHROOT_DIR}/dev/tty" ]; then
  mknod -m 666 "${CHROOT_DIR}/dev/tty" c 5 0
fi
if [ ! -e "${CHROOT_DIR}/dev/random" ]; then
  mknod -m 666 "${CHROOT_DIR}/dev/random" c 1 8
fi
if [ ! -e "${CHROOT_DIR}/dev/urandom" ]; then
  mknod -m 666 "${CHROOT_DIR}/dev/urandom" c 1 9
fi

mkdir -p "${CHROOT_DIR}/etc"
TUNNEL_UID=$(id -u "${TUNNEL_USER}")
TUNNEL_GID=$(id -g "${TUNNEL_USER}")
cat > "${CHROOT_DIR}/etc/passwd" <<EOF
root:x:0:0:root:/root:/bin/bash
${TUNNEL_USER}:x:${TUNNEL_UID}:${TUNNEL_GID}:${TUNNEL_USER}:${TUNNEL_HOME}:/bin/bash
EOF
cat > "${CHROOT_DIR}/etc/group" <<EOF
root:x:0:
${TUNNEL_USER}:x:${TUNNEL_GID}:
EOF

mkdir -p "${CHROOT_DIR}/home/${TUNNEL_USER}/.ssh"
mkdir -p "/home/${TUNNEL_USER}/.ssh"
chmod 700 "${CHROOT_DIR}/home/${TUNNEL_USER}/.ssh"
chmod 700 "/home/${TUNNEL_USER}/.ssh"
chown "${TUNNEL_USER}:${TUNNEL_USER}" "${CHROOT_DIR}/home/${TUNNEL_USER}/.ssh"

if [ -f "${KEY_PUBLIC_ARTIFACT}" ]; then
  mkdir -p "/home/${TUNNEL_USER}/.ssh"
  cat "${KEY_PUBLIC_ARTIFACT}" > "/home/${TUNNEL_USER}/.ssh/authorized_keys"
  chmod 600 "/home/${TUNNEL_USER}/.ssh/authorized_keys"
  chown -R "${TUNNEL_USER}:${TUNNEL_USER}" "/home/${TUNNEL_USER}/.ssh"
fi

copy_binary /bin/bash
copy_binary /bin/sh
copy_binary /bin/ls
copy_binary /usr/bin/id
copy_binary /usr/bin/whoami

cat > "${INFO_ARTIFACT}" <<EOF
username=${TUNNEL_USER}
private_key=${KEY_PRIVATE_ARTIFACT}
endpoint=192.168.0.252
EOF
chmod 600 "${INFO_ARTIFACT}"

if ! grep -q "Match User ${TUNNEL_USER}" "${SSHD_CONFIG}"; then
  cat >> "${SSHD_CONFIG}" <<EOF

Match User ${TUNNEL_USER}
    ChrootDirectory ${CHROOT_DIR}
    AllowTcpForwarding yes
    PermitTTY yes
    X11Forwarding no
    AllowAgentForwarding no
    PasswordAuthentication no
    PubkeyAuthentication yes
EOF
fi

systemctl enable ssh
systemctl restart ssh

echo
echo "=========================================="
echo " SSH tunnel user setup complete"
echo " Private key: ${KEY_PRIVATE_ARTIFACT}"
echo " Public key: ${KEY_PUBLIC_ARTIFACT}"
echo " Info: ${INFO_ARTIFACT}"
echo " User: ${TUNNEL_USER}"
echo "=========================================="
