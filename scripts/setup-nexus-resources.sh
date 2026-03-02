#!/usr/bin/env bash
set -euo pipefail

# Nexus Repository Manager setup script
# Installs Java, downloads and configures Nexus OSS

NEXUS_HOME="/opt/nexus"
NEXUS_DATA="/opt/sonatype-work/nexus3"
NEXUS_PORT=8081
JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
NEXUS_URL_BASE="http://localhost:${NEXUS_PORT}"
DOCKER_REPO_NAME="docker-hosted"
DOCKER_PROXY_NAME="docker-proxy"
DOCKER_REPO_PORT=8082
NEXUS_ADMIN_PASS_FILE="${NEXUS_DATA}/admin.password"


if [ -f /nexus-readonly-credentials.txt ]; then
  echo "    Found existing read-only credentials, reusing"
  READONLY_PASS=$(cat /nexus-readonly-credentials.txt | cut -d: -f2)
  READONLY_USER=$(cat /nexus-readonly-credentials.txt | cut -d: -f1)
else
  echo "    No existing read-only credentials found, generating new ones"
  READONLY_USER="docker-reader"
  READONLY_PASS="$(openssl rand -base64 12)"
fi

if [ -f /nexus-upload-credentials.txt ]; then
  echo "    Found existing upload credentials, reusing"
  UPLOAD_PASS=$(cat /nexus-upload-credentials.txt | cut -d: -f2)
  UPLOAD_USER=$(cat /nexus-upload-credentials.txt | cut -d: -f1)
else
  echo "    No existing upload credentials found, generating new ones"
  UPLOAD_USER="docker-writer"
  UPLOAD_PASS="$(openssl rand -base64 12)"
fi

if [ -f /artifacts/nexus-admin-password.txt ]; then
  echo "    Found existing admin password, reusing"
  NEXUS_ADMIN_PASSWORD=$(cat /artifacts/nexus-admin-password.txt | cut -d: -f2)
else
  echo "    No existing admin password found, generating new one"
  NEXUS_BOOTSTRAP_PASS="$(cat "${NEXUS_ADMIN_PASS_FILE}")"
  NEED_TO_SET_ADMIN_PASS=true
  NEXUS_ADMIN_PASSWORD="$(openssl rand -base64 12)"
fi

echo "==> Configuring Nexus (Docker repo + users)"

wait_for_nexus_api() {
  for i in {1..60}; do
    if curl -sS -u "admin:${NEXUS_BOOTSTRAP_PASS:-$NEXUS_ADMIN_PASSWORD}" "${NEXUS_URL_BASE}/service/rest/v1/status" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

if ! wait_for_nexus_api; then
  echo "    Nexus API not responding, skipping provisioning"
  exit 1
fi

if [ "${NEED_TO_SET_ADMIN_PASS:-false}" = true ]; then
  echo "    Setting admin password"
  curl -sS -u "admin:${NEXUS_BOOTSTRAP_PASS}" -X PUT \
    -H "Content-Type: text/plain" \
    --data "${NEXUS_ADMIN_PASSWORD}" \
    "${NEXUS_URL_BASE}/service/rest/v1/security/users/admin/change-password" >/dev/null
  rm -f "${NEXUS_ADMIN_PASS_FILE}"
  echo "admin:${NEXUS_ADMIN_PASSWORD}" > /artifacts/nexus-admin-password.txt
fi

ensure_realm() {
  local realm_name=$1
  local active
  active=$(curl -sS -u "admin:${NEXUS_ADMIN_PASSWORD}" "${NEXUS_URL_BASE}/service/rest/v1/security/realms/active")
  if echo "${active}" | grep -q "\"${realm_name}\""; then
    return 0
  fi
  local updated
  updated=$(echo "${active}" | sed 's/\]$/, "'"${realm_name}"'" ]/')
  curl -sS -u "admin:${NEXUS_ADMIN_PASSWORD}" -X PUT \
    -H "Content-Type: application/json" \
    --data "${updated}" \
    "${NEXUS_URL_BASE}/service/rest/v1/security/realms/active" >/dev/null
}

echo "    Enabling Docker Bearer Token Realm"
ensure_realm "DockerToken"

echo "    Creating Docker hosted repository (${DOCKER_REPO_NAME})"
REPO_STATUS=$(curl -sS -o /dev/null -w "%{http_code}" -u "admin:${NEXUS_ADMIN_PASSWORD}" \
  "${NEXUS_URL_BASE}/service/rest/v1/repositories/docker/hosted/${DOCKER_REPO_NAME}")
if [ "${REPO_STATUS}" != "200" ]; then
  curl -sS -u "admin:${NEXUS_ADMIN_PASSWORD}" -X POST \
    -H "Content-Type: application/json" \
    --data "{\"name\":\"${DOCKER_REPO_NAME}\",\"online\":true,\"storage\":{\"blobStoreName\":\"default\",\"strictContentTypeValidation\":true,\"writePolicy\":\"ALLOW\"},\"cleanup\":{\"policyNames\":[]},\"docker\":{\"v1Enabled\":false,\"forceBasicAuth\":true,\"httpPort\":null,\"pathEnabled\":true},\"component\":{\"proprietaryComponents\":false}}" \
    "${NEXUS_URL_BASE}/service/rest/v1/repositories/docker/hosted" >/dev/null
fi

echo "    Creating Docker proxy repository (${DOCKER_PROXY_NAME})"
REPO_STATUS=$(curl -sS -o /dev/null -w "%{http_code}" -u "admin:${NEXUS_ADMIN_PASSWORD}" \
  "${NEXUS_URL_BASE}/service/rest/v1/repositories/docker/proxy/${DOCKER_PROXY_NAME}")
if [ "${REPO_STATUS}" != "200" ]; then
  curl -sS -u "admin:${NEXUS_ADMIN_PASSWORD}" -X POST \
    -H "Content-Type: application/json" \
    --data "{\"name\":\"${DOCKER_PROXY_NAME}\",\"online\":true,\"storage\":{\"blobStoreName\":\"default\",\"strictContentTypeValidation\":true},\"cleanup\":{\"policyNames\":[]},\"proxy\":{\"remoteUrl\":\"https://registry-1.docker.io\",\"contentMaxAge\":1440,\"metadataMaxAge\":1440},\"negativeCache\":{\"enabled\":true,\"timeToLive\":1440},\"httpClient\":{\"blocked\":false,\"autoBlock\":true},\"docker\":{\"v1Enabled\":false,\"forceBasicAuth\":false,\"httpPort\":null,\"pathEnabled\":true},\"dockerProxy\":{\"indexType\":\"HUB\",\"cacheForeignLayers\":true,\"foreignLayerUrlWhitelist\":[]}}" \
    "${NEXUS_URL_BASE}/service/rest/v1/repositories/docker/proxy" >/dev/null
fi

echo "    Creating roles"
READ_ROLE_ID="docker-${DOCKER_REPO_NAME}-ro"
WRITE_ROLE_ID="docker-${DOCKER_REPO_NAME}-rw"
PROXY_READ_ROLE_ID="docker-${DOCKER_PROXY_NAME}-ro"

ROLE_STATUS=$(curl -sS -o /dev/null -w "%{http_code}" -u "admin:${NEXUS_ADMIN_PASSWORD}" \
  "${NEXUS_URL_BASE}/service/rest/v1/security/roles/${READ_ROLE_ID}")
if [ "${ROLE_STATUS}" != "200" ]; then
  curl -sS -u "admin:${NEXUS_ADMIN_PASSWORD}" -X POST \
    -H "Content-Type: application/json" \
    --data "{\"id\":\"${READ_ROLE_ID}\",\"name\":\"Docker ${DOCKER_REPO_NAME} Read\",\"description\":\"Read-only access to ${DOCKER_REPO_NAME}\",\"privileges\":[\"nx-repository-view-docker-${DOCKER_REPO_NAME}-browse\",\"nx-repository-view-docker-${DOCKER_REPO_NAME}-read\"],\"roles\":[]}" \
    "${NEXUS_URL_BASE}/service/rest/v1/security/roles" >/dev/null
fi

ROLE_STATUS=$(curl -sS -o /dev/null -w "%{http_code}" -u "admin:${NEXUS_ADMIN_PASSWORD}" \
  "${NEXUS_URL_BASE}/service/rest/v1/security/roles/${WRITE_ROLE_ID}")
if [ "${ROLE_STATUS}" != "200" ]; then
  curl -sS -u "admin:${NEXUS_ADMIN_PASSWORD}" -X POST \
    -H "Content-Type: application/json" \
    --data "{\"id\":\"${WRITE_ROLE_ID}\",\"name\":\"Docker ${DOCKER_REPO_NAME} Write\",\"description\":\"Write access to ${DOCKER_REPO_NAME}\",\"privileges\":[\"nx-repository-view-docker-${DOCKER_REPO_NAME}-browse\",\"nx-repository-view-docker-${DOCKER_REPO_NAME}-read\",\"nx-repository-view-docker-${DOCKER_REPO_NAME}-add\",\"nx-repository-view-docker-${DOCKER_REPO_NAME}-edit\"],\"roles\":[]}" \
    "${NEXUS_URL_BASE}/service/rest/v1/security/roles" >/dev/null
fi

ROLE_STATUS=$(curl -sS -o /dev/null -w "%{http_code}" -u "admin:${NEXUS_ADMIN_PASSWORD}" \
  "${NEXUS_URL_BASE}/service/rest/v1/security/roles/${PROXY_READ_ROLE_ID}")
if [ "${ROLE_STATUS}" != "200" ]; then
  curl -sS -u "admin:${NEXUS_ADMIN_PASSWORD}" -X POST \
    -H "Content-Type: application/json" \
    --data "{\"id\":\"${PROXY_READ_ROLE_ID}\",\"name\":\"Docker ${DOCKER_PROXY_NAME} Read\",\"description\":\"Read-only access to ${DOCKER_PROXY_NAME}\",\"privileges\":[\"nx-repository-view-docker-${DOCKER_PROXY_NAME}-browse\",\"nx-repository-view-docker-${DOCKER_PROXY_NAME}-read\"],\"roles\":[]}" \
    "${NEXUS_URL_BASE}/service/rest/v1/security/roles" >/dev/null
fi

echo "    Creating users"
USER_STATUS=$(curl -sS -o /dev/null -w "%{http_code}" -u "admin:${NEXUS_ADMIN_PASSWORD}" \
  "${NEXUS_URL_BASE}/service/rest/v1/security/users/${READONLY_USER}")
if [ "${USER_STATUS}" != "200" ]; then
  curl -sS -u "admin:${NEXUS_ADMIN_PASSWORD}" -X POST \
    -H "Content-Type: application/json" \
    --data "{\"userId\":\"${READONLY_USER}\",\"firstName\":\"Docker\",\"lastName\":\"Reader\",\"emailAddress\":\"${READONLY_USER}@local\",\"status\":\"active\",\"password\":\"${READONLY_PASS}\",\"roles\":[\"${READ_ROLE_ID}\",\"${PROXY_READ_ROLE_ID}\"]}" \
    "${NEXUS_URL_BASE}/service/rest/v1/security/users" >/dev/null
    echo "${READONLY_USER}:${READONLY_PASS}" > /artifacts/nexus-readonly-credentials.txt
fi


USER_STATUS=$(curl -sS -o /dev/null -w "%{http_code}" -u "admin:${NEXUS_ADMIN_PASSWORD}" \
  "${NEXUS_URL_BASE}/service/rest/v1/security/users/${UPLOAD_USER}")
if [ "${USER_STATUS}" != "200" ]; then
  curl -sS -u "admin:${NEXUS_ADMIN_PASSWORD}" -X POST \
    -H "Content-Type: application/json" \
    --data "{\"userId\":\"${UPLOAD_USER}\",\"firstName\":\"Docker\",\"lastName\":\"Writer\",\"emailAddress\":\"${UPLOAD_USER}@local\",\"status\":\"active\",\"password\":\"${UPLOAD_PASS}\",\"roles\":[\"${WRITE_ROLE_ID}\"]}" \
    "${NEXUS_URL_BASE}/service/rest/v1/security/users" >/dev/null
    echo "${UPLOAD_USER}:${UPLOAD_PASS}" > /artifacts/nexus-upload-credentials.txt
fi

echo
echo "=========================================="
echo " Nexus Repository Manager setup complete"
echo
echo " Nexus URL: http://localhost:${NEXUS_PORT}"
echo " Nexus Home: ${NEXUS_HOME}"
echo " Data Directory: ${NEXUS_DATA}"
echo " Port: ${NEXUS_PORT}"
echo
echo "=========================================="
