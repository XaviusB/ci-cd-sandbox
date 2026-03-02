# Vagrant + Ansible Provisioning Guide

## Overview

The Vagrantfile is configured to use Ansible for DNS and HTTP proxy provisioning, while keeping shell scripts for application-specific services.

## VM Architecture

| VM | IP | Role | Ansible Provisioning | Shell Provisioning |
|---|---|---|---|---|
| haproxy | 192.168.56.10 | DNS Server + Load Balancer | dns_server, dns_client, http_proxy, ssh_tunnel | haproxy |
| gitea | 192.168.56.11 | Git Server | dns_client | gitea, gitea-backup |
| nexus | 192.168.56.12 | Artifact Repository | dns_client | nexus, nexus-resources |
| runner | 192.168.56.13 | CI/CD Runner | dns_client | gitea-runner |
| kube | 192.168.56.14 | Kubernetes | dns_client | asdf, k3s, helm-charts |

## Prerequisites

```bash
# Install Vagrant
# Install VirtualBox
# Install Ansible
sudo apt-get install ansible  # Ubuntu/Debian
brew install ansible           # macOS
```

## Common Operations

### Start all VMs
```bash
vagrant up
```

### Start a specific VM
```bash
vagrant up haproxy
vagrant up gitea
```

### Provision (run Ansible playbooks)

Re-run ALL provisioners on a VM:
```bash
vagrant provision haproxy
```

Re-run ONLY Ansible provisioners:
```bash
vagrant provision haproxy --provision-with ansible
```

Run specific provisioner by name (if you add names to provisioners).

### Destroy and rebuild
```bash
vagrant destroy -f
vagrant up
```

### SSH into a VM
```bash
vagrant ssh haproxy
vagrant ssh gitea
```

## Ansible Provisioning Details

### DNS Server (haproxy VM only)

```ruby
haproxy.vm.provision "ansible" do |ansible|
  ansible.playbook = "provisioning/playbooks/vagrant-dns-server.yml"
  ansible.config_file = "provisioning/ansible.cfg"
  ansible.become = true
  ansible.extra_vars = {
    dns_domain: "devops.active",
    dns_ip: "192.168.56.10",
    dns_forwarder: "8.8.8.8"
  }
end
```

**Note**: The `vagrant-dns-server.yml` playbook targets `hosts: all` because Vagrant provisions one VM at a time.

### DNS Client (all VMs)

```ruby
vm.provision "ansible" do |ansible|
  ansible.playbook = "provisioning/playbooks/vagrant-dns-client.yml"
  ansible.config_file = "provisioning/ansible.cfg"
  ansible.become = true
  ansible.extra_vars = {
    dns_server: "192.168.56.10"
  }
end
```

**Note**: The `vagrant-dns-client.yml` playbook targets `hosts: all` because Vagrant provisions one VM at a time.

## Troubleshooting

### "skipping: no hosts matched" Error

This happens when the playbook targets a host group (like `dns_server` or `dns_clients`) but Vagrant's auto-generated inventory doesn't have those groups.

**Solution**: Use the Vagrant-specific playbooks that target `hosts: all`:
- `vagrant-dns-server.yml` instead of `setup-dns-server.yml`
- `vagrant-dns-client.yml` instead of `setup-dns-client.yml`

These are already configured in the Vagrantfile.

### Ansible not found
Vagrant looks for Ansible on the host machine. Install it:
```bash
# Ubuntu/Debian
sudo apt-get install ansible

# macOS
brew install ansible
```

### Check Ansible version
```bash
ansible --version
```

### Test Ansible connectivity manually
```bash
cd provisioning
ansible all -i inventory/hosts.ini -m ping
```

### Run Ansible playbook manually (outside Vagrant)
```bash
cd provisioning

# Single VM
ansible-playbook playbooks/setup-dns-server.yml -i inventory/hosts.ini

# All infrastructure
ansible-playbook playbooks/setup-dns-infrastructure.yml -i inventory/hosts.ini
```

### Verbose Ansible output
Edit Vagrantfile and change:
```ruby
ansible.verbose = "vv"  # -vv for more details
```

### Skip Ansible provisioning temporarily
```bash
# Use only shell provisioning
vagrant provision haproxy --provision-with shell
```

## Advantages of Ansible Provisioning

✅ **Idempotent** - Safe to run `vagrant provision` multiple times
✅ **Faster** - Skips unchanged configurations
✅ **Declarative** - Define desired state, not steps
✅ **Better error handling** - Clearer error messages
✅ **Reusable** - Same roles work outside Vagrant
✅ **Testing** - Can test with `--check` mode

## Migrating Other Services to Ansible

To convert more shell scripts to Ansible roles:

1. Create a new role: `provisioning/roles/service_name/`
2. Convert bash commands to Ansible tasks
3. Update Vagrantfile provisioner
4. Test with `vagrant provision`

Example structure:
```
provisioning/roles/gitea/
├── defaults/main.yml
├── handlers/main.yml
├── tasks/main.yml
└── templates/
    └── gitea.ini.j2
```

## Environment Variables

You can override variables when provisioning:

```bash
# Via environment
export ANSIBLE_ARGS="--extra-vars 'dns_forwarder=1.1.1.1'"
vagrant provision haproxy
```

Or edit the Vagrantfile `extra_vars` section directly.

## See Also

- [Ansible Provisioning Guide](provisioning/README.md)
- [DNS Server Role](provisioning/roles/dns_server/README.md)
- [DNS Client Role](provisioning/roles/dns_client/README.md)
