# Local Testing Guide

This guide explains how to test the Maven Parent POM installation scripts locally before pushing changes to GitHub.

## Prerequisites

- Python 3 (for local HTTP server)
- Bash shell
- Maven (optional, for full installation test)

## Testing Methods

### Method 1: Direct Local Testing (Fastest)

Test the install script directly from your local filesystem.

**Steps:**

```bash
# 1. Navigate to your project
cd /path/to/mvn-parent

# 2. Create a test directory
mkdir -p /tmp/mvn-test-$(date +%s)
cd /tmp/mvn-test-*

# 3. Run install script with --local flag
/path/to/mvn-parent/install/install.sh --local /path/to/mvn-parent

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

**Clean up:**

```bash
# Remove test directory when done
rm -rf /tmp/mvn-test-*
```

---

### Method 2: HTTP Server Testing (Most Realistic)

Test the installation as users would via curl, using Python's built-in HTTP server.

**Steps:**

```bash
# 1. Navigate to your project root
cd /path/to/mvn-parent

# 2. Start Python HTTP server
python3 -m http.server 8000

# Output should show:
# Serving HTTP on 0.0.0.0 port 8000 (http://0.0.0.0:8000/) ...
```

**Leave this terminal running** and open a new terminal for testing:

```bash
# 3. In a new terminal, create test directory
mkdir -p /tmp/mvn-http-test-$(date +%s)
cd /tmp/mvn-http-test-*

# 4. Test the installation command
bash <(curl -fsSL http://localhost:8000/install/install.sh)

# You'll be prompted for:
# - Company groupId (e.g., com.testcompany)
# - Container registry (e.g., docker.io)
# - Container organization
# - Parent version
# - Confirmation (y/N)

# 5. Verify installation
ls -la

# 6. Test additional-setup.sh
./additional-setup.sh
# Follow prompts or Ctrl+C to exit

# 7. Check generated files
cat .mvn/maven.config
head -20 README.md
grep "groupId" pom.xml
```

**What to verify:**

- ✅ Curl downloads and executes successfully
- ✅ Interactive prompts work correctly
- ✅ All files created with correct content
- ✅ Variable substitution works (check README.md and maven.config)
- ✅ additional-setup.sh is present and executable

**Stop the server:**

```bash
# In the first terminal, press Ctrl+C to stop the Python server
```

**Clean up:**

```bash
rm -rf /tmp/mvn-http-test-*
```

---

### Method 3: Full Integration Test

Test the complete workflow including Maven installation.

**Steps:**

```bash
# 1. Start HTTP server (in project root)
cd /path/to/mvn-parent
python3 -m http.server 8000

# 2. In new terminal, create test directory
mkdir -p /tmp/mvn-full-test-$(date +%s)
cd /tmp/mvn-full-test-*

# 3. Run installation
bash <(curl -fsSL http://localhost:8000/install/install.sh)
# Enter test values:
#   GroupId: com.testcompany
#   Registry: docker.io
#   Organization: testorg
#   Version: 1.0.0-TEST
#   Confirm: y

# 4. Set up credentials (optional, for testing additional-setup.sh)
./additional-setup.sh
# Press Ctrl+C to skip or enter test credentials

# 5. Install to local Maven repository
mvn clean install

# 6. Verify installation
ls ~/.m2/repository/com/testcompany/mvn-parent/1.0.0-TEST/

# 7. Test in a child project
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

# 8. Verify child can use parent
mvn validate
```

**What to verify:**

- ✅ Maven install succeeds
- ✅ Parent POM in local repository
- ✅ Child project can inherit from parent
- ✅ No Maven errors or warnings

**Clean up:**

```bash
rm -rf /tmp/mvn-full-test-*
rm -rf /tmp/test-child-project
# Remove from Maven repo (optional)
rm -rf ~/.m2/repository/com/testcompany
```

---

## Common Test Scenarios

### Test 1: Variable Substitution

Verify that template variables are correctly replaced:

```bash
cd /tmp/test && /path/to/mvn-parent/install/install.sh --local /path/to/mvn-parent
# Enter: com.acme, ghcr.io, acme-corp, 2.0.0

# Check substitution
grep "com.acme" README.md pom.xml
grep "ghcr.io" .mvn/maven.config .env.example
grep "acme-corp" .mvn/maven.config .env.example
grep "2.0.0" pom.xml README.md
```

### Test 2: Documentation Files

Verify all documentation is copied correctly:

```bash
cd /tmp/test && bash <(curl -fsSL http://localhost:8000/install/install.sh)

# Check files exist
test -f SECURITY.md && echo "✓ SECURITY.md"
test -f CONTAINER_CREDENTIALS.md && echo "✓ CONTAINER_CREDENTIALS.md"
test -f settings.xml.template && echo "✓ settings.xml.template"
test -f additional-setup.sh && echo "✓ additional-setup.sh"
test -f README.md && echo "✓ README.md"
```

### Test 3: Executable Permissions

Verify scripts are executable:

```bash
cd /tmp/test && bash <(curl -fsSL http://localhost:8000/install/install.sh)

# Check permissions
test -x additional-setup.sh && echo "✓ additional-setup.sh is executable"
```

### Test 4: Default Values

Test that default values work when user just presses Enter:

```bash
# Press Enter for all prompts, then 'y' to confirm
cd /tmp/test && bash <(curl -fsSL http://localhost:8000/install/install.sh)

# Should use defaults:
grep "com.example" pom.xml
grep "docker.io" .mvn/maven.config
grep "1.0.0-SNAPSHOT" pom.xml
```

---

## Troubleshooting

### Issue: "Device not configured" error

**Problem:** `/dev/tty: Device not configured` when running automated tests

**Solution:** Use heredoc or --local flag:

```bash
# Option 1: Local flag (bypasses TTY redirect)
./install/install.sh --local /path/to/repo

# Option 2: Use heredoc
./install/install.sh <<EOF
com.test
docker.io
testorg
1.0.0
y
EOF
```

### Issue: "Failed to clone repository"

**Problem:** Git clone fails in HTTP server test

**Solution:** Ensure you're using `--local` flag or the server is running:

```bash
# Check server is running
curl http://localhost:8000/install/install.sh
# Should output the script content
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

## Automated Testing Script

Create a comprehensive test script:

```bash
#!/bin/bash
# test-installation.sh - Automated testing

set -e

PROJECT_ROOT="/path/to/mvn-parent"
TEST_DIR="/tmp/mvn-auto-test-$(date +%s)"

echo "🧪 Starting automated tests..."

# Test 1: Local installation
echo "Test 1: Local installation..."
mkdir -p "$TEST_DIR/test1"
cd "$TEST_DIR/test1"
printf "com.test1\ndocker.io\ntest1\n1.0.0\ny\n" | "$PROJECT_ROOT/install/install.sh" --local "$PROJECT_ROOT" || true

test -f pom.xml && echo "  ✅ pom.xml created" || echo "  ❌ pom.xml missing"
test -f README.md && echo "  ✅ README.md created" || echo "  ❌ README.md missing"
test -f additional-setup.sh && echo "  ✅ additional-setup.sh created" || echo "  ❌ additional-setup.sh missing"

# Test 2: Variable substitution
echo "Test 2: Variable substitution..."
grep -q "com.test1" pom.xml && echo "  ✅ GroupId substituted" || echo "  ❌ GroupId not substituted"
grep -q "docker.io" .mvn/maven.config && echo "  ✅ Registry substituted" || echo "  ❌ Registry not substituted"

# Test 3: File permissions
echo "Test 3: File permissions..."
test -x additional-setup.sh && echo "  ✅ additional-setup.sh executable" || echo "  ❌ additional-setup.sh not executable"

echo ""
echo "🎉 Tests complete! Results in: $TEST_DIR"
echo "Review output above and check $TEST_DIR manually if needed."
echo ""
echo "Clean up with: rm -rf $TEST_DIR"
```

**Usage:**

```bash
chmod +x test-installation.sh
./test-installation.sh
```

---

## Pre-Commit Checklist

Before committing changes, verify:

- [ ] **Local test passes** - `./install/install.sh --local .`
- [ ] **HTTP test passes** - Test via Python server
- [ ] **Templates exist** - All 5 templates in `install/templates/`
- [ ] **Docs moved** - SECURITY.md and CONTAINER_CREDENTIALS.md in `docs/`
- [ ] **References updated** - All paths in readme.md correct
- [ ] **Line count reduced** - install.sh < 220 lines
- [ ] **No hardcoded values** - Check for test values in templates
- [ ] **Executable permissions** - additional-setup.sh and install.sh have +x

---

## Testing for Different Scenarios

### Test with Different Registries

```bash
# Test with ghcr.io
cd /tmp/test-ghcr && curl http://localhost:8000/install/install.sh | bash
# Enter: com.company, ghcr.io, myorg, 1.0.0, y
grep "ghcr.io" .mvn/maven.config .env.example

# Test with custom registry
cd /tmp/test-custom && curl http://localhost:8000/install/install.sh | bash
# Enter: com.company, registry.company.com, team, 1.0.0, y
grep "registry.company.com" .mvn/maven.config
```

### Test Edge Cases

```bash
# Special characters in organization name
# Test: org-name-with-dashes
# Test: org.name.with.dots

# Long groupId
# Test: com.very.long.company.department.team

# Different version formats
# Test: 1.0.0-SNAPSHOT
# Test: 2.0.0-RC1
# Test: 3.0.0.RELEASE
```

---

## CI/CD Testing (Future)

For automated testing in CI/CD pipelines:

```yaml
# .github/workflows/test-install.yml
name: Test Installation Script

on: [ push, pull_request ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Test local installation
        run: |
          TEST_DIR=$(mktemp -d)
          cd $TEST_DIR
          printf "com.test\ndocker.io\ntest\n1.0.0\ny\n" | \
            $GITHUB_WORKSPACE/install/install.sh --local $GITHUB_WORKSPACE

          # Verify files
          test -f pom.xml || exit 1
          test -f README.md || exit 1

          # Check substitution
          grep -q "com.test" pom.xml || exit 1
```

---

## Quick Reference

**Test locally (fastest):**

```bash
./install/install.sh --local .
```

**Test via HTTP (most realistic):**

```bash
# Terminal 1:
python3 -m http.server 8000

# Terminal 2:
bash <(curl -fsSL http://localhost:8000/install/install.sh)
```

**Full integration test:**

```bash
# After HTTP installation:
mvn clean install
```

**Clean up all test directories:**

```bash
rm -rf /tmp/mvn-*test* /tmp/test-*
```

---

## Support

If you encounter issues during testing:

1. Check the Troubleshooting section above
2. Verify project structure matches the expected layout
3. Check file permissions on scripts
4. Review install.sh logs for errors
5. Test with --local flag to isolate issues

For questions or issues, refer to the main project documentation or create an issue in the repository.
