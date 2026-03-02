#!/bin/bash

set -e

source "$(dirname "$0")/common/apt-update.sh"

# Variables
HELM_VERSION="4.1.0"
KUBE_API="k8s.devops.active"
K3S_VERSION="v1.32.11+k3s1"
KUBECTL_VERSION="1.35.0"
KUBECTX_VERSION="0.9.5"
NEXUS_REGISTRY_HOST="nexus.devops.active"
NEXUS_CA_SOURCE="/artifacts/devops-active-CA.crt"
NEXUS_CA_TARGET="/usr/local/share/ca-certificates/devops-active-CA.crt"
STERN_VERSION="1.25.0"
YQ_VERSION="4.30.8"

echo "==> Create asdf configuration for kubectl"
cat <<EOF >/root/.tool-versions
helm ${HELM_VERSION}
kubectx ${KUBECTX_VERSION}
stern ${STERN_VERSION}
yq ${YQ_VERSION}
EOF

echo "==> Installing dependencies"
apt_update
apt-get install -y curl fzf ca-certificates

export PATH="$HOME/.asdf/shims:$PATH"

asdf plugin add helm
asdf plugin add kubectx
asdf plugin add stern
asdf plugin add yq
asdf install

echo "==> Trusting DevOps CA for Nexus"
if [ ! -f "${NEXUS_CA_TARGET}" ]; then
    cp "${NEXUS_CA_SOURCE}" "${NEXUS_CA_TARGET}"
    update-ca-certificates
else
    echo "==> ${NEXUS_CA_TARGET} already exists. Skipping CA update."
fi

echo "==> Configuring containerd registry for Nexus"
mkdir -p /etc/rancher/k3s
cat > /etc/rancher/k3s/registries.yaml <<EOF
mirrors:
  "${NEXUS_REGISTRY_HOST}":
    endpoint:
      - "https://${NEXUS_REGISTRY_HOST}"
configs:
  "${NEXUS_REGISTRY_HOST}":
    tls:
      ca_file: "${NEXUS_CA_TARGET}"
EOF

echo "==> Install k3s"
mkdir -p /root/.kube
if systemctl is-active --quiet k3s; then
    echo "k3s is already running."
else
    curl -sfL https://get.k3s.io | \
       INSTALL_K3S_VERSION="${K3S_VERSION}" INSTALL_K3S_EXEC="server --tls-san ${KUBE_API} --tls-san 192.168.56.13 --write-kubeconfig /root/.kube/config --write-kubeconfig-mode 600 --disable=traefik" sh -
fi

echo "=> Copying kubeconfig to artifacts"
cp /root/.kube/config /artifacts/kubeconfig.yml
yq eval --inplace ".clusters[0].cluster.server = \"https://${KUBE_API}:6443\"" /artifacts/kubeconfig.yml
echo "k3s setup complete."
