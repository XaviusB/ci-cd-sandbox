# SSH Tunnel Role

This Ansible role sets up a secure SSH tunnel user with chroot jail on Ubuntu/Debian systems.

## Features

- ✅ **Chroot jail** - Restricted environment for SSH tunnel user
- ✅ **Key-based authentication** - Automatic SSH key generation
- ✅ **Port forwarding** - Allows TCP forwarding for tunneling
- ✅ **Minimal binaries** - Only essential binaries copied to chroot
- ✅ **Security hardened** - Disabled password auth, X11, agent forwarding
- ✅ **MOTD disabled** - Clean tunnel experience
- ✅ **Automated setup** - Complete environment configuration

## Requirements

- Ubuntu/Debian system
- Ansible 2.9+
- Root/sudo access
- OpenSSH server

## Role Variables

Available variables with their default values (see `defaults/main.yml`):

```yaml
# User configuration
tunnel_user: "tunnel"
tunnel_home: "/home/{{ tunnel_user }}"
tunnel_chroot_dir: "/var/jail/sshtunnel"

# Artifact paths
artifacts_dir: "/artifacts"
tunnel_key_private: "{{ artifacts_dir }}/ssh-tunnel-key"
tunnel_key_public: "{{ artifacts_dir }}/ssh-tunnel-key.pub"
tunnel_info_file: "{{ artifacts_dir }}/ssh-tunnel-info.txt"

# SSH configuration
sshd_config_path: "/etc/ssh/sshd_config"
tunnel_endpoint: "192.168.0.252"

# Binaries to copy into chroot
tunnel_chroot_binaries:
  - /bin/bash
  - /bin/sh
  - /bin/ls
  - /usr/bin/id
  - /usr/bin/whoami

# MOTD disable
disable_motd: true
```

## Dependencies

None.

## Example Playbook

### Basic usage:

```yaml
---
- name: Setup SSH tunnel
  hosts: tunnel_server
  become: true
  roles:
    - role: ssh_tunnel
```

### With custom configuration:

```yaml
---
- name: Setup SSH tunnel with custom settings
  hosts: tunnel_server
  become: true
  roles:
    - role: ssh_tunnel
      vars:
        tunnel_user: "mytunnel"
        tunnel_endpoint: "10.0.0.1"
        tunnel_chroot_binaries:
          - /bin/bash
          - /bin/sh
          - /bin/ls
          - /usr/bin/id
          - /usr/bin/whoami
          - /usr/bin/curl
```

## Usage

1. Add the role to your playbook
2. Configure inventory with the tunnel server host
3. Run the playbook:

```bash
ansible-playbook -i inventory playbooks/setup-ssh-tunnel.yml
```

## What Gets Created

### Directory Structure

```
/var/jail/sshtunnel/
├── dev/                    # Device nodes (null, zero, tty, random, urandom)
├── etc/
│   ├── passwd             # Minimal passwd file
│   └── group              # Minimal group file
├── home/
│   └── tunnel/
│       └── .ssh/          # SSH configuration
├── tmp/                   # Temporary directory
├── bin/                   # Essential binaries
├── lib/                   # Required libraries
├── lib64/                 # 64-bit libraries
└── usr/
    ├── bin/               # User binaries
    └── lib/               # User libraries
```

### Artifacts

The role generates the following files in `/artifacts/`:

- `ssh-tunnel-key` - Private SSH key (mode 600)
- `ssh-tunnel-key.pub` - Public SSH key (mode 644)
- `ssh-tunnel-info.txt` - Connection info (mode 600)

## Post-Installation Usage

### From client machine:

```bash
# Copy the private key
scp vagrant@192.168.0.252:/artifacts/ssh-tunnel-key ~/.ssh/

# Set proper permissions
chmod 600 ~/.ssh/ssh-tunnel-key

# Create an SSH tunnel
ssh -i ~/.ssh/ssh-tunnel-key \
    -N -f \
    -L 6443:192.168.56.14:6443 \
    tunnel@192.168.0.252

# Or with dynamic SOCKS proxy
ssh -i ~/.ssh/ssh-tunnel-key \
    -N -f \
    -D 1080 \
    tunnel@192.168.0.252
```

### Verify tunnel:

```bash
# Check if tunnel is running
ps aux | grep "ssh.*tunnel"

# Test connection
ssh -i ~/.ssh/ssh-tunnel-key tunnel@192.168.0.252 whoami
```

### Close tunnel:

```bash
# Find and kill the SSH process
pkill -f "ssh.*tunnel@192.168.0.252"
```

## Security Features

The chroot jail provides:

- **Restricted filesystem** - User can only see chroot environment
- **No password authentication** - Key-based only
- **No X11 forwarding** - Prevents GUI applications
- **No agent forwarding** - Prevents SSH key theft
- **Limited binaries** - Only essential commands available
- **TCP forwarding only** - Allows tunnel but nothing else

## SSH Configuration

The role adds this configuration to `/etc/ssh/sshd_config`:

```
Match User tunnel
    ChrootDirectory /var/jail/sshtunnel
    AllowTcpForwarding yes
    PermitTTY yes
    X11Forwarding no
    AllowAgentForwarding no
    PasswordAuthentication no
    PubkeyAuthentication yes
```

## Troubleshooting

### User can't login:

```bash
# Check SSH logs
journalctl -u ssh -f

# Verify key permissions
ls -la /home/tunnel/.ssh/authorized_keys

# Test SSH manually
ssh -i /artifacts/ssh-tunnel-key -vvv tunnel@localhost
```

### Missing libraries error:

Add the required binary to `tunnel_chroot_binaries` variable and re-run the role.

### Permission denied errors:

```bash
# Check chroot ownership
ls -ld /var/jail/sshtunnel

# Should be root:root with mode 755
# If not, re-run the role
```

## Files and Templates

- `files/copy-binary-to-chroot.sh` - Script to copy binaries with dependencies
- `templates/ssh-tunnel-info.txt.j2` - Connection info template

## Handlers

- `Restart SSH service` - Restarts SSH daemon
- `Reload SSH service` - Reloads SSH configuration

## License

MIT

## Author

Created for TP2026 DevOps course
