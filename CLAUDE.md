# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository provides a production-ready solution for deploying **Ansible Automation Platform (AAP)** with **EnterpriseDB PostgreSQL** in a **multi-datacenter Active/Passive configuration** for disaster recovery.

**Key capabilities:**
- Multi-datacenter HA/DR with automatic in-datacenter failover (RTO <1 min, RPO <5 sec)
- Cross-datacenter orchestrated failover (RTO <5 min)
- Comprehensive DR testing framework with automated RTO/RPO measurement
- Support for both OpenShift (operator-based) and RHEL (VM-based) deployments

**Primary use cases:**
- Enterprise AAP deployments requiring 99.9%+ availability
- DR planning and testing for PostgreSQL-backed automation platforms
- Multi-datacenter database replication patterns (physical streaming + WAL archiving)

## Architecture Context

**Topology:** Active (DC1) / Passive (DC2) multi-datacenter
- **DC1 (Primary):** Active AAP cluster + PostgreSQL primary cluster (3 nodes: 1 primary, 2 replicas)
- **DC2 (Standby):** Scaled-down AAP cluster + PostgreSQL replica cluster (async replication from DC1)
- **Replication:** Physical streaming replication + WAL archiving to S3
- **Failover:** EFM (EDB Failover Manager) for in-datacenter, orchestration scripts for cross-datacenter

**Deployment models:**
- **OpenShift:** CloudNativePG operator + AAP operator (containerized)
- **RHEL:** TPA (Trusted Postgres Architect) + AAP systemd services

See `docs/architecture.md` for complete details.

## Repository Structure

```
├── aap-deploy/           # AAP operator manifests (OpenShift)
│   └── openshift/        # Subscription, AnsibleAutomationPlatform CR
├── db-deploy/            # PostgreSQL operator manifests (OpenShift)
│   ├── operator/         # CloudNativePG operator via Kustomize
│   ├── sample-cluster/   # Base PostgreSQL cluster manifests
│   └── cross-cluster/    # DC1→DC2 replication setup
├── docs/                 # Comprehensive documentation (see docs/INDEX.md)
│   ├── INDEX.md          # Documentation index by topic
│   ├── quick-start-guide.md
│   ├── architecture.md
│   ├── dr-testing-guide.md
│   └── install-*.md      # Platform-specific deployment guides
├── scripts/              # Operational automation scripts
│   ├── lib/              # Shared libraries (logging, scaling)
│   ├── scale-aap-*.sh    # AAP scaling (OpenShift)
│   ├── dr-*.sh           # DR orchestration and testing
│   ├── validate-*.sh     # Validation and integrity checks
│   └── efm-*.sh          # EFM integration hooks
├── openshift/dr-testing/ # DR testing CronJob manifests
└── reports/              # Deployment validation reports
```

## Development Commands

### Pre-commit Validation

Always run before committing:
```bash
pre-commit run --all-files
```

Install hooks if not present:
```bash
pip install pre-commit
pre-commit install
```

### Testing and Validation

**YAML validation:**
```bash
yamllint -f colored .
```

**Shell script validation:**
```bash
shellcheck scripts/*.sh
bash -n scripts/your-script.sh  # Syntax check
```

**Kubernetes manifest validation:**
```bash
kubeval --strict --ignore-missing-schemas manifest.yaml
```

**Kustomize build:**
```bash
kustomize build db-deploy/sample-cluster/base/
kustomize build aap-deploy/openshift/
```

**Local CI checks:**
```bash
./scripts/run-ci-checks-locally.sh
```

### DR Testing

**Run automated DR failover test:**
```bash
./scripts/dr-failover-test.sh --dc1-context <dc1> --dc2-context <dc2>
```

**Measure RTO/RPO:**
```bash
./scripts/measure-rto-rpo.sh --dc1-context <dc1> --dc2-context <dc2>
```

**Validate AAP data integrity:**
```bash
./scripts/validate-aap-data.sh create-baseline <context>
./scripts/validate-aap-data.sh validate <context>
```

### AAP Cluster Management (OpenShift)

**Scale AAP up/down:**
```bash
./scripts/scale-aap-up.sh <cluster-context>
./scripts/scale-aap-down.sh <cluster-context>
```

## Code Standards and Conventions

### Shell Scripts

**Requirements:**
- Shebang: `#!/bin/bash`
- Error handling: `set -euo pipefail`
- Executable: `chmod +x script.sh`
- Quote all variables: `"$VAR"` not `$VAR`
- Use descriptive names: `DB_NAMESPACE` not `ns`
- Add usage/help message for user-facing scripts
- Source shared libraries: `source "$(dirname "$0")/lib/logging.sh"`

**Shared libraries:**
- `scripts/lib/logging.sh` - Standardized logging (log_info, log_error, log_success)
- `scripts/lib/aap-scaling.sh` - AAP scaling functions

### YAML Manifests

**Requirements:**
- Indentation: 2 spaces (no tabs)
- Line length: ≤120 characters
- Kubernetes resource naming: `kebab-case`
- Always specify namespace unless intentionally cluster-scoped
- Pass yamllint (see `.yamllint` for config)
- Pass kubeval schema validation
- Kustomize directories must have `kustomization.yaml`

### Documentation

**File naming:** lowercase with hyphens (`my-document.md`)

**Terminology consistency:**
- PostgreSQL (not "Postgres" in docs)
- Ansible Automation Platform (AAP) - use abbreviation after first mention
- OpenShift (not "OCP" except in context)
- Datacenter (one word)
- DC1/DC2 (datacenter naming)

**Cross-references:** Use relative paths (`[Link](../path/to/file.md)`)

**Update `docs/INDEX.md`** when adding new documentation

See `CONTRIBUTING.md` for complete standards.

## Platform-Specific Context

### OpenShift Deployments

**AAP 2.6 operator on OpenShift:**
- Deploys via `AnsibleAutomationPlatform` CR (parent resource)
- External PostgreSQL: use separate secrets for gateway/controller/hub/EDA
  - Gateway: `spec.database.database_secret`
  - Controller: `spec.controller.postgres_configuration_secret`
  - Hub: `spec.hub.postgres_configuration_secret`
  - EDA: `spec.eda.database.database_secret`
- Secret type: `type: unmanaged` with `host`, `port`, `database`, `username`, `password`
- Scaling all components to zero: set `idle_aap: true` on parent CR
- Use channel `stable-2.6` (namespace-scoped) or `stable-2.6-cluster-scoped`

**CloudNativePG operator:**
- Primary operator for PostgreSQL on OpenShift
- Install via OLM: `db-deploy/olm-openshift/`
- Cluster manifests: `db-deploy/sample-cluster/`
- Cross-cluster replication: `db-deploy/cross-cluster/`

**Tools required:**
- `oc` CLI with valid kubeconfig
- `kubectl` (optional, `oc` preferred)
- `kustomize` for manifest builds

### RHEL Deployments

**TPA (Trusted Postgres Architect):**
- Recommended automated deployment for RHEL/bare metal
- See `docs/install-tpa.md`

**AAP on RHEL:**
- Systemd service management: `scripts/start-aap-cluster.sh`, `scripts/stop-aap-cluster.sh`
- EFM integration: `scripts/efm-*.sh`

**Tools required:**
- Root/sudo access
- EDB Postgres Advanced Server subscription
- EFM 4.x for failover management

## Ansible Best Practices (redhat-cop)

When working with Ansible roles/playbooks in this repository:

**Variable naming:**
- Prefix role variables with role name: `foo_packages`, not `packages`
- Internal variables: prefix with `__` (e.g., `__foo_internal`)

**Idempotency:**
- All tasks must be idempotent
- Use `changed_when:` for `command`/`shell` modules
- Support check mode where possible

**Structure:**
- Keep playbooks simple (list of roles)
- Put logic in roles, not playbooks
- Use `vars/` for platform-specific data with `include_vars`
- Defaults in `defaults/main.yml`, static values in `vars/main.yml`

**Style:**
- `snake_case` for all names
- Task names in imperative mood: "Ensure service is running"
- Use bracket notation: `ansible_facts['distribution']`, not `ansible_distribution`
- Use FQCN for modules: `kubernetes.core.k8s`, `ansible.posix.synchronize`

See `.cursor/skills/ansible-redhat-cop-practices/` for complete guidelines.

## Working with DR Testing

**Key concepts:**
- **RTO (Recovery Time Objective):** Time to restore service (<1 min in-DC, <5 min cross-DC)
- **RPO (Recovery Point Objective):** Maximum data loss (<5 sec via streaming replication)
- **Split-brain prevention:** Fencing logic ensures only one primary active

**DR test workflow:**
1. Create baseline: `./scripts/validate-aap-data.sh create-baseline <dc1-context>`
2. Trigger failover: `./scripts/dr-failover-test.sh --dc1-context <dc1> --dc2-context <dc2>`
3. Measure metrics: `./scripts/measure-rto-rpo.sh` (tracks timestamps, calculates RTO/RPO)
4. Validate data: `./scripts/validate-aap-data.sh validate <dc2-context>`
5. Generate report: `./scripts/generate-dr-report.sh --latest`

**Automated testing:**
- OpenShift CronJob: `openshift/dr-testing/cronjob-dr-test.yaml`
- Results stored in PVC: `openshift/dr-testing/pvc-test-results.yaml`

See `docs/dr-testing-guide.md` for complete framework.

## CI/CD Workflows

GitHub Actions workflows (`.github/workflows/`):
- **pr-validation.yml** - YAML/shell/docs validation, security scanning, PR size check
- **yaml-validation.yml** - Standalone YAML validation
- **shell-script-testing.yml** - ShellCheck and syntax validation

**Pre-commit hooks** (`.pre-commit-config.yaml`):
- Trailing whitespace, YAML syntax, ShellCheck, markdownlint, secret detection
- Custom hooks: `hooks/check-script-permissions.sh`, `hooks/validate-openshift-manifests.sh`

## Common Tasks

**Deploy PostgreSQL on OpenShift:**
```bash
# Install CloudNativePG operator
oc apply -k db-deploy/olm-openshift/

# Deploy PostgreSQL cluster
oc apply -k db-deploy/sample-cluster/
```

**Deploy AAP on OpenShift:**
```bash
# Install AAP operator
oc apply -k aap-deploy/openshift/

# Verify deployment
oc get ansibleautomationplatform -n ansible-automation-platform
```

**Check PostgreSQL cluster status:**
```bash
oc get cluster -n edb-postgres
oc get pods -n edb-postgres -l cnpg.io/cluster=postgresql
```

**View AAP components:**
```bash
oc get pods -n ansible-automation-platform
oc get route -n ansible-automation-platform
```

**Trigger manual failover (in-datacenter):**
```bash
# PostgreSQL failover managed by CloudNativePG/EFM
# AAP scaling handled by scripts
./scripts/scale-aap-down.sh <dc1-context>
./scripts/scale-aap-up.sh <dc2-context>
```

## Important Notes

- **Never commit secrets** - Use `.example` files for templates (e.g., `postgres-configuration-secret.example.yaml`)
- **Test on CRC first** - Use local OpenShift (CodeReady Containers) for testing before production
- **DR drills are manual** - Cross-datacenter failover requires orchestration scripts, not automatic
- **EFM integration** - For RHEL deployments, EFM hooks in `scripts/efm-*.sh` coordinate AAP scaling
- **Baseline before DR tests** - Always create AAP data baseline before DR testing to validate integrity
- **HAProxy + PgBouncer** - See `docs/haproxy-pgbouncer-architectural-analysis.md` for connection pooling patterns

## Quick Reference Links

- **[Quick Start Guide](docs/quick-start-guide.md)** - 15-30 min deployment paths
- **[Documentation Index](docs/INDEX.md)** - Complete documentation organized by topic
- **[Architecture Details](docs/architecture.md)** - Comprehensive architecture documentation
- **[DR Testing Guide](docs/dr-testing-guide.md)** - Complete DR testing framework
- **[Scripts Reference](scripts/README.md)** - All automation scripts documented
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions
- **[Contributing Guide](CONTRIBUTING.md)** - Development standards and workflow
- **[Changelog](CHANGELOG.md)** - All notable changes to this project
