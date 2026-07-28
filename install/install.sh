#!/bin/bash
# install.sh - Remote Maven Parent POM Installation
#
# This script handles remote installation via curl | bash
# Downloads the repository and delegates to local-install.sh
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/sabirhussain/mvn-parent/main/install/install.sh | bash
#   
# Or with bash -c for passing arguments:
#   bash <(curl -fsSL ...) [arguments for local-install.sh]

set -euo pipefail

# Redirect stdin from TTY if running via pipe (e.g., curl | bash)
if [ ! -t 0 ] && [ -e /dev/tty ]; then
    exec < /dev/tty
fi

check_dependencies() {
    for cmd in git mktemp; do
        command -v "$cmd" >/dev/null 2>&1 || { echo "❌ Required tool not found: $cmd"; exit 1; }
    done
}

REPO_URL="https://github.com/sabirhussain/mvn-parent"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║         Maven Parent POM - Remote Installation          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

check_dependencies

# Clone repository to temp dir
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT INT TERM

echo "📦 Downloading Maven Parent POM..."

if ! git clone --depth 1 "$REPO_URL" "$TEMP_DIR"; then
    echo "❌ Failed to clone repository. Check your network connection and git configuration."
    exit 1
fi

echo "✅ Downloaded to: $TEMP_DIR"
echo ""

# Make local-install.sh executable
chmod +x "$TEMP_DIR/install/local-install.sh"

# Run local installation script
echo "🚀 Starting installation..."
echo ""

"$TEMP_DIR/install/local-install.sh" "$TEMP_DIR" "$@"
