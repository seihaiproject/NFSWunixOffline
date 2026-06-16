#!/bin/bash

set -e

# ----------------------------
# Resolve script directory
# ----------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/config.json"

# ----------------------------
# Ensure config exists
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

    echo "Default config created at $CONFIG_FILE"
fi

# ----------------------------
# Node.js dependencies
# ----------------------------

dependencies=("express" "xml2js" "compression")
install_needed=0

for dep in "${dependencies[@]}"; do
    if [ ! -d "node_modules/$dep" ]; then
        echo "Missing Node dependency: $dep"
        install_needed=1
    fi
done

if [ "$install_needed" -eq 1 ]; then
    echo
    echo "Installing Node.js dependencies..."
    npm install
fi

# ----------------------------
# System dependencies
# ----------------------------

missing_packages=()

check_command() {
    command -v "$1" >/dev/null 2>&1
}

# Wine
if ! check_command wine; then
    missing_packages+=("wine")
fi

# Zenity
if ! check_command zenity; then
    missing_packages+=("zenity")
fi

# taskset (util-linux)
if ! check_command taskset; then
    if command -v pacman >/dev/null 2>&1; then
        missing_packages+=("util-linux")
    else
        missing_packages+=("util-linux")
    fi
fi

# ----------------------------
# Install missing system deps
# ----------------------------

if [ ${#missing_packages[@]} -gt 0 ]; then
    echo
    echo "Missing system dependencies:"
    printf ' - %s\n' "${missing_packages[@]}"
    echo

    if command -v pacman >/dev/null 2>&1; then
        echo "Detected Arch Linux."
        sudo pacman -Sy --needed "${missing_packages[@]}"

    elif command -v apt >/dev/null 2>&1; then
        echo "Detected Debian/Ubuntu."
        sudo apt update
        sudo apt install -y "${missing_packages[@]}"

    elif command -v dnf >/dev/null 2>&1; then
        echo "Detected Fedora."
        sudo dnf install -y "${missing_packages[@]}"

    else
        echo "Unsupported package manager."
        echo "Please install manually:"
        printf '%s\n' "${missing_packages[@]}"
        exit 1
    fi
fi

# ----------------------------
# Launch app
# ----------------------------

clear

echo "Starting server..."
node src/index.js

read -p "Press Enter to continue..."