# CI/CD Pipeline Documentation

**Version:** 1.0
**Date:** 2026-03-31
**Status:** ✅ IMPLEMENTED

---

## Overview

This repository uses **GitHub Actions** for continuous integration and deployment (CI/CD). The pipeline automatically validates code quality, runs tests, and enforces best practices before changes are merged.

### Pipeline Components

| Workflow | Trigger | Purpose | Status |
|----------|---------|---------|--------|
| **YAML Validation** | Push, PR (YAML files) | Validate OpenShift manifests | ✅ Active |
| **Shell Script Testing** | Push, PR (scripts) | Lint and test bash scripts | ✅ Active |
| **PR Validation** | Pull Request | Comprehensive validation before merge | ✅ Active |
| **Pre-commit Hooks** | Local commits | Client-side validation | ✅ Available |

---

## Quick Start

### For Developers

**1. Install pre-commit hooks (one-time setup):**

```bash
# Install pre-commit framework
pip install pre-commit

# Install hooks
cd /path/to/EDB_Testing
pre-commit install

# Test installation
pre-commit run --all-files
```

**2. Make changes and commit:**

```bash
# Edit files
vim scripts/my-script.sh

# Make script executable
chmod +x scripts/my-script.sh

# Pre-commit hooks run automatically on commit
git add scripts/my-script.sh
git commit -m "Add new failover script"

# If hooks fail, fix issues and try again
```

**3. Create pull request:**

```bash
# Push to your branch
git push origin feature/my-changes

# Create PR via GitHub UI
# CI/CD pipeline runs automatically
```

---

## Workflow Details

### 1. YAML Validation Workflow

**File:** `.github/workflows/yaml-validation.yml`

**Runs on:**
- Push to `main` or `develop` branches
- Pull requests changing YAML files

**Validation Steps:**

| Step | Tool | Purpose | Failure Impact |
|------|------|---------|----------------|
| **YAML Lint** | yamllint | Syntax and style validation | ❌ Blocks merge |
| **Kubeval** | kubeval | OpenShift manifest schema validation | ❌ Blocks merge |
| **Kustomize Build** | kustomize | Test kustomization builds | ❌ Blocks merge |

**Example Output:**

```text
Running yamllint on YAML files...
✅ All YAML files passed linting

Validating OpenShift manifests...
Validating: db-deploy/sample-cluster/base/cluster.yaml
  ✅ Valid

Testing Kustomize build: db-deploy/sample-cluster/base
  ✅ Build successful

✅ All validation checks passed
```

**Common Errors:**

| Error | Cause | Fix |
|-------|-------|-----|
| `line too long` | Line exceeds 120 chars | Break into multiple lines |
| `wrong indentation` | Incorrect spacing | Use 2 spaces for indentation |
| `invalid manifest` | Missing required fields | Add required OpenShift resource fields |
| `kustomize build failed` | Invalid kustomization.yaml | Fix resource references |

---

### 2. Shell Script Testing Workflow

**File:** `.github/workflows/shell-script-testing.yml`

**Runs on:**
- Push to `main` or `develop` branches
- Pull requests changing `.sh` files or `scripts/` directory

**Validation Steps:**

| Step | Tool | Purpose | Failure Impact |
|------|------|---------|----------------|
| **ShellCheck** | shellcheck | Bash linting and best practices | ❌ Blocks merge |
| **Syntax Check** | bash -n | Syntax validation | ❌ Blocks merge |
| **Permissions** | ls -l | Ensure scripts are executable | ⚠️ Warning |
| **Standards** | grep | Check for shebang, set -e | ⚠️ Warning |
| **Unit Tests** | BATS | Run automated tests | ⚠️ If tests exist |

**Example Output:**

```text
Checking: scripts/scale-aap-up.sh
  ✅ No issues found

Syntax check: scripts/scale-aap-up.sh
  ✅ Syntax valid

✅ scripts/scale-aap-up.sh - executable
✅ Has shebang
✅ Has error handling (set -e)

✅ All required checks passed
```

**Common ShellCheck Warnings:**

| Code | Issue | Fix |
|------|-------|-----|
| **SC2086** | Double quote to prevent globbing | `"$variable"` instead of `$variable` |
| **SC2181** | Check exit code directly | `if ! command; then` instead of `if [ $? -ne 0 ]` |
| **SC2034** | Variable unused | Remove or prefix with `_` |
| **SC2155** | Declare and assign separately | Split into two lines |

**Fixing ShellCheck Issues:**

```bash
# Before (SC2086):
echo $MY_VAR

# After:
echo "$MY_VAR"

# Before (SC2181):
command
if [ $? -ne 0 ]; then
  echo "Failed"
fi

# After:
if ! command; then
  echo "Failed"
fi
```

---

### 3. PR Validation Workflow

**File:** `.github/workflows/pr-validation.yml`

**Runs on:**
- Pull request opened, synchronized, or reopened
- Pull request marked ready for review

**Smart Detection:**

The workflow detects which files changed and only runs relevant checks:

```text
Changed files detected:
  YAML files: true → Run YAML validation
  Scripts: false → Skip shell validation
  Docs: true → Run markdown linting
```

**Validation Matrix:**

| Check | Always Run | Conditional |
|-------|------------|-------------|
| **Security Scan** | ✅ Always | - |
| **YAML Validation** | - | If YAML files changed |
| **Shell Validation** | - | If scripts changed |
| **Docs Validation** | - | If markdown changed |
| **PR Size Check** | ✅ Always | - |

**Security Scanning:**

Automatically scans for:
- Hardcoded passwords, API keys, tokens
- Private keys (RSA, ECDSA)
- AWS credentials
- TODO/FIXME markers (informational)

**PR Size Warnings:**

```text
⚠️ Large PR: 52 files changed (consider splitting)
⚠️ Large PR: 1,234 lines changed (consider splitting)
```

**Best Practices:**
- Keep PRs under 50 files
- Keep PRs under 1,000 lines
- Split large changes into multiple PRs

---

### 4. Pre-commit Hooks

**File:** `.pre-commit-config.yaml`

**Purpose:** Run validation **before** committing (catch issues early)

**Installation:**

```bash
# One-time setup
pip install pre-commit
pre-commit install

# Update hooks to latest versions
pre-commit autoupdate
```

**Hooks Enabled:**

| Hook | Tool | Purpose |
|------|------|---------|
| **trailing-whitespace** | pre-commit | Remove trailing spaces |
| **end-of-file-fixer** | pre-commit | Ensure newline at end of file |
| **check-yaml** | pre-commit | Basic YAML syntax check |
| **check-added-large-files** | pre-commit | Block files > 1MB |
| **detect-private-key** | pre-commit | Prevent committing private keys |
| **shellcheck** | shellcheck-py | Bash linting |
| **yamllint** | yamllint | YAML linting |
| **markdownlint** | markdownlint-cli | Markdown linting |
| **detect-secrets** | detect-secrets | Secret scanning |
| **bash-syntax** | bash | Syntax validation |
| **openshift-manifest-validate** | kubeval | OpenShift manifest validation |

**Running Manually:**

```bash
# Run all hooks
pre-commit run --all-files

# Run specific hook
pre-commit run shellcheck --all-files

# Skip hooks for a commit (not recommended)
git commit --no-verify -m "Emergency fix"
```

**Example Pre-commit Output:**

```text
Trim trailing whitespace............Passed
Fix end of files...................Passed
Check YAML syntax..................Passed
Check for large files..............Passed
Detect private keys................Passed
ShellCheck.........................Passed
Lint YAML files....................Failed

- hook id: yamllint
- exit code: 1

db-deploy/sample-cluster/base/cluster.yaml
  42:121    error    line too long (132 > 120 characters)  (line-length)

# Fix the issue and try again
```

---

## Troubleshooting

### Pre-commit Hooks Failing

**Problem:** Hooks fail on every commit

**Solution:**

```bash
# See which hooks failed
pre-commit run --all-files

# Update hooks to latest
pre-commit autoupdate

# Clear pre-commit cache
pre-commit clean
pre-commit install --install-hooks

# Uninstall and reinstall
pre-commit uninstall
rm -rf ~/.cache/pre-commit
pre-commit install
```

### GitHub Actions Failing

**Problem:** Workflows fail in CI but pass locally

**Causes:**
1. Different tool versions
2. Files not committed
3. Different environment

**Solution:**

```bash
# Run same checks locally
.github/workflows/run-checks-locally.sh

# Check what files are committed
git status

# Ensure all dependencies are committed
git add .
git status
```

### ShellCheck Errors

**Problem:** Too many ShellCheck warnings

**Solution:**

```bash
# Fix automatically (if possible)
shellcheck -f diff scripts/my-script.sh | git apply

# Disable specific warning (use sparingly)
# shellcheck disable=SC2086
echo $VAR

# Disable for entire file
# shellcheck disable=SC2086,SC2181
```

### YAML Validation Errors

**Problem:** Valid YAML fails kubeval

**Cause:** Kubeval doesn't recognize all OpenShift CRDs and extension APIs

**Solution:**

```yaml
# Add to .github/workflows/yaml-validation.yml
kubeval --ignore-missing-schemas "$file"

# Or skip validation for specific CRDs
if grep -q "kind: MyCustomResource" "$file"; then
  echo "Skipping custom resource"
  continue
fi
```

---

## Best Practices

### Writing Shell Scripts

**Always include:**

```bash
#!/bin/bash
#
# Script description
#

set -e  # Exit on error
set -u  # Exit on undefined variable (optional)
set -o pipefail  # Exit on pipe failure (optional)

# Use quotes around variables
echo "$MY_VAR"

# Check if command exists
if ! command -v oc &> /dev/null; then
    echo "oc not found"
    exit 1
fi

# Validate arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <arg>"
    exit 1
fi
```

### Writing OpenShift manifests

**Follow conventions:**

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
  namespace: my-namespace
  labels:
    app: my-app
    version: v1
data:
  config.yaml: |
    # Keep lines under 120 characters
    key: value
```

### Pull Request Guidelines

**Good PR:**
- ✅ Small, focused changes
- ✅ Clear title and description
- ✅ All CI checks passing
- ✅ Addresses one concern

**Bad PR:**
- ❌ 100+ files changed
- ❌ Multiple unrelated changes
- ❌ No description
- ❌ Failing CI checks

---

## CI/CD Metrics

### Pipeline Performance

**Average Execution Times:**

| Workflow | Duration | Cost (GitHub Actions) |
|----------|----------|----------------------|
| YAML Validation | ~2 minutes | ~$0.01 |
| Shell Testing | ~3 minutes | ~$0.02 |
| PR Validation | ~5 minutes | ~$0.03 |

**Monthly Costs (estimated):**
- 100 PRs/month: ~$3
- 500 commits/month: ~$10

### Success Rates

**Target Metrics:**
- First-time pass rate: > 80%
- Mean time to fix: < 10 minutes
- False positive rate: < 5%

**Track with:**

```bash
# Check recent workflow runs
gh run list --workflow=pr-validation.yml --limit 50

# View failure reasons
gh run list --workflow=pr-validation.yml --status=failure
```

---

## Advanced Configuration

### Custom Workflow Triggers

**Run on specific paths only:**

```yaml
on:
  push:
    paths:
      - 'critical-scripts/**'
      - '!docs/**'  # Exclude docs
```

**Run on schedule:**

```yaml
on:
  schedule:
    - cron: '0 2 * * 1'  # Monday at 2 AM UTC
```

### Matrix Builds

**Test across multiple versions:**

```yaml
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, ubuntu-20.04]
        shell: [bash, zsh]
    runs-on: ${{ matrix.os }}
    steps:
      - name: Test script
        shell: ${{ matrix.shell }}
        run: ./scripts/test.sh
```

### Secrets Management

**Store credentials securely:**

```yaml
# GitHub Settings → Secrets → Actions

jobs:
  deploy:
    steps:
      - name: Login to OpenShift
        run: |
          oc login --token=${{ secrets.OPENSHIFT_TOKEN }} \
            --server=${{ secrets.OPENSHIFT_SERVER }}
```

---

## Future Enhancements

### Planned Features

**Phase 1 (Q2 2026):**
- [ ] Automated deployment to staging environment
- [ ] Integration tests on PR
- [ ] Code coverage reporting

**Phase 2 (Q3 2026):**
- [ ] Automated DR drill testing
- [ ] Performance regression testing
- [ ] Dependency vulnerability scanning

**Phase 3 (Q4 2026):**
- [ ] GitOps with ArgoCD integration
- [ ] Automated rollback on failure
- [ ] Canary deployments

---

## References

- **GitHub Actions Docs:** https://docs.github.com/en/actions
- **ShellCheck Wiki:** https://github.com/koalaman/shellcheck/wiki
- **Pre-commit Hooks:** https://pre-commit.com/
- **Kubeval:** https://kubeval.instrumenta.dev/
- **Yamllint:** https://yamllint.readthedocs.io/

---

## Support

**Issues with CI/CD:**
- Check workflow logs in GitHub Actions tab
- Review this documentation
- Create issue in repository

**Feature Requests:**
- Open GitHub issue with label `enhancement`
- Describe use case and expected behavior

**Emergency Bypass:**

```bash
# Only use in true emergencies
git commit --no-verify -m "Emergency production fix"

# Create follow-up PR to fix validation issues
```

---

## Change Log

| Date | Version | Change | Author |
|------|---------|--------|--------|
| 2026-03-31 | 1.0 | Initial CI/CD pipeline implementation | DevOps Automation Engineer |

---

**Pipeline Status:** ✅ Active and monitoring all commits
