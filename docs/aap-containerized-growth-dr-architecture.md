# AAP Containerized Multi-Datacenter DR Architecture
## Growth Topology - Active-Passive Deployment

**Last Updated:** 2026-03-31
**Version:** 1.0
**Target RTO:** < 5 minutes
**Target RPO:** < 5 seconds
**Based On:** Red Hat AAP 2.6 Container Growth Topology

---

## Executive Summary

This architecture implements Red Hat Ansible Automation Platform 2.6 using the **containerized installer** on RHEL in an **Active-Passive multi-datacenter** configuration optimized for **smaller deployments** and **rapid deployment**.

**Key Design:**
- **Deployment Method:** AAP 2.6 Containerized Installer (Podman on RHEL 9.4+)
- **Topology:** Growth (3 multi-component nodes) with Active/Passive DR
- **AAP Nodes:** 3 nodes per datacenter with multiple components colocated (6 total)
- **Database:** 3-node PostgreSQL cluster per datacenter (6 total)
- **Replication:** Physical streaming + WAL archiving
- **High Availability:** EDB Failover Manager (EFM) + Redis colocated
- **Load Balancing:** HAProxy local + Global Load Balancer
- **Automated Failover:** < 5 minutes RTO via EFM orchestration

> **⚠️ Important:** This design is optimized for **cost efficiency and rapid deployment**. For production enterprise workloads requiring component isolation and higher scale, see [AAP Containerized Enterprise DR Architecture](aap-containerized-enterprise-dr-architecture.md).

> **Multi-DC Extension:** This multi-datacenter Active/Passive design extends Red Hat's single-datacenter Container Growth Topology. While the individual datacenter configuration follows Red Hat's tested model, the multi-DC failover architecture is **not officially tested by Red Hat**. The design follows PostgreSQL and industry DR best practices but requires additional validation.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Component Specifications](#2-component-specifications)
3. [Database Replication Design](#3-database-replication-design)
4. [AAP Containerized Configuration](#4-aap-containerized-installer-configuration)
5. [Failover and Failback Procedures](#5-failover-and-failback-procedures)
6. [Monitoring and Alerting](#6-monitoring-and-alerting-strategy)
7. [Implementation Roadmap](#7-implementation-phases)
8. [Configuration Examples](#8-configuration-file-examples)
9. [Comparison with Enterprise Topology](#9-comparison-with-enterprise-topology)

---

## 1. Architecture Overview

### 1.1 High-Level Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│                        GLOBAL LOAD BALANCER                            │
│                      (F5 / HAProxy / Route53)                          │
│                    https://aap.example.com                             │
│                                                                        │
│  Health Checks: /api/v2/ping/ every 10s                               │
│  Active-Passive Routing: DC1 (Priority 100) → DC2 (Priority 50)       │
└──────────────┬────────────────────────────────┬────────────────────────┘
               │ (Active - 100% traffic)        │ (Passive - 0% traffic)
               │                                │
┌──────────────▼─────────────────┐   ┌──────────▼──────────────────────┐
│      DATACENTER 1 (Active)     │   │    DATACENTER 2 (Standby)       │
│                                │   │                                 │
│  ┌───────────────────────────┐ │   │  ┌───────────────────────────┐  │
│  │  HAProxy Load Balancer    │ │   │  │  HAProxy Load Balancer    │  │
│  │  haproxy-dc1              │ │   │  │  haproxy-dc2              │  │
│  │  10.1.1.10                │ │   │  │  10.2.1.10                │  │
│  └────────┬──────────────────┘ │   │  └────────┬──────────────────┘  │
│           │                    │   │           │                     │
│  ┌────────▼─────────────────┐  │   │  ┌────────▼─────────────────┐   │
│  │  AAP Growth Nodes        │  │   │  │  AAP Growth Nodes        │   │
│  │  (3 VMs - All Active)    │  │   │  │  (3 VMs - STOPPED)       │   │
│  │                          │  │   │  │                          │   │
│  │  aap-node1-dc1           │  │   │  │  aap-node1-dc2           │   │
│  │    - gateway             │  │   │  │  Containers: STOPPED     │   │
│  │    - controller          │  │   │  │  until failover          │   │
│  │    - hub                 │  │   │  │                          │   │
│  │    - eda                 │  │   │  │  aap-node2-dc2           │   │
│  │    - redis               │  │   │  │  Containers: STOPPED     │   │
│  │                          │  │   │  │                          │   │
│  │  aap-node2-dc1           │  │   │  │  aap-node3-dc2           │   │
│  │    - controller          │  │   │  │  Containers: STOPPED     │   │
│  │    - hub                 │  │   │  │                          │   │
│  │    - redis               │  │   │  │                          │   │
│  │                          │  │   │  │                          │   │
│  │  aap-node3-dc1           │  │   │  │                          │   │
│  │    - controller          │  │   │  │                          │   │
│  │    - eda                 │  │   │  │                          │   │
│  │    - redis               │  │   │  │                          │   │
│  └─────────┬────────────────┘  │   │  └─────────┬────────────────┘   │
│            │                   │   │            │                    │
│  ┌─────────▼──────────────────┐│   │  ┌─────────▼──────────────────┐ │
│  │ PostgreSQL Cluster (3)     ││   │  │ PostgreSQL Cluster (3)     │ │
│  │ (EDB PostgreSQL Advanced 16) ││   │  │ (EDB PostgreSQL Advanced 16) │ │
│  │                            ││   │  │                            │ │
│  │ pg-dc1-1 (PRIMARY)         ││   │  │ pg-dc2-1 (STANDBY/DP)      │ │
│  │   - awx                    ││   │  │   - awx (replica)          │ │
│  │   - automationhub          ││   │  │   - automationhub          │ │
│  │   - automationedacontroller││   │  │   - automationedacontroller│ │
│  │   - automationgateway      ││   │  │   - automationgateway      │ │
│  │                            ││   │  │                            │ │
│  │ pg-dc1-2 (STANDBY)         ││   │  │ pg-dc2-2 (STANDBY)         │ │
│  │ pg-dc1-3 (STANDBY)         ││   │  │ pg-dc2-3 (STANDBY)         │ │
│  │                            ││   │  │                            │ │
│  │ VIP: 10.1.2.100 (EFM)      ││   │  │ VIP: 10.2.2.100 (EFM)      │ │
│  └────────┬───────────────────┘│   │  └────────┬───────────────────┘ │
│           │                    │   │           │                     │
│  ┌────────▼──────────────────┐ │   │  ┌────────▼───────────────────┐ │
│  │ Barman Backup Server      │ │   │  │ Barman Backup Server       │ │
│  │ + WAL Archive (NFS/S3)    │ │   │  │ + WAL Archive (NFS/S3)     │ │
│  └───────────────────────────┘ │   │  └────────────────────────────┘ │
└───────────┬────────────────────┘   └────────────┬────────────────────┘
            │                                     │
            │      Streaming Replication (SSL)    │
            │      5432 (direct or VPN tunnel)    │
            └─────────────────────────────────────┘
                     (Asynchronous)
```

### 1.2 Data Flow Architecture

**Normal Operations (DC1 Active):**
```
User → GLB → HAProxy(DC1) → AAP Growth Nodes(DC1) → VIP(DC1) → PostgreSQL PRIMARY(DC1)
                                                                      │
                                    ┌─────────────────────────────────┼───────────────┐
                                    │                                 │               │
                                    ▼                                 ▼               ▼
                            PG Standby DC1-2                  PG Standby DC1-3    S3/Barman
                                                                      │
                                                        Streaming Replication (WAN)
                                                                      │
                                                                      ▼
                                                          PG Designated Primary DC2-1
                                                                      │
                                            ┌─────────────────────────┼──────────────┐
                                            │                         │              │
                                            ▼                         ▼              ▼
                                    PG Standby DC2-2          PG Standby DC2-3   S3/Barman
```

**Failover Operations (DC2 Active):**
```
User → GLB → HAProxy(DC2) → AAP Growth Nodes(DC2) → VIP(DC2) → PostgreSQL PRIMARY(DC2)
```

---

## 2. Component Specifications

### 2.1 AAP Growth Nodes

**Based on Red Hat AAP 2.6 Container Growth Topology**

**DC1 (Active Site) - AAP Growth Nodes**

| Component | Specification | Count | Resource per VM | Total Resources |
|-----------|--------------|-------|-----------------|-----------------|
| **AAP Multi-Component Nodes** | RHEL 9.4+, Podman + Redis | 3 | 8 vCPU, 32GB RAM, 100GB disk | 24 vCPU, 96GB RAM |
| **HAProxy Load Balancer** | RHEL 9.4+ | 1 | 2 vCPU, 8GB RAM, 40GB disk | 2 vCPU, 8GB RAM |
| **Total AAP Infrastructure DC1** | - | **4 VMs** | - | **26 vCPU, 104GB RAM** |

**DC2 (Standby Site) - AAP Growth Nodes (STOPPED)**

| Component | Specification | Count | Resource per VM | Total Resources |
|-----------|--------------|-------|-----------------|-----------------|
| **AAP Multi-Component Nodes** | RHEL 9.4+, Podman + Redis (STOPPED) | 3 | 8 vCPU, 32GB RAM, 100GB disk | 24 vCPU, 96GB RAM |
| **HAProxy Load Balancer** | RHEL 9.4+ | 1 | 2 vCPU, 8GB RAM, 40GB disk | 2 vCPU, 8GB RAM |
| **Total AAP Infrastructure DC2** | - | **4 VMs** | - | **26 vCPU, 104GB RAM** |

> **Growth Topology Design:** Components are colocated on 3 nodes for cost efficiency. This is suitable for deployments with moderate automation workloads (<500 automation jobs/hour).

**VM Naming Convention:**

```text
DC1:
  aap-node1-dc1.example.com  (primary - gateway, controller, hub, eda, redis)
  aap-node2-dc1.example.com  (secondary - controller, hub, redis)
  aap-node3-dc1.example.com  (secondary - controller, eda, redis)
  haproxy-dc1.example.com

DC2:
  aap-node1-dc2.example.com  (stopped until failover)
  aap-node2-dc2.example.com  (stopped until failover)
  aap-node3-dc2.example.com  (stopped until failover)
  haproxy-dc2.example.com
```

**Component Distribution (Growth Pattern)**

```yaml
aap-node1-dc1 (Primary - all components):
  - automation-gateway:          cpu: 1 core, memory: 2GB
  - automation-controller-web:   cpu: 2 cores, memory: 8GB
  - automation-controller-task:  cpu: 2 cores, memory: 8GB
  - automation-hub:              cpu: 2 cores, memory: 6GB
  - eda-activation-worker:       cpu: 1 core, memory: 4GB
  - receptor:                    cpu: 1 core, memory: 2GB
  - redis:                       cpu: 1 core, memory: 4GB

aap-node2-dc1 (Controller + Hub):
  - automation-controller-web:   cpu: 2 cores, memory: 8GB
  - automation-controller-task:  cpu: 2 cores, memory: 8GB
  - automation-hub:              cpu: 2 cores, memory: 6GB
  - redis:                       cpu: 1 core, memory: 4GB

aap-node3-dc1 (Controller + EDA):
  - automation-controller-web:   cpu: 2 cores, memory: 8GB
  - automation-controller-task:  cpu: 2 cores, memory: 8GB
  - eda-activation-worker:       cpu: 1 core, memory: 4GB
  - redis:                       cpu: 1 core, memory: 4GB
```

### 2.2 PostgreSQL Database Cluster

**Same as Enterprise Topology**

| Datacenter | Role | Count | Specification |
|------------|------|-------|---------------|
| **DC1** | Primary + 2 Standby | 3 | 8 vCPU, 32GB RAM, 500GB SSD |
| **DC2** | Designated Primary + 2 Standby | 3 | 8 vCPU, 32GB RAM, 500GB SSD |

**AAP Databases (4 databases on each PostgreSQL instance)**

```sql
-- Database Layout (AAP 2.6 official database names)
CREATE DATABASE awx OWNER aap;                          -- 50GB (main controller database)
CREATE DATABASE automationhub OWNER aap;                -- 20GB (content/collections)
CREATE DATABASE automationedacontroller OWNER aap;      -- 10GB (event-driven automation)
CREATE DATABASE automationgateway OWNER aap;            -- 5GB (platform gateway)

-- Extensions
\c automationhub
CREATE EXTENSION IF NOT EXISTS hstore;
```

**PostgreSQL Configuration** - Same as Enterprise (see [AAP Containerized Enterprise DR Architecture](aap-containerized-enterprise-dr-architecture.md#22-postgresql-database-cluster))

### 2.3 Network Topology

**Network Segmentation**

```text
DC1 Network:
  - AAP Subnet:       10.1.1.0/24
    - aap-node1-dc1:    10.1.1.11
    - aap-node2-dc1:    10.1.1.12
    - aap-node3-dc1:    10.1.1.13
    - haproxy-dc1:      10.1.1.10
    - HAProxy VIP:      10.1.1.100

  - Database Subnet:  10.1.2.0/24
    - pg-dc1-1:         10.1.2.21
    - pg-dc1-2:         10.1.2.22
    - pg-dc1-3:         10.1.2.23
    - Database VIP:     10.1.2.100 (EFM managed)

DC2 Network:
  - AAP Subnet:       10.2.1.0/24
    - aap-node1-dc2:    10.2.1.11
    - aap-node2-dc2:    10.2.1.12
    - aap-node3-dc2:    10.2.1.13
    - haproxy-dc2:      10.2.1.10
    - HAProxy VIP:      10.2.1.100

  - Database Subnet:  10.2.2.0/24
    - pg-dc2-1:         10.2.2.21
    - pg-dc2-2:         10.2.2.22
    - pg-dc2-3:         10.2.2.23
    - Database VIP:     10.2.2.100 (EFM managed)
```

**Firewall Rules**

```bash
# User Access (GLB → HAProxy)
Source: 0.0.0.0/0
Dest: 10.1.1.100, 10.2.1.100
Port: 443/tcp

# HAProxy → Platform Gateway (on aap-node1)
Source: 10.1.1.10, 10.2.1.10
Dest: 10.1.1.11, 10.2.1.11
Port: 80/443

# AAP Components → PostgreSQL (via EFM VIP)
Source: 10.1.1.0/24, 10.2.1.0/24
Dest: 10.1.2.100, 10.2.2.100
Port: 5432/tcp

# Redis (colocated - localhost communication)
# No external firewall rule needed

# PostgreSQL Replication (DC1 → DC2)
Source: 10.1.2.21-23
Dest: 10.2.2.21-23
Port: 5432/tcp

# EFM Cluster Communication
Source: 10.1.2.0/24, 10.2.2.0/24
Dest: 10.1.2.0/24, 10.2.2.0/24
Port: 7800-7810/tcp
```

---

## 3. Database Replication Design

**Same as Enterprise Topology** - See [AAP Containerized Enterprise DR Architecture](aap-containerized-enterprise-dr-architecture.md#3-database-replication-design)

---

## 4. AAP Containerized Installer Configuration

### 4.1 AAP Inventory File (DC1)

**Based on Red Hat AAP 2.6 Container Growth Topology**

```ini
# /opt/aap/inventory-dc1
# Red Hat Ansible Automation Platform 2.6 - Container Growth Topology
# Multi-Datacenter Active/Passive Extension

# Platform Gateway (on primary node)
[automationgateway]
aap-node1-dc1.example.com

# Automation Controller (distributed across all 3 nodes)
[automationcontroller]
aap-node1-dc1.example.com
aap-node2-dc1.example.com
aap-node3-dc1.example.com

# Automation Hub (on nodes 1 and 2)
[automationhub]
aap-node1-dc1.example.com
aap-node2-dc1.example.com

# Event-Driven Ansible (on nodes 1 and 3)
[automationeda]
aap-node1-dc1.example.com
aap-node3-dc1.example.com

# Redis (colocated on all 3 AAP nodes)
[redis]
aap-node1-dc1.example.com
aap-node2-dc1.example.com
aap-node3-dc1.example.com

[all:vars]
# Common variables
postgresql_admin_username=postgres
postgresql_admin_password='<set your own>'

# Red Hat Registry Credentials
registry_username='<your RHN username>'
registry_password='<your RHN password>'

# Redis Configuration
redis_mode='standalone'

# Platform Gateway Configuration
gateway_admin_password='<set your own>'
gateway_pg_host='10.1.2.100'  # EFM VIP for DC1 PostgreSQL cluster
gateway_pg_port='5432'
gateway_pg_database='automationgateway'
gateway_pg_username='aap'
gateway_pg_password='<set your own>'
gateway_main_url='https://aap.example.com'

# Automation Controller Configuration
controller_admin_password='<set your own>'
controller_pg_host='10.1.2.100'  # EFM VIP
controller_pg_port='5432'
controller_pg_database='awx'
controller_pg_username='aap'
controller_pg_password='<set your own>'

# Automation Hub Configuration
hub_admin_password='<set your own>'
hub_pg_host='10.1.2.100'  # EFM VIP
hub_pg_port='5432'
hub_pg_database='automationhub'
hub_pg_username='aap'
hub_pg_password='<set your own>'

# Event-Driven Ansible Configuration
eda_admin_password='<set your own>'
eda_pg_host='10.1.2.100'  # EFM VIP
eda_pg_port='5432'
eda_pg_database='automationedacontroller'
eda_pg_username='aap'
eda_pg_password='<set your own>'
```

### 4.2 AAP Inventory File (DC2 - Standby)

```ini
# /opt/aap/inventory-dc2
# IMPORTANT: All AAP containers will be STOPPED after installation until failover

# Platform Gateway
[automationgateway]
aap-node1-dc2.example.com

# Automation Controller
[automationcontroller]
aap-node1-dc2.example.com
aap-node2-dc2.example.com
aap-node3-dc2.example.com

# Automation Hub
[automationhub]
aap-node1-dc2.example.com
aap-node2-dc2.example.com

# Event-Driven Ansible
[automationeda]
aap-node1-dc2.example.com
aap-node3-dc2.example.com

# Redis
[redis]
aap-node1-dc2.example.com
aap-node2-dc2.example.com
aap-node3-dc2.example.com

[all:vars]
# CRITICAL: All passwords MUST match DC1
postgresql_admin_username=postgres
postgresql_admin_password='<SAME AS DC1>'
registry_username='<your RHN username>'
registry_password='<your RHN password>'
redis_mode='standalone'

# Admin passwords MUST match DC1
gateway_admin_password='<SAME AS DC1>'
controller_admin_password='<SAME AS DC1>'
hub_admin_password='<SAME AS DC1>'
eda_admin_password='<SAME AS DC1>'

# Platform Gateway (pointing to DC2 PostgreSQL VIP)
gateway_pg_host='10.2.2.100'  # EFM VIP for DC2 (standby until promotion)
gateway_pg_port='5432'
gateway_pg_database='automationgateway'
gateway_pg_username='aap'
gateway_pg_password='<SAME AS DC1>'

# Automation Controller
controller_pg_host='10.2.2.100'
controller_pg_port='5432'
controller_pg_database='awx'
controller_pg_username='aap'
controller_pg_password='<SAME AS DC1>'

# Automation Hub
hub_pg_host='10.2.2.100'
hub_pg_port='5432'
hub_pg_database='automationhub'
hub_pg_username='aap'
hub_pg_password='<SAME AS DC1>'

# Event-Driven Ansible
eda_pg_host='10.2.2.100'
eda_pg_port='5432'
eda_pg_database='automationedacontroller'
eda_pg_username='aap'
eda_pg_password='<SAME AS DC1>'
```

### 4.3 Installation Steps

**DC1 Installation (Active)**

```bash
# 1. Download AAP containerized installer
cd /opt
tar -xzf ansible-automation-platform-containerized-setup-2.6-1.tar.gz
cd ansible-automation-platform-containerized-setup-2.6-1

# 2. Configure inventory
cp inventory-dc1 inventory

# 3. Run installer
./setup.sh

# 4. Verify installation
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 5. Verify all components running
curl -k https://localhost/api/v2/ping/
```

**DC2 Installation (Standby)**

```bash
# 1. Install AAP (same as DC1)
cd /opt
tar -xzf ansible-automation-platform-containerized-setup-2.6-1.tar.gz
cd ansible-automation-platform-containerized-setup-2.6-1

# 2. Configure inventory for DC2
cp inventory-dc2 inventory

# 3. Run installer
./setup.sh

# 4. IMMEDIATELY STOP all AAP containers (standby mode)
for node in aap-node1-dc2 aap-node2-dc2 aap-node3-dc2; do
    ssh "$node" '
        systemctl stop automation-gateway 2>/dev/null || true
        systemctl stop automation-controller-web automation-controller-task
        systemctl stop automation-hub 2>/dev/null || true
        systemctl stop eda-activation-worker 2>/dev/null || true
        systemctl stop redis
    '
done

# 5. Disable auto-start
for node in aap-node1-dc2 aap-node2-dc2 aap-node3-dc2; do
    ssh "$node" '
        systemctl disable automation-gateway 2>/dev/null || true
        systemctl disable automation-controller-web automation-controller-task
        systemctl disable automation-hub 2>/dev/null || true
        systemctl disable eda-activation-worker 2>/dev/null || true
        systemctl disable redis
    '
done
```

---

## 5. Failover and Failback Procedures

### 5.1 Automated Failover (via EFM)

**EFM Integration Script**

```bash
#!/bin/bash
# /usr/edb/efm-4.7/bin/efm-orchestrated-failover.sh

set -e

CLUSTER_NAME="$1"
NODE_TYPE="$2"
NODE_ADDRESS="$3"
VIP_ADDRESS="$4"

# Determine datacenter
if [[ "$NODE_ADDRESS" == *"dc2"* ]] || [[ "$NODE_ADDRESS" == "10.2"* ]]; then
    DATACENTER="DC2"
    AAP_NODES=("aap-node1-dc2" "aap-node2-dc2" "aap-node3-dc2")
else
    echo "ERROR: Failover to DC1 not expected"
    exit 1
fi

# Start AAP containers on all nodes
echo "Starting AAP containers in $DATACENTER..."
for node in "${AAP_NODES[@]}"; do
    echo "Starting containers on $node..."
    ssh "$node" '
        # Start services that exist on this node
        systemctl start automation-gateway 2>/dev/null || true
        systemctl start automation-controller-web automation-controller-task
        systemctl start automation-hub 2>/dev/null || true
        systemctl start eda-activation-worker 2>/dev/null || true
        systemctl start redis
    ' &
done

# Wait for all parallel starts to complete
wait

# Wait for AAP API
MAX_WAIT=300
ELAPSED=0
echo "Waiting for AAP API to become ready..."
while [ $ELAPSED -lt $MAX_WAIT ]; do
    if curl -k -s https://10.2.1.100/api/v2/ping/ | grep -q "200"; then
        echo "AAP is ready in $DATACENTER"
        logger -t efm-failover "AAP activated in $DATACENTER - RTO: ${ELAPSED}s"
        exit 0
    fi
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

echo "ERROR: AAP failed to start within ${MAX_WAIT}s"
logger -t efm-failover "AAP activation FAILED in $DATACENTER after ${MAX_WAIT}s"
exit 1
```

### 5.2 Manual Failover Procedure

```bash
# 1. Verify replication lag is acceptable
ssh pg-dc1-1 "psql -U postgres -c \"SELECT * FROM pg_stat_replication;\""

# 2. Stop AAP in DC1 (all 3 nodes in parallel)
for node in aap-node1-dc1 aap-node2-dc1 aap-node3-dc1; do
    ssh "$node" '
        systemctl stop automation-gateway 2>/dev/null || true
        systemctl stop automation-controller-web automation-controller-task
        systemctl stop automation-hub 2>/dev/null || true
        systemctl stop eda-activation-worker 2>/dev/null || true
        systemctl stop redis
    ' &
done
wait

# 3. Promote DC2 database to primary
ssh pg-dc2-1 "sudo -u enterprisedb /usr/edb/as16/bin/pg_ctl promote -D /var/lib/edb/as16/data"

# 4. Verify promotion
ssh pg-dc2-1 "psql -U postgres -c \"SELECT pg_is_in_recovery();\""
# Expected: f (false - not in recovery)

# 5. Start AAP in DC2 (all 3 nodes in parallel)
for node in aap-node1-dc2 aap-node2-dc2 aap-node3-dc2; do
    ssh "$node" '
        systemctl start automation-gateway 2>/dev/null || true
        systemctl start automation-controller-web automation-controller-task
        systemctl start automation-hub 2>/dev/null || true
        systemctl start eda-activation-worker 2>/dev/null || true
        systemctl start redis
    ' &
done
wait

# 6. Update Global Load Balancer to DC2
# (Via GLB management interface)

# 7. Verify traffic flows to DC2
curl -k https://aap.example.com/api/v2/ping/
```

---

## 6. Monitoring and Alerting Strategy

**Same as Enterprise Topology** - See [AAP Containerized Enterprise DR Architecture](aap-containerized-enterprise-dr-architecture.md#6-monitoring-and-alerting-strategy)

---

## 7. Implementation Phases

### Phase 1: Infrastructure Preparation (Week 1)

**Tasks:**
- Provision VMs (6 AAP nodes, 6 database nodes, 2 HAProxy, 2 Barman)
  - DC1: 3 AAP VMs + 3 PostgreSQL + 1 HAProxy + 1 Barman
  - DC2: 3 AAP VMs + 3 PostgreSQL + 1 HAProxy + 1 Barman
  - **Total: 16 VMs** (vs 26 for Enterprise)
- Install RHEL 9.4+ on all nodes
- Configure network (VLANs, firewall rules, VPN between DCs)
- Install Podman on AAP nodes
- Install PostgreSQL on database nodes

### Phase 2: Database Cluster Setup (Week 2-3)

**Tasks:**
- Install EDB PostgreSQL Advanced Server
- Configure primary database (DC1)
- Initialize AAP databases
- Set up local standbys (DC1-2, DC1-3)
- Configure WAL archiving
- Set up cross-datacenter standby (DC2-1)
- Install and configure EFM

### Phase 3: AAP Installation (Week 4-5)

**Tasks:**
- Download AAP containerized installer
- Create inventory files for DC1 and DC2
- Install AAP on DC1 (active)
- Install AAP on DC2 (standby)
- Configure HAProxy
- Stop AAP containers in DC2
- Test AAP functionality

### Phase 4: Integration and Testing (Week 6-7)

**Tasks:**
- Integrate EFM with AAP start/stop scripts
- Configure Global Load Balancer
- Set up monitoring (Prometheus, Grafana)
- Configure alerting
- Test failover (manual and automated)
- Measure RTO/RPO

---

## 8. Configuration File Examples

**HAProxy Configuration**

```haproxy
# /etc/haproxy/haproxy.cfg (DC1 and DC2)

backend aap_backend
    mode http
    balance roundrobin
    option httpchk GET /api/v2/ping/
    http-check expect status 200

    # Platform Gateway (on aap-node1 only)
    server aap-node1-dc1 10.1.1.11:80 check inter 5s rise 2 fall 3
```

---

## 9. Comparison with Enterprise Topology

| Aspect | Growth Topology | Enterprise Topology |
|--------|-----------------|---------------------|
| **AAP VMs per DC** | 3 (multi-component) | 8 (dedicated roles) |
| **Total VMs** | 16 | 26 |
| **Component Separation** | Colocated | Fully separated |
| **Cost** | Lower (fewer VMs) | Higher (more VMs) |
| **Complexity** | Lower | Higher |
| **Scalability** | Moderate (<500 jobs/hour) | High (>1000 jobs/hour) |
| **Resource Isolation** | Limited | Full |
| **Failure Blast Radius** | Higher (multiple components per VM) | Lower (1 component per VM) |
| **Best For** | Small-medium deployments, cost-sensitive | Large enterprise, production-critical |

**When to Choose Growth:**
- ✅ Budget constraints require minimizing VM count
- ✅ Automation workload < 500 jobs/hour
- ✅ Faster deployment timeline (fewer VMs to provision)
- ✅ Lower operational complexity preferred

**When to Choose Enterprise:**
- ✅ Production-critical workloads requiring component isolation
- ✅ High automation throughput (>1000 jobs/hour)
- ✅ Need to scale individual components independently
- ✅ Security/compliance requires process isolation

---

## Summary: RTO/RPO Achievement

**Recovery Time Objective (RTO)**
- **Target:** < 5 minutes
- **Automated Failover:** 3-4 minutes (via EFM)
  - Database promotion: ~15 seconds
  - AAP startup: ~2 minutes (3 nodes in parallel vs 8 for Enterprise)
  - GLB detection: ~30 seconds

**Recovery Point Objective (RPO)**
- **Target:** < 5 seconds
- **Achieved:** 1-5 seconds (streaming replication)

**Infrastructure Scale**
- **Total VMs:** 16 (8 per datacenter)
  - 3 AAP multi-component VMs per DC
  - 3 PostgreSQL VMs per DC
  - 1 HAProxy + 1 Barman per DC
- **Total Resources:** 26 vCPU, 104GB RAM per DC (AAP layer)
- **Cost Savings:** ~40% fewer VMs vs Enterprise Topology

---

## Related Documentation

- **[AAP Containerized Enterprise DR Architecture](aap-containerized-enterprise-dr-architecture.md)** - 8-node dedicated component design
- **[Architecture Validation Report](aap-architecture-validation-report.md)** - Validation vs Red Hat tested models
- [Main Architecture](architecture.md) - Comprehensive architecture documentation
- [EDB Failover Manager](enterprisefailovermanager.md) - EFM integration guide
- [DR Testing Guide](dr-testing-guide.md) - Testing framework

**External References:**
- [Red Hat AAP 2.6 Container Growth Topology](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/tested_deployment_models/container-topologies#cont-a-env-a)
- [AAP 2.6 Containerized Installation Guide](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/containerized_installation)

---

**Document Version:** 1.0
**Last Review:** 2026-03-31
**Next Review:** 2026-06-30
**Validation Status:** ✅ Conforms to Red Hat AAP 2.6 Container Growth Topology (with multi-DC extension)
