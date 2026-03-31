# AAP with EDB Postgres Multi-Datacenter Architecture

> **🚀 NEW: [Quick Start Guide](docs/quick-start-guide.md)** - Deploy in 15-30 minutes
> Choose your path: [OpenShift (15 min)](docs/quick-start-guide.md#quick-start-openshift-15-minutes) | [RHEL with TPA (20 min)](docs/quick-start-guide.md#quick-start-rhel-with-tpa-20-minutes) | [Local CRC (30 min)](docs/quick-start-guide.md#quick-start-local-testing-with-crc-30-minutes)

**📚 [Complete Documentation Index](docs/INDEX.md)** - Navigate all documentation by topic, deployment type, or audience

## Table of Contents

- [Overview](#overview)
- [Quick Links](#quick-links)
- [Installation](#installation)
- [Architecture](#architecture)
- [Operations](#operations)
- [Contributing](#contributing)

## Overview

This repository provides a complete solution for deploying Ansible Automation Platform (AAP) with
EnterpriseDB PostgreSQL in a multi-datacenter Active/Passive configuration. The architecture
achieves **near-HA** with automatic failover within datacenters and orchestrated failover across
datacenters.

**Key Features:**
- ✅ **Multi-datacenter HA/DR** - Active-Passive across two datacenters
- ✅ **Automatic failover** - In-datacenter failover <1 minute
- ✅ **PostgreSQL replication** - Physical streaming + WAL archiving
- ✅ **AAP orchestration** - Automated scaling during failover
- ✅ **Comprehensive testing** - Automated DR testing framework
- ✅ **Production-ready** - Security, monitoring, backup strategies

**Target RTO/RPO:**
- **In-datacenter failover:** RTO <1 minute, RPO <5 seconds
- **Cross-datacenter failover:** RTO <5 minutes, RPO <5 seconds

## Quick Links

### Getting Started
- **[🚀 Quick Start Guide](docs/quick-start-guide.md)** - Deploy in 15-30 minutes
- **[📚 Documentation Index](docs/INDEX.md)** - Complete documentation organized by topic
- **[🏗️ Architecture Details](docs/architecture.md)** - Comprehensive architecture documentation

### Deployment
- **[OpenShift Deployment](docs/install-kubernetes-manual.md)** - Operator-based deployment
- **[RHEL with TPA](docs/install-tpa.md)** - Automated deployment with Trusted Postgres Architect
- **[Database Deploy (Kustomize)](db-deploy/README.md)** - GitOps-friendly manifests
- **[AAP Deploy (Kustomize)](aap-deploy/README.md)** - AAP operator deployment

### Operations
- **[Operations Runbook](docs/manual-scripts-doc.md)** - Day-to-day operational procedures
- **[Scripts Reference](scripts/README.md)** - All automation scripts documented
- **[DR Testing Guide](docs/dr-testing-guide.md)** - Complete DR testing framework
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions

## Installation

**Preferred automation:** Use **[Trusted Postgres Architect (TPA)](https://github.com/EnterpriseDB/tpa)**
from EnterpriseDB for Postgres on **bare metal, cloud instances, or SSH-managed hosts**—see
[docs/install-tpa.md](docs/install-tpa.md) and [EDB TPA documentation](https://www.enterprisedb.com/docs/tpa/latest/).

TPA does **not** deploy the **EDB Postgres on OpenShift** operator; for Postgres **on OpenShift
as pods**, use the operator and manual/GitOps steps in this repo.

### Installation Quick Reference

| Platform | Time | Guide |
|----------|------|-------|
| **OpenShift** | 15 min | [Quick Start - OpenShift](docs/quick-start-guide.md#quick-start-openshift-15-minutes) |
| **RHEL with TPA** | 20 min | [Quick Start - RHEL](docs/quick-start-guide.md#quick-start-rhel-with-tpa-20-minutes) |
| **Local CRC** | 30 min | [Quick Start - CRC](docs/quick-start-guide.md#quick-start-local-testing-with-crc-30-minutes) |

### Detailed Installation Guides

| Area | Description | Guide |
|------|-------------|--------|
| **RHEL / hosts (TPA)** *(recommended)* | `tpaexec` workflows for supported platforms (bare metal, cloud, Docker for testing) | [TPA install](docs/install-tpa.md)<br>[RHEL / Ansible entry](docs/install-tpa.md#rhel-tpa-ansible)<br>[TPA on GitHub](https://github.com/EnterpriseDB/tpa)<br>[EDB TPA docs](https://www.enterprisedb.com/docs/tpa/latest/) |
| **OpenShift** | Operator install, `Cluster` CRs, passive cross-cluster replica (streaming), AAP operator with external EDB Postgres | [Ansible / GitOps pointers](docs/install-kubernetes-manual.md#ansible-gitops)<br>[Manual `oc` / YAML](docs/install-kubernetes-manual.md)<br>[Kustomize EDB Install (`db-deploy/`)](db-deploy/README.md)<br>[Cross-cluster replica](db-deploy/cross-cluster/README.md)<br>[AAP deploy (`aap-deploy/`)](aap-deploy/README.md)<br>[AAP OpenShift manifests](aap-deploy/openshift/README.md)<br>[Operator smoke test](docs/openshift-edb-operator-smoke-test.md)<br>[EDB Postgres on OpenShift architecture](docs/install-kubernetes-manual.md#edb-postgres-on-openshift-architecture)<br>[Scaling (OpenShift)](docs/install-kubernetes-manual.md#scaling-considerations) |
| RHEL EDB Install (manual) | Traditional VM-based install without TPA | [RHEL — Manual](docs/install-rhel-manual.md) |
| OpenShift (manual) | Operator + YAML/`oc` only | [OpenShift — Manual](docs/install-kubernetes-manual.md) |
| **AAP architecture** | Reference layouts for AAP on RHEL vs OpenShift | [RHEL AAP](docs/rhel-aap-architecture.md)<br>[OpenShift AAP](docs/openshift-aap-architecture.md) |
| **Disaster recovery** | DR scenarios and failover planning | [DR scenarios](docs/dr-scenarios.md) |
| **EDB Failover Manager (EFM)** | EFM integration with Postgres | [EFM Integration](docs/enterprisefailovermanager.md) |
| **Troubleshooting** | Diagnostics and issue resolution | [Troubleshooting](docs/troubleshooting.md) |
| **AAP cluster scripts & runbook** | Automation and operational procedures | [Scripts](scripts/README.md)<br>[Runbook](docs/manual-scripts-doc.md) |

## Architecture

### Architecture Overview

The solution implements a **multi-datacenter Active/Passive architecture** with:

- **Two datacenters:** DC1 (active), DC2 (passive/DR)
- **PostgreSQL replication:** Physical streaming replication + WAL archiving to S3
- **AAP deployment:** Separate clusters in each datacenter, scaled based on active/passive state
- **Failover orchestration:** EDB Failover Manager (EFM) integration with AAP scaling scripts
- **Global load balancer:** Routes traffic to active datacenter

![EDB Postgres Multi-Datacenter Architecture](images/AAP_EDB.drawio.png)

### Key Components

1. **Global Load Balancer** - Single entry point with health check-based routing
2. **Ansible Automation Platform (AAP)** - Deployed in both datacenters
3. **PostgreSQL Clusters** - EDB Postgres Advanced with CloudNativePG operator
4. **Replication** - Streaming replication DC1→DC2 with S3 WAL archive fallback
5. **Backup** - Barman Cloud to S3 with 30-day retention and PITR capability

### Architecture Documentation

**📖 [Complete Architecture Documentation](docs/architecture.md)**

Detailed documentation includes:
- Component details (GLB, AAP, PostgreSQL)
- Network connectivity and data flow
- Replication topology and configuration
- Backup and restore strategies
- Scaling considerations
- Deployment architecture for RHEL and OpenShift

**Platform-Specific Architecture:**
- **[RHEL AAP Architecture](docs/rhel-aap-architecture.md)** - Systemd services, HAProxy, manual orchestration
- **[OpenShift AAP Architecture](docs/openshift-aap-architecture.md)** - Operators, native services, automated orchestration

## Operations

### Day-to-Day Operations

- **[Operations Runbook](docs/manual-scripts-doc.md)** - Step-by-step operational procedures
- **[Script Reference](scripts/README.md)** - All automation scripts with usage examples
- **[Troubleshooting Guide](docs/troubleshooting.md)** - Common issues and diagnostics

### Disaster Recovery

- **[DR Scenarios](docs/dr-scenarios.md)** - 6 documented failure scenarios with procedures
- **[DR Testing Guide](docs/dr-testing-guide.md)** - Complete testing framework with quarterly drills
- **[Split-Brain Prevention](docs/split-brain-prevention.md)** - Database role validation and fencing
- **[EDB Failover Manager](docs/enterprisefailovermanager.md)** - EFM integration and configuration

### Automation Scripts

Located in [`scripts/`](scripts/):

**AAP Management:**
- `scale-aap-up.sh` - Scale AAP to operational state
- `scale-aap-down.sh` - Scale AAP to zero (maintenance/DR)

**DR Orchestration:**
- `efm-orchestrated-failover.sh` - Full automated failover
- `dr-failover-test.sh` - DR testing automation
- `validate-aap-data.sh` - Post-failover validation
- `measure-rto-rpo.sh` - RTO/RPO measurement
- `generate-dr-report.sh` - Automated DR test reporting

**Pre-commit Hooks:**
- `hooks/check-script-permissions.sh` - Verify executable permissions
- `hooks/validate-openshift-manifests.sh` - Validate YAML manifests

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for:

- Documentation standards
- Code standards (shell scripts, YAML)
- Testing requirements
- Pull request process
- Commit message guidelines

### Documentation

All documentation is in [`docs/`](docs/):

- **[Documentation Index](docs/INDEX.md)** - Complete documentation organized by topic
- **[Quick Start Guide](docs/quick-start-guide.md)** - 15-30 minute deployment paths
- **[Architecture](docs/architecture.md)** - Comprehensive architecture documentation

### Repository Structure

```
EDB_Testing/
├── docs/                    # All documentation
│   ├── INDEX.md            # Documentation index
│   ├── quick-start-guide.md # Quick start (15-30 min)
│   ├── architecture.md     # Architecture details
│   ├── dr-testing-guide.md # DR testing framework
│   └── ...                 # Additional guides
├── db-deploy/              # PostgreSQL deployment manifests
│   ├── operator/           # CloudNativePG operator
│   ├── sample-cluster/     # Base cluster manifests
│   └── cross-cluster/      # DC1→DC2 replication
├── aap-deploy/             # AAP deployment
│   ├── openshift/          # OpenShift manifests
│   └── edb-bootstrap/      # Database initialization
├── scripts/                # Automation scripts
│   ├── scale-aap-*.sh      # AAP scaling
│   ├── dr-*.sh             # DR orchestration
│   └── validate-*.sh       # Validation scripts
├── openshift/              # OpenShift-specific configs
│   └── dr-testing/         # DR testing CronJob
└── .github/                # CI/CD workflows
    └── workflows/          # GitHub Actions
```

---

**Questions?** See [docs/INDEX.md](docs/INDEX.md) for complete documentation or open an issue.
