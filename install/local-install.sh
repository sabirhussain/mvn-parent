#!/bin/bash
# local-install.sh - Local Maven Parent POM Installation
# 
# This script handles local installation from a filesystem directory.
# Used for local testing and development.
#
# Usage:
#   ./local-install.sh [source-directory]
#
# Arguments:
#   source-directory: Path to mvn-parent repository root (default: parent of script dir)

set -e

# Determine source directory
if [ -n "$1" ]; then
    SOURCE_DIR="$1"
else
    # Default: parent directory of this script
    SOURCE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
fi

# Resolve to absolute path
SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd)"

echo "🔧 LOCAL INSTALLATION MODE"
echo "   Using files from: $SOURCE_DIR"
echo ""

# Verify source directory has required files
if [ ! -f "$SOURCE_DIR/pom.xml" ]; then
    echo "❌ Error: pom.xml not found in $SOURCE_DIR"
    echo "   Please provide a valid mvn-parent directory."
    exit 1
fi

if [ ! -d "$SOURCE_DIR/install/templates" ]; then
    echo "❌ Error: install/templates/ not found in $SOURCE_DIR"
    echo "   Please provide a valid mvn-parent directory."
    exit 1
fi

# Template substitution function
substitute_template() {
    local template_file=$1
    local output_file=$2
    
    sed -e "s|{{GROUP_ID}}|$GROUP_ID|g" \
        -e "s|{{VERSION}}|$VERSION|g" \
        -e "s|{{REGISTRY}}|$REGISTRY|g" \
        -e "s|{{ORGANIZATION}}|$ORGANIZATION|g" \
        "$template_file" > "$output_file"
}

echo "╔══════════════════════════════════════════════════════════╗"
echo "║         Maven Parent POM - Company Setup                ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Prompt for customization
read -p "Enter your company groupId (e.g., com.mycompany): " GROUP_ID
GROUP_ID=${GROUP_ID:-com.example}

read -p "Enter container registry (docker.io/ghcr.io/custom): " REGISTRY
REGISTRY=${REGISTRY:-docker.io}

read -p "Enter container organization/namespace: " ORGANIZATION
ORGANIZATION=${ORGANIZATION:-${GROUP_ID##*.}}

read -p "Enter parent version [1.0.0-SNAPSHOT]: " VERSION
VERSION=${VERSION:-1.0.0-SNAPSHOT}

echo ""
echo "Configuration Summary:"
echo "  GroupId:      $GROUP_ID"
echo "  Registry:     $REGISTRY"
echo "  Organization: $ORGANIZATION"
echo "  Version:      $VERSION"
echo "  Install Dir:  $(pwd)"
echo ""
read -p "Proceed with installation? (y/N): " CONFIRM

if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

# Set paths for templates and docs
TEMPLATES_DIR="$SOURCE_DIR/install/templates"
DOCS_DIR="$SOURCE_DIR/docs"

# Copy core files to current directory
echo "📋 Copying project files..."
cp "$SOURCE_DIR/pom.xml" .
cp -r "$SOURCE_DIR/.mvn" . 2>/dev/null || true
cp "$SOURCE_DIR/.gitignore" . 2>/dev/null || true
cp "$SOURCE_DIR/LICENSE" . 2>/dev/null || true

# Copy scripts
cp "$SOURCE_DIR/install/additional-setup.sh" .
chmod +x additional-setup.sh 2>/dev/null || true

# Copy documentation
cp "$DOCS_DIR/SECURITY.md" .
cp "$DOCS_DIR/CONTAINER_CREDENTIALS.md" .

# Copy static templates
cp "$TEMPLATES_DIR/settings.xml.template" .

# Update pom.xml
echo "🔧 Customizing pom.xml..."
sed -i.bak "s|<groupId>io.xprevel</groupId>|<groupId>$GROUP_ID</groupId>|g" pom.xml
sed -i.bak "s|<version>1.0.0-SNAPSHOT</version>|<version>$VERSION</version>|" pom.xml

# Update properties
sed -i.bak "s|<container.registry>.*</container.registry>|<container.registry>$REGISTRY</container.registry>|" pom.xml
sed -i.bak "s|<container.organization>.*</container.organization>|<container.organization>$ORGANIZATION</container.organization>|" pom.xml

rm -f pom.xml.bak

# Generate files from templates
echo "📝 Generating configuration files..."

# Create .mvn/maven.config from template
mkdir -p .mvn
substitute_template "$TEMPLATES_DIR/maven-config.template" ".mvn/maven.config"

# Create .env.example from template
substitute_template "$TEMPLATES_DIR/env.template" ".env.example"

# Create README.md from template
substitute_template "$TEMPLATES_DIR/README.template.md" "README.md"

echo ""
echo "✅ Installation complete!"
echo ""
echo "Files created:"
echo "  ✓ pom.xml (customized)"
echo "  ✓ .mvn/maven.config"
echo "  ✓ .env.example"
echo "  ✓ additional-setup.sh"
echo "  ✓ settings.xml.template"
echo "  ✓ README.md"
echo "  ✓ SECURITY.md"
echo "  ✓ CONTAINER_CREDENTIALS.md"
echo "  ✓ .gitignore"
echo ""
echo "Usage in child projects:"
echo "  <parent>"
echo "    <groupId>$GROUP_ID</groupId>"
echo "    <artifactId>mvn-parent</artifactId>"
echo "    <version>$VERSION</version>"
echo "  </parent>"
echo ""
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Would you like to configure credentials and repositories now?"
echo "(You can also run ./additional-setup.sh later)"
echo ""
read -p "Run additional setup now? (y/N): " RUN_ADDITIONAL

if [[ $RUN_ADDITIONAL =~ ^[Yy]$ ]]; then
    echo ""
    echo "Starting additional setup..."
    echo ""
    if [ -x ./additional-setup.sh ]; then
        ./additional-setup.sh
    else
        chmod +x ./additional-setup.sh
        ./additional-setup.sh
    fi
    
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo ""
fi

echo "Next steps:"
if [[ ! $RUN_ADDITIONAL =~ ^[Yy]$ ]]; then
    echo "  1. (Optional) Configure credentials and repositories: ./additional-setup.sh"
    echo "  2. Review and customize pom.xml for your company standards"
    echo "  3. Install to local Maven repository: mvn clean install"
    echo "  4. Commit to your company's version control"
    echo "  5. Deploy to your Maven repository (Nexus/Artifactory): mvn deploy"
    echo "  6. Reference from child projects"
else
    echo "  1. Review and customize pom.xml for your company standards"
    echo "  2. Install to local Maven repository: mvn clean install"
    echo "  3. Commit to your company's version control"
    echo "  4. Deploy to your Maven repository (Nexus/Artifactory): mvn deploy"
    echo "  5. Reference from child projects"
fi
echo ""
