# Maven Parent POM

A customizable Maven parent POM to enforce company-level standards across all Maven projects.

## Features

- 🐳 **Container Image Management** - Jib-based containerization with customizable registry
- 📊 **Code Coverage** - JaCoCo integration with active coverage profile
- 🔍 **SonarQube Support** - Pre-configured Sonar plugin
- 📦 **Plugin Version Management** - Centralized plugin versions for consistency
- 🎯 **Property-Based Customization** - Override defaults via properties or profiles
- 🌍 **Open Source Ready** - Fully genericized for any organization

## Quick Start

### Option 1: Automated Installation (Recommended)

```bash
# Create a new directory for your company parent POM
mkdir my-company-parent && cd my-company-parent

# Run the installer
bash <(curl -fsSL https://raw.githubusercontent.com/sabirhussain/mvn-parent/main/install/install.sh)
```

**Alternative (download first):**

```bash
curl -fsSL https://raw.githubusercontent.com/sabirhussain/mvn-parent/main/install/install.sh -o install.sh
chmod +x install.sh
./install.sh
```

The installer will prompt you for:

- Company groupId (e.g., `com.mycompany`)
- Container registry (e.g., `docker.io`, `ghcr.io`)
- Container organization/namespace
- Parent version

### Option 2: Manual Setup

```bash
# Clone the repository
git clone https://github.com/sabirhussain/mvn-parent.git
cd mvn-parent

# Customize pom.xml
# Update <groupId>, <version>, and properties as needed

# Install to local Maven repository
mvn clean install
```

## Usage in Child Projects

Add the parent reference to your project's `pom.xml`:

```xml

<project>
    <parent>
        <groupId>com.mycompany</groupId>
        <artifactId>mvn-parent</artifactId>
        <version>1.0.0-SNAPSHOT</version>
    </parent>

    <artifactId>my-service</artifactId>
    <!-- Your project configuration -->
</project>
```

## Customization

### Default Properties

The parent POM defines these customizable properties:

| Property                 | Default                                    | Description                     |
|--------------------------|--------------------------------------------|---------------------------------|
| `container.registry`     | `docker.io`                                | Container registry URL          |
| `container.organization` | `changeme`                                 | Registry organization/namespace |
| `container.repo`         | `${container.organization}`                | Repository within registry      |
| `sonar.projectKey`       | `${project.groupId}:${project.artifactId}` | SonarQube project key           |

### Override Options

**1. In Child POM:**

```xml

<properties>
    <container.registry>ghcr.io</container.registry>
    <container.organization>my-team</container.organization>
</properties>
```

**2. Via Command Line:**

```bash
mvn package -Dcontainer.registry=custom-registry.io
```

**3. In Child's `.mvn/maven.config`:**

```properties
-Dcontainer.registry=ghcr.io
-Dcontainer.organization=my-team
```

### SonarQube Configuration

**Secure Approach:** Use environment variables instead of hardcoding credentials.

**Step 1:** Set environment variables

```bash
# Copy example file
cp .env.example .env

# Edit with your credentials
vim .env

# Source it
source .env
```

**Step 2:** Configure `~/.m2/settings.xml` with variable references:

```xml

<settings>
    <profiles>
        <!-- SonarCloud Profile -->
        <profile>
            <id>sonar</id>
            <properties>
                <sonar.host.url>https://sonarcloud.io</sonar.host.url>
                <sonar.organization>your-org</sonar.organization>
                <sonar.login>${env.SONAR_TOKEN}</sonar.login>
            </properties>
        </profile>

        <!-- Local SonarQube Profile -->
        <profile>
            <id>sonar-local</id>
            <properties>
                <sonar.host.url>http://localhost:9000</sonar.host.url>
                <sonar.login>${env.SONAR_LOCAL_TOKEN}</sonar.login>
            </properties>
        </profile>
    </profiles>

    <activeProfiles>
        <activeProfile>sonar</activeProfile>
    </activeProfiles>
</settings>
```

**Usage:**

```bash
# With SonarCloud (auto-activated)
mvn clean verify sonar:sonar

# With local SonarQube
mvn clean verify sonar:sonar -Psonar-local
```

**References:**

- See [install/templates/settings.xml.template](install/templates/settings.xml.template) for complete configuration
- See [docs/SECURITY.md](docs/SECURITY.md) for credential management best practices

## Building Container Images

Build and push container images using Jib:

```bash
# Build to Docker daemon (local testing)
mvn compile jib:dockerBuild

# Build and push to registry
mvn compile jib:build
```

The image will be tagged as: `${container.registry}/${container.repo}/${project.artifactId}:${project.version}`

### Container Registry Authentication

Jib automatically discovers credentials from:

- Docker login (`~/.docker/config.json`)
- Maven settings (`~/.m2/settings.xml`)
- Environment variables
- OS credential helpers

**Quick setup:**

```bash
# Option 1: Docker login (simplest for local dev)
docker login docker.io

# Option 2: Environment variables (best for CI/CD)
export DOCKER_USERNAME=myuser
export DOCKER_PASSWORD=mytoken
```

**For detailed setup including:**

- Registry-specific configuration (Docker Hub, GHCR, ECR, GCR, ACR)
- CI/CD integration examples
- Troubleshooting authentication issues
- Security best practices

👉 **See [docs/CONTAINER_CREDENTIALS.md](docs/CONTAINER_CREDENTIALS.md) for complete guide**

## Profiles

### Coverage Profile (Active by Default)

Generates JaCoCo code coverage reports:

```bash
mvn clean verify
# Coverage report: target/site/jacoco/index.html
```

### Disable Coverage

```bash
mvn clean verify -P-coverage
```

## Deploying to Your Maven Repository

After customization, deploy to your company's Maven repository:

```xml
<!-- Add to your customized pom.xml -->
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

## Property Precedence

When the same property is defined in multiple places, Maven uses this order (highest to lowest):

1. Command line: `-Dproperty=value`
2. Child's `.mvn/maven.config`
3. Child POM `<properties>`
4. Parent's `.mvn/maven.config`
5. Parent POM `<properties>`

## Plugin Versions

The parent manages versions for common plugins:

- maven-clean-plugin: 3.4.0
- maven-resources-plugin: 3.3.1
- maven-jar-plugin: 3.4.2
- maven-surefire-plugin: 3.5.2
- maven-failsafe-plugin: 3.5.2
- jacoco-maven-plugin: 0.8.13
- jib-maven-plugin: 3.4.5
- sonar-maven-plugin: 5.1.0.4751

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

See [LICENSE](LICENSE) file for details.