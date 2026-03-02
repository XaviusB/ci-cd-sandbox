#!/usr/bin/env bash
set -euo pipefail

# Nexus Repository Manager setup script
# Installs Java, downloads and configures Nexus OSS
source "$(dirname "$0")/common/apt-update.sh"

NEXUS_VERSION="3.89.0-09"
NEXUS_URL="https://cdn.download.sonatype.com/repository/downloads-prod-group/3/nexus-${NEXUS_VERSION}-linux-x86_64.tar.gz"
NEXUS_USER="nexus"
NEXUS_HOME="/opt/nexus"
NEXUS_DATA="/var/nexus-data"
NEXUS_PORT=8081
JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"

echo "==> Installing dependencies"
echo "    Waiting for apt locks to be released..."
apt_update
apt-get install -y openjdk-11-jdk curl net-tools

echo "==> Creating nexus user if it doesn't exist"
if ! id "${NEXUS_USER}" >/dev/null 2>&1; then
  useradd --system --home-dir "${NEXUS_DATA}" --shell /usr/sbin/nologin ${NEXUS_USER}
  echo "    created user ${NEXUS_USER}"
else
  echo "    nexus user already exists"
fi

echo "==> Creating Nexus directories"
mkdir -p "${NEXUS_HOME}"
mkdir -p "${NEXUS_DATA}"
chown -R ${NEXUS_USER}:${NEXUS_USER} "${NEXUS_HOME}"
chown -R ${NEXUS_USER}:${NEXUS_USER} "${NEXUS_DATA}"
chmod 755 "${NEXUS_HOME}"
chmod 755 "${NEXUS_DATA}"

echo "==> Downloading and installing Nexus ${NEXUS_VERSION}"
NEXUS_TARBALL="/tmp/nexus-${NEXUS_VERSION}-unix.tar.gz"

systemctl stop nexus || true
rm -rf "${NEXUS_HOME}"
curl -sSL --fail -o "${NEXUS_TARBALL}" "${NEXUS_URL}"
tar -xzf "${NEXUS_TARBALL}" -C /opt
mv /opt/nexus-${NEXUS_VERSION} "${NEXUS_HOME}"
rm -f "${NEXUS_TARBALL}"

echo "==> Configuring Nexus"
chown -R ${NEXUS_USER}:${NEXUS_USER} "${NEXUS_HOME}"
chown -R ${NEXUS_USER}:${NEXUS_USER} "${NEXUS_DATA}"
mkdir -p  /opt/sonatype-work/nexus3/
chown -R ${NEXUS_USER}:${NEXUS_USER} /opt/sonatype-work/nexus3/

# Create Nexus configuration
mkdir -p "${NEXUS_HOME}/bin"
cat > "${NEXUS_HOME}/bin/nexus.vmoptions" <<EOF
-Xms1024m
-Xmx1024m
-XX:+UseG1GC
-XX:MaxGCPauseMillis=30
-XX:InitiatingHeapOccupancyPercent=35
-XX:+ParallelRefProcEnabled
-XX:+UnlockDiagnosticVMOptions
-Dkaraf.data=/opt/sonatype-work/nexus3
-Djava.io.tmpdir=/opt/sonatype-work/nexus3/tmp
-XX:LogFile=/opt/sonatype-work/nexus3/log/jvm.log
-Dkaraf.log=/opt/sonatype-work/nexus3/log
-Djava.util.prefs.userRoot=${NEXUS_DATA}/javaprefs
EOF

chown ${NEXUS_USER}:${NEXUS_USER} "${NEXUS_HOME}/bin/nexus.vmoptions"
chmod 644 "${NEXUS_HOME}/bin/nexus.vmoptions"

# Configure Nexus properties
mkdir -p "${NEXUS_DATA}/etc"
cat > "${NEXUS_DATA}/etc/nexus.properties" <<EOF
# Nexus Properties
application-port=${NEXUS_PORT}
application-host=0.0.0.0
nexus-args=\${jetty.etc}/jetty.xml,\${jetty.etc}/jetty-http.xml,\${jetty.etc}/jetty-requestlog.xml
nexus-context-path=/
EOF

chown ${NEXUS_USER}:${NEXUS_USER} "${NEXUS_DATA}/etc/nexus.properties"
chmod 644 "${NEXUS_DATA}/etc/nexus.properties"

echo "==> Creating systemd service for Nexus"
cat > /etc/systemd/system/nexus.service <<EOF
[Unit]
Description=Nexus Repository Manager
After=network.target

[Service]
Type=forking
User=${NEXUS_USER}
Group=${NEXUS_USER}
Environment="NEXUS_HOME=${NEXUS_HOME}"
Environment="NEXUS_DATA=${NEXUS_DATA}"
Environment="JAVA_HOME=${JAVA_HOME}"
WorkingDirectory=${NEXUS_DATA}

ExecStart=${NEXUS_HOME}/bin/nexus start
ExecStop=${NEXUS_HOME}/bin/nexus stop
ExecReload=${NEXUS_HOME}/bin/nexus restart

Restart=always
RestartSec=10

# Security
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

echo "==> Enabling and starting Nexus service"
systemctl daemon-reload
systemctl enable nexus
systemctl start nexus

echo "==> Waiting for Nexus to start (this may take up to 120 seconds)"
for i in {1..120}; do
  if curl -sSL -o /dev/null http://localhost:${NEXUS_PORT} 2>/dev/null; then
    echo "    Nexus is up and running"
    break
  fi
  echo "    Waiting... ($i/120)"
  sleep 1
done

echo
echo "=========================================="
echo " Nexus Repository Manager setup complete"
echo
echo " Nexus URL: http://localhost:${NEXUS_PORT}"
echo " Nexus Home: ${NEXUS_HOME}"
echo " Data Directory: ${NEXUS_DATA}"
echo " Port: ${NEXUS_PORT}"
echo
echo " Default credentials:"
echo "   Username: admin"
echo "   Password: (check ${NEXUS_DATA}/admin.password)"
echo
echo " First login will prompt you to change the password"
echo "=========================================="
