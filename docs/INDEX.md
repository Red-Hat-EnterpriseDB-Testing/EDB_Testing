# Documentation Index

**Repository:** EDB_Testing - AAP with EnterpriseDB PostgreSQL Multi-Datacenter
**Last Updated:** 2026-03-31
**Documentation Version:** 1.0

---

## Quick Start

**New to this repository?** Start here:

1. **[Quick Start Guide](quick-start-guide.md)** ⭐ **START HERE** - OpenShift/RHEL deployment (15-30 min)
2. **[AAP Containerized Quick Start](aap-containerized-quickstart.md)** ⭐ **NEW** - Multi-DC DR deployment (30-60 min planning)
3. **[Main README](../README.md)** - Architecture overview and table of contents
4. **[Deployment Guides](#deployment-guides)** - Detailed deployment methods
5. **[DR Testing Guide](dr-testing-guide.md)** - Complete testing framework

**Quick deployment paths:**
- **OpenShift (15 min):** [Quick Start Guide - OpenShift](quick-start-guide.md#quick-start-openshift-15-minutes)
- **RHEL with TPA (20 min):** [Quick Start Guide - RHEL](quick-start-guide.md#quick-start-rhel-with-tpa-20-minutes)
- **AAP Containerized Growth (30 min):** [AAP Containerized Quick Start - Growth](aap-containerized-quickstart.md#growth-topology-deployment)
- **AAP Containerized Enterprise (30 min):** [AAP Containerized Quick Start - Enterprise](aap-containerized-quickstart.md#enterprise-topology-deployment)
- **Local testing (30 min):** [Quick Start Guide - CRC](quick-start-guide.md#quick-start-local-testing-with-crc-30-minutes)

**Need to perform a DR drill?**
- **[DR Testing Guide](dr-testing-guide.md)** - Complete testing framework
- **[DR Scenarios](dr-scenarios.md)** - 6 documented failure scenarios

---

## Documentation by Topic

### 🚀 Deployment Guides

**Choose your deployment method:**

| Platform | Guide | Description |
|----------|-------|-------------|
| **RHEL / Bare Metal** | [TPA Deployment](install-tpa.md) ⭐ **RECOMMENDED** | Automated deployment with Trusted Postgres Architect |
| **RHEL Manual** | [RHEL Manual Install](install-rhel-manual.md) | Traditional VM-based installation |
| **OpenShift** | [OpenShift Manual Install](install-kubernetes-manual.md) | Operator-based deployment on OpenShift |
| **OpenShift (Kustomize)** | [Database Deployment](../db-deploy/README.md) | GitOps-friendly Kustomize manifests |
| **AAP on OpenShift** | [AAP Deployment](../aap-deploy/README.md) | AAP operator with external PostgreSQL |

**Automated Infrastructure Provisioning:**
- [AWS Multi-Region Playbooks](../playbooks/PLAYBOOK-OVERVIEW.md) ⭐ **NEW** - Automated AWS provisioning (us-east-1/us-west-1 with RDS)
- [AWS Provisioning Guide](../playbooks/README-aws-provisioning.md) - Detailed guide for AWS deployment

**Specialized Deployment Topics:**
- [EDB Operator Installation](../db-deploy/olm-openshift/README.md) - CloudNativePG operator via OLM
- [Cross-Cluster Replication](../db-deploy/cross-cluster/README.md) - DC1 → DC2 streaming replication
- [AAP OpenShift Manifests](../aap-deploy/openshift/README.md) - Subscription and AnsibleAutomationPlatform CR
- [AAP Deployment Reference](aap-components-reference.md) ⭐ **NEW** - Database setup, verification, troubleshooting (Gateway, Controller, Hub, EDA)
- [EDB Operator Smoke Test](openshift-edb-operator-smoke-test.md) - Validation procedures

---

### 🏗️ Architecture

**Understanding the system:**

| Document | Description | Read Time |
|----------|-------------|-----------|
| **[Architecture Overview](architecture.md)** ⭐ **COMPREHENSIVE** | Complete architecture documentation | 45 min |
| **[Main README Architecture](../README.md#architecture)** | High-level overview with diagram | 5 min |
| **[AAP Containerized Growth DR](aap-containerized-growth-dr-architecture.md)** ⭐ **NEW** | 3-node multi-DC deployment (cost-optimized) | 25 min |
| **[AAP Containerized Enterprise DR](aap-containerized-enterprise-dr-architecture.md)** ⭐ **NEW** | 8-node multi-DC deployment (production-grade) | 30 min |
| **[Architecture Validation Report](../reports/aap-architecture-validation-report.md)** | Validation vs Red Hat AAP 2.6 tested models | 15 min |
| **[RHEL AAP Architecture](rhel-aap-architecture.md)** | AAP on RHEL with systemd services | 10 min |
| **[OpenShift AAP Architecture](openshift-aap-architecture.md)** | AAP on OpenShift with operator | 10 min |

**[Architecture Overview](architecture.md)** covers:
- Component details (GLB, AAP, PostgreSQL clusters)
- Network connectivity and data flow (writes, reads, backups)
- Replication topology (streaming + WAL archiving)
- Datacenter configurations (DC1 active, DC2 passive)
- Scaling strategies (horizontal, vertical, geographic)
- Backup and restore architecture

**AAP Containerized Deployment Models:**

Choose based on your requirements:

| Topology | VMs | Best For | RTO | Cost |
|----------|-----|----------|-----|------|
| **[Growth](aap-containerized-growth-dr-architecture.md)** | 16 total (3 AAP/DC) | Small-medium, budget-conscious | < 5 min | Lower |
| **[Enterprise](aap-containerized-enterprise-dr-architecture.md)** | 26 total (8 AAP/DC) | Production-critical, high-scale | < 5 min | Higher |

**Architecture Decisions:**
- Active-Passive topology (DC1 primary, DC2 standby)
- Physical streaming replication + WAL archiving to S3
- CloudNativePG operator (OpenShift) or EDB Postgres Advanced (RHEL)
- EDB Failover Manager (EFM) for automated database failover
- Global Load Balancer for traffic management and health-based routing

---

### 🔄 Disaster Recovery

**DR Planning and Testing:**

| Document | Purpose | Read Time |
|----------|---------|-----------|
| **[DR Scenarios](dr-scenarios.md)** | 6 documented failure scenarios | 15 min |
| **[DR Testing Guide](dr-testing-guide.md)** | Complete testing framework (10,000+ words) | 45 min |
| **[DR Testing Implementation Summary](dr-testing-implementation-summary.md)** | Implementation details and metrics | 10 min |
| **[Split-Brain Prevention](split-brain-prevention.md)** | Database role validation and fencing | 15 min |
| **[EDB Failover Manager](enterprisefailovermanager.md)** | EFM integration and configuration | 20 min |

**DR Validation Reports:**
- [DR Replication Validation](../reports/dr-replication-validation-report.md) - Architecture assessment (Score: 7.1/10)
- [DR Replication Implementation Status](dr-replication-implementation-status.md) - Gap tracking
- [Component Testing Results](component-testing-results.md) - Script validation on macOS/CRC
- [AAP Deployment Validation (CRC)](aap-deployment-validation-crc.md) - Local OpenShift testing

**DR Scripts:**
- See [Operational Scripts](#-operational-scripts) section below

---

### ⚙️ Operations

**Day-to-day operations:**

- **[Operations Runbook](manual-scripts-doc.md)** - AAP cluster management procedures
- **[AAP Deployment Reference](aap-components-reference.md)** ⭐ **NEW** - Deployment verification, troubleshooting, scaling
- **[Script Reference](../scripts/README.md)** - All automation scripts documented
- **[Troubleshooting Guide](troubleshooting.md)** - Common issues and diagnostics
- **[EDB Failover Manager](enterprisefailovermanager.md)** - EFM integration and VIP management

**Key Operational Tasks:**
- Scaling AAP up/down: See [scale-aap-up.sh](../scripts/scale-aap-up.sh), [scale-aap-down.sh](../scripts/scale-aap-down.sh)
- Monitoring replication: See [monitor-efm-scripts.sh](../scripts/monitor-efm-scripts.sh)
- DR failover: See [efm-orchestrated-failover.sh](../scripts/efm-orchestrated-failover.sh)
- Data validation: See [validate-aap-data.sh](../tests/scripts/validate-aap-data.sh)

---

### 📜 Operational Scripts

**All scripts located in [`/scripts/`](../scripts/):**

| Script | Purpose | Usage |
|--------|---------|-------|
| **[scale-aap-up.sh](../scripts/scale-aap-up.sh)** | Scale AAP to operational state | `./scale-aap-up.sh <dc1\|dc2>` |
| **[scale-aap-down.sh](../scripts/scale-aap-down.sh)** | Scale AAP to zero (DR prep) | `./scale-aap-down.sh <dc1\|dc2>` |
| **[efm-orchestrated-failover.sh](../scripts/efm-orchestrated-failover.sh)** | Full DR failover orchestration | Called by EFM (post-promotion) |
| **[efm-aap-failover-wrapper.sh](../scripts/efm-aap-failover-wrapper.sh)** | EFM integration hook | Called by EFM with failover context |
| **[monitor-efm-scripts.sh](../scripts/monitor-efm-scripts.sh)** | Monitor EFM failover events | `./monitor-efm-scripts.sh` (CronJob) |
| **[dr-failover-test.sh](../tests/scripts/dr-failover-test.sh)** | Automated DR testing framework | See [DR Testing Guide](dr-testing-guide.md) |
| **[validate-aap-data.sh](../tests/scripts/validate-aap-data.sh)** | AAP data integrity validation | `./validate-aap-data.sh <dc1\|dc2>` |
| **[measure-rto-rpo.sh](../tests/scripts/measure-rto-rpo.sh)** | RTO/RPO measurement with milestones | `./measure-rto-rpo.sh start <test-id>` |
| **[generate-dr-report.sh](../tests/scripts/generate-dr-report.sh)** | DR test report generation | `./generate-dr-report.sh <test-id>` |

**Script Documentation:**
- **[Scripts README](../scripts/README.md)** ⭐ - Quick reference for all scripts
- **[Scripts Guide](scripts-guide.md)** - Comprehensive usage guide
- **[Scripts Library Reference](scripts-library-reference.md)** - Shared library functions API
- **[Scripts Hooks and CI/CD](scripts-hooks-and-cicd.md)** - Pre-commit hooks and quality automation
- **[Manual Scripts Doc](manual-scripts-doc.md)** - Operations runbook

---

### 🔒 Development & CI/CD

**Contributing and automation:**

- **[CI/CD Pipeline](cicd-pipeline.md)** - GitHub Actions workflows (6,500 words)
- **[Scripts Hooks and CI/CD](scripts-hooks-and-cicd.md)** ⭐ **NEW** - Pre-commit hooks, CI checks, and quality automation
- **[Pre-commit Hooks](../.pre-commit-config.yaml)** - Local validation before commit
- **CONTRIBUTING.md** - _Coming soon_ (see [Documentation Audit](../reports/documentation-audit-report.md))

**GitHub Actions Workflows:**
- `.github/workflows/yaml-validation.yml` - Kubernetes manifest validation
- `.github/workflows/shell-script-testing.yml` - Bash script testing
- `.github/workflows/pr-validation.yml` - PR validation and security scanning

**Testing:**
- [Component Testing Results](component-testing-results.md) - Script validation (macOS/CRC)
- [AAP Deployment Validation](aap-deployment-validation-crc.md) - End-to-end validation
- [run-ci-checks-locally.sh](../tests/scripts/run-ci-checks-locally.sh) - Run CI checks before pushing

---

### 📊 Monitoring & Observability

**Visibility and alerting:**

- [DR Testing Guide - Monitoring Section](dr-testing-guide.md#monitoring-integration) - CronJob-based DR testing
- [EDB Operator Metrics](install-kubernetes-manual.md#monitoring) - Prometheus ServiceMonitor
- [Split-Brain Prevention](split-brain-prevention.md#monitoring) - Database role monitoring

**Planned Documentation:**
- Monitoring and Alerting Guide (see [Documentation Audit](../reports/documentation-audit-report.md#gap-analysis))
- Grafana Dashboard Setup
- PagerDuty Integration

---

### 🔐 Security

**Security considerations:**

- [Pre-commit Secret Detection](../.pre-commit-config.yaml#L89-L98) - `detect-secrets` integration
- [RBAC Configuration](../tests/openshift/dr-testing/serviceaccount.yaml) - DR testing ServiceAccount
- [EFM Security](enterprisefailovermanager.md#security) - EFM permissions and VIP management

**Planned Documentation:**
- Security Hardening Guide (see [Documentation Audit](../reports/documentation-audit-report.md#gap-analysis))
- TLS/SSL Configuration
- Secrets Management (Vault, Sealed Secrets)

---

### 📦 Reference Materials

**Additional resources:**

- **[Documentation Audit Report](../reports/documentation-audit-report.md)** - Comprehensive documentation assessment
- **[Glossary](GLOSSARY.md)** - _Coming soon_ - Terminology and abbreviations
- **[FAQ](FAQ.md)** - _Coming soon_ - Frequently asked questions
- **[LICENSE](../LICENSE)** - Copyright and licensing

**External Links:**
- [EnterpriseDB TPA Documentation](https://www.enterprisedb.com/docs/tpa/latest/)
- [CloudNativePG Operator](https://cloudnative-pg.io/)
- [AAP Documentation](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/)

---

## Documentation by Deployment Type

### RHEL / Bare Metal Deployment

**Recommended Path:**
1. [TPA Deployment Guide](install-tpa.md) - Automated deployment ⭐
2. [RHEL AAP Architecture](rhel-aap-architecture.md) - Reference architecture
3. [EDB Failover Manager](enterprisefailovermanager.md) - EFM setup
4. [Operations Runbook](manual-scripts-doc.md) - Day-to-day operations

**Alternative:**
- [RHEL Manual Install](install-rhel-manual.md) - Manual installation

### OpenShift Deployment

**Recommended Path:**
1. [Database Deployment (Kustomize)](../db-deploy/README.md) - Deploy PostgreSQL ⭐
2. [AAP Deployment](../aap-deploy/README.md) - Deploy AAP with external database
3. [OpenShift AAP Architecture](openshift-aap-architecture.md) - Reference architecture
4. [Cross-Cluster Replication](../db-deploy/cross-cluster/README.md) - Setup DC1 → DC2 replication
5. [DR Testing Guide](dr-testing-guide.md) - Test failover procedures

**Alternative:**
- [OpenShift Manual Install](install-kubernetes-manual.md) - Step-by-step manual deployment

**Validation:**
- [EDB Operator Smoke Test](openshift-edb-operator-smoke-test.md)
- [AAP Deployment Validation](aap-deployment-validation-crc.md)

---

## Documentation by Audience

### 🎯 SRE / Operations Team

**Essential Reading:**
1. [DR Scenarios](dr-scenarios.md) - Understand failure modes
2. [Operations Runbook](manual-scripts-doc.md) - Day-to-day procedures
3. [DR Testing Guide](dr-testing-guide.md) - Quarterly drill procedures
4. [Troubleshooting Guide](troubleshooting.md) - Issue resolution
5. [Scripts README](../scripts/README.md) - Automation tools

### 🎯 Database Administrators

**Essential Reading:**
1. [Install TPA](install-tpa.md) - Automated PostgreSQL deployment
2. [EDB Operator](../db-deploy/olm-openshift/README.md) - CloudNativePG operator
3. [Cross-Cluster Replication](../db-deploy/cross-cluster/README.md) - Replication setup
4. [EDB Failover Manager](enterprisefailovermanager.md) - EFM integration
5. [Split-Brain Prevention](split-brain-prevention.md) - Database safety

### 🎯 Platform Engineers

**Essential Reading:**
1. [Main README](../README.md) - Architecture overview
2. [OpenShift AAP Architecture](openshift-aap-architecture.md) - Platform design
3. [CI/CD Pipeline](cicd-pipeline.md) - Automation workflows
4. [Database Deployment](../db-deploy/README.md) - Kustomize manifests
5. [DR Testing Guide](dr-testing-guide.md) - Testing framework

### 🎯 Application Developers

**Essential Reading:**
1. [AAP Deployment Reference](aap-components-reference.md) - Deployment verification and troubleshooting
2. [AAP Deployment](../aap-deploy/README.md) - AAP usage and integration
3. [Red Hat AAP Documentation](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6) - Component capabilities and features
4. [Troubleshooting Guide](troubleshooting.md) - Common issues
5. [Main README](../README.md) - System architecture

---

## Documentation Status

| Status | Count | Description |
|--------|-------|-------------|
| ✅ Complete | 23 | Comprehensive, tested, up-to-date |
| ⚠️ Partial | 4 | Exists but needs expansion (security, monitoring) |
| ❌ Planned | 3 | Identified in audit, not yet created (GLOSSARY, FAQ, Migration Guide) |

**Recent Additions (2026-03-31 to 2026-04-03):**
- ✅ DR Testing Guide (10,000+ words)
- ✅ DR Testing Implementation Summary
- ✅ Component Testing Results
- ✅ Split-Brain Prevention Documentation
- ✅ CI/CD Pipeline Documentation
- ✅ Documentation Audit Report
- ✅ Documentation Index (this file)
- ✅ Contributing Guide (CONTRIBUTING.md)
- ✅ Scripts Library Reference (2026-04-03)
- ✅ Scripts Hooks and CI/CD Guide (2026-04-03)
- ✅ Scripts README reorganization (2026-04-03)
- ✅ AAP Deployment Reference (2026-04-03) - Deployment-specific configuration and troubleshooting

**Next Documentation Priorities:**
1. Security Hardening Guide (Week 2)
2. Monitoring and Alerting Guide (Week 3)
3. Backup and Restore Guide (Week 4)
4. GLOSSARY.md (Month 2)

See [Documentation Audit Report](../reports/documentation-audit-report.md) for complete roadmap.

---

## Getting Help

**For questions or issues:**
- See [Troubleshooting Guide](troubleshooting.md)
- Check [FAQ](FAQ.md) _(coming soon)_
- Review [GitHub Issues](https://github.com/your-org/EDB_Testing/issues) _(if applicable)_

**For contributions:**
- See [CONTRIBUTING.md](../CONTRIBUTING.md) _(coming soon)_
- Review [CI/CD Pipeline](cicd-pipeline.md) for testing requirements
- Ensure pre-commit hooks pass: `pre-commit run --all-files`

---

## Feedback

Documentation feedback welcome! Please:
- Open an issue for corrections or suggestions
- Submit a PR for improvements
- Contact SRE team for urgent documentation needs

**Last Documentation Review:** 2026-03-31
**Next Review:** 2026-06-30 (quarterly)

---

*This index is maintained by the SRE team. Auto-generated documentation should reference this index for consistency.*
