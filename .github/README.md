# GitHub Actions Workflows

This directory contains CI/CD workflows for the EDB_Testing repository.

## Workflows

### 1. YAML Validation (`yaml-validation.yml`)

Validates all OpenShift manifests and Kustomize configurations.

**Triggers:**
- Push to `main` or `develop`
- Pull requests changing `.yaml` or `.yml` files

**Jobs:**
- `yaml-lint`: Runs yamllint for syntax and style
- `kubeval`: Validates OpenShift / declarative resource schema compliance
- `kustomize-build`: Tests kustomize builds
- `summary`: Aggregates results

### 2. Shell Script Testing (`shell-script-testing.yml`)

Tests all bash scripts for quality and correctness.

**Triggers:**
- Push to `main` or `develop`
- Pull requests changing `.sh` files or `scripts/` directory

**Jobs:**
- `shellcheck`: Lints scripts with ShellCheck
- `syntax-check`: Validates bash syntax
- `script-permissions`: Checks executable permissions
- `script-standards`: Verifies best practices (shebang, set -e)
- `unit-tests`: Runs BATS tests if available
- `summary`: Aggregates results

### 3. PR Validation (`pr-validation.yml`)

Comprehensive validation for pull requests before merge.

**Triggers:**
- Pull request opened, synchronized, or reopened

**Jobs:**
- `pr-info`: Displays PR metadata
- `changed-files`: Detects which file types changed
- `yaml-validation`: Runs if YAML files changed
- `shell-validation`: Runs if scripts changed
- `security-scan`: Always runs (secrets, credentials)
- `docs-validation`: Runs if markdown changed
- `pr-size-check`: Warns on large PRs
- `summary`: Aggregates all results

## Running Locally

Install dependencies:

```bash
# Python tools
pip install yamllint pre-commit

# ShellCheck
brew install shellcheck  # macOS
apt-get install shellcheck  # Ubuntu

# Kubeval
wget https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz
tar xf kubeval-linux-amd64.tar.gz
sudo mv kubeval /usr/local/bin/

# Kustomize
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/
```

Run checks manually:

```bash
# YAML validation
yamllint .
find . -name "*.yaml" -exec kubeval --strict {} \;

# Shell script testing
find . -name "*.sh" -exec shellcheck {} \;
find . -name "*.sh" -exec bash -n {} \;

# Or use pre-commit
pre-commit run --all-files
```

## Configuration Files

- `.yamllint` - YAML linting rules (created by workflow)
- `.markdownlint.json` - Markdown linting rules
- `.pre-commit-config.yaml` - Pre-commit hook configuration
- `.secrets.baseline` - Secret detection baseline

## Workflow Status

Check status badges (add to main README.md):

```markdown
![YAML Validation](https://github.com/YOUR_ORG/EDB_Testing/workflows/YAML%20Validation/badge.svg)
![Shell Testing](https://github.com/YOUR_ORG/EDB_Testing/workflows/Shell%20Script%20Testing/badge.svg)
```

## Troubleshooting

**Workflow fails but passes locally:**
- Check tool versions match
- Ensure all files are committed
- Review workflow logs in Actions tab

**Too many false positives:**
- Adjust severity levels in workflow files
- Add exclusions to yamllint/shellcheck configs
- Update `.secrets.baseline` for false secret detections

## References

- [CI/CD Pipeline Documentation](../docs/cicd-pipeline.md)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
