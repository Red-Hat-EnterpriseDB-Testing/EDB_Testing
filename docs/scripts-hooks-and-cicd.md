# Scripts Hooks and CI/CD

This document covers pre-commit hooks, CI/CD validation scripts, and code quality automation.

## Overview

The repository includes automation for code quality, testing, and validation:

- **Pre-commit hooks** - Validate code before commits
- **CI/CD scripts** - Run quality checks locally or in CI pipelines
- **GitHub Actions integration** - Automated validation on push/PR

## Pre-Commit Hooks

Location: `scripts/hooks/`

### check-script-permissions.sh

**Purpose:** Ensures all shell scripts have executable permissions before committing.

**Location:** `scripts/hooks/check-script-permissions.sh`

**Usage:**
```bash
# Called automatically by pre-commit framework
# Or manually:
./scripts/hooks/check-script-permissions.sh script1.sh script2.sh
```

**What It Checks:**
- Each script has executable bit set (`chmod +x`)
- Fails if any script is not executable
- Provides fix command: `chmod +x <script-name>`

**Exit Codes:**
- `0` - All scripts are executable
- `1` - One or more scripts lack execute permission

**Example Output:**
```text
⚠️  Script not executable: scripts/my-script.sh
   Fix with: chmod +x scripts/my-script.sh

❌ 1 script(s) are not executable
Run: chmod +x <script-name>
```

**Integration with pre-commit:**

`.pre-commit-config.yaml`:
```yaml
repos:
  - repo: local
    hooks:
      - id: check-script-permissions
        name: Check script permissions
        entry: scripts/hooks/check-script-permissions.sh
        language: script
        files: \.sh$
```

---

### validate-openshift-manifests.sh

**Purpose:** Validates Kubernetes/OpenShift YAML manifests using `kubeval`.

**Location:** `scripts/hooks/validate-openshift-manifests.sh`

**Usage:**
```bash
# Called automatically by pre-commit framework
# Or manually:
./scripts/hooks/validate-openshift-manifests.sh manifest1.yaml manifest2.yaml
```

**What It Validates:**
- Kubernetes API schema compliance
- Field types and structure
- Required fields presence
- API version compatibility

**Skips:**
- Files without `apiVersion:` field
- Kustomization files (`kind: Kustomization`)
- Non-YAML files

**Tool Required:**
- `kubeval` - Install from https://kubeval.com/

**Exit Codes:**
- `0` - All manifests are valid or tool not installed (graceful degradation)
- `1` - One or more manifests failed validation

**Example Output:**
```text
Validating: manifests/deployment.yaml
  ✅ Valid
Validating: manifests/service.yaml
  ❌ Validation failed: manifests/service.yaml

❌ 1 OpenShift manifest(s) failed validation
```

**Kubeval Flags:**
- `--strict` - Strict schema validation
- `--ignore-missing-schemas` - Skip schemas not in kubeval database

**Integration with pre-commit:**

`.pre-commit-config.yaml`:
```yaml
repos:
  - repo: local
    hooks:
      - id: validate-k8s-manifests
        name: Validate Kubernetes manifests
        entry: scripts/hooks/validate-openshift-manifests.sh
        language: script
        files: \.(yaml|yml)$
```

---

## CI/CD Scripts

### run-ci-checks-locally.sh

**Purpose:** Runs comprehensive quality checks locally before pushing code.

**Location:** `scripts/run-ci-checks-locally.sh`

**Usage:**
```bash
# Run all CI checks
./scripts/run-ci-checks-locally.sh

# Simulates GitHub Actions validation
cd /path/to/repo && ./scripts/run-ci-checks-locally.sh
```

**Checks Performed:**

#### 1. YAML Validation

**Tool:** `yamllint`

**What it checks:**
- YAML syntax
- Indentation consistency
- Line length
- Trailing whitespace

**Skip if:** yamllint not installed

---

#### 2. Kubernetes Manifest Validation

**Tool:** `kubeval`

**What it checks:**
- All `*.yaml` files with `apiVersion:`
- Skips Kustomization files
- Skips `.github/` workflows
- Validates against Kubernetes schema

**Skip if:** kubeval not installed

---

#### 3. Shell Script Linting

**Tool:** `shellcheck`

**What it checks:**
- Bash/shell best practices
- Common pitfalls (unquoted variables, etc.)
- POSIX compliance issues
- Security vulnerabilities

**Configuration:**
- Severity level: warning (`-S warning`)
- Excludes: `.git/`, `node_modules/`

**Skip if:** shellcheck not installed

---

#### 4. Bash Syntax Check

**Tool:** Built-in `bash -n`

**What it checks:**
- Syntax errors in all `.sh` files
- Does NOT execute the script

**Always runs** (no dependencies)

---

#### 5. Security Scan

**Tool:** Custom grep patterns

**What it checks:**
- Hardcoded passwords
- API keys in code
- Potential secret leaks

**Patterns detected:**
```regex
password\s*=\s*['\"][^'\"]+['\"]
api[_-]?key\s*=\s*['\"][^'\"]+['\"]
```

**Exclusions:**
- `*.md` files (documentation)
- The CI script itself
- `.git/` directory

**Result:** Warning only (doesn't fail build)

---

#### 6. Pre-commit Hooks

**Tool:** `pre-commit`

**What it runs:**
- All configured hooks in `.pre-commit-config.yaml`
- Runs against all files (`--all-files`)

**Skip if:** pre-commit not installed

---

**Exit Codes:**
- `0` - All checks passed
- `1` - One or more checks failed

**Example Output:**

```text
=============================================
Running CI Checks Locally
=============================================

📋 YAML Validation
-------------------
✅ YAML linting passed

Validating Kubernetes manifests...
✅ Kubeval passed

🐚 Shell Script Testing
------------------------
Running ShellCheck...
✅ ShellCheck passed

Checking Bash syntax...
✅ Bash syntax check passed

🔒 Security Scan
----------------
Scanning for potential secrets...
✅ No obvious secrets detected

🪝 Pre-commit Hooks
-------------------
✅ Pre-commit hooks passed

=============================================
Summary
=============================================
✅ All checks passed!

You're ready to push your changes.
```

**Failure Output:**

```text
=============================================
Summary
=============================================
❌ Some checks failed:
  - shellcheck
  - bash-syntax

Please fix the issues before pushing.
```

---

## Setting Up Pre-Commit Framework

### Installation

```bash
# Install pre-commit
pip install pre-commit

# Or using Homebrew (macOS)
brew install pre-commit

# Or using conda
conda install -c conda-forge pre-commit
```

### Configuration

Create `.pre-commit-config.yaml` in repository root:

```yaml
repos:
  # Local hooks (scripts in this repo)
  - repo: local
    hooks:
      # Check script permissions
      - id: check-script-permissions
        name: Check script permissions
        entry: scripts/hooks/check-script-permissions.sh
        language: script
        files: \.sh$

      # Validate Kubernetes manifests
      - id: validate-k8s-manifests
        name: Validate Kubernetes manifests
        entry: scripts/hooks/validate-openshift-manifests.sh
        language: script
        files: \.(yaml|yml)$

  # Standard pre-commit hooks
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: mixed-line-ending

  # Shell script linting
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.9.0.6
    hooks:
      - id: shellcheck
```

### Activate Hooks

```bash
# Install git hooks
pre-commit install

# Run against all files (first time)
pre-commit run --all-files

# Update hook versions
pre-commit autoupdate
```

### Daily Usage

Once installed, pre-commit runs automatically on `git commit`:

```bash
# Make changes
vim scripts/my-script.sh

# Stage changes
git add scripts/my-script.sh

# Commit (hooks run automatically)
git commit -m "Update script"
```

**If hooks fail:**

```text
Check script permissions.................................................Failed
- hook id: check-script-permissions
- exit code: 1

⚠️  Script not executable: scripts/my-script.sh
   Fix with: chmod +x scripts/my-script.sh
```

**Fix and retry:**

```bash
# Fix the issue
chmod +x scripts/my-script.sh

# Commit again
git commit -m "Update script"
```

---

## GitHub Actions Integration

### Workflow Configuration

Create `.github/workflows/validate.yml`:

```yaml
name: Validate

on:
  push:
    branches: [ main, testing-* ]
  pull_request:
    branches: [ main ]

jobs:
  validate:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y shellcheck
          pip install yamllint pre-commit
          
          # Install kubeval
          wget https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz
          tar xf kubeval-linux-amd64.tar.gz
          sudo mv kubeval /usr/local/bin/
      
      - name: Run CI checks
        run: ./scripts/run-ci-checks-locally.sh
      
      - name: Run pre-commit hooks
        run: pre-commit run --all-files
```

### Branch Protection

Enable branch protection rules:

1. Go to repository **Settings** → **Branches**
2. Add rule for `main` branch:
   - ✅ Require status checks to pass before merging
   - ✅ Require branches to be up to date before merging
   - Select: `validate / validate`
3. Save changes

Now all PRs must pass validation before merging.

---

## Tool Installation Guide

### shellcheck

**macOS:**
```bash
brew install shellcheck
```

**Ubuntu/Debian:**
```bash
sudo apt-get install shellcheck
```

**RHEL/CentOS:**
```bash
sudo yum install ShellCheck
```

---

### kubeval

**Linux/macOS:**
```bash
wget https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-$(uname -s)-amd64.tar.gz
tar xf kubeval-$(uname -s)-amd64.tar.gz
sudo mv kubeval /usr/local/bin/
```

---

### yamllint

**pip:**
```bash
pip install yamllint
```

**Homebrew:**
```bash
brew install yamllint
```

---

### pre-commit

**pip:**
```bash
pip install pre-commit
```

**Homebrew:**
```bash
brew install pre-commit
```

---

## Best Practices

### For Script Authors

1. **Always make scripts executable:**
   ```bash
   chmod +x scripts/new-script.sh
   ```

2. **Test locally before pushing:**
   ```bash
   ./scripts/run-ci-checks-locally.sh
   ```

3. **Fix shellcheck warnings:**
   ```bash
   shellcheck scripts/my-script.sh
   ```

4. **Validate YAML manifests:**
   ```bash
   kubeval manifests/deployment.yaml
   ```

### For Repository Maintainers

1. **Keep tool versions updated:**
   ```bash
   pre-commit autoupdate
   ```

2. **Enforce pre-commit hooks:**
   - Document in README
   - Include in onboarding

3. **Monitor CI failures:**
   - Fix breaking changes quickly
   - Update tool configurations as needed

4. **Review security scan results:**
   - Never commit real credentials
   - Use secrets management

---

## Troubleshooting

### Pre-commit hooks not running

```bash
# Reinstall hooks
pre-commit uninstall
pre-commit install

# Verify installation
pre-commit run --all-files
```

### Shellcheck too strict

Add exclusions to script:
```bash
# shellcheck disable=SC2086
echo $VARIABLE_WITHOUT_QUOTES
```

Or configure globally in `.shellcheckrc`:
```text
disable=SC2086
```

### Kubeval missing schemas

Use `--ignore-missing-schemas` flag (already enabled in hooks).

### CI checks fail locally but pass in GitHub Actions

- Ensure same tool versions
- Check `.gitignore` exclusions
- Verify file permissions

---

## See Also

- [Scripts Guide](scripts-guide.md) - Complete scripts documentation
- [Scripts Library Reference](scripts-library-reference.md) - Library functions
- [CI/CD Pipeline](cicd-pipeline.md) - CI/CD pipeline documentation
