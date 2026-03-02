#!/bin/bash
set -euo pipefail


source "$(dirname "$0")/common/apt-update.sh"

apt_update
apt-get install -y curl tar git zip unzip


echo "=== Installing ASDF Version Manager (v0.16.0+) ==="


# Detect OS and architecture
OS=$(uname -s)
ARCH=$(uname -m)

case "$OS" in
    Linux)
        OSTYPE="linux"
        ;;
    Darwin)
        OSTYPE="darwin"
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

case "$ARCH" in
    x86_64)
        ARCHTYPE="amd64"
        ;;
    aarch64)
        ARCHTYPE="arm64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Set up directory for binary
BIN_DIR="/usr/local/bin"
ASDF_DATA_DIR="${ASDF_DATA_DIR:=$HOME/.asdf}"

# Create directories if they don't exist
mkdir -p "$BIN_DIR"
mkdir -p "$ASDF_DATA_DIR"

echo "OS: $OSTYPE, Architecture: $ARCHTYPE"
echo "Binary directory: $BIN_DIR"
echo "Data directory: $ASDF_DATA_DIR"
echo ""

# Download the latest asdf binary
echo "Downloading latest asdf binary..."
LATEST_RELEASE=$(curl -s https://api.github.com/repos/asdf-vm/asdf/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')

if [ -z "$LATEST_RELEASE" ]; then
    echo "❌ Failed to fetch latest release from GitHub"
    exit 1
fi

echo "Latest release: $LATEST_RELEASE"

# Get the actual download URL by following redirects
BINARY_URL="https://github.com/asdf-vm/asdf/releases/download/${LATEST_RELEASE}/asdf-${LATEST_RELEASE}-${OSTYPE}-${ARCHTYPE}.tar.gz"
ASDF_TAR_GZ="$BIN_DIR/asdf-${LATEST_RELEASE}-${OSTYPE}-${ARCHTYPE}.tar.gz"
ASDF_BIN="$BIN_DIR/asdf"

echo "Downloading from: $BINARY_URL"
# Use -L to follow redirects, -C - to resume if interrupted
curl -sSL -C - "$BINARY_URL" -o "$ASDF_TAR_GZ"

if [ ! -f "$ASDF_TAR_GZ" ]; then
    echo "❌ Failed to download binary"
    exit 1
fi

cd /usr/local/bin
tar xzf "$ASDF_TAR_GZ"
rm "$ASDF_TAR_GZ"
chmod +x "$ASDF_BIN"

echo "✓ Binary installed to $ASDF_BIN"
echo ""

# Configure shell environment
echo "Configuring shell environment..."

# Detect shell
SHELL_RC=""
if [ -n "${BASH_VERSION:-}" ]; then
    SHELL_RC="$HOME/.bashrc"
elif [ -n "${ZSH_VERSION:-}" ]; then
    SHELL_RC="$HOME/.zshrc"
else
    # Fallback: check what shell is set
    if [ "${SHELL##*/}" = "zsh" ]; then
        SHELL_RC="$HOME/.zshrc"
    else
        SHELL_RC="$HOME/.bashrc"
    fi
fi

echo "Using shell config: $SHELL_RC"

# Function to add or update environment variable
add_or_update_var() {
    local var_name=$1
    local var_value=$2
    local rc_file=$3

    # Check if variable already exists
    if grep -q "^export $var_name=" "$rc_file" 2>/dev/null; then
        # Update existing variable
        sed -i "s|^export $var_name=.*|export $var_name=\"$var_value\"|" "$rc_file"
        echo "✓ Updated $var_name in $rc_file"
    else
        # Add new variable
        echo "export $var_name=\"$var_value\"" >> "$rc_file"
        echo "✓ Added $var_name to $rc_file"
    fi
}

# Ensure shell config file exists
touch "$SHELL_RC"

# Add $HOME/bin to PATH (if not already present)
if ! grep -q "export PATH.*$HOME/bin" "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "# ASDF Configuration" >> "$SHELL_RC"
    echo "export PATH=\"\$HOME/bin:\$PATH\"" >> "$SHELL_RC"
    echo "✓ Added \$HOME/bin to PATH"
else
    echo "✓ \$HOME/bin already in PATH"
fi

# Set ASDF_DATA_DIR
add_or_update_var "ASDF_DATA_DIR" "$ASDF_DATA_DIR" "$SHELL_RC"

# Add shims to PATH
if ! grep -q "export PATH.*ASDF_DATA_DIR/shims" "$SHELL_RC" 2>/dev/null; then
    echo "export PATH=\"\$ASDF_DATA_DIR/shims:\$PATH\"" >> "$SHELL_RC"
    echo "✓ Added \$ASDF_DATA_DIR/shims to PATH"
else
    echo "✓ ASDF shims already in PATH"
fi

# Update PATH for current session
export PATH="$BIN_DIR:$PATH"
export PATH="$ASDF_DATA_DIR/shims:$PATH"
export ASDF_DATA_DIR="$ASDF_DATA_DIR"

echo ""
echo "=== Verifying Installation ==="
$ASDF_BIN --version

echo ""
echo "=== ASDF Setup Complete ==="
echo "Installed asdf version: $LATEST_RELEASE"
echo "Binary location: $ASDF_BIN"
echo "Data directory: $ASDF_DATA_DIR"
echo ""
echo "Available commands:"
echo "  asdf --version              Show ASDF version"
echo "  asdf plugin list            List all installed plugins"
echo "  asdf plugin list all        List all available plugins"
echo "  asdf plugin add <name>      Add a plugin"
echo "  asdf install <plugin> <ver> Install a specific version"
echo "  asdf set <plugin> <ver>     Set version for current project"
echo ""
echo "Please restart your shell or run:"
echo "  source $SHELL_RC"
