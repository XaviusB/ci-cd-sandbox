#!/usr/bin/env bash
set -euo pipefail

# Gitea Backup Script
# Creates daily backups of Gitea data and MySQL database

BACKUP_DIR="/var/backups/gitea"
GITEA_USER="git"
GITEA_HOME="/var/lib/gitea"
CONFIG_DIR="/etc/gitea"
RETENTION_DAYS=30
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="gitea_backup_${TIMESTAMP}"

echo "==> Starting Gitea backup at $(date)"

# Create backup directory
mkdir -p "${BACKUP_DIR}"
cd "${BACKUP_DIR}"

echo "==> Creating backup directory: ${BACKUP_NAME}"
mkdir -p "${BACKUP_NAME}"

# Backup MySQL database
echo "==> Backing up MySQL database"
mysqldump --single-transaction \
  --routines \
  --triggers \
  --events \
  gitea > "${BACKUP_NAME}/gitea_db.sql"

if [ $? -eq 0 ]; then
  echo "    Database backup completed successfully"
else
  echo "    ERROR: Database backup failed!"
  exit 1
fi

# Backup Gitea data directory
echo "==> Backing up Gitea data directory"
rsync -a --delete \
  "${GITEA_HOME}/" \
  "${BACKUP_NAME}/gitea_data/"

# Backup Gitea configuration
echo "==> Backing up Gitea configuration"
cp -r "${CONFIG_DIR}" "${BACKUP_NAME}/gitea_config"

# Create backup metadata
echo "==> Creating backup metadata"
cat > "${BACKUP_NAME}/backup_info.txt" <<EOF
Backup Date: $(date)
Hostname: $(hostname)
Gitea Data: ${GITEA_HOME}
Config Dir: ${CONFIG_DIR}
Database: gitea (MySQL)
EOF

# Compress the backup
echo "==> Compressing backup"
tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"
rm -rf "${BACKUP_NAME}"

BACKUP_SIZE=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)
echo "    Backup compressed: ${BACKUP_NAME}.tar.gz (${BACKUP_SIZE})"

# Calculate checksum
echo "==> Calculating checksum"
sha256sum "${BACKUP_NAME}.tar.gz" > "${BACKUP_NAME}.tar.gz.sha256"

# Clean up old backups
echo "==> Cleaning up backups older than ${RETENTION_DAYS} days"
find "${BACKUP_DIR}" -name "gitea_backup_*.tar.gz*" -mtime +${RETENTION_DAYS} -delete
REMAINING=$(find "${BACKUP_DIR}" -name "gitea_backup_*.tar.gz" | wc -l)
echo "    ${REMAINING} backup(s) remaining"

echo "==> Backup completed successfully at $(date)"
