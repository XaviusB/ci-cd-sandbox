#!/bin/bash
# Script to copy a binary and its libraries to a chroot
set -euo pipefail

BIN_PATH="$1"
CHROOT_DIR="$2"

if [ ! -x "${BIN_PATH}" ]; then
    echo "Binary ${BIN_PATH} not found or not executable"
    exit 0
fi

# Copy the binary itself
TARGET_DIR="${CHROOT_DIR}$(dirname ${BIN_PATH})"
mkdir -p "${TARGET_DIR}"
install -D -m 755 "${BIN_PATH}" "${CHROOT_DIR}${BIN_PATH}"

# Copy all library dependencies
ldd "${BIN_PATH}" 2>/dev/null | awk '{
    for (i=1; i<=NF; i++) {
        if ($i ~ /^\//) {
            print $i
        }
    }
}' | sort -u | while read -r lib; do
    if [ -f "${lib}" ]; then
        LIB_DIR="${CHROOT_DIR}$(dirname ${lib})"
        mkdir -p "${LIB_DIR}"
        install -D -m 755 "${lib}" "${CHROOT_DIR}${lib}"
    fi
done

# Also handle the dynamic linker which doesn't always show in ldd output
if [ -x /lib64/ld-linux-x86-64.so.2 ]; then
    mkdir -p "${CHROOT_DIR}/lib64"
    cp -L /lib64/ld-linux-x86-64.so.* "${CHROOT_DIR}/lib64/" 2>/dev/null || true
fi
