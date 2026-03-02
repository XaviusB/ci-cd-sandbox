# HAProxy Role

This Ansible role installs and configures HAProxy as a reverse proxy and load balancer with SSL termination, routing traffic to Gitea, Nexus, and Kubernetes backends.

## Features

- ✅ **SSL termination** - HTTPS with custom certificates
- ✅ **HTTP to HTTPS redirect** - Automatic redirect
- ✅ **Host-based routing** - Routes by domain name
- ✅ **Multiple backends** - Gitea, Nexus, Kubernetes
- ✅ **TCP proxying** - K8s API and Gitea SSH
- ✅ **Configuration validation** - Validates before applying
- ✅ **Idempotent** - Safe to run multiple times
- ✅ **Browser proxy** - Additional proxy port

## Requirements

- Ubuntu/Debian system
- Ansible 2.9+
- Root/sudo access
- TLS certificates (use `tls_certificates` role first)

### Certificate Requirement

This role expects a PEM bundle (certificate + private key) to exist at `/etc/haproxy/certs/devops.active.pem`. Use the `tls_certificates` role to generate this before running the `haproxy` role.

## Role Variables

Available variables with their default values (see `defaults/main.yml`):

### Certificate Settings

```yaml
haproxy_cert_dir: "/etc/haproxy/certs"
haproxy_cert_domain: "devops.active"
haproxy_cert_pem: "{{ haproxy_cert_dir }}/{{ haproxy_cert_domain }}.pem"
```

### SSL Configuration

```yaml
haproxy_ssl_min_ver: "TLSv1.2"
haproxy_ssl_ciphers: "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:..."
haproxy_ssl_ciphersuites: "TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:..."
```

### Timeout Settings

```yaml
haproxy_timeout_connect: "5000"
haproxy_timeout_client: "50000"
haproxy_timeout_server: "50000"
```

### Backend Servers

```yaml
# Gitea backend
haproxy_backend_gitea_host: "192.168.56.11"
haproxy_backend_gitea_http_port: "3000"
haproxy_backend_gitea_ssh_port: "2222"

# Nexus backend
haproxy_backend_nexus_host: "192.168.56.12"
haproxy_backend_nexus_port: "8081"

# Kubernetes backend
haproxy_backend_kube_host: "192.168.56.14"
haproxy_backend_kube_http_port: "30080"
haproxy_backend_kube_api_port: "6443"
```

### Frontend Ports

```yaml
haproxy_frontend_http_port: "80"
haproxy_frontend_https_port: "443"
haproxy_frontend_k8s_api_port: "6443"
haproxy_frontend_gitea_ssh_port: "2222"
haproxy_frontend_browser_proxy_port: "8080"
```

### Domain Routing

```yaml
haproxy_domain_nexus: "nexus.{{ haproxy_cert_domain }}"
haproxy_domain_gitea: "gitea.{{ haproxy_cert_domain }}"
```

### Service Settings

```yaml
haproxy_redirect_http_to_https: true
haproxy_enable_service: true
haproxy_validate_config: true
```

## Dependencies

None. However, you should run the `tls_certificates` role first to generate SSL certificates.

## Example Playbook

### Basic usage with certificate generation:

```yaml
---
- name: Setup HAProxy with SSL
  hosts: proxy_server
  become: true
  roles:
    - role: tls_certificates
    - role: haproxy
```

### With custom backend configuration:

```yaml
---
- name: Setup HAProxy with custom backends
  hosts: proxy_server
  become: true
  roles:
    - role: tls_certificates
      vars:
        cert_domain: "company.local"
    - role: haproxy
      vars:
        haproxy_cert_domain: "company.local"
        haproxy_backend_gitea_host: "10.0.1.11"
        haproxy_backend_nexus_host: "10.0.1.12"
        haproxy_backend_kube_host: "10.0.1.14"
```

### Complete infrastructure setup:

```yaml
---
- name: Setup HAProxy VM
  hosts: haproxy
  become: true
  roles:
    - role: dns_client
    - role: dns_server
    - role: http_proxy
    - role: ssh_tunnel
    - role: tls_certificates
    - role: haproxy
```

## Usage

1. Ensure certificates are generated (use `tls_certificates` role)
2. Add the role to your playbook
3. Configure backend servers as needed
4. Run the playbook:

```bash
ansible-playbook -i inventory playbooks/setup-haproxy.yml
```

## HAProxy Configuration

The role generates `/etc/haproxy/haproxy.cfg` with the following structure:

### Frontends

#### main (HTTP/HTTPS)
- **Port 80**: HTTP (redirects to HTTPS)
- **Port 443**: HTTPS with SSL termination
- **Routing**:
  - `nexus.devops.active` → nexus backend
  - `gitea.devops.active` → gitea backend
  - Default → kube backend

#### k8s_api (TCP)
- **Port 6443**: Kubernetes API server
- Routes to K8s backend on port 6443

#### giteassh (TCP)
- **Port 2222**: Gitea SSH
- Routes to Gitea SSH backend on port 2222

#### browser_proxy (HTTP)
- **Port 8080**: Browser proxy
- Routes to Gitea based on host header
- Default: Gitea

### Backends

#### giteaweb
- **Mode**: HTTP
- **Server**: `192.168.56.11:3000`
- **Options**: forwardfor

#### nexus
- **Mode**: HTTP
- **Server**: `192.168.56.12:8081`
- **Options**: forwardfor, health checks

#### kube
- **Mode**: HTTP
- **Server**: `192.168.56.14:30080`
- **Options**: forwardfor, health checks

#### k8s_api
- **Mode**: TCP
- **Server**: `192.168.56.14:6443`

#### giteassh
- **Mode**: TCP
- **Server**: `192.168.56.11:2222`

## SSL/TLS Configuration

The role uses Mozilla's intermediate SSL configuration:
- **TLS Version**: TLSv1.2 minimum
- **Ciphers**: Modern, secure cipher suites
- **Cipher Suites**: TLS 1.3 cipher suites
- **Options**: No TLS tickets

## Traffic Flow

### HTTPS Traffic
```
Client → HAProxy :443 (SSL termination)
  ├─ nexus.devops.active → 192.168.56.12:8081
  ├─ gitea.devops.active → 192.168.56.11:3000
  └─ *.devops.active     → 192.168.56.14:30080 (default)
```

### K8s API Traffic
```
Client → HAProxy :6443 → 192.168.56.14:6443
```

### Gitea SSH Traffic
```
Client → HAProxy :2222 → 192.168.56.11:2222
```

## Verification

### Check HAProxy status
```bash
systemctl status haproxy
```

### Validate configuration
```bash
haproxy -c -f /etc/haproxy/haproxy.cfg
```

### View HAProxy stats (if enabled)
The stats socket is available at `/run/haproxy/admin.sock`.

### Test routing
```bash
# Test HTTP to HTTPS redirect
curl -I http://gitea.devops.active

# Test HTTPS with domain routing
curl -k https://gitea.devops.active
curl -k https://nexus.devops.active

# Test K8s API
curl -k https://localhost:6443

# Test Gitea SSH
ssh -T -p 2222 git@localhost
```

## Port Overview

| Port | Protocol | Service | Backend |
|------|----------|---------|---------|
| 80 | HTTP | Web (redirects to HTTPS) | - |
| 443 | HTTPS | Web with SSL | gitea/nexus/kube |
| 2222 | TCP | Gitea SSH | gitea:2222 |
| 6443 | TCP | K8s API | kube:6443 |
| 8080 | HTTP | Browser Proxy | gitea |

## Idempotency

The role is idempotent:
- ✅ Only restarts HAProxy when config changes
- ✅ Validates configuration before applying
- ✅ Safe to run multiple times
- ✅ No changes if config is identical

## Troubleshooting

### Certificate not found error
```
FAILED! => {"msg": "Certificate PEM bundle not found at /etc/haproxy/certs/devops.active.pem"}
```
**Solution**: Run the `tls_certificates` role first.

### Configuration validation failed
Check HAProxy logs:
```bash
journalctl -u haproxy -n 50
```

### Backend health check failures
Check backend server connectivity:
```bash
# Test Gitea
curl http://192.168.56.11:3000

# Test Nexus
curl http://192.168.56.12:8081

# Test Kube
curl http://192.168.56.14:30080
```

### Port already in use
Check what's using the port:
```bash
sudo netstat -tlnp | grep :443
# or
sudo ss -tlnp | grep :443
```

## Security Considerations

- SSL termination at HAProxy
- TLS 1.2+ only
- Strong cipher suites (Mozilla intermediate)
- No TLS tickets (prevents session resumption attacks)
- Health checks on backends
- Proper timeout settings

## Integration with Other Roles

### With DNS
```yaml
roles:
  - role: dns_server
  - role: haproxy
```

### With HTTP Proxy
```yaml
roles:
  - role: http_proxy
  - role: haproxy
```

### Complete Stack
```yaml
roles:
  - role: dns_client
  - role: dns_server
  - role: http_proxy
  - role: ssh_tunnel
  - role: tls_certificates
  - role: haproxy
```

## Customization

### Add a new backend

1. Add backend variables in `defaults/main.yml`:
   ```yaml
   haproxy_backend_jenkins_host: "192.168.56.15"
   haproxy_backend_jenkins_port: "8080"
   ```

2. Update the template `templates/haproxy.cfg.j2`:
   ```haproxy
   backend jenkins
       option forwardfor
       mode http
       server jenkins {{ haproxy_backend_jenkins_host }}:{{ haproxy_backend_jenkins_port }} check
   ```

3. Add routing in frontend:
   ```haproxy
   use_backend jenkins if { req.hdr(host) -i jenkins.devops.active }
   ```

## License

MIT

## Author

Created for TP2026 DevOps course
