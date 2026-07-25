# Testing Guide

This guide explains how to test the Maven Parent POM installation scripts during development and after deployment.

## Prerequisites

- **Bash shell** (required)
- **Maven** (optional, only needed for full integration testing with `mvn clean install`)

**Note:** No Python, Git, or HTTP server needed for development testing!

## Testing Workflow

Understanding when to use each testing method:

### 🔧 Development Phase (Pre-Commit)

**Use `local-install.sh` exclusively** - Tests your uncommitted changes directly from the filesystem.

```
Edit code → Test with local-install.sh → Fix issues → Repeat
```

### ✅ Validation Phase (Post-Commit)

**Optionally test remote installation** - After pushing to GitHub, validate the production installation flow.

```
Commit & Push → Test via GitHub URL → Verify end-user experience
```

**❌ Never:** Try to test remote installation with Python HTTP server before committing - it won't work because
`install.sh` clones from GitHub where your changes don't exist yet!

---

## Pre-Commit Testing

### Method 1: Local Testing (Primary Method)

Test the install script directly from your local filesystem. **Use this for all development.**

**Steps:**

```bash
# 1. Navigate to your project
cd /path/to/mvn-parent

# 2. Create a test directory
mkdir -p /tmp/mvn-test-$(date +%s)
cd /tmp/mvn-test-*

# 3. Run local-install.sh directly
/path/to/mvn-parent/install/local-install.sh /path/to/mvn-parent

# 4. Verify files were created
ls -la

# 5. Check customized files
cat .mvn/maven.config
head README.md
grep "<groupId>" pom.xml
```

**What to verify:**

- ✅ All files created (pom.xml, .mvn/maven.config, README.md, etc.)
- ✅ Variables substituted correctly ({{GROUP_ID}} replaced)
- ✅ additional-setup.sh is executable and present
- ✅ Documentation files copied (SECURITY.md, CONTAINER_CREDENTIALS.md)
- ✅ settings.xml.template copied

**Benefits:**

- ⚡ **Instant feedback** - Tests uncommitted changes immediately
- 🚫 **No dependencies** - No HTTP server, no Python, no Git needed
- ✅ **Works offline** - Test anywhere, anytime
- ✅ **Fast iteration** - Edit → Test → Fix cycle in seconds

**Clean up:**

```bash
# Remove test directory when done
rm -rf /tmp/mvn-test-*
```

---

### Method 2: Full Integration Test

Test the complete workflow including Maven installation to local repository.

**Steps:**

```bash
# 1. Create test directory
mkdir -p /tmp/mvn-full-test-$(date +%s)
cd /tmp/mvn-full-test-*

# 2. Run local installation
/path/to/mvn-parent/install/local-install.sh /path/to/mvn-parent
# Enter test values:
#   GroupId: com.testcompany
#   Registry: docker.io
#   Organization: testorg
#   Version: 1.0.0-TEST
#   Confirm: y
#   Run additional-setup: n

# 3. Install to local Maven repository
mvn clean install

# 4. Verify installation
ls ~/.m2/repository/com/testcompany/mvn-parent/1.0.0-TEST/

# 5. Test in a child project
mkdir -p /tmp/test-child-project
cd /tmp/test-child-project

cat > pom.xml <<EOF
<project>
    <modelVersion>4.0.0</modelVersion>
    
    <parent>
        <groupId>com.testcompany</groupId>
        <artifactId>mvn-parent</artifactId>
        <version>1.0.0-TEST</version>
    </parent>
    
    <artifactId>test-service</artifactId>
    <version>1.0.0</version>
</project>
EOF

# 6. Verify child can use parent
mvn validate
```

**What to verify:**

- ✅ Maven install succeeds without errors
- ✅ Parent POM deployed to local repository (~/.m2/repository)
- ✅ Child project can inherit from parent
- ✅ No Maven warnings or configuration issues

**Clean up:**

```bash
rm -rf /tmp/mvn-full-test-*
rm -rf /tmp/test-child-project
# Remove test artifacts from Maven repo (optional)
rm -rf ~/.m2/repository/com/testcompany
```

---

## Post-Commit Testing

### Method 3: Remote Installation Testing (After Pushing to GitHub)

Test the production installation flow **after committing and pushing your changes**.

**⚠️ Prerequisites:**

- `local-install.sh` must be **committed and pushed** to GitHub
- Changes must be on the branch you're testing (e.g., `main` or feature branch)

**Steps:**

```bash
# 1. First, commit and push your changes
cd /path/to/mvn-parent
git add install/local-install.sh install/install.sh
git commit -m "Update installation scripts"
git push origin main  # or your branch name

# 2. Create test directory
mkdir -p /tmp/mvn-remote-test-$(date +%s)
cd /tmp/mvn-remote-test-*

# 3. Test via GitHub (replace with your repo details)
bash <(curl -fsSL https://raw.githubusercontent.com/YOUR-USERNAME/mvn-parent/main/install/install.sh)

# Or test a specific branch:
bash <(curl -fsSL https://raw.githubusercontent.com/YOUR-USERNAME/mvn-parent/BRANCH-NAME/install/install.sh)

# 4. Follow interactive prompts and verify installation
ls -la
cat .mvn/maven.config
head README.md
```

**What to verify:**

- ✅ Script downloads and executes from GitHub
- ✅ Repository clones successfully
- ✅ local-install.sh is found and executed
- ✅ All files created correctly
- ✅ End-user experience works as expected

**When to use this:**

- 🎯 Before releasing a new version
- 🎯 After major installation script changes
- 🎯 To validate the exact user experience
- ❌ NOT during active development (use Method 1 instead)

**Clean up:**

```bash
rm -rf /tmp/mvn-remote-test-*
```

---

## Common Test Scenarios

### Test 1: Variable Substitution

Verify that template variables are correctly replaced:

```bash
# Create test directory
mkdir -p /tmp/test-vars
cd /tmp/test-vars

# Run installation with specific values
/path/to/mvn-parent/install/local-install.sh /path/to/mvn-parent
# Enter: com.acme, ghcr.io, acme-corp, 2.0.0, y, n

# Verify substitution
grep "com.acme" README.md pom.xml
grep "ghcr.io" .mvn/maven.config .env.example
grep "acme-corp" .mvn/maven.config .env.example
grep "2.0.0" pom.xml README.md

# Clean up
cd /tmp && rm -rf test-vars
```

### Test 2: Documentation Files

Verify all documentation is copied correctly:

```bash
mkdir -p /tmp/test-docs
cd /tmp/test-docs

# Run installation
/path/to/mvn-parent/install/local-install.sh /path/to/mvn-parent
# Use defaults, confirm with y, skip additional-setup with n

# Check files exist
test -f SECURITY.md && echo "✓ SECURITY.md"
test -f CONTAINER_CREDENTIALS.md && echo "✓ CONTAINER_CREDENTIALS.md"
test -f settings.xml.template && echo "✓ settings.xml.template"
test -f additional-setup.sh && echo "✓ additional-setup.sh"
test -f README.md && echo "✓ README.md"

# Clean up
cd /tmp && rm -rf test-docs
```

### Test 3: Executable Permissions

Verify scripts are executable:

```bash
mkdir -p /tmp/test-perms
cd /tmp/test-perms

# Run installation
/path/to/mvn-parent/install/local-install.sh /path/to/mvn-parent

# Check permissions
test -x additional-setup.sh && echo "✓ additional-setup.sh is executable"

# Clean up
cd /tmp && rm -rf test-perms
```

### Test 4: Default Values

Test that default values work when user just presses Enter:

```bash
mkdir -p /tmp/test-defaults
cd /tmp/test-defaults

# Press Enter for all prompts, then 'y' to confirm, 'n' for additional-setup
printf "\n\n\n\ny\nn\n" | /path/to/mvn-parent/install/local-install.sh /path/to/mvn-parent

# Should use defaults
grep "com.example" pom.xml
grep "docker.io" .mvn/maven.config
grep "1.0.0-SNAPSHOT" pom.xml

# Clean up
cd /tmp && rm -rf test-defaults
```

---

## Troubleshooting

### Issue: Script not found

**Problem:** `local-install.sh: No such file or directory`

**Solution:** Use correct path to local-install.sh:

```bash
# Option 1: Provide full absolute path
/full/path/to/mvn-parent/install/local-install.sh /full/path/to/mvn-parent

# Option 2: From project root
cd /path/to/mvn-parent
./install/local-install.sh .

# Option 3: Relative path
cd /tmp/test-dir
../../path/to/mvn-parent/install/local-install.sh ../../path/to/mvn-parent
```

### Issue: Templates not found

**Problem:** "No such file or directory" for template files

**Solution:** Verify directory structure:

```bash
cd /path/to/mvn-parent
ls -la install/templates/

# Should show:
# README.template.md
# env.template
# maven-config.template
# settings.xml.template
```

### Issue: Variables not substituted

**Problem:** `{{GROUP_ID}}` appears in generated files

**Solution:** Check template files have correct syntax:

```bash
grep "{{" install/templates/*.template
# Should show all template variables
```

---

## Automated Testing Script (Optional)

You can optionally create an automated test script for continuous testing. This script is not included in the repository
but can be created for your convenience:

```bash
#!/bin/bash
# test-installation.sh - Automated testing for local-install.sh

set -e

PROJECT_ROOT="/path/to/mvn-parent"
TEST_DIR="/tmp/mvn-auto-test-$(date +%s)"

echo "🧪 Starting automated installation tests..."
echo "Project root: $PROJECT_ROOT"
echo "Test directory: $TEST_DIR"
echo ""

# Test 1: Basic local installation
echo "Test 1: Basic local installation..."
mkdir -p "$TEST_DIR/test1"
cd "$TEST_DIR/test1"
printf "com.test1\ndocker.io\ntest1\n1.0.0\ny\nn\n" | "$PROJECT_ROOT/install/local-install.sh" "$PROJECT_ROOT"

test -f pom.xml && echo "  ✅ pom.xml created" || { echo "  ❌ pom.xml missing"; exit 1; }
test -f README.md && echo "  ✅ README.md created" || { echo "  ❌ README.md missing"; exit 1; }
test -f additional-setup.sh && echo "  ✅ additional-setup.sh created" || { echo "  ❌ additional-setup.sh missing"; exit 1; }
test -f .mvn/maven.config && echo "  ✅ maven.config created" || { echo "  ❌ maven.config missing"; exit 1; }

# Test 2: Variable substitution
echo ""
echo "Test 2: Variable substitution..."
grep -q "com.test1" pom.xml && echo "  ✅ GroupId substituted" || { echo "  ❌ GroupId not substituted"; exit 1; }
grep -q "docker.io" .mvn/maven.config && echo "  ✅ Registry substituted" || { echo "  ❌ Registry not substituted"; exit 1; }
grep -q "test1" .mvn/maven.config && echo "  ✅ Organization substituted" || { echo "  ❌ Organization not substituted"; exit 1; }

# Test 3: File permissions
echo ""
echo "Test 3: File permissions..."
test -x additional-setup.sh && echo "  ✅ additional-setup.sh executable" || { echo "  ❌ additional-setup.sh not executable"; exit 1; }

# Test 4: Default values
echo ""
echo "Test 4: Default values..."
mkdir -p "$TEST_DIR/test4"
cd "$TEST_DIR/test4"
printf "\n\n\n\ny\nn\n" | "$PROJECT_ROOT/install/local-install.sh" "$PROJECT_ROOT"

grep -q "com.example" pom.xml && echo "  ✅ Default groupId used" || { echo "  ❌ Default groupId not used"; exit 1; }
grep -q "docker.io" .mvn/maven.config && echo "  ✅ Default registry used" || { echo "  ❌ Default registry not used"; exit 1; }

# Test 5: Documentation files
echo ""
echo "Test 5: Documentation files..."
cd "$TEST_DIR/test1"
for file in SECURITY.md CONTAINER_CREDENTIALS.md settings.xml.template; do
    test -f "$file" && echo "  ✅ $file exists" || { echo "  ❌ $file missing"; exit 1; }
done

echo ""
echo "🎉 All tests passed!"
echo ""
echo "📁 Test results in: $TEST_DIR"
echo "   You can inspect the generated files manually if needed."
echo ""
echo "🧹 Clean up with: rm -rf $TEST_DIR"
```

**Usage:**

```bash
# 1. Save as test-installation.sh in your project root
cd /path/to/mvn-parent
cat > test-installation.sh <<'EOF'
# ... paste script above ...
EOF

# 2. Update PROJECT_ROOT variable in the script
sed -i '' 's|/path/to/mvn-parent|'$(pwd)'|' test-installation.sh

# 3. Make executable
chmod +x test-installation.sh

# 4. Run tests
./test-installation.sh
```

---

## Pre-Commit Checklist

Before committing installation script changes, verify:

- [ ] **Local test passes** - `./install/local-install.sh .` in fresh directory
- [ ] **Variable substitution works** - Check groupId, registry, organization in generated files
- [ ] **All files created** - pom.xml, README.md, maven.config, additional-setup.sh
- [ ] **Templates exist** - All templates in `install/templates/` directory
- [ ] **Scripts executable** - local-install.sh and install.sh have +x permission
- [ ] **Docs updated** - README.md references are correct
- [ ] **No test values** - Check for hardcoded test values in templates
- [ ] **Default values work** - Test with all Enter keypresses

**Quick verification:**

```bash
# Quick manual test
cd /tmp/quick-test-$(date +%s)
/path/to/mvn-parent/install/local-install.sh /path/to/mvn-parent
# Review output, then clean up
```

---

## CI/CD Testing

For automated testing in CI/CD pipelines (GitHub Actions, GitLab CI, etc.):

**GitHub Actions Example:**

```yaml
# .github/workflows/test-install.yml
name: Test Installation Scripts

on:
  push:
    branches: [ main, develop ]
    paths:
      - 'install/**'
      - 'docs/**'
  pull_request:
    branches: [ main, develop ]
    paths:
      - 'install/**'
      - 'docs/**'

jobs:
  test-installation:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Test local installation with defaults
        run: |
          TEST_DIR=$(mktemp -d)
          cd $TEST_DIR
          printf "\n\n\n\ny\nn\n" | \
            $GITHUB_WORKSPACE/install/local-install.sh $GITHUB_WORKSPACE
          
          # Verify critical files exist
          test -f pom.xml || { echo "pom.xml missing"; exit 1; }
          test -f README.md || { echo "README.md missing"; exit 1; }
          test -f .mvn/maven.config || { echo "maven.config missing"; exit 1; }
          test -f additional-setup.sh || { echo "additional-setup.sh missing"; exit 1; }
          
          echo "✅ All files created successfully"

      - name: Test with custom values
        run: |
          TEST_DIR=$(mktemp -d)
          cd $TEST_DIR
          printf "com.citest\nghcr.io\nciorg\n1.0.0-CI\ny\nn\n" | \
            $GITHUB_WORKSPACE/install/local-install.sh $GITHUB_WORKSPACE
          
          # Verify substitution
          grep -q "com.citest" pom.xml || { echo "GroupId not substituted"; exit 1; }
          grep -q "ghcr.io" .mvn/maven.config || { echo "Registry not substituted"; exit 1; }
          grep -q "ciorg" .mvn/maven.config || { echo "Organization not substituted"; exit 1; }
          
          echo "✅ Variable substitution working"

      - name: Test Maven installation (optional)
        if: matrix.test-maven == 'true'
        run: |
          TEST_DIR=$(mktemp -d)
          cd $TEST_DIR
          printf "com.citest\ndocker.io\ntest\n1.0.0-CI\ny\nn\n" | \
            $GITHUB_WORKSPACE/install/local-install.sh $GITHUB_WORKSPACE
          
          # Install parent POM
          mvn clean install -DskipTests
          
          echo "✅ Maven install successful"

    strategy:
      matrix:
        test-maven: [false]  # Set to true to enable Maven testing

```

**GitLab CI Example:**

```yaml
# .gitlab-ci.yml
test:installation:
  stage: test
  image: openjdk:17-slim
  
  before_script:
    - apt-get update && apt-get install -y bash curl
  
  script:
    - |
      # Test with defaults
      TEST_DIR=$(mktemp -d)
      cd $TEST_DIR
      printf "\n\n\n\ny\nn\n" | $CI_PROJECT_DIR/install/local-install.sh $CI_PROJECT_DIR
      
      # Verify files
      test -f pom.xml && echo "✅ pom.xml" || exit 1
      test -f README.md && echo "✅ README.md" || exit 1
      
      # Verify substitution
      grep -q "com.example" pom.xml && echo "✅ Default groupId" || exit 1
  
  only:
    changes:
      - install/**
      - docs/**
```

---

## Testing for Different Scenarios

### Test with Different Registries

```bash
# Test with GitHub Container Registry
mkdir -p /tmp/test-ghcr
cd /tmp/test-ghcr
printf "com.company\nghcr.io\nmyorg\n1.0.0\ny\nn\n" | \
  /path/to/mvn-parent/install/local-install.sh /path/to/mvn-parent
grep "ghcr.io" .mvn/maven.config .env.example
cd /tmp && rm -rf test-ghcr

# Test with custom registry
mkdir -p /tmp/test-custom
cd /tmp/test-custom
printf "com.company\nregistry.company.com\nteam\n1.0.0\ny\nn\n" | \
  /path/to/mvn-parent/install/local-install.sh /path/to/mvn-parent
grep "registry.company.com" .mvn/maven.config
cd /tmp && rm -rf test-custom

# Test with Docker Hub
mkdir -p /tmp/test-dockerhub
cd /tmp/test-dockerhub
printf "com.company\ndocker.io\nusername\n1.0.0\ny\nn\n" | \
  /path/to/mvn-parent/install/local-install.sh /path/to/mvn-parent
grep "docker.io" .mvn/maven.config
cd /tmp && rm -rf test-dockerhub
```

### Test Edge Cases

```bash
# Test: Organization name with dashes
printf "com.test\ndocker.io\norg-name-with-dashes\n1.0.0\ny\nn\n" | \
  ./install/local-install.sh .

# Test: Organization name with dots
printf "com.test\ndocker.io\norg.name.with.dots\n1.0.0\ny\nn\n" | \
  ./install/local-install.sh .

# Test: Long groupId
printf "com.very.long.company.department.team\ndocker.io\norg\n1.0.0\ny\nn\n" | \
  ./install/local-install.sh .

# Test: Different version formats
printf "com.test\ndocker.io\norg\n1.0.0-SNAPSHOT\ny\nn\n" | ./install/local-install.sh .
printf "com.test\ndocker.io\norg\n2.0.0-RC1\ny\nn\n" | ./install/local-install.sh .
printf "com.test\ndocker.io\norg\n3.0.0.RELEASE\ny\nn\n" | ./install/local-install.sh .
```

---

## Quick Reference

### Pre-Commit Testing (Development)

**Primary method - use this 99% of the time:**

```bash
# From project root
./install/local-install.sh .

# Or from elsewhere
/path/to/mvn-parent/install/local-install.sh /path/to/mvn-parent
```

**Full integration test:**

```bash
cd /tmp/test-$(date +%s)
/path/to/mvn-parent/install/local-install.sh /path/to/mvn-parent
mvn clean install
```

### Post-Commit Testing (Validation)

**After pushing to GitHub:**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/YOUR-USERNAME/mvn-parent/main/install/install.sh)
```

### Clean Up Commands

**Remove all test directories:**

```bash
# Remove common test patterns
rm -rf /tmp/mvn-*test* /tmp/test-*

# Or be more specific
rm -rf /tmp/mvn-test-* /tmp/mvn-full-test-* /tmp/mvn-auto-test-*
```

**Remove test artifacts from Maven repository:**

```bash
# Remove specific test groupId
rm -rf ~/.m2/repository/com/testcompany
rm -rf ~/.m2/repository/com/test1
rm -rf ~/.m2/repository/com/citest

# Or clear entire local repository (nuclear option)
rm -rf ~/.m2/repository/*
```

---

## Support

If you encounter issues during testing:

1. **Check script paths** - Ensure you're providing the correct absolute or relative path
2. **Verify project structure** - Make sure `install/templates/` directory exists with all templates
3. **Check permissions** - Scripts should be executable (`chmod +x install/*.sh`)
4. **Review script output** - Error messages usually indicate what went wrong
5. **Test with defaults first** - Press Enter for all prompts to use default values
6. **Try a fresh directory** - Sometimes leftover files cause issues

**Common Solutions:**

- Script not found → Use absolute path: `/full/path/to/mvn-parent/install/local-install.sh`
- Templates missing → Check `install/templates/` directory exists
- Variables not substituted → Verify template files have `{{VARIABLE}}` syntax
- Permission denied → Run `chmod +x install/*.sh`

**For questions or issues:**

- Check the main project documentation
- Review this testing guide thoroughly
- Create an issue in the repository with details
