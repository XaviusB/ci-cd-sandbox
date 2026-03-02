# TLS Certificates Role

This Ansible role generates SSL/TLS certificates including a self-signed CA and server certificates with Subject Alternative Names (SAN) support.

## Features

- ✅ **Self-signed CA** - Creates a Certificate Authority for signing server certificates
- ✅ **Server certificates** - Generates server certificates with proper CN
- ✅ **SAN support** - Subject Alternative Names for wildcard and multiple domains
- ✅ **Idempotent** - Checks for existing certificates before generating
- ✅ **CN validation** - Regenerates certificates if CN changes
- ✅ **HAProxy ready** - Creates PEM bundles (cert + key)
- ✅ **Auto-export** - Copies CA cert to artifacts for browser import

## Requirements

- Ubuntu/Debian system
- Ansible 2.9+
- Ansible collection: `community.crypto`
- Root/sudo access
- Python 3 with `cryptography` library

### Install Requirements

```bash
# Install Ansible collection
ansible-galaxy collection install community.crypto

# Python cryptography is installed automatically by the role
```

## Role Variables

Available variables with their default values (see `defaults/main.yml`):

```yaml
# Basic settings
cert_domain: "devops.active"
cert_dir: "/etc/haproxy/certs"
artifacts_dir: "/artifacts"
cert_validity_days: 3650  # 10 years

# CA certificate settings
ca_key_name: "devops-active-CA.key"
ca_cert_name: "devops-active-CA.crt"
ca_key_size: 4096
ca_subject:
  country: "US"
  state: "DevOps"
  locality: "Lab"
  organization: "DevOps Local"
  organizational_unit: "CA"
  common_name: "DevOps Local CA"

# Server certificate settings
server_key_size: 4096
server_subject:
  country: "US"
  state: "DevOps"
  locality: "Lab"
  organization: "DevOps Local"
  organizational_unit: "HAProxy"
  common_name: "{{ cert_domain }}"

# Subject Alternative Names
cert_san_dns:
  - "{{ cert_domain }}"
  - "*.{{ cert_domain }}"
  - "localhost"

# Export options
copy_ca_to_artifacts: true
```

## Dependencies

None.

## Example Playbook

### Basic usage:

```yaml
---
- name: Generate TLS certificates
  hosts: proxy_server
  become: true
  roles:
    - role: tls_certificates
```

### With custom domain:

```yaml
---
- name: Generate TLS certificates for custom domain
  hosts: proxy_server
  become: true
  roles:
    - role: tls_certificates
      vars:
        cert_domain: "mycompany.local"
        cert_san_dns:
          - "mycompany.local"
          - "*.mycompany.local"
          - "localhost"
          - "www.mycompany.local"
```

### Custom certificate directories:

```yaml
---
- name: Generate certificates with custom paths
  hosts: proxy_server
  become: true
  roles:
    - role: tls_certificates
      vars:
        cert_domain: "example.com"
        cert_dir: "/etc/ssl/custom"
        artifacts_dir: "/tmp/certs"
        cert_validity_days: 365
```

## Usage

1. Add the role to your playbook
2. Configure variables as needed
3. Run the playbook:

```bash
ansible-playbook -i inventory playbooks/setup-tls-certificates.yml
```

## Generated Files

### In certificate directory (default: `/etc/haproxy/certs/`):

```
/etc/haproxy/certs/
├── devops-active-CA.key       # CA private key (mode 600)
├── devops-active-CA.crt       # CA certificate (self-signed)
├── devops-active-CA.srl       # CA serial number
├── devops.active.key          # Server private key (mode 600)
├── devops.active.crt          # Server certificate (signed by CA)
└── devops.active.pem          # PEM bundle for HAProxy (cert + key, mode 600)
```

### In artifacts directory (default: `/artifacts/`):

```
/artifacts/
└── devops-active-CA.crt       # CA certificate (for browser import)
```

## Certificate Details

### CA Certificate:
- **Type**: Self-signed root CA
- **Key Size**: 4096 bits RSA
- **Validity**: 10 years (default)
- **Hash**: SHA-256

### Server Certificate:
- **Type**: Server certificate signed by CA
- **Key Size**: 4096 bits RSA
- **Validity**: 10 years (default)
- **Hash**: SHA-256
- **Extensions**: Subject Alternative Names (SAN)

## Browser Import

To trust the certificates in your browser:

### Chrome/Edge (Windows):
1. Copy `devops-active-CA.crt` from artifacts
2. Double-click the file
3. Click "Install Certificate"
4. Select "Local Machine" → "Place all certificates in the following store"
5. Browse → "Trusted Root Certification Authorities"
6. Click "Next" → "Finish"

### Firefox:
1. Settings → Privacy & Security → Certificates → View Certificates
2. Authorities tab → Import
3. Select `devops-active-CA.crt`
4. Check "Trust this CA to identify websites"

### Linux:
```bash
sudo cp devops-active-CA.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

### macOS:
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain devops-active-CA.crt
```

## HAProxy Integration

The generated PEM bundle can be used directly in HAProxy:

```haproxy
frontend https
    bind :443 ssl crt /etc/haproxy/certs/devops.active.pem
```

## Idempotency

The role is idempotent:
- ✅ Skips generation if certificates already exist
- ✅ Validates CN and regenerates if domain changes
- ✅ Safe to run multiple times
- ✅ Only generates what's missing

## Verification

Check certificate details:

```bash
# View CA certificate
openssl x509 -in /etc/haproxy/certs/devops-active-CA.crt -text -noout

# View server certificate
openssl x509 -in /etc/haproxy/certs/devops.active.crt -text -noout

# View SAN entries
openssl x509 -in /etc/haproxy/certs/devops.active.crt -text -noout | grep -A1 "Subject Alternative Name"

# Verify certificate chain
openssl verify -CAfile /etc/haproxy/certs/devops-active-CA.crt /etc/haproxy/certs/devops.active.crt
```

## Security Notes

- Private keys are stored with mode 600 (root only)
- Certificate directory has mode 700 (root only)
- PEM bundle combines cert and key for HAProxy
- CA certificate is exported for browser trust

## License

MIT

## Author

Created for TP2026 DevOps course
