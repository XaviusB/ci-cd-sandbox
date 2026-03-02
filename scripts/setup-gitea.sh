#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common/apt-update.sh"

GITEA_VERSION="1.25.4"
GITEA_USER="git"
INSTALL_DIR="/usr/local/bin"
DATA_DIR="/var/lib/gitea"
CONFIG_DIR="/etc/gitea"
GITEA_ADMIN_USER="admin"
GITEA_ADMIN_PASS="$(openssl rand -base64 16)"
GITEA_ADMIN_MAIL="admin@devops.active"

cat << 'BANNER'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                  WARNING: YOUR GRADE LIVES HERE!                             ║
║                                                                              ║
║   This server is your CI/CD lifeline for the year. Break it, and you'll      ║
║   be manually deploying code with carrier pigeons and USB sticks.            ║
║                                                                              ║
║   Remember: With great sudo power comes great responsibility...              ║
║   and potentially catastrophic consequences for your transcript.             ║
║                                                                              ║
║   TL;DR: Be careful, or become a cautionary tale in next year's lectures.    ║
║                                                                              ║
║   Don't worry, It's a joke                                                   ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
BANNER

echo "==> Starting Gitea setup"

echo "==> Installing dependencies"

apt_update
apt-get install -y git curl mariadb-server net-tools

echo "==> Creating git user"
if ! id ${GITEA_USER} >/dev/null 2>&1; then
  adduser \
    --system \
    --shell /bin/bash \
    --gecos 'Git Version Control' \
    --group \
    --disabled-password \
    --home /home/${GITEA_USER} \
    ${GITEA_USER}
fi

echo "==> Setting up MariaDB"
systemctl start mariadb
systemctl enable mariadb

# Create Gitea database and user
mysql -e "CREATE DATABASE IF NOT EXISTS gitea;"
mysql -e "CREATE USER IF NOT EXISTS 'gitea'@'localhost' IDENTIFIED BY 'gitea';"
mysql -e "GRANT ALL PRIVILEGES ON gitea.* TO 'gitea'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

echo "==> Creating directories"
mkdir -p \
  ${DATA_DIR}/{custom,data,log} \
  ${CONFIG_DIR}

chown -R ${GITEA_USER}:${GITEA_USER} ${DATA_DIR}
chown root:${GITEA_USER} ${CONFIG_DIR}
chmod 750 ${CONFIG_DIR}

echo "==> Downloading Gitea ${GITEA_VERSION}"

# Check if gitea binary exists and get its version
CURRENT_VERSION=""
if [ -f ${INSTALL_DIR}/gitea ]; then
  CURRENT_VERSION=$(${INSTALL_DIR}/gitea --version 2>/dev/null | grep -oP 'gitea version \K[\d.]+' || echo "")
fi

echo "    Current version: ${CURRENT_VERSION:-none}"
echo "    Target version: ${GITEA_VERSION}"

# Download and install only if version differs
if [ "${CURRENT_VERSION}" != "${GITEA_VERSION}" ]; then
  echo "    Stopping Gitea service"
  systemctl stop gitea || true

  echo "    Downloading Gitea ${GITEA_VERSION}"
  curl -sSL --fail -o ${INSTALL_DIR}/gitea \
    https://dl.gitea.com/gitea/${GITEA_VERSION}/gitea-${GITEA_VERSION}-linux-amd64

  chmod +x ${INSTALL_DIR}/gitea
  echo "    Gitea binary updated to version ${GITEA_VERSION}"
else
  echo "    Gitea binary is already at version ${GITEA_VERSION}, skipping download"
fi

echo "==> Creating systemd service"
cat >/etc/systemd/system/gitea.service <<EOF
[Unit]
Description=Gitea (Git not overweight)
After=network.target

[Service]
Restart=always
User=git
Group=git

WorkingDirectory=/var/lib/gitea

ExecStart=/usr/local/bin/gitea web \
  --config ${CONFIG_DIR}/gitea.ini

Environment=USER=git
Environment=HOME=/home/git
Environment=GITEA_WORK_DIR=/var/lib/gitea

CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF

echo "==> Creating default Gitea configuration"

cat >${CONFIG_DIR}/gitea.ini <<EOF
APP_NAME = Gitea: because GitLab is too fat and GitHub too mainstream
RUN_USER = gitea
WORK_PATH = /var/lib/gitea
RUN_MODE = prod

[database]
DB_TYPE = mysql
HOST = 127.0.0.1:3306
NAME = gitea
USER = gitea
PASSWD = gitea
SSL_MODE = disable
SCHEMA =
PATH = /var/lib/gitea/data/gitea.db
LOG_SQL = false

[repository]
ROOT = /var/lib/gitea/data/gitea-repositories

[server]
SSH_DOMAIN = gitea.devops.active
DOMAIN = gitea.devops.active
HTTP_PORT = 3000
HTTP_ADDR = 0.0.0.0

ROOT_URL = https://gitea.devops.active/
APP_DATA_PATH = /var/lib/gitea/data
DISABLE_SSH = false
SSH_PORT = 2222
LFS_START_SERVER = true
LFS_JWT_SECRET = aSE03nQ_69ULnK1CW2wmLIXLofZ2JRKOMrQuaGiMYng
OFFLINE_MODE = true
START_SSH_SERVER = true

[lfs]
PATH = /var/lib/gitea/data/lfs

[mailer]
ENABLED = false

[service]
REGISTER_EMAIL_CONFIRM = false
ENABLE_NOTIFY_MAIL = false
DISABLE_REGISTRATION = false
EMAIL_DOMAIN_ALLOWLIST = hesias.fr,devops.active
REGISTER_MANUAL_CONFIRM = true
ALLOW_ONLY_EXTERNAL_REGISTRATION = false
ENABLE_CAPTCHA = false
REQUIRE_SIGNIN_VIEW = true
DEFAULT_KEEP_EMAIL_PRIVATE = false
DEFAULT_ALLOW_CREATE_ORGANIZATION = false
DEFAULT_ENABLE_TIMETRACKING = true
NO_REPLY_ADDRESS = noreply.localhost
ENABLE_CAPTCHA = true
CAPTCHA_TYPE = image

[openid]
ENABLE_OPENID_SIGNIN = true
ENABLE_OPENID_SIGNUP = true

[cron.update_checker]
ENABLED = false

[session]
PROVIDER = file

[log]
MODE = console
LEVEL = info
ROOT_PATH = /var/lib/gitea/log

[repository.pull-request]
DEFAULT_MERGE_STYLE = merge

[repository.signing]
DEFAULT_TRUST_MODEL = committer

[security]
INSTALL_LOCK = true
INTERNAL_TOKEN = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYmYiOjE3NjE3NzA3NDV9.i8VP-KzdPUZLVPKHYNYBPx9LJt6-cse8y7hqJcorumE
PASSWORD_HASH_ALGO = pbkdf2

[oauth2]
JWT_SECRET = SbpHPvUYMN_wyzTIxBM83kET1nM4Bm4MSMM1pSv9nPM

[ui.meta]
AUTHOR = Xavier Bourdeau
DESCRIPTION = This server is your CI/CD lifeline for the year. Break it, and you'll be manually deploying code with carrier pigeons and USB sticks.
KEYWORDS = go,git,self-hosted,gitea

[i18n]
LANGS = en-US
NAMES = English
EOF

echo "==> Reloading systemd"
systemctl daemon-reexec
systemctl daemon-reload

echo "==> Enabling and (re)starting Gitea"
systemctl enable gitea
systemctl restart gitea

echo "==> Waiting for Gitea to start"
until curl -s http://localhost:3000/ >/dev/null 2>&1; do
  echo "    Waiting for Gitea to be available..."
  sleep 3
done


echo "==> Creating initial admin user"

exists=$(sudo -u git gitea admin user list --config /etc/gitea/gitea.ini | grep -w "${GITEA_ADMIN_USER}" || true)
if [ -n "$exists" ]; then
  echo "Admin user '${GITEA_ADMIN_USER}' already exists, skipping creation"
else
  sudo -u git gitea admin user create --username "${GITEA_ADMIN_USER}" --password "${GITEA_ADMIN_PASS}" --admin --email "${GITEA_ADMIN_MAIL}" --config /etc/gitea/gitea.ini
  echo  "${GITEA_ADMIN_USER}":"${GITEA_ADMIN_PASS}" > /artifacts/gitea-admin-credentials.txt
  echo "Admin user '${GITEA_ADMIN_USER}' created with generated password"
fi

echo "==> Generating runner registration token"
sudo -u git gitea actions generate-runner-token --config /etc/gitea/gitea.ini > /artifacts/gitea-runner-token.txt

echo
echo "======================================"
echo " Gitea installation complete"
echo
echo " Web UI: http://<vm-ip>:3000"
echo " Config: ${CONFIG_DIR}/gitea.ini"
echo " Data:   /var/lib/gitea"
echo " Logs:   /var/lib/gitea/log"
echo "======================================"
