# Security Best Practices

## Credential Management

**Never commit credentials to version control!** This project provides secure methods for managing sensitive
information.

## Recommended Approaches

### 1. Environment Variables (Recommended)

Store credentials in environment variables and reference them in `settings.xml`:

```xml
<server>
    <id>sonar</id>
    <username>${env.SONAR_TOKEN}</username>
    <password>${env.SONAR_TOKEN}</password>
</server>
```

**Setup:**

```bash
# Copy the example file
cp .env.example .env

# Edit with your credentials
vim .env

# Source before running Maven
source .env
mvn clean install
```

### 2. Maven Password Encryption

Encrypt passwords using Maven's master password feature:

**Step 1: Create master password**

```bash
mvn --encrypt-master-password
# Output: {jSMOWnoPFgsHVpMvz5VrIt5kRbzGpI8u+9EF1iFQyJQ=}
```

**Step 2: Store in `~/.m2/settings-security.xml`**

```xml
<settingsSecurity>
    <master>{jSMOWnoPFgsHVpMvz5VrIt5kRbzGpI8u+9EF1iFQyJQ=}</master>
</settingsSecurity>
```

**Step 3: Encrypt server password**

```bash
mvn --encrypt-password your-actual-password
# Output: {COQLCE6DU6GtcS5P=}
```

**Step 4: Use encrypted password in `settings.xml`**

```xml
<server>
    <id>company-releases</id>
    <username>your-username</username>
    <password>{COQLCE6DU6GtcS5P=}</password>
</server>
```

### 3. CI/CD Secrets

For CI/CD pipelines, use platform-specific secret management:

**GitHub Actions:**

```yaml
env:
  SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
  MAVEN_REPO_USERNAME: ${{ secrets.MAVEN_USERNAME }}
  MAVEN_REPO_PASSWORD: ${{ secrets.MAVEN_PASSWORD }}
```

**GitLab CI:**

```yaml
variables:
  SONAR_TOKEN: $SONAR_TOKEN
  MAVEN_REPO_USERNAME: $MAVEN_USERNAME
  MAVEN_REPO_PASSWORD: $MAVEN_PASSWORD
```

**Jenkins:**

```groovy
withCredentials([
    string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN'),
    usernamePassword(credentialsId: 'maven-repo', 
                     usernameVariable: 'MAVEN_REPO_USERNAME', 
                     passwordVariable: 'MAVEN_REPO_PASSWORD')
]) {
    sh 'mvn clean deploy'
}
```

### 4. External Secret Managers (Enterprise)

For production environments, consider:

- **HashiCorp Vault** - Industry-standard secret management
- **AWS Secrets Manager** - For AWS environments
- **Azure Key Vault** - For Azure environments
- **Google Secret Manager** - For GCP environments

## Environment Variable Reference

| Variable              | Description                       | Example           |
|-----------------------|-----------------------------------|-------------------|
| `SONAR_TOKEN`         | SonarCloud/SonarQube token        | `squ_abc123...`   |
| `SONAR_LOCAL_TOKEN`   | Local SonarQube token             | `squ_local123...` |
| `MAVEN_REPO_USERNAME` | Nexus/Artifactory username        | `deploy-user`     |
| `MAVEN_REPO_PASSWORD` | Nexus/Artifactory password        | `secure-password` |
| `DOCKER_USERNAME`     | Container registry username       | `docker-user`     |
| `DOCKER_PASSWORD`     | Container registry password/token | `ghp_token...`    |

## Shell Profile Integration

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
# Maven credentials
if [ -f ~/.maven-credentials ]; then
    source ~/.maven-credentials
fi
```

Create `~/.maven-credentials`:

```bash
export SONAR_TOKEN="your-token"
export MAVEN_REPO_USERNAME="your-username"
export MAVEN_REPO_PASSWORD="your-password"
```

Make it readable only by you:

```bash
chmod 600 ~/.maven-credentials
```

## Security Checklist

- [ ] Never commit `settings.xml` with plain-text passwords
- [ ] Never commit `.env` files
- [ ] Add `.env` and `settings.xml` to `.gitignore`
- [ ] Use environment variables or Maven encryption
- [ ] Rotate credentials regularly
- [ ] Use token-based authentication where possible
- [ ] Restrict file permissions: `chmod 600 ~/.m2/settings.xml`
- [ ] Use different credentials for CI/CD vs local development
- [ ] Review and audit access regularly

## Reporting Security Issues

If you discover a security vulnerability, please email security@example.com instead of using the issue tracker.
