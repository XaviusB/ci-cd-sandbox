# Gitea Role

This Ansible role installs and configures Gitea, a lightweight self-hosted Git service, with MariaDB as the database backend.

## Features

- ✅ **Automated installation** - Downloads and installs specific Gitea version
- ✅ **Version management** - Only downloads if version differs
- ✅ **MariaDB integration** - Automatic database and user creation
- ✅ **User management** - Creates Git system user
- ✅ **Admin creation** - Creates initial admin user with auto-generated password
- ✅ **Runner token** - Generates Gitea Actions runner registration token
- ✅ **Systemd service** - Configures and enables Gitea service
- ✅ **Idempotent** - Safe to run multiple times
- ✅ **SSH server** - Built-in SSH server on custom port
- ✅ **LFS support** - Git Large File Storage enabled

## Requirements

- Ubuntu/Debian system
- Ansible 2.9+
- Ansible collection: `community.mysql`
- Root/sudo access
- Python 3 with `pymysql` library

### Install Requirements

```bash
# Install Ansible collection
ansible-galaxy collection install community.mysql

# Python pymysql is installed automatically by the role
```

## Role Variables

Available variables with their default values (see `defaults/main.yml`):

### Gitea Version and Paths

```yaml
gitea_version: "1.25.4"
gitea_user: "git"
gitea_group: "git"
gitea_home: "/home/git"
gitea_install_dir: "/usr/local/bin"
gitea_data_dir: "/var/lib/gitea"
gitea_config_dir: "/etc/gitea"
```

### Admin User Configuration

```yaml
gitea_admin_user: "xavier"
gitea_admin_email: "me@devops.active"
gitea_admin_password: ""  # Auto-generated if empty
gitea_admin_password_length: 16
```

### Database Configuration

```yaml
gitea_db_type: "mysql"
gitea_db_name: "gitea"
gitea_db_user: "gitea"
gitea_db_password: "gitea"
gitea_db_host: "127.0.0.1:3306"
```

### Server Configuration

```yaml
gitea_domain: "gitea.devops.active"
gitea_http_port: 3000
gitea_http_addr: "0.0.0.0"
gitea_ssh_port: 2222
gitea_disable_ssh: false
gitea_start_ssh_server: true
gitea_root_url: "https://gitea.devops.active/"
```

### Service Settings

```yaml
gitea_register_email_confirm: false
gitea_enable_notify_mail: false
gitea_disable_registration: false
gitea_email_domain_allowlist: "hesias.fr,devops.active"
gitea_register_manual_confirm: true
gitea_require_signin_view: true
gitea_enable_captcha: true
```

### Artifacts Export

```yaml
artifacts_dir: "/artifacts"
gitea_export_credentials: true
gitea_generate_runner_token: true
```

## Dependencies

None.

## Example Playbook

### Basic usage:

```yaml
---
- name: Install Gitea
  hosts: gitea_server
  become: true
  roles:
    - role: gitea
```

### With custom configuration:

```yaml
---
- name: Install Gitea with custom settings
  hosts: gitea_server
  become: true
  roles:
    - role: gitea
      vars:
        gitea_version: "1.25.4"
        gitea_domain: "git.company.local"
        gitea_root_url: "https://git.company.local/"
        gitea_admin_user: "admin"
        gitea_admin_email: "admin@company.local"
        gitea_admin_password: "SecurePassword123!"
        gitea_db_password: "strong_database_password"
```

### With DNS client integration:

```yaml
---
- name: Setup Gitea with DNS
  hosts: gitea_server
  become: true
  roles:
    - role: dns_client
      vars:
        dns_servers:
          - "10.0.0.10"
    - role: gitea
```

## Usage

1. Add the role to your playbook
2. Configure variables as needed
3. Run the playbook:

```bash
ansible-playbook -i inventory playbooks/setup-gitea.yml
```

## Generated Files

### Application Files

```
/usr/local/bin/gitea               # Gitea binary
/var/lib/gitea/                    # Data directory
├── custom/                        # Custom files
├── data/                          # Repositories and database
│   ├── gitea-repositories/        # Git repositories
│   └── lfs/                       # LFS objects
└── log/                           # Log files
/etc/gitea/gitea.ini               # Configuration file
```

### Artifacts

```
/artifacts/
├── gitea-admin-credentials.txt    # Admin username:password
└── gitea-runner-token.txt         # Runner registration token
```

## Accessing Gitea

### Web Interface

Access Gitea at:
- Local: `http://localhost:3000`
- Domain: `https://gitea.devops.active` (via reverse proxy)

### SSH Git Access

Clone repositories via SSH:
```bash
git clone ssh://git@gitea.devops.active:2222/username/repo.git
```

### Admin Credentials

Admin credentials are saved to `/artifacts/gitea-admin-credentials.txt` in the format:
```
username:password
```

## Gitea Actions Runner

The role generates a runner registration token saved to `/artifacts/gitea-runner-token.txt`. Use this token to register Gitea Actions runners:

```bash
# On the runner machine
gitea-runner register \
  --instance https://gitea.devops.active \
  --token $(cat /artifacts/gitea-runner-token.txt)
```

## Configuration

The main configuration file is generated at `/etc/gitea/gitea.ini`. Key settings:

### Database
- Type: MariaDB/MySQL
- Database: `gitea`
- User: `gitea`
- Connection: localhost

### Server
- HTTP port: 3000
- SSH port: 2222 (built-in SSH server)
- Domain: configurable via variables

### Features
- ✅ LFS (Large File Storage)
- ✅ Built-in SSH server
- ✅ OpenID signin/signup
- ✅ Actions (CI/CD)
- ❌ Email notifications
- ❌ User registration (manual confirm required)

## Upgrade Procedure

To upgrade Gitea:

1. Update the version variable:
   ```yaml
   gitea_version: "1.26.0"
   ```

2. Run the playbook:
   ```bash
   ansible-playbook -i inventory playbooks/setup-gitea.yml
   ```

The role will:
- Detect version mismatch
- Stop Gitea service
- Download new binary
- Restart service

## Idempotency

The role is idempotent:
- ✅ Skips database creation if exists
- ✅ Skips user creation if exists
- ✅ Only downloads binary if version differs
- ✅ Only restarts service when needed
- ✅ Skips admin creation if user exists

## Troubleshooting

### Check Gitea status
```bash
systemctl status gitea
```

### View logs
```bash
journalctl -u gitea -f
# or
tail -f /var/lib/gitea/log/gitea.log
```

### Test database connection
```bash
mysql -u gitea -pgitea gitea -e "SELECT 1;"
```

### Verify configuration
```bash
sudo -u git gitea admin user list --config /etc/gitea/gitea.ini
```

### Reset admin password
```bash
sudo -u git gitea admin user change-password \
  --username xavier \
  --password newpassword \
  --config /etc/gitea/gitea.ini
```

## Security Considerations

- Admin password is auto-generated and saved to artifacts
- Database password should be changed in production
- JWT secrets should be regenerated in production
- User registration requires manual confirmation
- CAPTCHA enabled for registration
- Signin required to view content
- Email domain allowlist restricts registrations

## Behind a Reverse Proxy

When using Gitea behind HAProxy or nginx:

1. Set `ROOT_URL` correctly:
   ```yaml
   gitea_root_url: "https://gitea.example.com/"
   ```

2. Configure the proxy to forward to port 3000

3. Enable proxy protocol if needed (HAProxy):
   ```haproxy
   backend gitea
       server gitea1 127.0.0.1:3000 send-proxy
   ```

## Integration with CI/CD

### Gitea Actions

Gitea has built-in CI/CD similar to GitHub Actions. To use it:

1. Get the runner token from `/artifacts/gitea-runner-token.txt`
2. Install and register a Gitea Actions runner
3. Create `.gitea/workflows/*.yaml` in your repositories

### Webhooks

Configure webhooks in Gitea to trigger external CI/CD systems like Jenkins, Drone, or other tools.

## Backup and Restore

### Automated Backups

The role includes automated backup functionality that creates daily backups of:
- Gitea MySQL database
- Gitea data directory
- Gitea configuration files

#### Backup Configuration

```yaml
gitea_enable_backup: true           # Enable/disable automated backups
gitea_backup_dir: "/var/backups/gitea"  # Backup storage directory
gitea_backup_cron_hour: "2"         # Hour to run backup (24h format)
gitea_backup_cron_minute: "30"      # Minute to run backup
```

#### What Gets Backed Up

Each backup includes:
- **Database dump**: Complete MySQL dump of the `gitea` database
- **Data directory**: All repositories, LFS objects, and application data
- **Configuration**: Gitea configuration files from `/etc/gitea`
- **Metadata**: Backup timestamp, hostname, and paths

#### Backup Retention

Backups are automatically cleaned up after 30 days. To change retention:

```bash
# Edit the script
sudo nano /usr/local/bin/backup-gitea.sh
# Change RETENTION_DAYS variable
```

#### Manual Backup

To manually create a backup:
```bash
sudo /usr/local/bin/backup-gitea.sh
```

#### Backup Location

Backups are stored in `/var/backups/gitea/`:
```
/var/backups/gitea/
├── gitea_backup_20260215_023000.tar.gz
├── gitea_backup_20260215_023000.tar.gz.sha256
├── gitea_backup_20260216_023000.tar.gz
└── gitea_backup_20260216_023000.tar.gz.sha256
```

#### View Backup Logs

```bash
sudo tail -f /var/log/gitea-backup.log
```

#### Restore from Backup

The role deploys a restore script for easy recovery. To restore from a backup:

**Using the restore script (recommended):**
```bash
# List available backups
sudo /usr/local/bin/restore-gitea.sh

# Restore from a specific backup
sudo /usr/local/bin/restore-gitea.sh /var/backups/gitea/gitea_backup_YYYYMMDD_HHMMSS.tar.gz
```

The restore script will:
- Verify backup integrity (if checksum exists)
- Prompt for confirmation
- Stop Gitea service
- Restore database, data directory, and configuration
- Fix file permissions
- Start Gitea service
- Wait for Gitea to be available

**Manual restore:**

1. Stop Gitea:
   ```bash
   sudo systemctl stop gitea
   ```

2. Extract the backup:
   ```bash
   cd /var/backups/gitea
   tar -xzf gitea_backup_YYYYMMDD_HHMMSS.tar.gz
   cd gitea_backup_YYYYMMDD_HHMMSS
   ```

3. Restore the database:
   ```bash
   mysql -u gitea -p gitea < gitea_db.sql
   ```

4. Restore data directory:
   ```bash
   sudo rsync -a gitea_data/ /var/lib/gitea/
   sudo chown -R git:git /var/lib/gitea
   ```

5. Restore configuration (if needed):
   ```bash
   sudo cp -r gitea_config /etc/gitea
   sudo chown root:git /etc/gitea
   sudo chmod 750 /etc/gitea
   ```

6. Start Gitea:
   ```bash
   sudo systemctl start gitea
   ```

#### Disable Automated Backups

To disable automated backups:
```yaml
gitea_enable_backup: false
```

## License

MIT

## Author

Created for TP2026 DevOps course
