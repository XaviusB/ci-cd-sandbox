** This is experimental **

# TP2026 Ansible Provisioning

Ansible-based provisioning for TP2026 DevOps infrastructure.

## Structure

```
provisioning/
├── ansible.cfg                    # Ansible configuration
├── inventory/
│   └── hosts.ini                 # Inventory file
├── playbooks/
│   ├── setup-dns-client.yml      # DNS client setup (standalone)
│   ├── setup-dns-server.yml      # DNS server setup (standalone)
│   ├── setup-dns-infrastructure.yml  # Complete DNS infrastructure
│   ├── setup-http-proxy.yml      # HTTP proxy setup (standalone)
│   ├── setup-ssh-tunnel.yml      # SSH tunnel setup (standalone)
│   ├── vagrant-dns-client.yml    # Vagrant-specific DNS client (hosts: all)
│   ├── vagrant-dns-server.yml    # Vagrant-specific DNS server (hosts: all)
│   ├── vagrant-http-proxy.yml    # Vagrant-specific HTTP proxy (hosts: all)
│   ├── vagrant-ssh-tunnel.yml    # Vagrant-specific SSH tunnel (hosts: all)
│   └── playbook-haproxy.yml      # Complete HAProxy VM setup
└── roles/
    ├── dns_client/               # DNS client configuration role
    │   ├── README.md
    │   ├── defaults/
    │   │   └── main.yml
    │   ├── handlers/
    │   │   └── main.yml
    │   ├── meta/
    │   │   └── main.yml
    │   └── tasks/
    │       └── main.yml
    ├── dns_server/               # DNS server configuration role
    │   ├── README.md
    │   ├── defaults/
    │   │   └── main.yml
    │   ├── handlers/
    │   │   └── main.yml
    │   ├── meta/
    │   │   └── main.yml
    │   ├── tasks/
    │   │   └── main.yml
    │   └── templates/
    │       ├── named.conf.options.j2
    │       ├── named.conf.local.j2
    │       └── zone.db.j2
    └── http_proxy/               # HTTP proxy (Squid) configuration role
        ├── README.md
        ├── defaults/
        │   └── main.yml
        ├── handlers/
        │   └── main.yml
        ├── meta/
        │   └── main.yml
        ├── tasks/
        │   └── main.yml
        └── templates/
            └── squid.conf.j2
    └── ssh_tunnel/               # SSH tunnel with chroot jail role
        ├── README.md
        ├── defaults/
        │   └── main.yml
        ├── files/
        │   └── copy-binary-to-chroot.sh
        ├── handlers/
        │   └── main.yml
        ├── meta/
        │   └── main.yml
        ├── tasks/
        │   └── main.yml
        └── templates/
            └── ssh-tunnel-info.txt.j2
```
            ├── named.conf.local.j2
            └── zone.db.j2
```

## Quick Start

### 1. Configure Inventory

Edit `inventory/hosts.ini` and add your target hosts:

```ini
[dns_server]
192.168.56.10

[dns_clients]
192.168.56.11
192.168.56.12
```

### 2. Run the Playbook

Setup complete DNS infrastructure (server + clients):

```bash
cd provisioning
ansible-playbook playbooks/setup-dns-infrastructure.yml
```

Or setup components individually:

```bash
# DNS server only
ansible-playbook playbooks/setup-dns-server.yml

# DNS clients only
ansible-playbook playbooks/setup-dns-client.yml

# HTTP proxy only
ansible-playbook playbooks/setup-http-proxy.yml

# SSH tunnel only
ansible-playbook playbooks/setup-ssh-tunnel.yml
```

### 3. Run with Custom Variables

```bash
ansible-playbook playbooks/setup-dns-client.yml -e "dns_server=10.0.0.1"
```

## Available Roles

### dns_server

Installs and configures a Bind9 DNS server with forwarding capabilities.

**Key features:**
- Bind9 installation and configuration
- DNS forwarding to upstream servers
- Authoritative zone for local domain
- Template-based configuration
- Automatic validation (named-checkconf, named-checkzone)
- Built-in DNS resolution testing
- Wildcard DNS support

See [roles/dns_server/README.md](roles/dns_server/README.md) for details.

### dns_client

Configures DNS client settings using netplan. **No external dependencies required** - uses native Ansible YAML manipulation instead of `yq`.

**Key features:**
- Automatic network interface detection
- Backup of existing configuration
- Native Ansible YAML manipulation (no `yq` needed)
- Automatic netplan application
- DNS verification

See [roles/dns_client/README.md](roles/dns_client/README.md) for details.

### http_proxy

Installs and configures Squid HTTP proxy server with caching and access control.

**Key features:**
- Squid installation and configuration
- Memory and disk caching
- ACL-based access control
- DNS integration
- K8s API CONNECT support
- Template-based configuration
- Automatic testing and validation

See [roles/http_proxy/README.md](roles/http_proxy/README.md) for details.

### ssh_tunnel

Sets up a secure SSH tunnel user with chroot jail for restricted access.

**Key features:**
- Chroot jail environment
- Key-based authentication only
- Automatic SSH key generation
- Port forwarding support
- Minimal binaries in chroot
- Security hardened configuration
- MOTD disabled for clean tunnel experience

See [roles/ssh_tunnel/README.md](roles/ssh_tunnel/README.md) for details.

## Advantages Over Bash Scripts

✅ **Idempotent** - Safe to run multiple times
✅ **No external tools** - No need for `yq`, uses native Ansible
✅ **Better error handling** - Built-in rollback capabilities
✅ **Declarative** - Define desired state, not steps
✅ **Multi-host** - Easy to apply to multiple VMs
✅ **Reusable** - Modular roles can be shared

## Testing

Test the role without making changes:

```bash
ansible-playbook playbooks/setup-dns-client.yml --check
```

## Requirements

- Ansible 2.9 or higher
- SSH access to target hosts
- Sudo privileges on target hosts

## License

MIT
