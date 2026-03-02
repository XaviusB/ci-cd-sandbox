#!/bin/bash
function apt_update() {
  echo "==> Install dependencies"
  while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 || sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
    echo "    apt is locked, waiting..."
    sleep 2
  done

  # Only run apt-get update if it hasn't been run in the last 24 hours
  if [ ! -d "/var/lib/apt/lists" ] || [ -z "$(find /var/lib/apt/lists -maxdepth 1 -mtime -1 -type f 2>/dev/null | head -n1)" ]; then
    echo "    Running apt-get update..."
    apt-get update -y
  else
    echo "    apt-get update was run recently (within 24h), skipping..."
  fi
}
