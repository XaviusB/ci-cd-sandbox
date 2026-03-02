#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/common/apt-update.sh"

ANSIBLE_USER="ansible"
ARTIFACTS_DIR="/artifacts"
ANSIBLE_VENV="/opt/ansible-venv"
KEY_PRIVATE="${ARTIFACTS_DIR}/ansible_id_ed25519"
KEY_PUBLIC="${ARTIFACTS_DIR}/ansible_id_ed25519.pub"
SUDOERS_FILE="/etc/sudoers.d/ansible"

if [ ! -x "${ANSIBLE_VENV}/bin/ansible" ]; then
  apt_update
  DEBIAN_FRONTEND=noninteractive apt-get install -y python3-venv python3-pip
  python3 -m venv "${ANSIBLE_VENV}"
  "${ANSIBLE_VENV}/bin/pip" install --upgrade pip
  "${ANSIBLE_VENV}/bin/pip" install ansible
fi

if [ ! -L /usr/local/bin/ansible ]; then
  ln -s "${ANSIBLE_VENV}/bin/ansible" /usr/local/bin/ansible
fi

if ! id "${ANSIBLE_USER}" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "${ANSIBLE_USER}"
fi

mkdir -p "${ARTIFACTS_DIR}"

if [ ! -f "${KEY_PRIVATE}" ]; then
  umask 077
  ssh-keygen -t ed25519 -f "${KEY_PRIVATE}" -N "" -C "${ANSIBLE_USER}@haproxy"
  chmod 600 "${KEY_PRIVATE}"
  chmod 644 "${KEY_PUBLIC}"
fi

if [ -f "${KEY_PRIVATE}" ] && [ ! -f "${KEY_PUBLIC}" ]; then
  umask 077
  ssh-keygen -y -f "${KEY_PRIVATE}" > "${KEY_PUBLIC}"
  chmod 644 "${KEY_PUBLIC}"
fi

if [ ! -f "${SUDOERS_FILE}" ]; then
  echo "${ANSIBLE_USER} ALL=(ALL) NOPASSWD:ALL" > "${SUDOERS_FILE}"
  chmod 440 "${SUDOERS_FILE}"
fi

ANSIBLE_HOME="/home/${ANSIBLE_USER}"
mkdir -p "${ANSIBLE_HOME}/.ssh"
chmod 700 "${ANSIBLE_HOME}/.ssh"
chown -R "${ANSIBLE_USER}:${ANSIBLE_USER}" "${ANSIBLE_HOME}/.ssh"

cp "${KEY_PRIVATE}" "${ANSIBLE_HOME}/.ssh/id_ed25519"
cp "${KEY_PUBLIC}" "${ANSIBLE_HOME}/.ssh/id_ed25519.pub"
cat "${KEY_PUBLIC}" > "${ANSIBLE_HOME}/.ssh/authorized_keys"
chmod 600 "${ANSIBLE_HOME}/.ssh/id_ed25519"
chmod 644 "${ANSIBLE_HOME}/.ssh/id_ed25519.pub"
chmod 600 "${ANSIBLE_HOME}/.ssh/authorized_keys"
chown "${ANSIBLE_USER}:${ANSIBLE_USER}" "${ANSIBLE_HOME}/.ssh/id_ed25519" "${ANSIBLE_HOME}/.ssh/id_ed25519.pub" "${ANSIBLE_HOME}/.ssh/authorized_keys"

echo "==> Ansible keygen complete"
echo "    Private key: ${KEY_PRIVATE}"
echo "    Public key:  ${KEY_PUBLIC}"
