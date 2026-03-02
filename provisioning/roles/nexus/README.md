# Nexus Repository Manager Role

This Ansible role installs and configures Sonatype Nexus Repository Manager OSS, including automated setup of Docker repositories and user access control.

## Features

- ✅ **Automated installation** - Downloads and installs specific Nexus version
- ✅ **Version management** - Only downloads if version differs
- ✅ **User management** - Creates Nexus system user
- ✅ **Admin password** - Auto-generates or uses provided password
- ✅ **Docker repository** - Automatically creates hosted Docker repository
- ✅ **Access control** - Creates read-only and read-write Docker users
- ✅ **Systemd service** - Configures and enables Nexus service
- ✅ **Idempotent** - Safe to run multiple times
- ✅ **API-based configuration** - Uses Nexus REST API for resource management

## Requirements

- Ubuntu/Debian system
- Ansible 2.9+
- Root/sudo access
- At least 2GB RAM recommended
- OpenJDK 11

## Role Variables

Available variables with their default values (see `defaults/main.yml`):

### Nexus Version and Paths

```yaml
nexus_version: "3.89.0-09"
nexus_home: "/opt/nexus"
nexus_data_dir: "/opt/sonatype-work/nexus3"
nexus_user: "nexus"
nexus_group: "nexus"
```

### Server Configuration

```yaml
nexus_port: 8081
nexus_host: "0.0.0.0"
nexus_context_path: "/"
```

### JVM Settings

```yaml
nexus_jvm_heap_min: "1024m"
nexus_jvm_heap_max: "1024m"
nexus_jvm_extra_opts: ""
```

### Admin Configuration

```yaml
nexus_admin_user: "admin"
nexus_admin_password: ""  # Auto-generated if empty
nexus_admin_password_length: 16
```

### Docker Repository Settings

```yaml
nexus_docker_repo_enabled: true
nexus_docker_repo_name: "docker-hosted"
nexus_docker_repo_http_port: null  # null = path-based routing
nexus_docker_repo_https_port: null
```

### Docker Proxy Repository Settings

```yaml
nexus_docker_proxy_enabled: true
nexus_docker_proxy_name: "docker-proxy"
nexus_docker_proxy_url: "https://registry-1.docker.io"
nexus_docker_proxy_index_type: "HUB"  # HUB, REGISTRY, or CUSTOM
nexus_docker_proxy_http_port: null  # null = path-based routing
nexus_docker_proxy_https_port: null
```

### Docker Group Repository Settings

```yaml
nexus_docker_group_enabled: true
nexus_docker_group_name: "docker-group"
nexus_docker_group_http_port: null  # null = path-based routing
nexus_docker_group_https_port: null
nexus_docker_group_members:
  - "docker-hosted"
  - "docker-proxy"
```

**Note:** By default, all Docker repositories use **path-based routing** (ports set to `null`). This means they are accessed via paths like `http://nexus:8081/repository/docker-hosted/`. To use dedicated ports instead (e.g., `8082`, `8083`, `8084`), set the respective `http_port` variables to specific port numbers.

### Docker Users

```yaml
nexus_docker_readonly_user: "docker-reader"
nexus_docker_readonly_password: ""  # Auto-generated if empty
nexus_docker_writer_user: "docker-writer"
nexus_docker_writer_password: ""  # Auto-generated if empty
```

### Artifacts Export

```yaml
artifacts_dir: "/artifacts"
nexus_export_credentials: true
```

## Dependencies

None.

## Example Playbook

### Basic usage:

```yaml
---
- name: Install Nexus
  hosts: nexus_server
  become: true
  roles:
    - role: nexus
```

### With custom configuration:

```yaml
---
- name: Install Nexus with custom settings
  hosts: nexus_server
  become: true
  roles:
    - role: nexus
      vars:
        nexus_version: "3.89.0-09"
        nexus_port: 8081
        nexus_jvm_heap_min: "2048m"
        nexus_jvm_heap_max: "2048m"
        nexus_admin_password: "SecurePassword123!"
        nexus_docker_repo_name: "my-docker-repo"
```

### Disable Docker repository:

```yaml
---
- name: Install Nexus without Docker repo
  hosts: nexus_server
  become: true
  roles:
    - role: nexus
      vars:
        nexus_docker_repo_enabled: false
```

## Usage

1. Add the role to your playbook
2. Configure variables as needed
3. Run the playbook:

```bash
ansible-playbook -i inventory playbooks/setup-nexus.yml
```

## Generated Files

### Application Files

```
/opt/nexus -> /opt/nexus-3.89.0-09  # Symlink
/opt/nexus-3.89.0-09/               # Nexus installation
/opt/sonatype-work/nexus3/          # Data directory
├── db/                             # Nexus database
├── etc/                            # Configuration
├── log/                            # Log files
├── tmp/                            # Temporary files
└── blobs/                          # Repository blobs
```

### Artifacts

```
/artifacts/
├── nexus-admin-password.txt          # Admin username:password
├── nexus-readonly-credentials.txt    # Docker reader username:password
└── nexus-upload-credentials.txt      # Docker writer username:password
```

## Accessing Nexus

### Web Interface

Access Nexus at:
- Local: `http://localhost:8081`
- Domain: Configure via reverse proxy

### Admin Credentials

Admin credentials are saved to `/artifacts/nexus-admin-password.txt` in the format:
```
admin:password
```

On first installation, Nexus generates a bootstrap password in `admin.password`. The role automatically:
1. Reads the bootstrap password
2. Changes it to a secure random password (or your specified password)
3. Exports credentials to artifacts directory
4. Removes the bootstrap password file

### Docker Repository Access

The role creates three types of Docker repositories using **path-based routing**:

#### Docker Hosted Repository
Store your own private Docker images:
```bash
# Access via path
NEXUS_URL="localhost:8081/repository/docker-hosted"

# Login
docker login ${NEXUS_URL}

# Tag and push your images
docker tag myapp:latest ${NEXUS_URL}/myapp:latest
docker push ${NEXUS_URL}/myapp:latest
```

#### Docker Proxy Repository
Cache images from Docker Hub:
```bash
# Access via path
NEXUS_PROXY="localhost:8081/repository/docker-proxy"

# Login
docker login ${NEXUS_PROXY}

# Pull from Docker Hub through Nexus cache
docker pull ${NEXUS_PROXY}/nginx:latest
docker pull ${NEXUS_PROXY}/ubuntu:22.04
```

#### Docker Group Repository (Recommended)
Combine hosted and proxy - use this as your default registry:
```bash
# Access via path
NEXUS_GROUP="localhost:8081/repository/docker-group"

# Configure as default registry
docker login ${NEXUS_GROUP}

# Pull includes both hosted and cached images
docker pull ${NEXUS_GROUP}/myapp:latest      # from hosted
docker pull ${NEXUS_GROUP}/nginx:latest      # from proxy (Docker Hub)

# Push to hosted
docker tag myapp:latest ${NEXUS_GROUP}/myapp:latest
docker push ${NEXUS_GROUP}/myapp:latest
```

#### User Credentials

**Read-Only User** (credentials in `/artifacts/nexus-readonly-credentials.txt`):
```bash
NEXUS_GROUP="localhost:8081/repository/docker-group"
docker login ${NEXUS_GROUP}
Username: docker-reader
Password: (from credentials file)

# Can pull from all repositories
docker pull ${NEXUS_GROUP}/myimage:latest
```

**Read-Write User** (credentials in `/artifacts/nexus-upload-credentials.txt`):
```bash
NEXUS_GROUP="localhost:8081/repository/docker-group"
docker login ${NEXUS_GROUP}
Username: docker-writer
Password: (from credentials file)

# Can push to hosted and pull from all
docker tag myimage:latest ${NEXUS_GROUP}/myimage:latest
docker push ${NEXUS_GROUP}/myimage:latest
```

## Docker Repository Configuration

The role automatically creates:

1. **Docker hosted repository** - For private images
2. **Docker proxy repository** - Caches Docker Hub images
3. **Docker group repository** - Combines hosted + proxy
4. **Docker Bearer Token Realm** - For authentication
5. **Read-only role** - Browse and read access to all repositories
6. **Read-write role** - Full access to hosted, read access to proxy/group
7. **Two users** - With appropriate role assignments

### Repository Details

| Repository Type | Name | Access Path | Purpose |
|----------------|------|-------------|---------|
| Hosted | docker-hosted | `/repository/docker-hosted` | Store private images |
| Proxy | docker-proxy | `/repository/docker-proxy` | Cache Docker Hub images |
| Group | docker-group | `/repository/docker-group` | Combined access (recommended) |

**Access Methods:**
- **Path-based** (default): `http://nexus:8081/repository/<repo-name>`
- **Port-based** (optional): Configure by setting `nexus_docker_*_http_port` to specific port numbers

**Best Practice:** Use the group repository as your default Docker registry. It provides access to both your private images and cached public images from Docker Hub.

**Example with port-based routing:**
```yaml
nexus_docker_repo_http_port: 8082
nexus_docker_proxy_http_port: 8083
nexus_docker_group_http_port: 8084
```
This allows access via `localhost:8082`, `localhost:8083`, and `localhost:8084` instead of paths.

### Disabling Repositories

To disable certain repository types:
```yaml
nexus_docker_proxy_enabled: false   # Disable proxy
nexus_docker_group_enabled: false   # Disable group
```

## Configuration

The main configuration files:

### JVM Options
`/opt/nexus/bin/nexus.vmoptions`:
- Heap size settings
- Garbage collection tuning
- Data directory paths

### Nexus Properties
`/opt/sonatype-work/nexus3/etc/nexus.properties`:
- Application port
- Context path
- Host binding

### Systemd Service
`/etc/systemd/system/nexus.service`:
- Service definition
- User/group configuration
- Restart policies

## Upgrade Procedure

To upgrade Nexus:

1. Update the version variable:
   ```yaml
   nexus_version: "3.90.0-01"
   ```

2. Run the playbook:
   ```bash
   ansible-playbook -i inventory playbooks/setup-nexus.yml
   ```

The role will:
- Detect version mismatch
- Stop Nexus service
- Download new version
- Update symlink
- Restart service

## Idempotency

The role is idempotent:
- ✅ Skips download if same version exists
- ✅ Skips repository creation if exists
- ✅ Skips user creation if exists
- ✅ Skips role creation if exists
- ✅ Only restarts service when needed
- ✅ Reuses existing credentials

## Troubleshooting

### Check Nexus status
```bash
systemctl status nexus
```

### View logs
```bash
# Service logs
journalctl -u nexus -f

# Application logs
tail -f /opt/sonatype-work/nexus3/log/nexus.log

# JVM logs
tail -f /opt/sonatype-work/nexus3/log/jvm.log
```

### Test API access
```bash
# Read admin password
ADMIN_PASS=$(cat /artifacts/nexus-admin-password.txt | cut -d: -f2)

# Test API
curl -u admin:${ADMIN_PASS} http://localhost:8081/service/rest/v1/status
```

### Check repositories
```bash
curl -u admin:${ADMIN_PASS} http://localhost:8081/service/rest/v1/repositories
```

### Reset admin password

If you lose the admin password, you can reset it:

1. Stop Nexus:
   ```bash
   sudo systemctl stop nexus
   ```

2. Remove the admin user from OrientDB (requires admin script or manual DB edit)

3. Or restore from backup

### Disk Space

Nexus can consume significant disk space. Monitor:
```bash
# Check data directory size
du -sh /opt/sonatype-work/nexus3

# Check blob stores
du -sh /opt/sonatype-work/nexus3/blobs/*
```

## Security Considerations

- Admin password is auto-generated and saved to artifacts
- Docker user passwords are auto-generated
- All passwords use 16 characters with letters and digits
- Bearer token authentication required for Docker
- Force basic auth enabled for Docker repository
- No privileged operations (NoNewPrivileges=true)
- Private temporary directory (PrivateTmp=true)

## Behind a Reverse Proxy

When using Nexus behind HAProxy or nginx:

### For Web UI

```haproxy
backend nexus
    server nexus1 127.0.0.1:8081
```

### For Docker Registry

```haproxy
backend nexus-docker
    server nexus1 127.0.0.1:8082
```

Or use path-based routing:
```nginx
location /repository/docker-hosted/ {
    proxy_pass http://127.0.0.1:8081/repository/docker-hosted/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

## Repository Types

While this role only creates Docker hosted repositories by default, Nexus supports:

- **Hosted**: Your own repository
- **Proxy**: Cache remote repositories (Docker Hub, Maven Central, etc.)
- **Group**: Combine multiple repositories

You can create additional repositories via the Nexus UI or extend this role.

## Performance Tuning

For better performance:

1. **Increase JVM heap**:
   ```yaml
   nexus_jvm_heap_min: "2048m"
   nexus_jvm_heap_max: "4096m"
   ```

2. **Use SSD storage** for `/opt/sonatype-work/nexus3`

3. **Separate blob stores** for different repository types

4. **Enable cleanup policies** to remove old artifacts

## Backup

To backup Nexus:

```bash
# Stop Nexus
sudo systemctl stop nexus

# Backup data directory
sudo tar -czf nexus-backup-$(date +%Y%m%d).tar.gz \
  /opt/sonatype-work/nexus3

# Start Nexus
sudo systemctl start nexus
```

Or use Nexus built-in backup tasks (configure via UI).

## License

MIT

## Author

Created for TP2026 DevOps course

## Improvements Over Shell Scripts

This role improves on the original shell scripts by:

1. **Idempotency** - Safe to run multiple times without breaking things
2. **Version detection** - Only downloads when version changes
3. **API-driven** - Uses Nexus REST API instead of waiting and hoping
4. **Error handling** - Proper status code checking and retries
5. **Credential management** - Reuses existing credentials on re-runs
6. **Modular structure** - Separate tasks for install, configure, resources
7. **Template** - Use Jinja2 templates for configuration files
8. **Handlers** - Only restart when configuration changes
9. **No hardcoded waits** - Uses actual API checks instead of sleep loops
10. **Better security** - Uses Ansible's no_log for sensitive data
