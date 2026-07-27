#!/bin/bash
# additional-setup.sh - Interactive credentials and repository setup

set -e

ENV_FILE=".env"
ENV_EXAMPLE=".env.example"
SETTINGS_TEMPLATE="settings.xml.template"
SETTINGS_FILE="$HOME/.m2/settings.xml"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║   Maven Parent - Credentials & Repository Setup         ║"
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

echo "This script will help you set up:"
echo "  • Container registry credentials (Docker Hub, GHCR, etc.)"
echo "  • SonarQube/SonarCloud tokens"
echo "  • Maven repository credentials"
echo "  • Distribution management (for mvn deploy)"
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
echo "Configure SonarQube settings for code quality analysis."
read -p "Configure SonarQube? (y/N): " CONFIGURE_SONAR

if [[ $CONFIGURE_SONAR =~ ^[Yy]$ ]]; then
    read -p "Enter Sonar host URL [http://localhost:9000]: " SONAR_HOST_URL
    SONAR_HOST_URL=${SONAR_HOST_URL:-http://localhost:9000}
    
    read -p "Enter Sonar project key [\${project.groupId}:\${project.artifactId}]: " SONAR_PROJECT_KEY
    SONAR_PROJECT_KEY=${SONAR_PROJECT_KEY:-\${project.groupId}:\${project.artifactId}}
    
    # Tokens for authentication
    echo ""
    read -p "SonarCloud token (leave empty to skip): " SONAR_TOKEN
    read -p "Local SonarQube token (leave empty to skip): " SONAR_LOCAL_TOKEN
else
    SONAR_HOST_URL=""
    SONAR_PROJECT_KEY=""
    SONAR_TOKEN=""
    SONAR_LOCAL_TOKEN=""
fi

# Maven Repository
echo ""
echo "=== Maven Repository (Optional) ==="
read -p "Maven repository username (leave empty to skip): " MAVEN_REPO_USERNAME
if [ -n "$MAVEN_REPO_USERNAME" ]; then
    read -s -p "Maven repository password: " MAVEN_REPO_PASSWORD
    echo ""
fi

# Generate .env file from .env.example template
echo ""
echo "📝 Creating $ENV_FILE from template..."

# Copy template and substitute values
cp "$ENV_EXAMPLE" "$ENV_FILE"

# Substitute placeholder values with actual credentials
sed -i.bak \
    -e "s|export DOCKER_USERNAME=.*|export DOCKER_USERNAME=\"$DOCKER_USERNAME\"|g" \
    -e "s|export DOCKER_PASSWORD=.*|export DOCKER_PASSWORD=\"$DOCKER_PASSWORD\"|g" \
    "$ENV_FILE"

# Handle GitHub credentials (uncomment if provided)
if [ -n "$GITHUB_USERNAME" ]; then
    sed -i.bak \
        -e "s|# export GITHUB_USERNAME=.*|export GITHUB_USERNAME=\"$GITHUB_USERNAME\"|g" \
        -e "s|# export GITHUB_TOKEN=.*|export GITHUB_TOKEN=\"$GITHUB_TOKEN\"|g" \
        "$ENV_FILE"
fi

# Handle Sonar credentials (update if provided)
if [ -n "$SONAR_TOKEN" ]; then
    sed -i.bak "s|export SONAR_TOKEN=.*|export SONAR_TOKEN=\"$SONAR_TOKEN\"|g" "$ENV_FILE"
fi

if [ -n "$SONAR_LOCAL_TOKEN" ]; then
    sed -i.bak "s|export SONAR_LOCAL_TOKEN=.*|export SONAR_LOCAL_TOKEN=\"$SONAR_LOCAL_TOKEN\"|g" "$ENV_FILE"
fi

# Handle Maven repo credentials (update if provided)
if [ -n "$MAVEN_REPO_USERNAME" ]; then
    sed -i.bak \
        -e "s|export MAVEN_REPO_USERNAME=.*|export MAVEN_REPO_USERNAME=\"$MAVEN_REPO_USERNAME\"|g" \
        -e "s|export MAVEN_REPO_PASSWORD=.*|export MAVEN_REPO_PASSWORD=\"$MAVEN_REPO_PASSWORD\"|g" \
        "$ENV_FILE"
fi

# Clean up backup file
rm -f "$ENV_FILE.bak"

# Set secure permissions
chmod 600 "$ENV_FILE"

# Copy .env to ~/.m2 directory (user-wide location)
M2_ENV_FILE="$HOME/.m2/.env"
mkdir -p "$HOME/.m2"
cp "$ENV_FILE" "$M2_ENV_FILE"
chmod 600 "$M2_ENV_FILE"

echo ""
echo "✅ Credentials saved to:"
echo "   • $ENV_FILE (project-local)"
echo "   • $M2_ENV_FILE (user-wide)"
echo "   Permissions set to 600 (owner read/write only)"
echo ""

# Update maven.config with SonarQube settings if configured
if [[ $CONFIGURE_SONAR =~ ^[Yy]$ ]] && [ -n "$SONAR_HOST_URL" ]; then
    MAVEN_CONFIG_FILE=".mvn/maven.config"
    if [ -f "$MAVEN_CONFIG_FILE" ]; then
        echo "📝 Updating $MAVEN_CONFIG_FILE with SonarQube settings..."
        
        # Uncomment and update Sonar lines
        sed -i.bak \
            -e "s|# -Dsonar.host.url=.*|-Dsonar.host.url=$SONAR_HOST_URL|g" \
            -e "s|# -Dsonar.projectKey=.*|-Dsonar.projectKey=$SONAR_PROJECT_KEY|g" \
            "$MAVEN_CONFIG_FILE"
        
        rm -f "$MAVEN_CONFIG_FILE.bak"
        
        echo "✅ SonarQube configured in $MAVEN_CONFIG_FILE"
        echo "   Host URL:    $SONAR_HOST_URL"
        echo "   Project Key: $SONAR_PROJECT_KEY"
        echo ""
    else
        echo "⚠️  Warning: $MAVEN_CONFIG_FILE not found, skipping Sonar configuration."
        echo ""
    fi
fi

# Distribution Management Configuration
echo "════════════════════════════════════════════════════════════"
echo "=== Maven Distribution Management (Optional) ==="
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Configure repository URLs for deploying artifacts (mvn deploy)."
read -p "Configure distribution management? (y/N): " CONFIGURE_DISTRO

if [[ $CONFIGURE_DISTRO =~ ^[Yy]$ ]]; then
    echo ""
    echo "Enter your Maven repository URLs (Nexus, Artifactory, etc.):"
    echo ""
    
    # Snapshot repository
    read -p "Snapshot repository URL [https://nexus.example.com/repository/maven-snapshots/]: " SNAPSHOT_REPO_URL
    SNAPSHOT_REPO_URL=${SNAPSHOT_REPO_URL:-https://nexus.example.com/repository/maven-snapshots/}
    
    # Release repository
    read -p "Release repository URL [https://nexus.example.com/repository/maven-releases/]: " RELEASE_REPO_URL
    RELEASE_REPO_URL=${RELEASE_REPO_URL:-https://nexus.example.com/repository/maven-releases/}
    
    # Server IDs
    echo ""
    read -p "Snapshot repository server ID [company-snapshots]: " SNAPSHOT_REPO_ID
    SNAPSHOT_REPO_ID=${SNAPSHOT_REPO_ID:-company-snapshots}
    
    read -p "Release repository server ID [company-releases]: " RELEASE_REPO_ID
    RELEASE_REPO_ID=${RELEASE_REPO_ID:-company-releases}
    
    # Check if settings.xml.template exists
    if [ ! -f "$SETTINGS_TEMPLATE" ]; then
        echo ""
        echo "❌ Error: $SETTINGS_TEMPLATE not found!"
        echo "   Distribution management setup requires settings.xml.template."
        echo "   Skipping settings.xml generation."
        echo ""
    else
        # Ask where to place settings.xml
        echo ""
        echo "Where should settings.xml be placed?"
        echo "  1) ~/.m2/settings.xml (user-wide, recommended)"
        echo "  2) ./settings.xml (project-local)"
        read -p "Choose location [1]: " SETTINGS_LOCATION
        SETTINGS_LOCATION=${SETTINGS_LOCATION:-1}
        
        if [ "$SETTINGS_LOCATION" = "1" ]; then
            SETTINGS_FILE="$HOME/.m2/settings.xml"
            mkdir -p "$HOME/.m2"
        else
            SETTINGS_FILE="./settings.xml"
        fi
        
        # Check if settings.xml already exists and create backup
        if [ -f "$SETTINGS_FILE" ]; then
            # Always create timestamped backup
            TIMESTAMP=$(date +%Y%m%d_%H%M%S)
            BACKUP_FILE="${SETTINGS_FILE}.backup.${TIMESTAMP}"
            
            echo ""
            echo "📦 Backing up existing settings.xml..."
            cp "$SETTINGS_FILE" "$BACKUP_FILE"
            echo "✅ Backup created: $BACKUP_FILE"
            
            # Check if file has meaningful content (more than just default structure)
            CONTENT_LINES=$(grep -c "<server>\|<profile>\|<mirror>" "$SETTINGS_FILE" || echo "0")
            
            if [ "$CONTENT_LINES" -gt 3 ]; then
                # File has substantial content, offer merge
                echo ""
                echo "⚠️  Existing settings.xml has custom configurations."
                echo "   Options:"
                echo "     1) Smart merge - Keep existing + add our sections (recommended)"
                echo "     2) Replace entirely - Use our template (backup preserved)"
                echo "     3) Skip - Keep existing unchanged"
                read -p "Choose option [1]: " MERGE_OPTION
                MERGE_OPTION=${MERGE_OPTION:-1}
                
                case $MERGE_OPTION in
                    1)
                        MERGE_MODE=true
                        echo "   → Will merge configurations"
                        ;;
                    2)
                        MERGE_MODE=false
                        echo "   → Will replace entirely"
                        ;;
                    3)
                        echo "   → Keeping existing settings.xml"
                        echo ""
                        echo "Manual setup required:"
                        echo "  1. Edit $SETTINGS_FILE"
                        echo "  2. Add repository URLs and server credentials"
                        echo "  3. See settings.xml.template for reference"
                        echo "  4. Restore backup if needed: mv $BACKUP_FILE $SETTINGS_FILE"
                        SKIP_SETTINGS_GEN=true
                        ;;
                esac
            else
                # Minimal content, safe to replace
                echo "   → Minimal content detected, will replace"
                MERGE_MODE=false
            fi
        else
            # No existing file, create new
            MERGE_MODE=false
        fi
        
        # Generate or merge settings.xml
        if [ "$SKIP_SETTINGS_GEN" != "true" ]; then
            echo ""
            
            if [ "$MERGE_MODE" = "true" ]; then
                # Smart merge: append our sections
                echo "📝 Merging configurations into $SETTINGS_FILE..."
                
                # Generate our sections from template
                TEMP_SETTINGS=$(mktemp)
                sed -e "s|{{RELEASE_REPO_URL}}|$RELEASE_REPO_URL|g" \
                    -e "s|{{SNAPSHOT_REPO_URL}}|$SNAPSHOT_REPO_URL|g" \
                    -e "s|{{RELEASE_REPO_ID}}|$RELEASE_REPO_ID|g" \
                    -e "s|{{SNAPSHOT_REPO_ID}}|$SNAPSHOT_REPO_ID|g" \
                    "$SETTINGS_TEMPLATE" > "$TEMP_SETTINGS"
                
                # Extract our marked sections from template
                SERVERS_SECTION_FILE=$(mktemp)
                PROFILES_SECTION_FILE=$(mktemp)
                sed -n '/<!-- MVN-PARENT-START: Servers/,/<!-- MVN-PARENT-END: Servers -->/p' "$TEMP_SETTINGS" > "$SERVERS_SECTION_FILE"
                sed -n '/<!-- MVN-PARENT-START: Profiles/,/<!-- MVN-PARENT-END: Profiles -->/p' "$TEMP_SETTINGS" > "$PROFILES_SECTION_FILE"
                
                # Remove old MVN-PARENT sections if they exist
                sed -i.merge '/<!-- MVN-PARENT-START:/,/<!-- MVN-PARENT-END:/d' "$SETTINGS_FILE"
                
                # Create a temporary merged file
                MERGED_FILE=$(mktemp)
                
                # Process settings.xml line by line and insert our sections
                while IFS= read -r line; do
                    echo "$line" >> "$MERGED_FILE"
                    
                    # Insert servers section before </servers>
                    if [[ "$line" == *"</servers>"* ]] && [ -s "$SERVERS_SECTION_FILE" ]; then
                        # Remove the last line (</servers>) from merged file
                        sed -i.tmp '$ d' "$MERGED_FILE"
                        # Add our servers section
                        cat "$SERVERS_SECTION_FILE" >> "$MERGED_FILE"
                        # Add back the </servers> tag
                        echo "$line" >> "$MERGED_FILE"
                    # Insert profiles section before </profiles>
                    elif [[ "$line" == *"</profiles>"* ]] && [ -s "$PROFILES_SECTION_FILE" ]; then
                        # Remove the last line (</profiles>) from merged file
                        sed -i.tmp '$ d' "$MERGED_FILE"
                        # Add our profiles section
                        cat "$PROFILES_SECTION_FILE" >> "$MERGED_FILE"
                        # Add back the </profiles> tag
                        echo "$line" >> "$MERGED_FILE"
                    fi
                done < "$SETTINGS_FILE"
                
                # Replace original with merged file
                mv "$MERGED_FILE" "$SETTINGS_FILE"
                
                # Clean up temp files
                rm -f "$TEMP_SETTINGS" "$SERVERS_SECTION_FILE" "$PROFILES_SECTION_FILE" "${SETTINGS_FILE}.merge" "${MERGED_FILE}.tmp"
                
                echo "✅ Merged configurations into $SETTINGS_FILE"
                echo "   Your existing settings preserved"
                echo "   Our sections added with markers (MVN-PARENT-START/END)"
            else
                # Replace with template
                echo "📝 Generating $SETTINGS_FILE..."
                
                sed -e "s|{{RELEASE_REPO_URL}}|$RELEASE_REPO_URL|g" \
                    -e "s|{{SNAPSHOT_REPO_URL}}|$SNAPSHOT_REPO_URL|g" \
                    -e "s|{{RELEASE_REPO_ID}}|$RELEASE_REPO_ID|g" \
                    -e "s|{{SNAPSHOT_REPO_ID}}|$SNAPSHOT_REPO_ID|g" \
                    "$SETTINGS_TEMPLATE" > "$SETTINGS_FILE"
                
                echo "✅ Generated $SETTINGS_FILE"
            fi
            
            if [ -n "$BACKUP_FILE" ]; then
                echo ""
                echo "💾 Backup information:"
                echo "   Original: $BACKUP_FILE"
                echo "   Restore:  mv $BACKUP_FILE $SETTINGS_FILE"
            fi
            
            echo ""
            echo "Repository configuration:"
            echo "  Snapshots: $SNAPSHOT_REPO_URL (ID: $SNAPSHOT_REPO_ID)"
            echo "  Releases:  $RELEASE_REPO_URL (ID: $RELEASE_REPO_ID)"
            echo ""
            
            if [ "$MERGE_MODE" = "true" ]; then
                echo "🔍 Verification (recommended):"
                echo "  1. Review merged settings: cat $SETTINGS_FILE | grep MVN-PARENT"
                echo "  2. Check for conflicts with existing configurations"
                echo "  3. Test deployment: mvn clean deploy -DskipTests -Pcompany-repos"
                echo ""
            fi
            
            echo "To deploy artifacts:"
            echo "  source .env"
            echo "  mvn clean deploy -Pcompany-repos"
            echo ""
            echo "💡 Tips:"
            echo "  • Activate profile: Add 'company-repos' to <activeProfiles> in settings.xml"
            echo "  • Update sections: Look for <!-- MVN-PARENT-START/END --> markers"
            if [ -n "$BACKUP_FILE" ]; then
                echo "  • Rollback if needed: mv $BACKUP_FILE $SETTINGS_FILE"
            fi
        fi
    fi
else
    echo ""
    echo "Skipped distribution management configuration."
    echo "You can run this script again later to configure it."
fi

echo ""
echo "To use these credentials:"
echo "  source .env              # Project-local"
echo "  source ~/.m2/.env        # User-wide"
echo "  mvn clean install"
echo ""
echo "To persist across sessions, add to your shell profile:"
echo "  echo 'source ~/.m2/.env' >> ~/.bashrc"
echo "  # or ~/.zshrc for zsh"
echo ""
echo "⚠️  Security reminder:"
echo "  • Never commit .env to version control"
echo "  • .env is already in .gitignore"
echo "  • Rotate credentials regularly"
echo ""
