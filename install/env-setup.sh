#!/bin/bash
# env-setup.sh - Interactive environment credentials setup

set -e

ENV_FILE=".env"
ENV_EXAMPLE=".env.example"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║      Maven Parent - Credentials Setup                   ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Check if .env.example exists
if [ ! -f "$ENV_EXAMPLE" ]; then
    echo "❌ Error: .env.example not found!"
    echo "   Run install.sh first to create the template."
    exit 1
fi

# Check if .env already exists
if [ -f "$ENV_FILE" ]; then
    echo "⚠️  Warning: $ENV_FILE already exists!"
    read -p "Do you want to overwrite it? (y/N): " OVERWRITE
    if [[ ! $OVERWRITE =~ ^[Yy]$ ]]; then
        echo "Keeping existing $ENV_FILE"
        exit 0
    fi
fi

echo "This script will help you set up credentials for:"
echo "  • Container registries (Docker Hub, GHCR, etc.)"
echo "  • SonarQube/SonarCloud"
echo "  • Maven repositories (Nexus/Artifactory)"
echo ""
echo "Press Ctrl+C to cancel at any time."
echo ""

# Detect registry from maven.config
DETECTED_REGISTRY="docker.io"
if [ -f ".mvn/maven.config" ]; then
    DETECTED_REGISTRY=$(grep "container.registry" .mvn/maven.config | cut -d'=' -f2 || echo "docker.io")
fi

echo "Detected registry: $DETECTED_REGISTRY"
echo ""

# Container Registry Credentials
echo "=== Container Registry Credentials ==="
read -p "Container registry username: " DOCKER_USERNAME
read -s -p "Container registry password/token: " DOCKER_PASSWORD
echo ""

# GitHub-specific (if using GHCR)
if [[ "$DETECTED_REGISTRY" == *"ghcr.io"* ]]; then
    echo ""
    echo "=== GitHub Container Registry ==="
    read -p "GitHub username: " GITHUB_USERNAME
    read -s -p "GitHub Personal Access Token (with write:packages): " GITHUB_TOKEN
    echo ""
fi

# SonarQube
echo ""
echo "=== SonarQube/SonarCloud (Optional) ==="
read -p "SonarCloud token (leave empty to skip): " SONAR_TOKEN
read -p "Local SonarQube token (leave empty to skip): " SONAR_LOCAL_TOKEN

# Maven Repository
echo ""
echo "=== Maven Repository (Optional) ==="
read -p "Maven repository username (leave empty to skip): " MAVEN_REPO_USERNAME
if [ -n "$MAVEN_REPO_USERNAME" ]; then
    read -s -p "Maven repository password: " MAVEN_REPO_PASSWORD
    echo ""
fi

# Generate .env file
echo ""
echo "📝 Creating $ENV_FILE..."

cat > "$ENV_FILE" <<EOF
# Maven Credentials Environment Variables
# Generated: $(date)
# IMPORTANT: Never commit this file to version control!

# Container Registry Authentication
# Registry: $DETECTED_REGISTRY
export DOCKER_USERNAME="$DOCKER_USERNAME"
export DOCKER_PASSWORD="$DOCKER_PASSWORD"
EOF

# Add GitHub credentials if provided
if [ -n "$GITHUB_USERNAME" ]; then
    cat >> "$ENV_FILE" <<EOF

# GitHub Container Registry
export GITHUB_USERNAME="$GITHUB_USERNAME"
export GITHUB_TOKEN="$GITHUB_TOKEN"
EOF
fi

# Add Sonar credentials if provided
if [ -n "$SONAR_TOKEN" ] || [ -n "$SONAR_LOCAL_TOKEN" ]; then
    cat >> "$ENV_FILE" <<EOF

# SonarQube/SonarCloud
EOF
    [ -n "$SONAR_TOKEN" ] && echo "export SONAR_TOKEN=\"$SONAR_TOKEN\"" >> "$ENV_FILE"
    [ -n "$SONAR_LOCAL_TOKEN" ] && echo "export SONAR_LOCAL_TOKEN=\"$SONAR_LOCAL_TOKEN\"" >> "$ENV_FILE"
fi

# Add Maven repo credentials if provided
if [ -n "$MAVEN_REPO_USERNAME" ]; then
    cat >> "$ENV_FILE" <<EOF

# Maven Repository (Nexus/Artifactory)
export MAVEN_REPO_USERNAME="$MAVEN_REPO_USERNAME"
export MAVEN_REPO_PASSWORD="$MAVEN_REPO_PASSWORD"
EOF
fi

# Add usage instructions
cat >> "$ENV_FILE" <<EOF

# Usage:
# source .env
# mvn clean install
EOF

# Set secure permissions
chmod 600 "$ENV_FILE"

echo ""
echo "✅ Credentials saved to $ENV_FILE"
echo "   Permissions set to 600 (owner read/write only)"
echo ""
echo "To use these credentials:"
echo "  source .env"
echo "  mvn clean install"
echo ""
echo "To persist across sessions, add to your shell profile:"
echo "  echo 'source $(pwd)/.env' >> ~/.bashrc"
echo "  # or ~/.zshrc for zsh"
echo ""
echo "⚠️  Security reminder:"
echo "  • Never commit .env to version control"
echo "  • .env is already in .gitignore"
echo "  • Rotate credentials regularly"
echo ""
