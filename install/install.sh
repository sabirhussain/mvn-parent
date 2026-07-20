#!/bin/bash
# install.sh - Maven Parent POM Setup

set -e

# Redirect stdin from TTY if running via pipe (e.g., curl | bash)
if [ ! -t 0 ] && [ -e /dev/tty ]; then
    exec < /dev/tty
fi

# Check for --local flag
LOCAL_MODE=false
if [ "$1" == "--local" ]; then
    LOCAL_MODE=true
    LOCAL_SOURCE_DIR="${2:-$(dirname "$0")}"
    LOCAL_SOURCE_DIR="$(cd "$LOCAL_SOURCE_DIR" && pwd)"  # Parent of install/ dir
    echo "🔧 LOCAL TEST MODE"
    echo "   Using files from: $LOCAL_SOURCE_DIR"
    echo ""
fi

REPO_URL="https://github.com/sabirhussain/mvn-parent"

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

# Clone repository to temp dir or use local files
TEMP_DIR=$(mktemp -d)

if [ "$LOCAL_MODE" = true ]; then
    echo "📦 Copying files from local directory..."
    cp -r "$LOCAL_SOURCE_DIR"/* "$TEMP_DIR/" 2>/dev/null || true
    cp -r "$LOCAL_SOURCE_DIR"/.mvn "$TEMP_DIR/" 2>/dev/null || true
    cp "$LOCAL_SOURCE_DIR"/.gitignore "$TEMP_DIR/" 2>/dev/null || true
    
    # Verify critical files exist
    if [ ! -f "$TEMP_DIR/pom.xml" ]; then
        echo "❌ Error: pom.xml not found in $LOCAL_SOURCE_DIR"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
else
    echo "📦 Downloading Maven Parent POM..."
    git clone --depth 1 "$REPO_URL" "$TEMP_DIR" 2>/dev/null || {
        echo "❌ Failed to clone repository"
        rm -rf "$TEMP_DIR"
        exit 1
    }
fi

# Set paths for templates and docs
if [ "$LOCAL_MODE" = true ]; then
    TEMPLATES_DIR="$TEMP_DIR/install/templates"
    DOCS_DIR="$TEMP_DIR/docs"
else
    TEMPLATES_DIR="$TEMP_DIR/install/templates"
    DOCS_DIR="$TEMP_DIR/docs"
fi

# Copy core files to current directory
echo "📋 Copying project files..."
cp "$TEMP_DIR/pom.xml" .
cp -r "$TEMP_DIR"/.mvn . 2>/dev/null || true
cp "$TEMP_DIR"/.gitignore . 2>/dev/null || true
cp "$TEMP_DIR/LICENSE" . 2>/dev/null || true

# Copy scripts
cp "$TEMP_DIR/install/env-setup.sh" .
chmod +x env-setup.sh 2>/dev/null || true

# Copy documentation
cp "$DOCS_DIR/SECURITY.md" .
cp "$DOCS_DIR/CONTAINER_CREDENTIALS.md" .

# Copy static templates
cp "$TEMPLATES_DIR/settings.xml.template" .

rm -rf "$TEMP_DIR"

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

# Set paths again for template substitution (after temp cleanup)
if [ "$LOCAL_MODE" = true ]; then
    TEMPLATES_DIR="$LOCAL_SOURCE_DIR/install/templates"
else
    # Re-clone just for templates since we cleaned up TEMP_DIR
    TEMP_DIR2=$(mktemp -d)
    git clone --depth 1 "$REPO_URL" "$TEMP_DIR2" 2>/dev/null
    TEMPLATES_DIR="$TEMP_DIR2/install/templates"
fi

# Create .mvn/maven.config from template
mkdir -p .mvn
substitute_template "$TEMPLATES_DIR/maven-config.template" ".mvn/maven.config"

# Create .env.example from template
substitute_template "$TEMPLATES_DIR/env.template" ".env.example"

# Create README.md from template
substitute_template "$TEMPLATES_DIR/README.template.md" "README.md"

# Cleanup temp clone if used
[ -n "$TEMP_DIR2" ] && rm -rf "$TEMP_DIR2"

echo ""
echo "✅ Installation complete!"
echo ""
echo "Files created:"
echo "  ✓ pom.xml (customized)"
echo "  ✓ .mvn/maven.config"
echo "  ✓ .env.example"
echo "  ✓ env-setup.sh"
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
echo "Next steps:"
echo "  1. Set up credentials: ./env-setup.sh (or manually: cp .env.example .env && vim .env)"
echo "  2. Review and customize pom.xml for your company standards"
echo "  3. Install to local Maven repository: mvn clean install"
echo "  4. Commit to your company's version control"
echo "  5. Deploy to your Maven repository (Nexus/Artifactory)"
echo "  6. Reference from child projects"
echo ""
