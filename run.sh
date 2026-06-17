#!/usr/bin/env bash

set -Eeuo pipefail

# ----------------------------
# Paths
# ----------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
CONFIG_FILE="$CONFIG_DIR/config.json"

# ----------------------------
# Helpers
# ----------------------------

check_command() {
    command -v "$1" >/dev/null 2>&1
}

install_packages() {
    local packages=("$@")

    if [ ${#packages[@]} -eq 0 ]; then
        return
    fi

    echo
    echo "Installing packages:"
    printf '  - %s\n' "${packages[@]}"
    echo

    if check_command pacman; then
        sudo pacman -S --needed "${packages[@]}"

    elif check_command apt; then
        sudo apt update
        sudo apt install -y "${packages[@]}"

    elif check_command dnf; then
        sudo dnf install -y "${packages[@]}"

    else
        echo "Unsupported package manager."
        exit 1
    fi
}

# ----------------------------
# Ensure sudo exists
# ----------------------------

if ! check_command sudo; then
    echo "sudo is required."
    exit 1
fi

# ----------------------------
# Create config directory
# ----------------------------

mkdir -p "$CONFIG_DIR"

# ----------------------------
# Create default config
# ----------------------------

if [ ! -f "$CONFIG_FILE" ]; then
    echo "config.json not found. Creating default config..."

    cat > "$CONFIG_FILE" <<EOF
{
    "LogRequests": false,
    "FakeFreeroamPlayers": true,
    "nfswFilePath": ""
}
EOF

    echo "Created: $CONFIG_FILE"
fi

# ----------------------------
# Detect distro packages
# ----------------------------

packages=()

if check_command pacman; then
    # Arch Linux

    check_command wine || packages+=("wine")
    check_command zenity || packages+=("zenity")
    check_command taskset || packages+=("util-linux")
    check_command node || packages+=("nodejs")
    check_command npm || packages+=("npm")

elif check_command apt; then
    # Debian / Ubuntu

    check_command wine || packages+=("wine")
    check_command zenity || packages+=("zenity")
    check_command taskset || packages+=("util-linux")
    check_command node || packages+=("nodejs")
    check_command npm || packages+=("npm")

elif check_command dnf; then
    # Fedora

    check_command wine || packages+=("wine")
    check_command zenity || packages+=("zenity")
    check_command taskset || packages+=("util-linux")
    check_command node || packages+=("nodejs")
    check_command npm || packages+=("npm")

else
    echo "Unsupported distribution."
    exit 1
fi

# ----------------------------
# Install missing packages
# ----------------------------

install_packages "${packages[@]}"

# ----------------------------
# Install Node.js dependencies
# ----------------------------

cd "$SCRIPT_DIR"

if [ ! -d "$SCRIPT_DIR/node_modules" ]; then
    echo
    echo "Installing Node.js dependencies..."
    npm install
else
    required_modules=(
        "express"
        "xml2js"
        "compression"
    )

    missing_modules=0

    for module in "${required_modules[@]}"; do
        if [ ! -d "$SCRIPT_DIR/node_modules/$module" ]; then
            missing_modules=1
            break
        fi
    done

    if [ "$missing_modules" -eq 1 ]; then
        echo
        echo "Installing missing Node.js dependencies..."
        npm install
    fi
fi

# ----------------------------
# Launch
# ----------------------------

clear

echo "Starting server..."
node "$SCRIPT_DIR/src/index.js"

read -rp "Press Enter to continue..."