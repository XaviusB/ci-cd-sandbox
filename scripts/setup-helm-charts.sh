#!/bin/bash
set -euo pipefail

export PATH="$HOME/.asdf/shims:$PATH"

# # Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo "Helm not found..."
    exit 1
else
    echo "✓ Helm is already installed"
    helm version
fi

echo ""

# Check if kubectl is available (required for Helm to work)
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

echo "✓ kubectl is available"
echo ""

# Add Helm repositories
echo "Adding Helm repositories..."

# Add Kong repository (official)
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add kyverno https://kyverno.github.io/kyverno/

# Update Helm repositories
echo "Updating Helm repositories..."
helm repo update
echo "✓ Repositories updated"
echo ""

echo "Install nginx with NodePort configuration for ports 30080 and 30443"
echo "Installing nginx Helm chart..."
kubectl create namespace nginx --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install nginx ingress-nginx/ingress-nginx --version 4.0.6 \
    --namespace nginx \
    --create-namespace \
    --wait \
    --set controller.service.type=NodePort \
    --set controller.service.nodePorts.http=30080 \
    --set controller.service.nodePorts.https=30443 \
    --set controller.extraArgs.enable-ssl-passthrough=true \
    --set controller.config.use-forwarded-headers=true \
    --set controller.config.forwarded-for-header=X-Forwarded-For \
    --set controller.config.compute-full-forwarded-for=true \
    --set controller.config.proxy-real-ip-cidr="192.168.56.0/24\,192.168.0.0/24"

echo "✓ nginx installed successfully"

echo "==> Getting Gitea SSH host keys"
GITEA_SSH_HOST_KEY=$(ssh-keyscan -p 2222 gitea.devops.active 2>/dev/null | grep -v "^#")

# echo "Installing argocd"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install argocd argo/argo-cd --version 9.4.1 \
    --namespace argocd \
    --create-namespace \
    --wait \
    --set global.domain=argocd.devops.active \
    --set server.ingress.enabled=true \
    --set "server.extraArgs={--insecure}" \
    --set server.auth.enabled=false \
    --set server.configs.params.server.insecure=true \
    --set server.ingress.ingressClassName=nginx \
    --set server.ingress.annotations.kubernetes.io/ingress\.class=nginx \
    --set server.ingress.annotations.nginx\.ingress\.kubernetes\.io/force-ssl-redirect=false \
    --set server.ingress.annotations.nginx\.ingress\.kubernetes\.io/ssl-passthrough=false \
    --set configs.ssh.extraHosts="${GITEA_SSH_HOST_KEY}"


# echo "Save argocd admin password to artifact folder"
ARGOCD_ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "admin:${ARGOCD_ADMIN_PASSWORD}" > /artifacts/argocd-admin-password.txt

echo "==> Installing Kyverno"
helm upgrade --install kyverno kyverno/kyverno --version 3.7.0 \
  -n kyverno \
  --create-namespace \
  --wait \
  --set admissionController.rbac.clusterRole.extraResources[0].apiGroups[0]="" \
  --set admissionController.rbac.clusterRole.extraResources[0].resources[0]="secrets" \
  --set admissionController.rbac.clusterRole.extraResources[0].verbs[0]="get" \
  --set admissionController.rbac.clusterRole.extraResources[0].verbs[1]="list" \
  --set admissionController.rbac.clusterRole.extraResources[0].verbs[2]="watch" \
  --set admissionController.rbac.clusterRole.extraResources[0].verbs[3]="create" \
  --set admissionController.rbac.clusterRole.extraResources[0].verbs[4]="update" \
  --set admissionController.rbac.clusterRole.extraResources[0].verbs[5]="patch" \
  --set admissionController.rbac.clusterRole.extraResources[0].verbs[6]="delete" \
  --set backgroundController.rbac.clusterRole.extraResources[0].apiGroups[0]="" \
  --set backgroundController.rbac.clusterRole.extraResources[0].resources[0]="secrets" \
  --set backgroundController.rbac.clusterRole.extraResources[0].verbs[0]="get" \
  --set backgroundController.rbac.clusterRole.extraResources[0].verbs[1]="list" \
  --set backgroundController.rbac.clusterRole.extraResources[0].verbs[2]="watch" \
  --set backgroundController.rbac.clusterRole.extraResources[0].verbs[3]="create" \
  --set backgroundController.rbac.clusterRole.extraResources[0].verbs[4]="update" \
  --set backgroundController.rbac.clusterRole.extraResources[0].verbs[5]="patch" \
  --set backgroundController.rbac.clusterRole.extraResources[0].verbs[6]="delete"

echo "==> Creating Kyverno policies to auto-sync image pull secrets and mutate pods to use them"
kubectl apply -f - <<EOF
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: sync-secret
spec:
  background: false
  rules:
  - name: sync-image-pull-secret
    match:
      resources:
        kinds:
        - Namespace
    generate:
      apiVersion: v1
      kind: Secret
      name: image-pull-secret
      namespace: "{{request.object.metadata.name}}"
      synchronize: true
      clone:
        namespace: default
        name: image-pull-secret
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: mutate-imagepullsecret
spec:
  rules:
    - name: mutate-imagepullsecret
      match:
        resources:
          kinds:
          - Pod
      mutate:
        patchStrategicMerge:
          spec:
            imagePullSecrets:
            - name: image-pull-secret 
            (containers):
            - (image): "*"
EOF

echo "==> Create image pull secret in default namespace for Nexus registry"

NEXUS_READER_USER=$(cat /artifacts/nexus-readonly-credentials.txt | cut -d: -f1)
NEXUS_READER_PASS=$(cat /artifacts/nexus-readonly-credentials.txt | cut -d: -f2)

kubectl create secret docker-registry image-pull-secret \
  --docker-server=nexus.devops.active \
  --docker-username="${NEXUS_READER_USER}" \
  --docker-password="${NEXUS_READER_PASS}" \
  --namespace=default \
  --dry-run=client -o yaml | kubectl apply -f - 
