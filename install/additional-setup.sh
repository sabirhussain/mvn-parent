#!/bin/bash
# additional-setup.sh - Interactive credentials and repository setup

set -euo pipefail

ENV_FILE=".env"
ENV_EXAMPLE=".env.example"
SETTINGS_TEMPLATE="settings.xml.template"
SETTINGS_FILE="$HOME/.m2/settings.xml"

# Initialize variables that may be conditionally set
GITHUB_USERNAME=""
GITHUB_TOKEN=""
SONAR_HOST_URL=""
SONAR_PROJECT_KEY=""
SONAR_TOKEN=""
SONAR_LOCAL_TOKEN=""
MAVEN_REPO_USERNAME=""
MAVEN_REPO_PASSWORD=""
BACKUP_FILE=""
MERGE_MODE=false
SKIP_SETTINGS_GEN=false
M2_ENV_FILE=""
CONFIGURE_SONAR=""
CONFIGURE_DISTRO=""
COPY_TO_M2=""

# Track temporary files for cleanup on exit
_CLEANUP_FILES=()
cleanup() {
    for f in "${_CLEANUP_FILES[@]+"${_CLEANUP_FILES[@]}"}";
    do
        rm -f "$f"
    done
}
trap cleanup EXIT INT TERM

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
    read -rp "Do you want to overwrite it? (y/N): " OVERWRITE
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

# Detect registry from maven.config (use awk for exact line matching, handles whitespace)
DETECTED_REGISTRY="docker.io"
if [ -f ".mvn/maven.config" ]; then
    _reg=$(awk -F'=' '/^-Dcontainer\.registry=/{print $2; exit}' .mvn/maven.config 2>/dev/null || true)
    [ -n "$_reg" ] && DETECTED_REGISTRY="$_reg"
fi

echo "Detected registry: $DETECTED_REGISTRY"
echo ""

# Container Registry Credentials
echo "=== Container Registry Credentials ==="
read -rp "Container registry username: " DOCKER_USERNAME
read -rsp "Container registry password/token: " DOCKER_PASSWORD
echo ""

# GitHub-specific (if using GHCR)
if [[ "$DETECTED_REGISTRY" == *"ghcr.io"* ]]; then
    echo ""
    echo "=== GitHub Container Registry ==="
    read -rp "GitHub username: " GITHUB_USERNAME
    read -rsp "GitHub Personal Access Token (with write:packages): " GITHUB_TOKEN
    echo ""
fi

# SonarQube
echo ""
echo "=== SonarQube/SonarCloud (Optional) ==="
echo "Configure SonarQube settings for code quality analysis."
read -rp "Configure SonarQube? (y/N): " CONFIGURE_SONAR

if [[ $CONFIGURE_SONAR =~ ^[Yy]$ ]]; then
    read -rp "Enter Sonar host URL [http://localhost:9000]: " SONAR_HOST_URL
    SONAR_HOST_URL=${SONAR_HOST_URL:-http://localhost:9000}
    
    read -rp "Enter Sonar project key [\${project.groupId}:\${project.artifactId}]: " SONAR_PROJECT_KEY
    # shellcheck disable=SC2016  # ${project.groupId} is a literal Maven property reference, not shell expansion
    SONAR_PROJECT_KEY=${SONAR_PROJECT_KEY:-'${project.groupId}:${project.artifactId}'}
    
    # Tokens for authentication - use -s to avoid echoing secrets to terminal
    echo ""
    read -rsp "SonarCloud token (leave empty to skip): " SONAR_TOKEN
    echo ""
    read -rsp "Local SonarQube token (leave empty to skip): " SONAR_LOCAL_TOKEN
    echo ""
else
    SONAR_HOST_URL=""
    SONAR_PROJECT_KEY=""
    SONAR_TOKEN=""
    SONAR_LOCAL_TOKEN=""
fi

# Maven Repository
echo ""
echo "=== Maven Repository (Optional) ==="
read -rp "Maven repository username (leave empty to skip): " MAVEN_REPO_USERNAME
if [ -n "$MAVEN_REPO_USERNAME" ]; then
    read -rsp "Maven repository password: " MAVEN_REPO_PASSWORD
    echo ""
fi

# Generate .env by processing .env.example line-by-line, replacing known export
# placeholders with safely-quoted actual values (printf %q).
# The template remains the single source of truth for file structure and comments.
echo ""
echo "📝 Creating $ENV_FILE from template..."

write_env_from_template() {
    local src="$1"
    local dst="$2"
    while IFS= read -r line; do
        case "$line" in
            'export DOCKER_USERNAME='*)
                printf 'export DOCKER_USERNAME=%q\n' "$DOCKER_USERNAME" ;;
            'export DOCKER_PASSWORD='*)
                printf 'export DOCKER_PASSWORD=%q\n' "$DOCKER_PASSWORD" ;;
            '# export GITHUB_USERNAME='*)
                if [ -n "$GITHUB_USERNAME" ]; then
                    printf 'export GITHUB_USERNAME=%q\n' "$GITHUB_USERNAME"
                else
                    printf '%s\n' "$line"
                fi ;;
            '# export GITHUB_TOKEN='*)
                if [ -n "$GITHUB_TOKEN" ]; then
                    printf 'export GITHUB_TOKEN=%q\n' "$GITHUB_TOKEN"
                else
                    printf '%s\n' "$line"
                fi ;;
            'export SONAR_TOKEN='*)
                if [ -n "$SONAR_TOKEN" ]; then
                    printf 'export SONAR_TOKEN=%q\n' "$SONAR_TOKEN"
                else
                    printf '# export SONAR_TOKEN=your-sonarcloud-token-here\n'
                fi ;;
            'export SONAR_LOCAL_TOKEN='*)
                if [ -n "$SONAR_LOCAL_TOKEN" ]; then
                    printf 'export SONAR_LOCAL_TOKEN=%q\n' "$SONAR_LOCAL_TOKEN"
                else
                    printf '# export SONAR_LOCAL_TOKEN=your-local-sonar-token-here\n'
                fi ;;
            'export MAVEN_REPO_USERNAME='*)
                if [ -n "$MAVEN_REPO_USERNAME" ]; then
                    printf 'export MAVEN_REPO_USERNAME=%q\n' "$MAVEN_REPO_USERNAME"
                else
                    printf '# export MAVEN_REPO_USERNAME=your-maven-username\n'
                fi ;;
            'export MAVEN_REPO_PASSWORD='*)
                if [ -n "$MAVEN_REPO_PASSWORD" ]; then
                    printf 'export MAVEN_REPO_PASSWORD=%q\n' "$MAVEN_REPO_PASSWORD"
                else
                    printf '# export MAVEN_REPO_PASSWORD=your-maven-password\n'
                fi ;;
            *)
                printf '%s\n' "$line" ;;
        esac
    done < "$src" > "$dst"
}

write_env_from_template "$ENV_EXAMPLE" "$ENV_FILE"

chmod 600 "$ENV_FILE"
echo "✅ Credentials saved to: $ENV_FILE"
echo "   Permissions set to 600 (owner read/write only)"
echo ""

# Ask before copying to ~/.m2 to avoid silently placing credentials in a global location
read -rp "Copy credentials to ~/.m2/.env for user-wide access? (y/N): " COPY_TO_M2
if [[ $COPY_TO_M2 =~ ^[Yy]$ ]]; then
    M2_ENV_FILE="$HOME/.m2/.env"
    mkdir -p "$HOME/.m2"
    cp "$ENV_FILE" "$M2_ENV_FILE"
    chmod 600 "$M2_ENV_FILE"
    echo "✅ Also saved to: $M2_ENV_FILE"
fi
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
read -rp "Configure distribution management? (y/N): " CONFIGURE_DISTRO

if [[ $CONFIGURE_DISTRO =~ ^[Yy]$ ]]; then
    echo ""
    echo "Enter your Maven repository URLs (Nexus, Artifactory, etc.):"
    echo ""
    
    # Snapshot repository
    read -rp "Snapshot repository URL [https://nexus.example.com/repository/maven-snapshots/]: " SNAPSHOT_REPO_URL
    SNAPSHOT_REPO_URL=${SNAPSHOT_REPO_URL:-https://nexus.example.com/repository/maven-snapshots/}
    
    # Release repository
    read -rp "Release repository URL [https://nexus.example.com/repository/maven-releases/]: " RELEASE_REPO_URL
    RELEASE_REPO_URL=${RELEASE_REPO_URL:-https://nexus.example.com/repository/maven-releases/}
    
    # Server IDs
    echo ""
    read -rp "Snapshot repository server ID [company-snapshots]: " SNAPSHOT_REPO_ID
    SNAPSHOT_REPO_ID=${SNAPSHOT_REPO_ID:-company-snapshots}
    
    read -rp "Release repository server ID [company-releases]: " RELEASE_REPO_ID
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
        read -rp "Choose location [1]: " SETTINGS_LOCATION
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
                read -rp "Choose option [1]: " MERGE_OPTION
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
                
                # Generate our sections from template (temp files tracked for cleanup)
                TEMP_SETTINGS=$(mktemp)
                _CLEANUP_FILES+=("$TEMP_SETTINGS")
                sed -e "s|{{RELEASE_REPO_URL}}|$RELEASE_REPO_URL|g" \
                    -e "s|{{SNAPSHOT_REPO_URL}}|$SNAPSHOT_REPO_URL|g" \
                    -e "s|{{RELEASE_REPO_ID}}|$RELEASE_REPO_ID|g" \
                    -e "s|{{SNAPSHOT_REPO_ID}}|$SNAPSHOT_REPO_ID|g" \
                    "$SETTINGS_TEMPLATE" > "$TEMP_SETTINGS"
                
                # Extract our marked sections from template
                SERVERS_SECTION_FILE=$(mktemp)
                _CLEANUP_FILES+=("$SERVERS_SECTION_FILE")
                PROFILES_SECTION_FILE=$(mktemp)
                _CLEANUP_FILES+=("$PROFILES_SECTION_FILE")
                MERGED_FILE=$(mktemp)
                _CLEANUP_FILES+=("$MERGED_FILE" "${MERGED_FILE}.tmp")
                
                sed -n '/<!-- MVN-PARENT-START: Servers/,/<!-- MVN-PARENT-END: Servers -->/p' "$TEMP_SETTINGS" > "$SERVERS_SECTION_FILE"
                sed -n '/<!-- MVN-PARENT-START: Profiles/,/<!-- MVN-PARENT-END: Profiles -->/p' "$TEMP_SETTINGS" > "$PROFILES_SECTION_FILE"
                
                # Remove old MVN-PARENT sections if they exist
                sed -i.merge '/<!-- MVN-PARENT-START:/,/<!-- MVN-PARENT-END:/d' "$SETTINGS_FILE"
                _CLEANUP_FILES+=("${SETTINGS_FILE}.merge")
                
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
if [ -n "$M2_ENV_FILE" ]; then
    echo "  source $M2_ENV_FILE    # User-wide"
fi
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
