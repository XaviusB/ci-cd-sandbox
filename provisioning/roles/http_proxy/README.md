# HTTP Proxy Role

This Ansible role installs and configures Squid HTTP proxy server on Ubuntu/Debian systems with caching and access control.

## Features

- ✅ **Idempotent configuration** - Safe to run multiple times
- ✅ **Template-based** - Flexible configuration using Jinja2 templates
- ✅ **Memory and disk caching** - Configurable cache sizes
- ✅ **Access control** - ACL-based security
- ✅ **DNS integration** - Uses local DNS server
- ✅ **K8s API support** - CONNECT method for Kubernetes API access
- ✅ **Automated testing** - Built-in proxy connectivity verification

## Requirements

- Ubuntu/Debian system
- Ansible 2.9+
- Root/sudo access

## Role Variables

Available variables with their default values (see `defaults/main.yml`):

```yaml
# Basic configuration
squid_port: 3128
squid_user: "squid"

# DNS server
squid_dns_nameservers: "192.168.56.10"

# Memory cache settings
squid_cache_mem: "256 MB"
squid_max_object_size_in_memory: "512 KB"

# Disk cache settings
squid_cache_dir: "ufs /var/spool/squid 1000 16 256"
squid_max_object_size: "512 MB"

# Performance tuning
squid_workers: 1
squid_max_filedescriptors: 65535

# Access Control Lists
squid_local_networks:
  - "192.168.0.0/16"
  - "10.0.0.0/8"
  - "172.16.0.0/12"
  - "fc00::/7"
  - "fe80::/10"

squid_k8s_api_domain: "k8s.devops.active"

squid_ssl_ports:
  - 443
  - 6443

squid_safe_ports:
  - 80
  - 21
  - 443
  - 70
  - 210
  - "1025-65535"
  - 280
  - 488
  - 591
  - 777

# Logging
squid_access_log: "/var/log/squid/access.log squid"
squid_cache_log: "/var/log/squid/cache.log"
squid_logfile_rotate: 10
```

## Dependencies

None.

## Example Playbook

### Basic usage:

```yaml
---
- name: Setup HTTP proxy
  hosts: proxy_server
  become: true
  roles:
    - role: http_proxy
```

### With custom configuration:

```yaml
---
- name: Setup HTTP proxy with custom settings
  hosts: proxy_server
  become: true
  roles:
    - role: http_proxy
      vars:
        squid_port: 8080
        squid_cache_mem: "512 MB"
        squid_max_object_size: "1 GB"
        squid_dns_nameservers: "8.8.8.8"
        squid_local_networks:
          - "10.0.0.0/8"
          - "172.16.0.0/12"
```

### Custom ACLs and domains:

```yaml
squid_k8s_api_domain: "kubernetes.local"
squid_ssl_ports:
  - 443
  - 6443
  - 8443
```

## Usage

1. Add the role to your playbook
2. Configure inventory with the proxy server host
3. Run the playbook:

```bash
ansible-playbook -i inventory playbooks/setup-http-proxy.yml
```

## Validation

The role automatically:
- Initializes Squid cache directories
- Validates configuration with `squid -k check`
- Tests proxy connectivity
- Reports test results

## Post-Installation Verification

### Check service status:
```bash
systemctl status squid
```

### Test proxy from client:
```bash
# Test HTTP
curl -x http://192.168.56.10:3128 http://www.google.com

# Test HTTPS
curl -x http://192.168.56.10:3128 https://www.google.com

# Test K8s API
curl -x http://192.168.56.10:3128 https://k8s.devops.active:6443
```

### View logs:
```bash
# Access log
tail -f /var/log/squid/access.log

# Cache log
tail -f /var/log/squid/cache.log

# System logs
journalctl -u squid -f
```

### Check cache statistics:
```bash
squidclient -p 3128 mgr:info
squidclient -p 3128 mgr:mem
```

## Configuration Files

- `templates/squid.conf.j2` - Main Squid configuration template

## Handlers

- `Restart squid` - Restarts the squid service
- `Reload squid` - Reloads configuration without restart
- `Validate squid configuration` - Runs squid -k check

## Client Configuration

To use the proxy from client machines:

### Environment variables:
```bash
export http_proxy="http://192.168.56.10:3128"
export https_proxy="http://192.168.56.10:3128"
export no_proxy="localhost,127.0.0.1"
```

### Docker:
```json
{
  "proxies": {
    "default": {
      "httpProxy": "http://192.168.56.10:3128",
      "httpsProxy": "http://192.168.56.10:3128",
      "noProxy": "localhost,127.0.0.1"
    }
  }
}
```

### APT (Ubuntu/Debian):
```bash
echo 'Acquire::http::Proxy "http://192.168.56.10:3128";' | sudo tee /etc/apt/apt.conf.d/proxy.conf
```

## Performance Tuning

For high-traffic environments:

```yaml
squid_cache_mem: "1024 MB"
squid_max_object_size: "2 GB"
squid_cache_dir: "ufs /var/spool/squid 10000 16 256"
squid_workers: 4
```

## License

MIT

## Author

Created for TP2026 DevOps course
