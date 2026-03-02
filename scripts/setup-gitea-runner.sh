#!/usr/bin/env bash
set -euo pipefail

# setup-gitea-runner.sh
# Installs Docker, creates a runner user, generates SSH keypair,
# and optionally installs and runs a gitea-runner binary when
# GITEA_RUNNER_URL, GITEA_URL and GITEA_RUNNER_TOKEN are provided.

source "$(dirname "$0")/common/apt-update.sh"

RUNNER_USER="runner"
RUNNER_HOME="/home/${RUNNER_USER}"
GITEA_RUNNER_BIN="/usr/local/bin/gitea-runner"
GITEA_RUNNER_BIN_URL="https://dl.gitea.com/act_runner/0.2.13/act_runner-0.2.13-linux-amd64"
GITEA_RUNNER_CONFIG="/etc/gitea/runner.yaml"
GITEA_RUNNER_TOKEN=$(cat /artifacts/gitea-runner-token.txt)
GITEA_RUNNER_URL=https://gitea.devops.active

echo "==> Starting Gitea Runner setup"

echo "==> Installing dependencies"

apt_update
apt-get install -y docker.io git wget curl build-essential net-tools jq ca-certificates


echo "==> Importing self-signed CA certificate"
CA_CERT_PATH="/artifacts/devops-active-CA.crt"
cp "${CA_CERT_PATH}" /usr/local/share/ca-certificates/devops-active-CA.crt
update-ca-certificates

echo "==> Configuring Docker registry CA certificate"
mkdir -p /etc/docker/certs.d/nexus.devops.active
cp "${CA_CERT_PATH}" /etc/docker/certs.d/nexus.devops.active/ca.crt

echo "==> Configuring Docker daemon"
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<DOCKEREOF
{
  "insecure-registries": [],
  "registry-mirrors": []
}
DOCKEREOF

echo "==> Ensure docker is enabled & restarted"
systemctl enable docker
systemctl restart docker

echo "==> Creating runner user and group if they don't exist"
if ! id "${RUNNER_USER}" >/dev/null 2>&1; then
  groupadd --system ${RUNNER_USER} || true
  useradd --system --create-home --home-dir "${RUNNER_HOME}" --shell /bin/bash --gid ${RUNNER_USER} ${RUNNER_USER} || true
  echo "==> Adding runner user to docker group"
  usermod -aG docker ${RUNNER_USER}
  echo "    created user ${RUNNER_USER}"
else
  echo "    runner user already exists"
  echo "==> Adding runner user to docker group"
  usermod -aG docker ${RUNNER_USER}
fi

echo "==> Configuring Git to trust self-signed certificate"
sudo -u ${RUNNER_USER} git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt

echo "==> Creating runner config"
mkdir -p "$(dirname ${GITEA_RUNNER_CONFIG})"

cat >${GITEA_RUNNER_CONFIG} <<EOF
log:
  level: info

runner:
  file: ${RUNNER_HOME}/.runner
  capacity: 2
  envs:
    A_TEST_ENV_NAME_1: a_test_env_value_1
    A_TEST_ENV_NAME_2: a_test_env_value_2
  env_file: .env
  timeout: 3h
  shutdown_timeout: 0s
  insecure: false
  fetch_timeout: 5s
  fetch_interval: 2s
  github_mirror: ''
  labels:
    - "ubuntu-latest:docker://docker.gitea.com/runner-images:ubuntu-latest"
    - "cdrunner:docker://nexus.devops.active:443/docker-host/cdrunner:v1.0.0"

cache:
  enabled: true
  dir: ""
  host: ""
  port: 0
  external_server: ""

container:
  network: ""
  privileged: false
  options: "--volume /etc/ssl/certs:/etc/ssl/certs:ro --volume /usr/local/share/ca-certificates:/usr/local/share/ca-certificates:ro --volume /etc/docker/certs.d:/etc/docker/certs.d:ro"
  workdir_parent: ${RUNNER_HOME}
  valid_volumes:
    - /etc/ssl/certs
    - /usr/local/share/ca-certificates
    - /etc/docker/certs.d
  docker_host: ""
  force_pull: false
  force_rebuild: false
  require_docker: false
  docker_timeout: 0s

host:
  workdir_parent:
EOF

if [ ! -f   "${GITEA_RUNNER_BIN:-}" ]; then
  echo "==> Installing gitea-runner from ${GITEA_RUNNER_BIN_URL}"
  curl -sSL -o "${GITEA_RUNNER_BIN}" "${GITEA_RUNNER_BIN_URL}"
  chmod +x "${GITEA_RUNNER_BIN}"
fi

if [ ! -f /${RUNNER_HOME}/.runner ]; then
  echo "==> Registering runner with Gitea"
  cd ${RUNNER_HOME}
  sudo -u ${RUNNER_USER} ${GITEA_RUNNER_BIN} register --no-interactive --instance "${GITEA_RUNNER_URL}" --token "${GITEA_RUNNER_TOKEN}" --name "${HOSTNAME}" --labels linux,amd64
else
  echo "==> Runner is already registered, skipping registration"
fi

cat >/etc/systemd/system/gitea-runner.service <<EOF
[Unit]
Description=Gitea Runner
After=network.target docker.service

[Service]
User=${RUNNER_USER}
Group=${RUNNER_USER}
WorkingDirectory=${RUNNER_HOME}
ExecStart=${GITEA_RUNNER_BIN} daemon --config ${GITEA_RUNNER_CONFIG}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

mkdir -p "${RUNNER_HOME}/work"
chown -R ${RUNNER_USER}:${RUNNER_USER} "${RUNNER_HOME}"
chown -R ${RUNNER_USER}:${RUNNER_USER} "${GITEA_RUNNER_CONFIG}"
chmod 755 "${RUNNER_HOME}"
chmod 644 "${GITEA_RUNNER_CONFIG}"

systemctl daemon-reload
systemctl enable gitea-runner
systemctl restart gitea-runner


echo
echo "=========================================="
echo " Gitea Runner setup complete"
echo " Runner user: ${RUNNER_USER}"
echo " Runner home: ${RUNNER_HOME}"
echo " To start/stop runner service: systemctl (enable|start|stop|restart) gitea-runner"
echo "=========================================="
