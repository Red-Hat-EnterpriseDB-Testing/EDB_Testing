# Contributing to EDB_Testing

Thank you for your interest in contributing to the AAP with EnterpriseDB PostgreSQL Multi-Datacenter project!

## Table of Contents

- [Getting Started](#getting-started)
- [Documentation Standards](#documentation-standards)
- [Code Standards](#code-standards)
- [Testing Requirements](#testing-requirements)
- [Pull Request Process](#pull-request-process)
- [Commit Message Guidelines](#commit-message-guidelines)
- [Development Workflow](#development-workflow)

---

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- Git configured on your machine
- Python 3.11+ (for pre-commit hooks)
- Access to an OpenShift cluster (for testing manifests)
- Basic understanding of PostgreSQL, Ansible Automation Platform, and Kubernetes

### Initial Setup

1. **Fork and clone the repository:**
   ```bash
   git clone https://github.com/your-username/EDB_Testing.git
   cd EDB_Testing
   ```

2. **Install pre-commit hooks:**
   ```bash
   pip install pre-commit
   pre-commit install
   ```

3. **Review the documentation:**
   - [Documentation Index](docs/INDEX.md) - Complete documentation navigation
   - [Architecture](README.md#architecture) - System overview
   - [CI/CD Pipeline](docs/cicd-pipeline.md) - Automated testing workflows

---

## Documentation Standards

### File Naming

- Use lowercase with hyphens: `my-document.md`
- Place in appropriate directory:
  - `/docs/` for general documentation
  - `/aap-deploy/` for AAP deployment docs
  - `/db-deploy/` for database deployment docs
  - `/scripts/` for script documentation

### Formatting

**Headings:**
- Use `#` for title (one per document)
- Use `##` for major sections
- Use `###` for subsections
- Maximum depth: `####` (avoid deeper nesting)

**Code Blocks:**
```markdown
```bash
# Use language tags for syntax highlighting
kubectl get pods -n edb-postgres
\```
```

**Preferred language tags:**
- `bash` - Shell commands
- `yaml` - Kubernetes manifests
- `sql` - Database queries
- `python` - Python scripts
- `json` - JSON data

**Cross-References:**
- Use relative paths: `[Link Text](../path/to/file.md)`
- Never use absolute paths: ~~`[Link](/Users/...)`~~
- Link to sections: `[Section](#section-name)`

**Consistency:**
- PostgreSQL (not "Postgres" or "postgres")
- OpenShift (not "OCP" except in context)
- Ansible Automation Platform (AAP) - use abbreviation after first mention
- Datacenter (one word, not "data center")
- DC1 / DC2 (datacenter naming)

### Table of Contents

Add TOC to documents > 200 lines:

```markdown
## Table of Contents

- [Section 1](#section-1)
- [Section 2](#section-2)
```

### Documentation Checklist

- [ ] File named with lowercase and hyphens
- [ ] TOC included (if > 200 lines)
- [ ] Cross-references use relative paths
- [ ] Code blocks have language tags
- [ ] Terminology consistent (PostgreSQL, AAP, etc.)
- [ ] No absolute file paths in examples
- [ ] Tested commands work as documented
- [ ] Updated [INDEX.md](docs/INDEX.md) if adding new documentation

---

## Code Standards

### Shell Scripts

**Requirements:**
- Shebang: `#!/bin/bash`
- Set error handling: `set -euo pipefail`
- Executable permissions: `chmod +x script.sh`

**Style:**
- Use descriptive variable names: `DB_NAMESPACE` not `ns`
- Quote variables: `"$VAR"` not `$VAR`
- Use functions for repeated logic
- Add usage/help message
- Comment complex sections

**Example:**
```bash
#!/bin/bash
#
# Description: Brief description of script purpose
#
# Usage: ./script-name.sh <arg1> <arg2>
#

set -euo pipefail

# Configuration
DB_NAMESPACE="${1:-edb-postgres}"

# Function: Check prerequisites
check_prerequisites() {
    if ! command -v oc &> /dev/null; then
        echo "❌ Error: oc command not found"
        exit 1
    fi
}

# Main execution
main() {
    check_prerequisites
    echo "✓ Prerequisites validated"
}

main "$@"
```

**Validation:**
- Must pass ShellCheck (SC2148, SC1091 excluded)
- Syntax validated: `bash -n script.sh`
- Executable: `test -x script.sh`

### YAML Manifests

**Requirements:**
- Indentation: 2 spaces (no tabs)
- Line length: ≤ 120 characters
- Valid Kubernetes schema (kubeval)
- Kustomize buildable (if in Kustomize directory)

**Style:**
- Consistent resource naming: `kebab-case`
- Namespace specified unless default intended
- Labels for resource organization
- Comments for non-obvious configuration

**Example:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgresql-rw
  namespace: edb-postgres
  labels:
    app: postgresql
    role: primary
spec:
  type: ClusterIP
  selector:
    cnpg.io/cluster: postgresql
    role: primary
  ports:
    - port: 5432
      targetPort: 5432
      name: postgres
```

**Validation:**
- yamllint passes (see [.yamllint](.yamllint) config)
- kubeval validates schema
- kustomize build succeeds (if applicable)

---

## Testing Requirements

### Pre-Commit Validation

All contributions must pass pre-commit hooks:

```bash
pre-commit run --all-files
```

**Hooks include:**
- Trailing whitespace removal
- YAML syntax validation
- Shell script checking (ShellCheck)
- Markdown linting
- Secret detection
- Kubernetes manifest validation

### Script Testing

**For new or modified scripts:**

1. **Syntax validation:**
   ```bash
   bash -n scripts/your-script.sh
   ```

2. **ShellCheck:**
   ```bash
   shellcheck scripts/your-script.sh
   ```

3. **Functional testing:**
   - Test on local OpenShift (CRC) if possible
   - Document test results in PR description
   - Include example output

4. **Cross-platform compatibility:**
   - Test on Linux (RHEL 9 preferred)
   - Test on macOS (if applicable)
   - Use Python fallbacks for OS-specific commands (e.g., `date`)

### Kubernetes Manifest Testing

**For new or modified manifests:**

1. **Schema validation:**
   ```bash
   kubeval --strict manifest.yaml
   ```

2. **Kustomize build:**
   ```bash
   cd db-deploy/sample-cluster
   kustomize build base/
   ```

3. **Deployment validation:**
   - Test on development cluster
   - Verify resources created
   - Check pod status
   - Validate functionality

### Documentation Testing

**For new or modified documentation:**

1. **Link validation:**
   - All cross-references work
   - External links accessible
   - No broken anchors

2. **Command validation:**
   - Commands execute successfully
   - Output matches documentation
   - Examples copyable (no special characters)

3. **Readability:**
   - Technical accuracy verified
   - Grammar and spelling checked
   - Clear and concise

---

## Pull Request Process

### Before Submitting

- [ ] Code/docs tested locally
- [ ] Pre-commit hooks pass
- [ ] Commits follow message guidelines
- [ ] PR description complete
- [ ] Related issue referenced (if applicable)

### PR Title Format

```
<type>: <brief description>

Examples:
feat: Add PITR restore script
fix: Correct split-brain prevention logic
docs: Update DR testing guide
refactor: Simplify AAP scaling logic
test: Add component tests for measure-rto-rpo.sh
```

**Types:**
- `feat` - New feature or capability
- `fix` - Bug fix
- `docs` - Documentation changes
- `refactor` - Code refactoring (no functionality change)
- `test` - Adding or updating tests
- `chore` - Maintenance tasks (dependencies, CI/CD)

### PR Description Template

```markdown
## Description
Brief description of changes and motivation.

## Changes Made
- Bullet list of specific changes
- Include file paths for major changes
- Note any breaking changes

## Testing
How was this tested?
- [ ] Local testing on CRC
- [ ] Integration testing on dev cluster
- [ ] Pre-commit hooks passed
- [ ] CI/CD pipeline green

## Related Issues
Closes #123
Relates to #456

## Checklist
- [ ] Documentation updated
- [ ] Tests pass
- [ ] No breaking changes (or documented)
- [ ] INDEX.md updated (if new docs)
```

### Review Process

1. **Automated Checks:**
   - GitHub Actions workflows must pass
   - All CI/CD checks green

2. **Manual Review:**
   - Minimum 1 approval required
   - Focus areas:
     - Code quality and standards
     - Security implications
     - Documentation accuracy
     - Breaking changes

3. **Merge:**
   - Squash and merge (default)
   - Rebase for feature branches (if requested)
   - Delete branch after merge

---

## Commit Message Guidelines

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Examples

**Simple commit:**
```
docs: Add security hardening guide

Created comprehensive security documentation covering TLS, RBAC,
secrets management, and audit logging for production deployments.
```

**Commit with scope:**
```
fix(scripts): Resolve macOS date compatibility in measure-rto-rpo.sh

BSD date doesn't support %3N for milliseconds. Added Python fallback
for cross-platform millisecond precision timestamps.

Fixes #789
```

**Breaking change:**
```
feat(db-deploy): Update PostgreSQL to version 17

BREAKING CHANGE: PostgreSQL 17 requires manual upgrade from v16.
See docs/migration-guide.md for upgrade procedures.

Closes #123
```

### Subject Line

- Use imperative mood: "Add" not "Added" or "Adds"
- No period at the end
- Max 72 characters
- Lowercase after type prefix

### Body

- Explain *what* and *why*, not *how*
- Wrap at 72 characters
- Separate from subject with blank line
- Can include multiple paragraphs

### Footer

- Reference issues: `Closes #123`, `Fixes #456`, `Relates to #789`
- Note breaking changes: `BREAKING CHANGE: description`

---

## Development Workflow

### Feature Development

1. **Create feature branch:**
   ```bash
   git checkout -b feature/my-feature
   ```

2. **Make changes:**
   - Follow code and documentation standards
   - Commit frequently with clear messages
   - Test as you go

3. **Before pushing:**
   ```bash
   pre-commit run --all-files
   ```

4. **Push and create PR:**
   ```bash
   git push origin feature/my-feature
   ```

5. **Address review feedback:**
   - Make requested changes
   - Push additional commits
   - Respond to comments

6. **Merge:**
   - PR approved and checks pass
   - Squash and merge
   - Delete branch

### Bug Fixes

1. **Create bug fix branch:**
   ```bash
   git checkout -b fix/bug-description
   ```

2. **Reproduce bug:**
   - Verify issue exists
   - Document reproduction steps

3. **Fix and test:**
   - Implement fix
   - Add test if possible
   - Verify fix works

4. **PR process:**
   - Reference issue in PR
   - Include before/after behavior
   - Document testing

### Documentation Updates

1. **Create docs branch:**
   ```bash
   git checkout -b docs/topic-name
   ```

2. **Update documentation:**
   - Follow documentation standards
   - Update INDEX.md if adding new docs
   - Verify cross-references

3. **Test documentation:**
   - Commands work as documented
   - Links resolve correctly
   - Grammar and spelling checked

---

## Quick Reference

### Pre-Commit Checks
```bash
pre-commit run --all-files
```

### Run Specific Hook
```bash
pre-commit run <hook-id> --all-files
```

### Validate YAML
```bash
yamllint db-deploy/sample-cluster/base/cluster.yaml
```

### Validate Shell Script
```bash
shellcheck scripts/my-script.sh
```

### Validate Kubernetes Manifest
```bash
kubeval --strict manifest.yaml
```

### Build Kustomize
```bash
kustomize build db-deploy/sample-cluster/base/
```

### Generate TOC (for Markdown)
```bash
# Use VS Code extension: Markdown All in One
# Or manually create based on headings
```

---

## Getting Help

**Questions or issues?**
- See [Documentation Index](docs/INDEX.md)
- Check [Troubleshooting Guide](docs/troubleshooting.md)
- Review [CI/CD Pipeline Docs](docs/cicd-pipeline.md)
- Ask in GitHub Discussions _(if enabled)_

**Found a bug?**
- Check existing issues
- Create new issue with:
  - Clear description
  - Reproduction steps
  - Expected vs actual behavior
  - Environment details

**Have a feature idea?**
- Open feature request issue
- Describe use case
- Explain expected behavior
- Consider implementation approach

---

## Code of Conduct

**Be respectful:**
- Treat all contributors with respect
- Provide constructive feedback
- Focus on the code, not the person

**Be collaborative:**
- Help others learn and grow
- Share knowledge and expertise
- Acknowledge contributions

**Be professional:**
- Keep discussions on-topic
- Use clear and concise language
- Maintain project quality standards

---

## License

By contributing to this project, you agree that your contributions will be licensed under the same license as the project.

See [LICENSE](LICENSE) for details.

---

## Thank You!

Your contributions help improve this project for everyone. We appreciate your time and effort!

**Additional Resources:**
- [Documentation Audit Report](docs/documentation-audit-report.md) - Current documentation status
- [DR Testing Guide](docs/dr-testing-guide.md) - Comprehensive DR testing framework
- [CI/CD Pipeline](docs/cicd-pipeline.md) - Automated workflows
- [Architecture](README.md#architecture) - System design

---

**Last Updated:** 2026-03-31
**Maintainers:** SRE Team
**Questions:** Open an issue or discussion
