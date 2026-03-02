# DNS Client Role

This Ansible role configures DNS client settings on Ubuntu/Debian systems using netplan.

## Features

- ✅ **No external dependencies** (no `yq` required - uses native Ansible YAML manipulation)
- Automatic network interface detection
- Backup of existing netplan configuration
- DNS configuration via netplan
- Automatic application of network changes
- DNS resolution verification

## Requirements

- Ubuntu/Debian system with netplan
- Ansible 2.9+
- Root/sudo access

## Role Variables

Available variables with their default values (see `defaults/main.yml`):

```yaml
# DNS server IP address
dns_server: "192.168.56.10"

# Path to the netplan configuration file
netplan_file: "/etc/netplan/50-vagrant.yaml"

# Whether to backup the existing netplan file
netplan_backup: true
```

## Dependencies

None.

## Example Playbook

```yaml
---
- name: Configure DNS clients
  hosts: dns_clients
  become: true
  roles:
    - role: dns_client
      vars:
        dns_server: "192.168.56.10"
```

### With custom variables:

```yaml
---
- name: Configure DNS clients with custom settings
  hosts: all
  become: true
  roles:
    - role: dns_client
      vars:
        dns_server: "10.0.0.1"
        netplan_file: "/etc/netplan/01-netcfg.yaml"
        netplan_backup: false
```

## Usage

1. Add the role to your playbook
2. Configure inventory with target hosts
3. Run the playbook:

```bash
ansible-playbook -i inventory playbooks/setup-dns-client.yml
```

## Verification

After running the role, verify DNS configuration:

```bash
# Check DNS settings
resolvectl status

# Test DNS resolution
dig gitea.devops.local
```

## License

MIT

## Author

Created for TP2026 DevOps course
