#!/usr/bin/env bash
set -euo pipefail

# Check if OVH Object Storage credentials exist
if [ -f "/artifacts/object-storage-creds.json" ]; then
  echo "==> Installing rclone"
  if ! command -v rclone &> /dev/null; then
    curl -sSL --fail https://rclone.org/install.sh | bash
  else
    echo "    rclone already installed"
  fi

  echo "==> Configuring rclone with OVH Object Storage"

  # Parse JSON file with jq
  ACCESS_KEY=$(jq -r '.accessKey' /artifacts/object-storage-creds.json)
  SECRET_KEY=$(jq -r '.secretKey' /artifacts/object-storage-creds.json)
  ENDPOINT=$(jq -r '.endpoint' /artifacts/object-storage-creds.json | sed 's|https://||')
  BUCKET=$(jq -r '.bucket' /artifacts/object-storage-creds.json)
  LOCATION=$(jq -r '.location' /artifacts/object-storage-creds.json)

  mkdir -p /root/.config/rclone
  cat > /root/.config/rclone/rclone.conf <<EOF
[backup]
type = s3
provider = Other
env_auth = false
access_key_id = ${ACCESS_KEY}
secret_access_key = ${SECRET_KEY}
endpoint = ${ENDPOINT}
acl = private
region = ${LOCATION}
location_constraint = ${LOCATION}
EOF

  chmod 600 /root/.config/rclone/rclone.conf

  echo "==> Testing OVH Object Storage connection"
  if rclone lsd backup:${BUCKET}; then
    echo "    Connection successful!"
  else
    echo "    WARNING: Failed to connect to OVH Object Storage"
  fi
else
  echo "==> Skipping rclone installation (OVH credentials not found at /artifacts/object-storage-creds.json)"
  echo "    Backups will be stored locally only in /var/backups/gitea"
fi

echo "==> Setting up Gitea automated backups"

# Copy backup scripts to /usr/local/bin
echo "==> Copying backup scripts to /usr/local/bin"
cp /scripts/gitea/backup-gitea.sh /usr/local/bin/backup-gitea.sh
cp /scripts/gitea/restore-gitea.sh /usr/local/bin/restore-gitea.sh

# Make backup scripts executable
chmod +x /usr/local/bin/backup-gitea.sh
chmod +x /usr/local/bin/restore-gitea.sh

# Create backup directory
mkdir -p /var/backups/gitea
chown root:root /var/backups/gitea
chmod 750 /var/backups/gitea

# Create systemd service for backup
cat > /etc/systemd/system/gitea-backup.service <<'EOF'
[Unit]
Description=Gitea Daily Backup
After=mariadb.service gitea.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup-gitea.sh
User=root
Group=root

# Send email on failure (if mail is configured)
# OnFailure=status-email@%n.service
EOF

# Create systemd timer for daily backups at 2 AM
cat > /etc/systemd/system/gitea-backup.timer <<'EOF'
[Unit]
Description=Gitea Daily Backup Timer
Requires=gitea-backup.service

[Timer]
# Run daily at 12 PM
OnCalendar=daily
OnCalendar=*-*-* 12:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Reload systemd and enable timer
systemctl daemon-reload
systemctl enable gitea-backup.timer
systemctl start gitea-backup.timer

# Show timer status
echo
echo "=========================================="
echo " Gitea backup automation configured"
echo
echo " Backup script:   /usr/local/bin/backup-gitea.sh"
echo " Restore script:  /usr/local/bin/restore-gitea.sh"
echo " Backup location: /var/backups/gitea"
if [ -f "/artifacts/object-storage-creds.json" ] && command -v rclone &> /dev/null; then
  BUCKET=$(jq -r '.bucket' /artifacts/object-storage-creds.json 2>/dev/null || echo "unknown")
  echo " Cloud storage:   OVH S3 (${BUCKET}/hesias/gitea/)"
else
  echo " Cloud storage:   Not configured (local backups only)"
fi
echo " Schedule:        Daily at 2:00 AM"
echo " Retention:       30 days"
echo
echo " Manual backup:   sudo backup-gitea.sh"
echo " Restore:         sudo restore-gitea.sh <backup.tar.gz>"
echo " Timer status:    systemctl status gitea-backup.timer"
echo " Next run:        systemctl list-timers gitea-backup.timer"
echo "=========================================="
