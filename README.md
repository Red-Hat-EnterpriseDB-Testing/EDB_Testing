# AAP with EDB Postgres Multi-Datacenter Architecture

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
![Status](https://img.shields.io/badge/Status-Production--Ready-green)
![Last Updated](https://img.shields.io/badge/Updated-April%202026-blue)
[![Changelog](https://img.shields.io/badge/Changelog-Keep%20a%20Changelog-orange.svg)](CHANGELOG.md)

> **🚀 NEW: [Quick Start Guide](docs/quick-start-guide.md)** - Deploy in 15-30 minutes
> Choose your path: [OpenShift (15 min)](docs/quick-start-guide.md#quick-start-openshift-15-minutes) | [RHEL with TPA (20 min)](docs/quick-start-guide.md#quick-start-rhel-with-tpa-20-minutes) | [Local CRC (30 min)](docs/quick-start-guide.md#quick-start-local-testing-with-crc-30-minutes)

**📚 [Complete Documentation Index](docs/INDEX.md)** - Navigate all documentation by topic, deployment type, or audience

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Links](#quick-links)
- [Repository Structure](#repository-structure)
- [Changelog](CHANGELOG.md)

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
- **In-datacenter failover:** RTO (Recovery Time Objective) <1 minute, RPO (Recovery Point Objective) <5 seconds
- **Cross-datacenter failover:** RTO <5 minutes, RPO <5 seconds

## Prerequisites

Before getting started, ensure you have:

- **Platform**: OpenShift 4.12+ OR RHEL 8+ with root access
- **Database**: EnterpriseDB subscription for EDB Postgres Advanced Server
- **Storage**: S3-compatible storage for WAL archiving and backups
- **Network**: Network connectivity between datacenters (for replication)
- **Tools**: `oc` or `kubectl` CLI tools installed

📋 See [detailed requirements](docs/quick-start-guide.md#prerequisites) in the Quick Start Guide

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

### Community
- **[📝 Changelog](CHANGELOG.md)** - All notable changes to this project
- **[Contributing Guide](CONTRIBUTING.md)** - How to contribute to this project
- **[License](LICENSE)** - Apache 2.0 License

## Repository Structure

<details>
<summary>📁 Click to expand repository structure</summary>

```
EDB_Testing/
├── aap-deploy/              # AAP deployment manifests
│   ├── openshift/           # OpenShift manifests
│   └── edb-bootstrap/       # Database initialization
├── db-deploy/               # PostgreSQL deployment manifests
│   ├── operator/            # CloudNativePG operator
│   ├── sample-cluster/      # Base cluster manifests
│   └── cross-cluster/       # DC1→DC2 replication
├── docs/                    # Comprehensive documentation
│   ├── INDEX.md             # Documentation index
│   ├── quick-start-guide.md # 15-30 min deployment guide
│   ├── architecture.md      # Architecture details
│   └── ...                  # Additional guides
├── scripts/                 # Operational automation scripts
│   ├── lib/                 # Shared libraries (logging, scaling)
│   ├── scale-aap-*.sh       # AAP scaling scripts
│   ├── dr-*.sh              # DR orchestration
│   └── validate-*.sh        # Validation scripts
├── openshift/               # OpenShift-specific resources
│   └── dr-testing/          # DR testing CronJob
└── .github/                 # CI/CD workflows
    └── workflows/           # GitHub Actions
```

See [complete structure](docs/INDEX.md#documentation-structure) in the documentation index.

</details>
