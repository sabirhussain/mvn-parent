# Container Registry Authentication

This guide explains how to authenticate with container registries when using Jib to build and push container images.

## How Jib Authenticates

Jib automatically discovers credentials through multiple methods in this priority order:

1. **Docker Config** (`~/.docker/config.json`)
2. **Maven Settings** (`~/.m2/settings.xml`)
3. **Environment Variables**
4. **Credential Helpers** (OS keychain)

## Setup Methods

### Method 1: Docker Login (Recommended for Local Development)

The simplest approach - just login once and Jib uses existing credentials:

```bash
# Docker Hub
docker login docker.io
# Username: your-username
# Password: your-token

# GitHub Container Registry
docker login ghcr.io
# Username: your-github-username
# Password: your-github-token (with write:packages scope)

# Custom Registry
docker login custom-registry.company.com
# Username: your-username
# Password: your-token
```

**Then build/push:**

```bash
mvn compile jib:build
```

Jib reads credentials from `~/.docker/config.json` automatically.

### Method 2: Maven Settings (Recommended for CI/CD)

Configure credentials in `~/.m2/settings.xml` with environment variables:

```xml
<settings>
    <servers>
        <!-- Server ID must match registry hostname -->
        
        <!-- Docker Hub -->
        <server>
            <id>docker.io</id>
            <username>${env.DOCKER_USERNAME}</username>
            <password>${env.DOCKER_PASSWORD}</password>
        </server>
        
        <!-- GitHub Container Registry -->
        <server>
            <id>ghcr.io</id>
            <username>${env.GITHUB_USERNAME}</username>
            <password>${env.GITHUB_TOKEN}</password>
        </server>
        
        <!-- Custom Registry -->
        <server>
            <id>custom-registry.company.com</id>
            <username>${env.REGISTRY_USERNAME}</username>
            <password>${env.REGISTRY_PASSWORD}</password>
        </server>
    </servers>
</settings>
```

**Set environment variables:**

```bash
# Add to .env file
export DOCKER_USERNAME=myuser
export DOCKER_PASSWORD=mytoken
export GITHUB_USERNAME=myuser
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxx

# Source it
source .env

# Build and push
mvn compile jib:build
```

**Important:** Server `<id>` must exactly match the registry hostname in your POM/maven.config.

### Method 3: Explicit Configuration in POM

For specific use cases, you can configure credentials directly in your project POM:

```xml
<plugin>
    <groupId>com.google.cloud.tools</groupId>
    <artifactId>jib-maven-plugin</artifactId>
    <configuration>
        <from>
            <image>eclipse-temurin:17-jre</image>
            <auth>
                <username>${env.BASE_IMAGE_USERNAME}</username>
                <password>${env.BASE_IMAGE_PASSWORD}</password>
            </auth>
        </from>
        <to>
            <image>${container.registry}/${container.organization}/${project.artifactId}:${project.version}</image>
            <auth>
                <username>${env.TARGET_REGISTRY_USERNAME}</username>
                <password>${env.TARGET_REGISTRY_PASSWORD}</password>
            </auth>
        </to>
    </configuration>
</plugin>
```

## Registry-Specific Setup

### Docker Hub

```bash
# Create access token at https://hub.docker.com/settings/security
docker login docker.io -u your-username -p dckr_pat_xxxxx
```

Or in settings.xml:

```xml
<server>
    <id>docker.io</id>
    <username>your-username</username>
    <password>${env.DOCKER_HUB_TOKEN}</password>
</server>
```

### GitHub Container Registry (GHCR)

```bash
# Create Personal Access Token with 'write:packages' scope
# at https://github.com/settings/tokens
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
```

Or in settings.xml:

```xml
<server>
    <id>ghcr.io</id>
    <username>your-github-username</username>
    <password>${env.GITHUB_TOKEN}</password>
</server>
```

Update maven.config:

```properties
-Dcontainer.registry=ghcr.io
-Dcontainer.organization=your-github-org
```

### AWS Elastic Container Registry (ECR)

```bash
# Get login token (expires after 12 hours)
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin \
    123456789012.dkr.ecr.us-east-1.amazonaws.com
```

Or use Jib's ECR credential helper:

```xml
<plugin>
    <groupId>com.google.cloud.tools</groupId>
    <artifactId>jib-maven-plugin</artifactId>
    <configuration>
        <from>
            <image>123456789012.dkr.ecr.us-east-1.amazonaws.com/base:latest</image>
            <credHelper>ecr-login</credHelper>
        </from>
        <to>
            <image>123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:${project.version}</image>
            <credHelper>ecr-login</credHelper>
        </to>
    </configuration>
</plugin>
```

### Google Container Registry (GCR)

```bash
# Authenticate with gcloud
gcloud auth configure-docker

# Or use service account
cat keyfile.json | docker login -u _json_key --password-stdin https://gcr.io
```

Or use credential helper:

```xml
<configuration>
    <to>
        <image>gcr.io/my-project/myapp:${project.version}</image>
        <credHelper>gcr</credHelper>
    </to>
</configuration>
```

### Azure Container Registry (ACR)

```bash
# Authenticate with Azure CLI
az acr login --name myregistry

# Or use service principal
docker login myregistry.azurecr.io -u <service-principal-id> -p <password>
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Build and Push

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up JDK
        uses: actions/setup-java@v3
        with:
          java-version: '17'
          distribution: 'temurin'
      
      - name: Build and push container
        env:
          DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}
          DOCKER_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}
        run: mvn compile jib:build
```

### GitLab CI

```yaml
build:
  image: maven:3.9-eclipse-temurin-17
  stage: build
  script:
    - mvn compile jib:build
  variables:
    DOCKER_USERNAME: $DOCKER_USERNAME
    DOCKER_PASSWORD: $DOCKER_PASSWORD
```

### Jenkins

```groovy
pipeline {
    agent any
    
    stages {
        stage('Build Container') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'docker-hub',
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )
                ]) {
                    sh 'mvn compile jib:build'
                }
            }
        }
    }
}
```

## Troubleshooting

### Issue: "Unauthorized" or "403 Forbidden"

**Solution:**

1. Verify credentials: `docker login <registry>`
2. Check server ID matches registry hostname in settings.xml
3. Ensure token has correct permissions (write:packages for GHCR)

### Issue: "401 Unauthorized" with settings.xml

**Solution:**

- Verify environment variables are set: `echo $DOCKER_USERNAME`
- Source your .env file: `source .env`
- Check for typos in `${env.VARIABLE_NAME}` syntax

### Issue: Credentials not found

**Solution:**

1. Check Jib can find credentials: `mvn jib:build -X` (debug mode)
2. Verify `~/.docker/config.json` exists and contains auth
3. Try explicit `docker login` first

### Issue: Different credentials for base and target images

**Solution:** Use explicit auth in POM configuration (see Method 3 above)

## Security Best Practices

✅ **Do:**

- Use access tokens instead of passwords
- Use environment variables in settings.xml
- Rotate credentials regularly
- Use least-privilege tokens (read-only when possible)
- Store credentials in CI/CD secrets, not in code

❌ **Don't:**

- Commit credentials to git
- Use root/admin accounts
- Share credentials across teams
- Hardcode passwords in POM files
- Log credentials in CI/CD output

## Credential Helpers

For enhanced security, use OS-native credential helpers:

**macOS:**

```bash
# Already configured by default
# Credentials stored in Keychain
```

**Windows:**

```bash
# Docker Desktop configures wincred automatically
# Credentials stored in Windows Credential Manager
```

**Linux:**

```bash
# Install pass (password manager)
sudo apt-get install pass gnupg2

# Configure docker to use it
echo '{"credsStore":"pass"}' > ~/.docker/config.json
```

## Reference

- [Jib Authentication Methods](https://github.com/GoogleContainerTools/jib/blob/master/docs/faq.md#authentication)
- [Maven Settings Reference](https://maven.apache.org/settings.html#servers)
- [Docker Login Documentation](https://docs.docker.com/engine/reference/commandline/login/)
- [SECURITY.md](SECURITY.md) - General credential management
