# DNS Server Role

This Ansible role installs and configures a Bind9 DNS server on Ubuntu/Debian systems with forwarding capabilities.

## Features

- ✅ **Idempotent configuration** - Safe to run multiple times
- ✅ **Automatic validation** - Configuration and zone files are validated before applying
- ✅ **Template-based** - Flexible configuration using Jinja2 templates
- ✅ **DNS forwarding** - Forward external queries to upstream DNS servers
- ✅ **Authoritative zone** - Host local domain records
- ✅ **Wildcard support** - Optional wildcard DNS entries
- ✅ **Automated testing** - Built-in DNS resolution verification

## Requirements

- Ubuntu/Debian system
- Ansible 2.9+
- Root/sudo access

## Role Variables

Available variables with their default values (see `defaults/main.yml`):

```yaml
# Domain configuration
dns_domain: "devops.active"
dns_ip: "192.168.56.10"
dns_forwarder: "8.8.8.8"

# Zone file settings
zone_serial: "2026020401"
zone_ttl: "604800"
zone_refresh: "604800"
zone_retry: "86400"
zone_expire: "2419200"
zone_negative_cache: "604800"

# DNS A records
dns_records:
  - name: "haproxy"
    ip: "{{ dns_ip }}"
  - name: "gitea"
    ip: "{{ dns_ip }}"
  - name: "nexus"
    ip: "{{ dns_ip }}"
  # Add more records as needed

# Wildcard configuration
dns_wildcard_enabled: true
dns_wildcard_ip: "{{ dns_ip }}"
```

## Dependencies

None.

## Example Playbook

### Basic usage:

```yaml
---
- name: Setup DNS server
  hosts: dns_server
  become: true
  roles:
    - role: dns_server
```

### With custom configuration:

```yaml
---
- name: Setup DNS server with custom settings
  hosts: dns_server
  become: true
  roles:
    - role: dns_server
      vars:
        dns_domain: "mycompany.local"
        dns_ip: "10.0.0.10"
        dns_forwarder: "1.1.1.1"
        dns_records:
          - name: "web"
            ip: "10.0.0.20"
          - name: "app"
            ip: "10.0.0.21"
          - name: "db"
            ip: "10.0.0.22"
        dns_wildcard_enabled: false
```

### Adding custom records:

```yaml
dns_records:
  - name: "haproxy"
    ip: "192.168.56.10"
  - name: "gitea"
    ip: "192.168.56.10"
  - name: "custom-service"
    ip: "192.168.56.20"
```

## Usage

1. Add the role to your playbook
2. Configure inventory with the DNS server host
3. Run the playbook:

```bash
ansible-playbook -i inventory playbooks/setup-dns-server.yml
```

## Validation

The role automatically:
- Validates Bind9 configuration with `named-checkconf`
- Validates zone files with `named-checkzone`
- Tests internal and external DNS resolution
- Reports test results

## Post-Installation Verification

After running the role, verify DNS from clients:

```bash
# Test internal domain resolution
dig gitea.devops.active @192.168.56.10

# Test external domain resolution (forwarding)
dig google.com @192.168.56.10

# Check DNS server status
systemctl status named
```

## Files and Templates

- `templates/named.conf.options.j2` - Bind9 main options configuration
- `templates/named.conf.local.j2` - Local zone definitions
- `templates/zone.db.j2` - DNS zone file with records

## Handlers

- `Restart bind9` - Restarts the named service
- `Reload bind9` - Reloads configuration without restart
- `Validate bind configuration` - Runs named-checkconf
- `Validate zone file` - Runs named-checkzone

## License

MIT

## Author

Created for TP2026 DevOps course
