#!/usr/bin/env bash
set -euo pipefail

# Gitea Restore Script
# Restores Gitea data and MySQL database from backup

BACKUP_DIR="/var/backups/gitea"
GITEA_USER="git"
GITEA_HOME="/var/lib/gitea"
CONFIG_DIR="/etc/gitea"

if [ $# -eq 0 ]; then
  echo "Usage: $0 <backup_file.tar.gz>"
  echo
  echo "Available backups:"
  ls -lh "${BACKUP_DIR}"/gitea_backup_*.tar.gz 2>/dev/null || echo "  No backups found"
  exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "${BACKUP_FILE}" ]; then
  echo "ERROR: Backup file not found: ${BACKUP_FILE}"
  exit 1
fi

echo "==> Starting Gitea restore from backup"
echo "    Backup file: ${BACKUP_FILE}"
echo

# Verify checksum if available
if [ -f "${BACKUP_FILE}.sha256" ]; then
  echo "==> Verifying backup integrity"
  if sha256sum -c "${BACKUP_FILE}.sha256"; then
    echo "    Checksum verified successfully"
  else
    echo "    ERROR: Checksum verification failed!"
    read -p "Continue anyway? (yes/no): " confirm
    if [ "${confirm}" != "yes" ]; then
      exit 1
    fi
  fi
fi

# Confirm restore
echo
echo "WARNING: This will overwrite current Gitea data!"
read -p "Are you sure you want to continue? (yes/no): " confirm
if [ "${confirm}" != "yes" ]; then
  echo "Restore cancelled"
  exit 0
fi

# Stop Gitea service
echo "==> Stopping Gitea service"
systemctl stop gitea

# Extract backup
echo "==> Extracting backup"
TEMP_DIR=$(mktemp -d)
tar -xzf "${BACKUP_FILE}" -C "${TEMP_DIR}"
BACKUP_NAME=$(basename "${BACKUP_FILE}" .tar.gz)

# Restore MySQL database
echo "==> Restoring MySQL database"
mysql gitea < "${TEMP_DIR}/${BACKUP_NAME}/gitea_db.sql"

if [ $? -eq 0 ]; then
  echo "    Database restored successfully"
else
  echo "    ERROR: Database restore failed!"
  rm -rf "${TEMP_DIR}"
  systemctl start gitea
  exit 1
fi

# Restore Gitea data directory
echo "==> Restoring Gitea data directory"
rsync -a --delete \
  "${TEMP_DIR}/${BACKUP_NAME}/gitea_data/" \
  "${GITEA_HOME}/"

# Restore Gitea configuration
echo "==> Restoring Gitea configuration"
rsync -a --delete \
  "${TEMP_DIR}/${BACKUP_NAME}/gitea_config/" \
  "${CONFIG_DIR}/"

# Fix permissions
echo "==> Fixing permissions"
chown -R ${GITEA_USER}:${GITEA_USER} "${GITEA_HOME}"
chown root:${GITEA_USER} "${CONFIG_DIR}"
chmod 750 "${CONFIG_DIR}"

# Clean up
rm -rf "${TEMP_DIR}"

# Start Gitea service
echo "==> Starting Gitea service"
systemctl start gitea

# Wait for Gitea to start
echo "==> Waiting for Gitea to be available"
until curl -s http://localhost:3000/ >/dev/null 2>&1; do
  echo "    Waiting..."
  sleep 3
done

echo
echo "=========================================="
echo " Gitea restore completed successfully"
echo
echo " Restored from: ${BACKUP_FILE}"
echo " Gitea is now running"
echo "=========================================="
