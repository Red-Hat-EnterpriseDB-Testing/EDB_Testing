# AAP with EDB Postgres Multi-Datacenter Architecture

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
  - [RHEL / hosts — Trusted Postgres Architect (TPA) (recommended)](docs/install-tpa.md)
  - [OpenShift / Kubernetes — EDB operator & manual](docs/install-kubernetes-manual.md)
  - [OpenShift / Kubernetes — Kustomize manifests (`db-deploy/`)](db-deploy/README.md)
  - [RHEL manual installation](docs/install-rhel-manual.md)
  - [OpenShift manual installation](docs/install-kubernetes-manual.md)
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
- [AAP cluster management — runbook](docs/manual-scripts-doc.md)
  - [AAP cluster scripts (`scripts/README.md`)](scripts/README.md)
- [EFM Integration (EDB Failover Manager)](docs/enterprisefailovermanager.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Disaster Recovery Scenarios](#disaster-recovery-scenarios)
  - [Full scenarios doc](docs/dr-scenarios.md)
- [Scaling Considerations](#scaling-considerations)
  - [Horizontal & vertical scaling (OpenShift)](docs/install-kubernetes-manual.md#scaling-considerations)
- [EDB Postgres on OpenShift Architecture](docs/install-kubernetes-manual.md#edb-postgres-for-kubernetes-architecture)

## Overview

This document describes the architecture of EnterpriseDB Postgres deployed Active/Passive across two clusters in different datacenters with in datacenter replication for the  Ansible Automation Platform (AAP). This will acheive a **NEAR** HA type architecture, especially for failover to the databases synching in region/datacenter. A DR scenario should be exactly for if there is a catastrophic failure. Failing to a in site database should cause little to no intervention needed at the application layer. The main thing to note is for a DR failover any running jobs will be lost, however if it fails in site, the jobs should continue to run UNLESS the controller has a failure.

## Installation

**Preferred automation:** Use **[Trusted Postgres Architect (TPA)](https://github.com/EnterpriseDB/tpa)** from EnterpriseDB for Postgres on **bare metal, cloud instances, or SSH-managed hosts**—see [docs/install-tpa.md](docs/install-tpa.md) and [EDB TPA documentation](https://www.enterprisedb.com/docs/tpa/latest/). TPA does **not** deploy the **EDB Postgres for Kubernetes** operator; for Postgres **on OpenShift as pods**, use the operator and manual/GitOps steps in this repo.

| Deployment | Description | Guide |
|------------|-------------|--------|
| **RHEL / hosts (TPA)** *(recommended)* | `tpaexec` workflows for supported platforms (bare metal, cloud, Docker for testing) | [TPA](docs/install-tpa.md) · [RHEL / Ansible entry](docs/install-tpa.md#rhel-tpa-ansible) |
| **OpenShift / Kubernetes** | Operator install, `Cluster` CRs, passive cross-cluster replica (streaming) | [Ansible / GitOps pointers](docs/install-kubernetes-manual.md#ansible-gitops) · [Manual `oc` / YAML](docs/install-kubernetes-manual.md) · [Kustomize (`db-deploy/`)](db-deploy/README.md) · [Cross-cluster replica](db-deploy/cross-cluster/README.md) |
| RHEL (manual) | Traditional VM-based install without TPA | [RHEL — Manual](docs/install-rhel-manual.md) |
| OpenShift (manual) | Operator + YAML/`oc` only | [OpenShift — Manual](docs/install-kubernetes-manual.md) |

## Architecture 

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

**Operator install with external EDB Postgres** (`edb-pg-demo` / `demo-pg`): see **[`aap-deploy/openshift/README.md`](aap-deploy/openshift/README.md)** (subscription + `AnsibleAutomationPlatform` CR).

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

AAP can only talk to one Read Write(RW) database at a time:
- **Protocol**: PostgreSQL wire protocol (port 5432)
- **Access**: Via OpenShift Services (ClusterIP within cluster, Routes/LoadBalancer for remote)
- **Authentication**: Certificate-based or password authentication
- **Encryption**: TLS/SSL enforced
- **Connection Pooling**: PgBouncer for efficient connection management

### Inter-Datacenter Replication

#### EDB-Managed Application Database Replication
- **Method**: PostgreSQL physical replication (streaming + WAL shipping)
- **Primary Mechanism**: Streaming replication from Primary to Designated Secondaries
- **Fallback Mechanism**: WAL shipping via S3/object store
- **Direction**: DC1 (Primary Cluster) → DC2 (Replica Cluster)
- **Network**: Encrypted tunnel (VPN/Direct Connect/WAN) for streaming replication
- **Replication Type**: Asynchronous (default) or synchronous (configurable)
- **Lag Monitoring**: Both AAP instances monitor replication lag via EDB operator metrics
- **Alerting**: Alerts triggered if lag exceeds threshold (e.g., 30 seconds)
- **Automatic Service Updates**: EDB operator automatically updates `-rw` service during failover
- **Cross-Cluster Limitation**: Automated failover across OpenShift clusters must be handled externally (via AAP or higher-level orchestration)

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

### Documentation

Comprehensive documentation is available:

- **TPA (recommended for host-based Postgres)**: [docs/install-tpa.md](docs/install-tpa.md) · [github.com/EnterpriseDB/tpa](https://github.com/EnterpriseDB/tpa) · [EDB TPA docs](https://www.enterprisedb.com/docs/tpa/latest/)
- **OpenShift / Kubernetes operator**: [db-deploy/README.md](db-deploy/README.md) (Kustomize: operator + sample `Cluster`) · [Cross-cluster passive replica](db-deploy/cross-cluster/README.md) · [docs/install-kubernetes-manual.md](docs/install-kubernetes-manual.md) · [Operator smoke test (generic)](docs/openshift-edb-operator-smoke-test.md)
- **RHEL manual**: [docs/install-rhel-manual.md](docs/install-rhel-manual.md) · **RHEL + TPA**: [docs/install-tpa.md](docs/install-tpa.md#rhel-tpa-ansible)
- **RHEL AAP**: [docs/rhel-aap-architecture.md](docs/rhel-aap-architecture.md) · **OpenShift AAP**: [docs/openshift-aap-architecture.md](docs/openshift-aap-architecture.md)
- **Disaster Recovery Scenarios**: [docs/dr-scenarios.md](docs/dr-scenarios.md)
- **EFM Integration**: [docs/enterprisefailovermanager.md](docs/enterprisefailovermanager.md)
- **Troubleshooting**: [docs/troubleshooting.md](docs/troubleshooting.md)
- **AAP scripts**: [scripts/README.md](scripts/README.md) · [Runbook](docs/manual-scripts-doc.md)
- **OpenShift Architecture**: [docs/install-kubernetes-manual.md#edb-postgres-for-kubernetes-architecture](docs/install-kubernetes-manual.md#edb-postgres-for-kubernetes-architecture)


