# {{GROUP_ID}}:mvn-parent

Maven Parent POM for enforcing company standards across all Maven projects.

**Generated Configuration:**

- GroupId: `{{GROUP_ID}}`
- Version: `{{VERSION}}`
- Container Registry: `{{REGISTRY}}`
- Container Organization: `{{ORGANIZATION}}`

## Getting Started

### 1. Set Up Credentials

Run the interactive credential setup:

```bash
./env-setup.sh
```

Or manually:

```bash
# Copy example file
cp .env.example .env

# Edit with your credentials
vim .env

# Source before running Maven
source .env
```

### 2. Use in Child Projects

Add this parent to your project's `pom.xml`:

```xml
<project>
    <parent>
        <groupId>{{GROUP_ID}}</groupId>
        <artifactId>mvn-parent</artifactId>
        <version>{{VERSION}}</version>
    </parent>
    
    <artifactId>my-service</artifactId>
    <!-- Your project configuration -->
</project>
```

### 3. Deploy to Company Repository

Update `pom.xml` with your repository settings:

```xml
<distributionManagement>
    <repository>
        <id>company-releases</id>
        <url>https://nexus.mycompany.com/repository/maven-releases/</url>
    </repository>
    <snapshotRepository>
        <id>company-snapshots</id>
        <url>https://nexus.mycompany.com/repository/maven-snapshots/</url>
    </snapshotRepository>
</distributionManagement>
```

Then deploy:

```bash
mvn clean deploy
```

## Features

- 🐳 **Container Images** - Jib plugin for building containers
- 📊 **Code Coverage** - JaCoCo integration (active by default)
- 🔍 **SonarQube** - Pre-configured analysis plugin
- 📦 **Plugin Management** - Centralized plugin versions

## Building Container Images

Build and push container images:

```bash
# Source credentials
source .env

# Build to Docker daemon (local)
mvn compile jib:dockerBuild

# Build and push to registry
mvn compile jib:build
```

Images are tagged as: `{{REGISTRY}}/{{ORGANIZATION}}/${project.artifactId}:${project.version}`

## Customization

### Override Properties in Child Projects

```xml
<properties>
    <container.organization>my-team</container.organization>
</properties>
```

### Override via Command Line

```bash
mvn package -Dcontainer.registry=ghcr.io
```

### Configure SonarQube

Add to `~/.m2/settings.xml`:

```xml
<settings>
    <profiles>
        <profile>
            <id>sonar</id>
            <properties>
                <sonar.host.url>https://sonarcloud.io</sonar.host.url>
                <sonar.organization>your-org</sonar.organization>
                <sonar.login>${env.SONAR_TOKEN}</sonar.login>
            </properties>
        </profile>
    </profiles>
    <activeProfiles>
        <activeProfile>sonar</activeProfile>
    </activeProfiles>
</settings>
```

Run analysis:

```bash
source .env
mvn clean verify sonar:sonar
```

## Files

- `pom.xml` - Parent POM configuration
- `.mvn/maven.config` - Default Maven arguments
- `.env.example` - Template for credentials
- `.env` - Your credentials (never commit!)
- `env-setup.sh` - Interactive credential setup
- `settings.xml.template` - Maven settings reference
- `SECURITY.md` - Credential management guide
- `CONTAINER_CREDENTIALS.md` - Container registry authentication

## Security

⚠️ **Never commit credentials to version control!**

- `.env` is in `.gitignore`
- Use environment variables in `settings.xml`
- See [SECURITY.md](SECURITY.md) for best practices
- See [CONTAINER_CREDENTIALS.md](CONTAINER_CREDENTIALS.md) for registry auth

## Profiles

- `coverage` - JaCoCo code coverage (active by default)

## Plugin Versions

- maven-surefire-plugin: 3.5.2
- maven-failsafe-plugin: 3.5.2
- jacoco-maven-plugin: 0.8.13
- jib-maven-plugin: 3.4.5
- sonar-maven-plugin: 5.1.0.4751

## Support

For issues or questions:

1. Check [SECURITY.md](SECURITY.md) for credential problems
2. Check [CONTAINER_CREDENTIALS.md](CONTAINER_CREDENTIALS.md) for registry auth
3. Review [settings.xml.template](settings.xml.template) for configuration examples

---

Based on [mvn-parent](https://github.com/sabirhussain/mvn-parent)
