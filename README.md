# AAP with EDB Postgres Multi-Datacenter Architecture

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
  - [RHEL with Ansible (recommended)](docs/install-rhel-ansible.md)
  - [Kubernetes with Ansible (recommended)](docs/install-kubernetes-ansible.md)
  - [RHEL manual installation](docs/install-rhel-manual.md)
  - [Kubernetes manual installation](docs/install-kubernetes-manual.md)
- [Architecture Diagram](#architecture-diagram)
- [Component Details](#component-details)
  - [Global Load Balancer](#global-load-balancer)
  - [Ansible Automation Platform (AAP)](#ansible-automation-platform-aap)
- [Network Connectivity](#network-connectivity)
  - [User to AAP (via Global Load Balancer)](#user-to-aap-via-global-load-balancer)
  - [AAP to PostgreSQL Databases](#aap-to-postgresql-databases)
  - [Inter-Datacenter Replication](#inter-datacenter-replication)
  - [Write Operations (Normal State)](#write-operations-normal-state)
  - [Read Operations](#read-operations)
  - [Backup Flow](#backup-flow)
- [AAP Deployment Architecture](#aap-deployment-architecture)
  - [RHEL AAP Architecture](docs/rhel-aap-architecture.md)
  - [OpenShift AAP Architecture](docs/openshift-aap-architecture.md)
- [AAP Cluster Management](#aap-cluster-management)
  - [Integration with EDB EFM (Enterprise Failover Manager)](#integration-with-edb-efm-enterprise-failover-manager)
- [AAP Cluster Management (Manual Scripts)](docs/manual-scripts-doc.md)
- [EFM Integration (EDB Failover Manager)](docs/enterprisefailovermanager.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Ansible Automation](#ansible-automation)
  - [Ansible Collection Overview](#ansible-collection-overview)
  - [Installation](#installation-1)
  - [Ansible Roles](#ansible-roles)
  - [Ansible Playbooks](#ansible-playbooks)
  - [Ansible vs Bash Scripts](#ansible-vs-bash-scripts)
  - [Directory Structure](#directory-structure)
  - [Integration with AAP Workflows](#integration-with-aap-workflows)
  - [Testing Ansible Automation](#testing-ansible-automation)
  - [Documentation](#documentation)
- [Disaster Recovery Scenarios](#disaster-recovery-scenarios)
  - [Full scenarios doc](docs/dr-scenarios.md)
- [Scaling Considerations](#scaling-considerations)
  - [Horizontal & vertical scaling (Kubernetes)](docs/install-kubernetes-manual.md#scaling-considerations)
- [EDB Postgres for Kubernetes Architecture](docs/install-kubernetes-manual.md#edb-postgres-for-kubernetes-architecture)

## Overview

This document describes the architecture of EnterpriseDB Postgres deployed Active/Passive across two clusters in different datacenters with in datacenter replication for the  Ansible Automation Platform (AAP). This will acheive a **NEAR** HA type architecture, especially for failover to the databases synching in region/datacenter. A DR scenario should be exactly for if there is a catastrophic failure. Failing to a in site database should cause little to no intervention needed at the application layer. The main thing to note is for a DR failover any running jobs will be lost, however if it fails in site, the jobs should continue to run UNLESS the controller has a failure.

## Installation

**Preferred:** Use the `edb.postgres_operations` Ansible collection for repeatable, automated installs. The guides below include Ansible playbooks and role usage, plus manual steps if needed.

| Deployment | Description | Guide |
|------------|-------------|--------|
| **RHEL with Ansible** *(recommended)* | Install EDB Postgres on RHEL 8/9 using the collection playbook and `install_postgres_rhel` role | [RHEL — Ansible](docs/install-rhel-ansible.md) |
| **Kubernetes with Ansible** *(recommended)* | Deploy PostgreSQL clusters on OpenShift/Kubernetes using the collection playbooks and `deploy_cluster` role | [Kubernetes — Ansible](docs/install-kubernetes-ansible.md) |
| RHEL (manual) | Traditional VM-based (systemd, PGD, EPAS); manual install and repo steps | [RHEL — Manual](docs/install-rhel-manual.md) |
| Kubernetes (manual) | Container-based; install operator and apply cluster YAML manually | [Kubernetes — Manual](docs/install-kubernetes-manual.md) |

For full Ansible collection usage, variables, and execution environment (AAP), see the [collection README](ansible_collections/edb/postgres_operations/README.md) and [GETTING_STARTED](ansible_collections/edb/postgres_operations/docs/GETTING_STARTED.md).

## Architecture Diagram

![EDB Postgres Multi-Datacenter Architecture](images/AAP_EDB.drawio.png)

## Component Details

### Global Load Balancer

The global load balancer provides a single entry point for AAP access:

- **DNS**: `aap.example.com`
- **Type**: Active-Passive (DC1 primary, DC2 standby)
- **Health Checks**: Monitors AAP Controller availability in both datacenters
- **Failover**: Automatic failover to DC2 if DC1 becomes unavailable
- **Routing**: Priority-based routing (100% traffic to DC1 when healthy)
- **Failback**: Automatic or manual failback to DC1 when it recovers
- **Protocols**: HTTPS (port 443), WebSocket support for real-time job updates

### Ansible Automation Platform (AAP)

For OpenShift AAP is deployed on **Sepearate OpenShift clusters** for high availability and geographic distribution. For RHEL you can do a single install across datacenters however you **MUST TURN OFF THE SERVICES ON THE SECONDARY SITE**

#### Datacenter 1 - AAP Instance
- **Namespace**: `ansible-automation-platform`
- **AAP Gateway**: 3 replicas for HA
- **AAP Controller**: 3 replicas for HA
- **Automation Hub**: 2 replicas
- **Database**: PostgreSQL cluster (1 primary + 2 replicas) managed by EDB operator
- **Route**: `aap-dc1.apps.ocp1.example.com`

#### Datacenter 2 - AAP Instance (scaled down)
- **Namespace**: `ansible-automation-platform`
- **AAP Gateway**: 3 replicas for HA
- **AAP Controller**: 3 replicas for HA
- **Automation Hub**: 2 replicas  
- **Database**: PostgreSQL cluster (1 primary + 2 replicas) managed by EDB operator
- **Route**: `aap-dc2.apps.ocp2.example.com`

#### AAP Database Replication

The AAP databases are replicated from active to passive datacenter:
- **Method**: PostgreSQL logical replication (Active → Passive) - *Note: AAP's internal database uses logical replication for flexibility*
- **Direction**: DC1 (Active) → DC2 (Passive)
- **Mode**: Asynchronous replication with minimal lag
- **Shared Data**: Job templates, inventory, credentials, execution history
- **Failover**: DC2 database promoted to read-write during failover
- **Failback**: Data synchronized back to DC1 when it recovers

#### EDB-Managed PostgreSQL Cluster Replication

EDB-managed application database clusters use physical replication:
- **Method**: PostgreSQL physical replication via streaming replication and WAL shipping
- **Primary Method**: Streaming replication from Primary to Designated Primary
- **Fallback Method**: WAL shipping via S3/object store (continuous WAL archiving)
- **Within Cluster**: Hot standby replicas use streaming replication from primary/designated primary
- **Mode**: Asynchronous streaming with optional synchronous mode
- **Benefits**: Block-level replication, faster failover, exact byte-for-byte replica

## Network Connectivity

### User to AAP (via Global Load Balancer)

Users and automation clients connect to AAP through the global load balancer:
- **URL**: `https://aap.example.com`
- **Protocol**: HTTPS/443 with WebSocket support
- **Load Balancing**: Active-Passive (priority-based)
- **Active Target**: DC1 AAP (100% traffic when healthy)
- **Passive Target**: DC2 AAP (standby, only receives traffic during failover)
- **Health Checks**: Layer 7 health checks to AAP Controller endpoints
- **Session Affinity**: Sticky sessions for long-running jobs
- **TLS Termination**: At load balancer or end-to-end encryption

### AAP to PostgreSQL Databases

Each AAP instance can connect to PostgreSQL databases in both datacenters:
- **Protocol**: PostgreSQL wire protocol (port 5432)
- **Access**: Via Kubernetes Services (ClusterIP within cluster, Routes/LoadBalancer for remote)
- **Authentication**: Certificate-based or password authentication
- **Encryption**: TLS/SSL enforced
- **Connection Pooling**: PgBouncer for efficient connection management

### Inter-Datacenter Replication

#### EDB-Managed Application Database Replication
- **Method**: PostgreSQL physical replication (streaming + WAL shipping)
- **Primary Mechanism**: Streaming replication from Primary to Designated Primary
- **Fallback Mechanism**: WAL shipping via S3/object store
- **Direction**: DC1 (Primary Cluster) → DC2 (Replica Cluster)
- **Network**: Encrypted tunnel (VPN/Direct Connect/WAN) for streaming replication
- **Replication Type**: Asynchronous (default) or synchronous (configurable)
- **Lag Monitoring**: Both AAP instances monitor replication lag via EDB operator metrics
- **Alerting**: Alerts triggered if lag exceeds threshold (e.g., 30 seconds)
- **Automatic Service Updates**: EDB operator automatically updates `-rw` service during failover
- **Cross-Cluster Limitation**: Automated failover across Kubernetes clusters must be handled externally (via AAP or higher-level orchestration)

### Write Operations (Normal State)

**For EDB-Managed Application Databases:**
1. Application → AAP Controller
2. AAP Controller → DC1 Primary Database (via `-rw` service)
3. DC1 Primary → DC1 Hot Standby Replicas (streaming replication within cluster)
4. DC1 Primary → DC2 Designated Primary (streaming replication across clusters)
5. DC1 Primary → S3/Object Store (continuous WAL archiving - fallback)
6. DC2 Designated Primary → DC2 Hot Standby Replicas (streaming replication within cluster)

### Read Operations

**EDB-Managed Clusters:**
- **DC1 Primary Cluster**: 
  - Write operations via `prod-db-rw` service (routes to primary)
  - Read operations via `prod-db-ro` service (routes to hot standby replicas)
  - Read operations via `prod-db-r` service (routes to any instance)
- **DC2 Replica Cluster**: 
  - Read operations only via `prod-db-replica-ro` service (routes to designated primary or replicas)
  - Cannot accept writes unless promoted
- **Load Balancing**: EDB operator manages service routing automatically

**Service Behavior During Failover:**
- EDB operator automatically updates `-rw` service to point to newly promoted primary
- Applications experience seamless redirection without connection string changes

### Backup Flow

**EDB-Managed PostgreSQL Backups:**
1. Scheduled backup job (initiated by AAP or CronJob via EDB operator)
2. Backup pod created by EDB operator
3. Database backup streamed to S3/object store (using Barman Cloud)
4. WAL files continuously archived to S3 (automatic by EDB operator)
5. WAL archiving serves dual purpose:
   - Point-in-time recovery (PITR)
   - Fallback replication mechanism for replica clusters
6. Replica clusters can recover from WAL archive if streaming replication fails
7. AAP monitors backup completion via operator metrics
8. Alerts sent if backup fails

**Backup Strategy per Datacenter:**
- **DC1**: Full backups + continuous WAL archiving to S3 bucket (primary region)
- **DC2**: Independent backups to separate S3 bucket (DR region) for redundancy

## AAP Deployment Architecture

Resource sizing and operational procedures for AAP:

- **RHEL (systemctl)**: [RHEL AAP Architecture](docs/rhel-aap-architecture.md) — startup/shutdown scripts, systemd unit.
- **OpenShift (pod scaling)**: [OpenShift AAP Architecture](docs/openshift-aap-architecture.md) — scale to zero, scale-up/down scripts, DR integration, monitoring.

## AAP Cluster Management

This section covers managing AAP clusters in both RHEL-based and OpenShift-based deployments. **RHEL** procedures are in [RHEL AAP Architecture](docs/rhel-aap-architecture.md). **OpenShift** pod scaling is in [OpenShift AAP Architecture](docs/openshift-aap-architecture.md).

### Integration with EDB EFM (Enterprise Failover Manager)

EDB Failover Manager (EFM) can automatically trigger the AAP cluster management scripts during PostgreSQL database failover events, coordinating database failover with AAP cluster activation. Full setup, scripting, configuration, testing, and best practices are documented in **[EDB EFM Integration](docs/enterprisefailovermanager.md)**.

## Ansible Automation

In addition to the bash scripts, comprehensive Ansible automation is available through the `edb.postgres_operations` collection.

### Ansible Collection Overview

The `edb.postgres_operations` collection provides production-ready roles and playbooks for:

- **AAP Cluster Management**: Automated scaling and service management
- **EFM Integration**: Seamless integration with EDB Failover Manager
- **Disaster Recovery Orchestration**: End-to-end DR failover automation
- **Testing and Validation**: Built-in testing capabilities

### Installation

```bash
# From project root: install collection
ansible-galaxy collection install ./ansible_collections/edb/postgres_operations

# Or build and install from collection dir
cd ansible_collections/edb/postgres_operations
ansible-galaxy collection build
ansible-galaxy collection install edb-postgres_operations-*.tar.gz
```

### Ansible Roles

#### manage_aap_cluster Role

Manages AAP cluster operations for both OpenShift and RHEL deployments.

**Capabilities:**
- Scale OpenShift pods up/down
- Start/stop RHEL systemd services
- Health checks and status monitoring
- Wait for operational readiness

**Example Usage:**

```yaml
---
- name: Scale up AAP in DR datacenter
  hosts: localhost
  gather_facts: false
  roles:
    - role: edb.postgres_operations.manage_aap_cluster
      manage_aap_cluster_action: scale_up
      manage_aap_cluster_context: api-changeme-com:6443
```

#### efm_integration Role

Integrates AAP cluster management with EDB Failover Manager for automated failover orchestration.

**Capabilities:**
- Install integration scripts to EFM nodes
- Configure EFM to call AAP management scripts
- Setup OpenShift kubeconfig for EFM user
- Test integration before production use

**Example Usage:**

```yaml
---
- name: Setup EFM AAP Integration
  hosts: efm_nodes
  become: true
  roles:
    - role: edb.postgres_operations.efm_integration
      efm_integration_action: install
      
    - role: edb.postgres_operations.efm_integration
      efm_integration_action: configure
```

### Ansible Playbooks

#### manage-aap-cluster.yml

General-purpose playbook for AAP cluster management operations.

```bash
# Scale up AAP
ansible-playbook edb.postgres_operations.manage-aap-cluster \
  -e 'manage_aap_cluster_action=scale_up' \
  -e 'manage_aap_cluster_context=api-changeme-com:6443'

# Check status
ansible-playbook edb.postgres_operations.manage-aap-cluster \
  -e 'manage_aap_cluster_action=status'

# Start services on RHEL
ansible-playbook edb.postgres_operations.manage-aap-cluster \
  -i rhel_inventory \
  -e 'manage_aap_cluster_action=start' \
  -e 'manage_aap_cluster_deployment_type=rhel' \
  -e 'aap_require_become=true'
```

#### setup-efm-integration.yml

Complete EFM integration setup with installation, configuration, and optional testing.

```bash
# Install and configure
ansible-playbook edb.postgres_operations.setup-efm-integration \
  -i inventory \
  -l efm_nodes

# With testing
ansible-playbook edb.postgres_operations.setup-efm-integration \
  -i inventory \
  -l efm_nodes \
  -e 'run_test=true'
```

#### disaster-recovery-failover.yml

Complete disaster recovery failover orchestration with safety checks and confirmation.

```bash
# Manual failover with confirmation
ansible-playbook edb.postgres_operations.disaster-recovery-failover \
  -e 'failover_source_dc=dc1' \
  -e 'failover_target_dc=dc2'

# Automatic failover (no confirmation)
ansible-playbook edb.postgres_operations.disaster-recovery-failover \
  -e 'failover_source_dc=dc1' \
  -e 'failover_target_dc=dc2' \
  -e 'dr_failover_mode=automatic' \
  -e 'dr_require_confirmation=false'
```

### Ansible vs Bash Scripts

Both automation approaches are available:

| Feature | Bash Scripts | Ansible Automation |
|---------|-------------|-------------------|
| **Complexity** | Simple, direct | More structured |
| **Idempotency** | Manual handling | Built-in |
| **Error Handling** | Basic | Comprehensive |
| **Testing** | Manual | Built-in check mode |
| **Orchestration** | Sequential | Parallel & conditional |
| **Logging** | File-based | Ansible native |
| **Integration** | EFM-specific | Multi-tool support |
| **Best For** | EFM integration | Complex workflows |

**Recommendation:**
- Use **Bash scripts** for direct EFM integration
- Use **Ansible automation** for:
  - Complex multi-step procedures
  - Testing and validation
  - Integration with AAP workflows
  - Centralized management
  - Audit trails

### Directory Structure

```
ansible_collections/          # at project root
└── edb/
    └── postgres_operations/
        ├── galaxy.yml
        ├── README.md
        ├── roles/
        │   ├── manage_aap_cluster/
        │   │   ├── README.md
        │   │   ├── defaults/main.yml
        │   │   ├── tasks/
        │   │   │   ├── main.yml
        │   │   │   ├── openshift_scale_up.yml
        │   │   │   ├── openshift_scale_down.yml
        │   │   │   ├── rhel_start.yml
        │   │   │   └── rhel_stop.yml
        │   │   └── meta/main.yml
        │   └── efm_integration/
        │       ├── README.md
        │       ├── defaults/main.yml
        │       ├── tasks/
        │       │   ├── main.yml
        │       │   ├── install.yml
        │       │   ├── configure.yml
        │       │   ├── test.yml
        │       │   └── uninstall.yml
        │       ├── handlers/main.yml
        │       └── meta/main.yml
        └── playbooks/
            ├── manage-aap-cluster.yml
            ├── setup-efm-integration.yml
            ├── disaster-recovery-failover.yml
            └── AAP_MANAGEMENT.md

ansible_collections/edb/postgres_operations/  # collection (inventory, playbooks, EE build)
    ├── inventory/example-multi-datacenter.yml
    ├── execution-environment.yml, requirements-ee.yml
    └── playbooks/, roles/, docs/
```

### Disaster Recovery Scenarios

Walkthroughs for datacenter failure, AAP or database failure, network partition, cluster failure, and load balancer failure: **[docs/dr-scenarios.md](docs/dr-scenarios.md)**.

### Scaling Considerations

Horizontal and vertical scaling for EDB Postgres on Kubernetes/OpenShift: **[docs/install-kubernetes-manual.md#scaling-considerations](docs/install-kubernetes-manual.md#scaling-considerations)**.

### Documentation

Comprehensive documentation is available:

- **Collection README**: [ansible_collections/edb/postgres_operations/README.md](ansible_collections/edb/postgres_operations/README.md)
- **Collection GETTING_STARTED**: [ansible_collections/edb/postgres_operations/docs/GETTING_STARTED.md](ansible_collections/edb/postgres_operations/docs/GETTING_STARTED.md)
- **AAP Management Guide**: [ansible_collections/edb/postgres_operations/playbooks/AAP_MANAGEMENT.md](ansible_collections/edb/postgres_operations/playbooks/AAP_MANAGEMENT.md)
- **Role READMEs**: Individual README files in each role directory
- **Installation**: [RHEL (Ansible / manual)](docs/install-rhel.md) · [Kubernetes (Ansible / manual)](docs/install-kubernetes.md)
- **RHEL AAP**: [docs/rhel-aap-architecture.md](docs/rhel-aap-architecture.md) · **OpenShift AAP**: [docs/openshift-aap-architecture.md](docs/openshift-aap-architecture.md)
- **Disaster Recovery Scenarios**: [docs/dr-scenarios.md](docs/dr-scenarios.md)
- **EFM Integration**: [docs/enterprisefailovermanager.md](docs/enterprisefailovermanager.md)
- **Troubleshooting**: [docs/troubleshooting.md](docs/troubleshooting.md)
- **Manual Scripts**: [docs/manual-scripts-doc.md](docs/manual-scripts-doc.md)
- **Kubernetes Architecture**: [docs/install-kubernetes-manual.md#edb-postgres-for-kubernetes-architecture](docs/install-kubernetes-manual.md#edb-postgres-for-kubernetes-architecture)


