# EDB Postgres Multi-Datacenter Architecture

## Overview

This document describes the architecture of EnterpriseDB Postgres for Kubernetes deployed across two OpenShift clusters in different datacenters, with Ansible Automation Platform (AAP) providing centralized management and automation.

## Architecture Diagram

```mermaid
graph TB
    GLB["Global Load Balancer<br/>aap.example.com<br/>Active-Passive HA"]

    subgraph DC1["Datacenter 1 - Primary"]
        subgraph OCP1["OpenShift Cluster 1<br/>ocp1.example.com"]
            subgraph NS1_AAP["Namespace: ansible-automation-platform"]
                AAP1_Controller["AAP Controller (DC1)<br/>Replicas: 3<br/>Route: aap-dc1.apps.ocp1.example.com"]
                AAP1_Hub["Automation Hub (DC1)<br/>Replicas: 2"]
                AAP1_DB["AAP PostgreSQL DB (DC1)<br/>Primary + 2 Replicas"]
                AAP1_Controller --- AAP1_Hub
                AAP1_Controller --- AAP1_DB
            end
            
            subgraph NS1_OPS["Namespace: postgresql-operator-system"]
                EDB_OP1["EDB Postgres Operator v1.28.0<br/>SCC: restricted-v2<br/>UID: 1000190000"]
            end
            
            subgraph NS1_APP1["Namespace: production"]
                PG_CLUSTER1["PostgreSQL Cluster: prod-db<br/>Instances: 3 (1 Primary + 2 Replicas)"]
                PG_PRIMARY1["pod: prod-db-1<br/>Role: Primary<br/>PostgreSQL 16.8"]
                PG_REPLICA1A["pod: prod-db-2<br/>Role: Replica"]
                PG_REPLICA1B["pod: prod-db-3<br/>Role: Replica"]
                PG_SVC1_RW["Service: prod-db-rw<br/>(Read-Write)"]
                PG_SVC1_RO["Service: prod-db-ro<br/>(Read-Only)"]
                
                PG_CLUSTER1 --> PG_PRIMARY1
                PG_CLUSTER1 --> PG_REPLICA1A
                PG_CLUSTER1 --> PG_REPLICA1B
                PG_SVC1_RW --> PG_PRIMARY1
                PG_SVC1_RO --> PG_REPLICA1A
                PG_SVC1_RO --> PG_REPLICA1B
            end
            
            subgraph NS1_APP2["Namespace: staging"]
                PG_CLUSTER2["PostgreSQL Cluster: stage-db<br/>Instances: 2"]
                PG_STAGE1["pod: stage-db-1<br/>Role: Primary"]
                PG_STAGE2["pod: stage-db-2<br/>Role: Replica"]
                PG_CLUSTER2 --> PG_STAGE1
                PG_CLUSTER2 --> PG_STAGE2
            end
            
            EDB_OP1 -.manages.-> PG_CLUSTER1
            EDB_OP1 -.manages.-> PG_CLUSTER2
            EDB_OP1 -.manages.-> AAP1_DB
        end
        
        OCP1_API["OpenShift API<br/>api.ocp1.example.com:6443"]
        OCP1_ROUTE["OpenShift Router<br/>*.apps.ocp1.example.com"]
        
        OCP1_API -.control plane.-> NS1_OPS
        OCP1_ROUTE -.ingress.-> NS1_APP1
        OCP1_ROUTE -.ingress.-> NS1_AAP
    end

    subgraph DC2["Datacenter 2 - DR Site"]
        subgraph OCP2["OpenShift Cluster 2<br/>ocp2.example.com"]
            subgraph NS2_AAP["Namespace: ansible-automation-platform"]
                AAP2_Controller["AAP Controller (DC2)<br/>Replicas: 3<br/>Route: aap-dc2.apps.ocp2.example.com"]
                AAP2_Hub["Automation Hub (DC2)<br/>Replicas: 2"]
                AAP2_DB["AAP PostgreSQL DB (DC2)<br/>Primary + 2 Replicas"]
                AAP2_Controller --- AAP2_Hub
                AAP2_Controller --- AAP2_DB
            end
            
            subgraph NS2_OPS["Namespace: postgresql-operator-system"]
                EDB_OP2["EDB Postgres Operator v1.28.0<br/>SCC: restricted-v2<br/>UID: 1000290000"]
            end
            
            subgraph NS2_APP1["Namespace: production"]
                PG_CLUSTER3["PostgreSQL Cluster: prod-db<br/>Instances: 3 (1 Primary + 2 Replicas)"]
                PG_PRIMARY2["pod: prod-db-1<br/>Role: Primary<br/>PostgreSQL 16.8"]
                PG_REPLICA2A["pod: prod-db-2<br/>Role: Replica"]
                PG_REPLICA2B["pod: prod-db-3<br/>Role: Replica"]
                PG_SVC2_RW["Service: prod-db-rw<br/>(Read-Write)"]
                PG_SVC2_RO["Service: prod-db-ro<br/>(Read-Only)"]
                
                PG_CLUSTER3 --> PG_PRIMARY2
                PG_CLUSTER3 --> PG_REPLICA2A
                PG_CLUSTER3 --> PG_REPLICA2B
                PG_SVC2_RW --> PG_PRIMARY2
                PG_SVC2_RO --> PG_REPLICA2A
                PG_SVC2_RO --> PG_REPLICA2B
            end
            
            subgraph NS2_APP2["Namespace: development"]
                PG_CLUSTER4["PostgreSQL Cluster: dev-db<br/>Instances: 1"]
                PG_DEV1["pod: dev-db-1<br/>Role: Primary"]
                PG_CLUSTER4 --> PG_DEV1
            end
            
            EDB_OP2 -.manages.-> PG_CLUSTER3
            EDB_OP2 -.manages.-> PG_CLUSTER4
            EDB_OP2 -.manages.-> AAP2_DB
        end
        
        OCP2_API["OpenShift API<br/>api.ocp2.example.com:6443"]
        OCP2_ROUTE["OpenShift Router<br/>*.apps.ocp2.example.com"]
        
        OCP2_API -.control plane.-> NS2_OPS
        OCP2_ROUTE -.ingress.-> NS2_APP1
        OCP2_ROUTE -.ingress.-> NS2_AAP
    end

    %% Global Load Balancer Connections
    GLB ==HTTPS Traffic==> AAP1_Controller
    GLB ==HTTPS Traffic==> AAP2_Controller

    %% AAP to OpenShift API Connections
    AAP1_Controller -.kubectl/oc.-> OCP1_API
    AAP1_Controller -.kubectl/oc.-> OCP2_API
    AAP2_Controller -.kubectl/oc.-> OCP1_API
    AAP2_Controller -.kubectl/oc.-> OCP2_API
    
    %% AAP to PostgreSQL Connections
    AAP1_Controller ==PostgreSQL Connection==> PG_SVC1_RW
    AAP1_Controller ==PostgreSQL Connection==> PG_SVC1_RO
    AAP1_Controller ==PostgreSQL Connection==> PG_SVC2_RW
    AAP1_Controller ==PostgreSQL Connection==> PG_SVC2_RO
    
    AAP2_Controller ==PostgreSQL Connection==> PG_SVC1_RW
    AAP2_Controller ==PostgreSQL Connection==> PG_SVC1_RO
    AAP2_Controller ==PostgreSQL Connection==> PG_SVC2_RW
    AAP2_Controller ==PostgreSQL Connection==> PG_SVC2_RO
    
    %% AAP Playbook Management
    AAP1_Controller -.Ansible Playbooks.-> PG_CLUSTER1
    AAP1_Controller -.Ansible Playbooks.-> PG_CLUSTER2
    AAP1_Controller -.Ansible Playbooks.-> PG_CLUSTER3
    AAP1_Controller -.Ansible Playbooks.-> PG_CLUSTER4
    
    AAP2_Controller -.Ansible Playbooks.-> PG_CLUSTER1
    AAP2_Controller -.Ansible Playbooks.-> PG_CLUSTER2
    AAP2_Controller -.Ansible Playbooks.-> PG_CLUSTER3
    AAP2_Controller -.Ansible Playbooks.-> PG_CLUSTER4

    %% AAP Database Replication
    AAP1_DB <-.Database Replication<br/>(Shared State).-> AAP2_DB

    %% PostgreSQL Replication between datacenters
    PG_PRIMARY1 <-.Logical Replication<br/>(Publications/Subscriptions).-> PG_PRIMARY2

    %% Backup Storage
    S3_DC1["S3 Storage<br/>Datacenter 1<br/>Backups & WAL Archive"]
    S3_DC2["S3 Storage<br/>Datacenter 2<br/>Backups & WAL Archive"]
    
    PG_CLUSTER1 -.Backup.-> S3_DC1
    PG_CLUSTER3 -.Backup.-> S3_DC2
    AAP1_DB -.Backup.-> S3_DC1
    AAP2_DB -.Backup.-> S3_DC2

    %% Monitoring
    PROM_DC1["Prometheus<br/>Datacenter 1"]
    PROM_DC2["Prometheus<br/>Datacenter 2"]
    
    PG_CLUSTER1 -.metrics.-> PROM_DC1
    PG_CLUSTER2 -.metrics.-> PROM_DC1
    AAP1_Controller -.metrics.-> PROM_DC1
    AAP1_DB -.metrics.-> PROM_DC1
    
    PG_CLUSTER3 -.metrics.-> PROM_DC2
    PG_CLUSTER4 -.metrics.-> PROM_DC2
    AAP2_Controller -.metrics.-> PROM_DC2
    AAP2_DB -.metrics.-> PROM_DC2

    classDef lbStyle fill:#ff0066,stroke:#333,stroke-width:3px,color:#fff
    classDef aapStyle fill:#ee0000,stroke:#333,stroke-width:2px,color:#fff
    classDef operatorStyle fill:#0066cc,stroke:#333,stroke-width:2px,color:#fff
    classDef primaryStyle fill:#00aa00,stroke:#333,stroke-width:2px,color:#fff
    classDef replicaStyle fill:#66cc66,stroke:#333,stroke-width:1px,color:#000
    classDef storageStyle fill:#ff9900,stroke:#333,stroke-width:2px,color:#fff
    classDef monitorStyle fill:#9966ff,stroke:#333,stroke-width:2px,color:#fff
    
    class GLB lbStyle
    class AAP1_Controller,AAP1_Hub,AAP1_DB,AAP2_Controller,AAP2_Hub,AAP2_DB aapStyle
    class EDB_OP1,EDB_OP2 operatorStyle
    class PG_PRIMARY1,PG_PRIMARY2,PG_STAGE1,PG_DEV1 primaryStyle
    class PG_REPLICA1A,PG_REPLICA1B,PG_REPLICA2A,PG_REPLICA2B,PG_STAGE2 replicaStyle
    class S3_DC1,S3_DC2 storageStyle
    class PROM_DC1,PROM_DC2 monitorStyle
```

## Traffic Flow Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         End Users                                │
│              (Administrators, Developers, CI/CD)                 │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTPS
                             ▼
          ┌──────────────────────────────────────────┐
          │     Global Load Balancer (GLB)           │
          │     aap.example.com                      │
          │     • Health Checks                      │
          │     • Geographic Routing                 │
          │     • Auto Failover                      │
          └──────────┬─────────────────────┬─────────┘
                     │                     │
        ┌────────────▼────────┐   ┌────────▼────────────┐
        │   Datacenter 1      │   │   Datacenter 2      │
        │   AAP Instance      │   │   AAP Instance      │
        │   (Active)          │   │   (Active)          │
        └────────────┬────────┘   └────────┬────────────┘
                     │                     │
        ┌────────────▼────────┐   ┌────────▼────────────┐
        │ OpenShift Cluster 1 │   │ OpenShift Cluster 2 │
        │ ┌─────────────────┐ │   │ ┌─────────────────┐ │
        │ │ AAP Controller  │ │   │ │ AAP Controller  │ │
        │ │ (3 replicas)    │ │   │ │ (3 replicas)    │ │
        │ └────────┬────────┘ │   │ └────────┬────────┘ │
        │          │          │   │          │          │
        │ ┌────────▼────────┐ │   │ ┌────────▼────────┐ │
        │ │ AAP Database    │ │   │ │ AAP Database    │ │
        │ │ (EDB Postgres)  │◄┼───┼─┤ (EDB Postgres)  │ │
        │ │ 3 instances     │ │   │ │ 3 instances     │ │
        │ └─────────────────┘ │   │ └─────────────────┘ │
        │          │          │   │          │          │
        │          │ Manages  │   │          │ Manages  │
        │          ▼          │   │          ▼          │
        │ ┌─────────────────┐ │   │ ┌─────────────────┐ │
        │ │ EDB Operator    │ │   │ │ EDB Operator    │ │
        │ └────────┬────────┘ │   │ └────────┬────────┘ │
        │          │          │   │          │          │
        │          ▼          │   │          ▼          │
        │ ┌─────────────────┐ │   │ ┌─────────────────┐ │
        │ │ PostgreSQL      │◄┼───┼─┤ PostgreSQL      │ │
        │ │ Clusters        │ │   │ │ Clusters        │ │
        │ │ (prod/stage/dev)│ │   │ │ (prod/stage/dev)│ │
        │ └─────────────────┘ │   │ └─────────────────┘ │
        └─────────────────────┘   └─────────────────────┘
              │                           │
              ▼                           ▼
        ┌─────────────┐           ┌─────────────┐
        │ S3 Storage  │           │ S3 Storage  │
        │ Datacenter 1│           │ Datacenter 2│
        └─────────────┘           └─────────────┘

Legend:
  ─── Data Flow
  ◄─► Bi-directional Replication
```

## Component Details

### Global Load Balancer

The global load balancer provides a single entry point for AAP access:

- **DNS**: `aap.example.com`
- **Type**: Active-Active (both datacenters serving traffic)
- **Health Checks**: Monitors AAP Controller availability in both datacenters
- **Failover**: Automatic failover if one datacenter becomes unavailable
- **Routing**: Geographic or round-robin routing to nearest/healthiest AAP instance
- **Protocols**: HTTPS (port 443), WebSocket support for real-time job updates

### Ansible Automation Platform (AAP)

AAP is deployed on **both OpenShift clusters** for high availability and geographic distribution:

#### Datacenter 1 - AAP Instance
- **Namespace**: `ansible-automation-platform`
- **AAP Controller**: 3 replicas for HA
- **Automation Hub**: 2 replicas
- **Database**: PostgreSQL cluster (1 primary + 2 replicas) managed by EDB operator
- **Route**: `aap-dc1.apps.ocp1.example.com`

#### Datacenter 2 - AAP Instance
- **Namespace**: `ansible-automation-platform`
- **AAP Controller**: 3 replicas for HA
- **Automation Hub**: 2 replicas  
- **Database**: PostgreSQL cluster (1 primary + 2 replicas) managed by EDB operator
- **Route**: `aap-dc2.apps.ocp2.example.com`

#### AAP Database Replication

The AAP databases in both datacenters are synchronized to maintain shared state:
- **Method**: PostgreSQL logical replication
- **Direction**: Bi-directional (both can accept writes)
- **Shared Data**: Job templates, inventory, credentials, execution history
- **Conflict Resolution**: Last-write-wins with timestamp-based conflict resolution

#### AAP High Availability Benefits

1. **Geographic Redundancy**: AAP instances in multiple datacenters
2. **Load Distribution**: Traffic balanced across both locations
3. **Disaster Recovery**: Automatic failover if one datacenter is unavailable
4. **Reduced Latency**: Users connect to nearest AAP instance
5. **Zero Downtime Updates**: Rolling updates across datacenters

#### AAP Responsibilities

1. **Cluster Management**
   - Deploy and configure EDB Postgres operator
   - Create and manage PostgreSQL clusters
   - Apply security policies (SCCs, network policies)

2. **Database Operations**
   - Execute SQL scripts across multiple databases
   - Manage database users and permissions
   - Perform schema migrations
   - Database configuration management

3. **Backup & Recovery**
   - Schedule and monitor backups
   - Restore databases from backups
   - Verify backup integrity
   - Manage retention policies

4. **Monitoring & Alerting**
   - Collect database metrics
   - Monitor cluster health
   - Alert on issues
   - Generate reports

5. **Disaster Recovery**
   - Coordinate failover between datacenters
   - Manage replication setup
   - Execute DR tests
   - Maintain DR documentation

### Datacenter 1 (Primary)

**OpenShift Cluster**: `ocp1.example.com`

#### Production Namespace
- **Cluster**: `prod-db` (3 instances)
  - 1 Primary + 2 Replicas
  - PostgreSQL 16.8
  - Auto-failover enabled
  - Continuous WAL archiving to S3

#### Staging Namespace
- **Cluster**: `stage-db` (2 instances)
  - 1 Primary + 1 Replica
  - Used for testing before production

### Datacenter 2 (DR Site)

**OpenShift Cluster**: `ocp2.example.com`

#### Production Namespace
- **Cluster**: `prod-db` (3 instances)
  - Replicated from DC1 using logical replication
  - Can be promoted to primary during DR
  - Independent backup to S3

#### Development Namespace
- **Cluster**: `dev-db` (1 instance)
  - Single instance for development work
  - No replication

## Network Connectivity

### User to AAP (via Global Load Balancer)

Users and automation clients connect to AAP through the global load balancer:
- **URL**: `https://aap.example.com`
- **Protocol**: HTTPS/443 with WebSocket support
- **Load Balancing**: Active-Active across both datacenters
- **Health Checks**: Layer 7 health checks to AAP Controller endpoints
- **Session Affinity**: Optional sticky sessions for long-running jobs
- **TLS Termination**: At load balancer or end-to-end encryption

### Global Load Balancer to AAP Instances

The load balancer distributes traffic to AAP instances:
- **Datacenter 1**: `aap-dc1.apps.ocp1.example.com`
- **Datacenter 2**: `aap-dc2.apps.ocp2.example.com`
- **Health Check Path**: `/api/v2/ping/`
- **Failover Time**: < 10 seconds
- **Traffic Distribution**: 50/50 or weighted based on capacity

### AAP to OpenShift Clusters

AAP instances connect to both OpenShift clusters (local and remote):
- **Control Plane**: OpenShift API (`api.ocp1.example.com:6443`, `api.ocp2.example.com:6443`)
- **Authentication**: Service account tokens or kubeconfig files
- **Network**: Direct connectivity required (VPN/WAN/Direct Connect)
- **Permissions**: Cluster-admin or namespace-specific RBAC

### AAP to PostgreSQL Databases

Each AAP instance can connect to PostgreSQL databases in both datacenters:
- **Protocol**: PostgreSQL wire protocol (port 5432)
- **Access**: Via Kubernetes Services (ClusterIP within cluster, Routes/LoadBalancer for remote)
- **Authentication**: Certificate-based or password authentication
- **Encryption**: TLS/SSL enforced
- **Connection Pooling**: PgBouncer for efficient connection management

### Inter-Datacenter Replication

Multiple replication streams between datacenters:

#### AAP Database Replication
- **Method**: PostgreSQL logical replication (bi-directional)
- **Direction**: DC1 ↔ DC2 (both active)
- **Conflict Resolution**: Timestamp-based, last-write-wins
- **Lag Monitoring**: Prometheus metrics + AAP monitoring jobs

#### Application Database Replication
- **Method**: PostgreSQL logical replication
- **Direction**: DC1 (Primary) → DC2 (DR)
- **Network**: Encrypted tunnel (VPN/Direct Connect/WAN)
- **Lag Monitoring**: Both AAP instances monitor replication lag
- **Alerting**: Alerts triggered if lag exceeds threshold (e.g., 30 seconds)

## Security Architecture

### Security Context Constraints

Both operators run with `restricted-v2` SCC:
- **UID Range**: Auto-assigned from namespace range
- **Privilege Escalation**: Disabled
- **Capabilities**: All dropped
- **Seccomp**: RuntimeDefault enabled

### Network Policies

- Pod-to-pod communication restricted
- External access via Routes only
- Database connections encrypted with TLS
- Inter-datacenter traffic encrypted

### Secrets Management

AAP manages:
- Database credentials (stored in AAP credential store)
- TLS certificates
- S3 access keys
- Service account tokens

## Data Flow

### Write Operations (Normal State)

1. Application → AAP Controller
2. AAP Controller → DC1 Primary Database
3. DC1 Primary → DC1 Replicas (streaming replication)
4. DC1 Primary → DC2 Primary (logical replication)
5. DC2 Primary → DC2 Replicas (streaming replication)

### Read Operations

- **DC1**: Read from replicas via `prod-db-ro` service
- **DC2**: Read from replicas via `prod-db-ro` service
- **Load Balancing**: OpenShift Service distributes reads

### Backup Flow

1. Scheduled backup job (initiated by AAP or CronJob)
2. Backup pod created by operator
3. Database backup streamed to S3
4. WAL files continuously archived
5. AAP monitors backup completion
6. Alerts sent if backup fails

## AAP Deployment Architecture

### AAP on OpenShift

Each AAP instance runs on OpenShift with the following components:

#### AAP Controller Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: automation-controller
  namespace: ansible-automation-platform
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: automation-controller
```

#### AAP Database (EDB Postgres)
```yaml
apiVersion: postgresql.k8s.enterprisedb.io/v1
kind: Cluster
metadata:
  name: aap-postgres
  namespace: ansible-automation-platform
spec:
  instances: 3
  storage:
    size: 100Gi
  backup:
    barmanObjectStore:
      destinationPath: s3://aap-backups/
```

#### Resource Requirements

**Per Datacenter:**
- **AAP Controller**: 3 pods × (4 CPU, 8GB RAM)
- **Automation Hub**: 2 pods × (2 CPU, 4GB RAM)
- **AAP Database**: 3 pods × (2 CPU, 4GB RAM)
- **Total**: ~18 CPUs, 36GB RAM per datacenter

### AAP State Synchronization

AAP maintains consistency across datacenters through:

1. **Shared PostgreSQL Database**: Replicated between DC1 and DC2
2. **Project Sync**: Git-based project synchronization
3. **Execution Environments**: Shared container registry or mirrored registries
4. **Credentials**: Encrypted in database, replicated across datacenters
5. **Job Output**: Stored in database and object storage

## Disaster Recovery Scenarios

### Scenario 1: Datacenter 1 Complete Failure

1. **Detection**: Global load balancer health checks fail for DC1 AAP
2. **Traffic Shift**: All traffic automatically routed to DC2 AAP instance
3. **AAP Continues**: DC2 AAP manages both OpenShift clusters
4. **Database Promotion**: DC2 production database can be promoted to primary
5. **Recovery**: When DC1 returns, reverse replication and rebalance traffic
6. **RTO**: < 2 minutes (load balancer failover time)
7. **RPO**: Depends on replication lag (typically < 30 seconds)

### Scenario 2: AAP Instance Failure in One Datacenter

1. **Detection**: Load balancer marks DC1 AAP as unhealthy
2. **Automatic Failover**: Traffic shifted to DC2 AAP
3. **Local Recovery**: OpenShift recreates failed AAP pods in DC1
4. **Database Intact**: AAP database in DC1 continues to replicate
5. **Service Restoration**: DC1 AAP rejoins pool when healthy
6. **Impact**: Users experience seamless continuation via DC2

### Scenario 3: Database Failure in DC1

1. **EDB Operator**: Detects primary PostgreSQL failure
2. **Automatic Failover**: Replica promoted to primary within DC1
3. **AAP Controller**: Reconnects to new primary automatically
4. **Replication**: Continues to DC2 from new primary
5. **Both AAP Instances**: Continue operating normally
6. **Downtime**: < 30 seconds for database failover

### Scenario 4: Complete Network Partition

**Scenario**: DC1 and DC2 lose connectivity

1. **AAP Instances**: Both continue to operate independently
2. **Database Writes**: Both AAP databases accept writes (split-brain)
3. **Conflict Resolution**: When connectivity restored, timestamp-based resolution
4. **Application DBs**: DC2 becomes read-only or applications use local DC only
5. **Manual Intervention**: May be required for complex conflicts
6. **Prevention**: Network monitoring and split-brain prevention policies

### Scenario 5: OpenShift Cluster Failure (DC1)

1. **AAP Impact**: DC1 AAP instance unavailable
2. **Load Balancer**: Routes all traffic to DC2 AAP
3. **DC2 AAP**: Manages DC2 OpenShift cluster, cannot manage DC1
4. **Application Failover**: Promote DC2 databases to primary
5. **Recovery**: Restore DC1 OpenShift, redeploy AAP, resync databases

### Scenario 6: Global Load Balancer Failure

1. **Direct Access**: Users access AAP directly via datacenter-specific URLs
   - `https://aap-dc1.apps.ocp1.example.com`
   - `https://aap-dc2.apps.ocp2.example.com`
2. **DNS Fallback**: Update DNS records to point to surviving datacenter
3. **AAP Continues**: Both instances operational, accept direct connections
4. **Restore LB**: Bring load balancer back online, resume normal routing

## Ansible Automation Examples

### Deploy PostgreSQL Cluster

```yaml
- name: Deploy PostgreSQL Cluster
  hosts: localhost
  tasks:
    - name: Create PostgreSQL Cluster
      kubernetes.core.k8s:
        kubeconfig: "{{ kubeconfig_dc1 }}"
        state: present
        definition:
          apiVersion: postgresql.k8s.enterprisedb.io/v1
          kind: Cluster
          metadata:
            name: prod-db
            namespace: production
          spec:
            instances: 3
            storage:
              size: 100Gi
```

### Execute SQL Across Clusters

```yaml
- name: Execute SQL on all databases
  hosts: postgres_clusters
  tasks:
    - name: Run migration script
      community.postgresql.postgresql_query:
        login_host: "{{ pg_host }}"
        login_user: "{{ pg_user }}"
        login_password: "{{ pg_password }}"
        db: "{{ pg_database }}"
        query: "{{ lookup('file', 'migration.sql') }}"
```

### Monitor Database Health

```yaml
- name: Check PostgreSQL Health
  hosts: localhost
  tasks:
    - name: Get cluster status
      kubernetes.core.k8s_info:
        kubeconfig: "{{ item.kubeconfig }}"
        kind: Cluster
        namespace: production
        name: prod-db
      loop:
        - { kubeconfig: "{{ kubeconfig_dc1 }}" }
        - { kubeconfig: "{{ kubeconfig_dc2 }}" }
      register: cluster_status
```

## Monitoring and Metrics

### Prometheus Metrics

Each datacenter has Prometheus collecting:
- PostgreSQL metrics (queries, connections, replication lag)
- Operator metrics (reconciliation loops, errors)
- OpenShift metrics (pod status, resource usage)

### AAP Dashboards

AAP provides centralized dashboards showing:
- All database clusters across datacenters
- Backup status and history
- Replication lag
- Connection pool status
- Query performance

## Scaling Considerations

### Horizontal Scaling

Add more replicas:
```bash
kubectl patch cluster prod-db -n production \
  --type='json' -p='[{"op": "replace", "path": "/spec/instances", "value": 5}]'
```

### Vertical Scaling

Increase resources:
```yaml
spec:
  resources:
    requests:
      memory: "4Gi"
      cpu: "2000m"
    limits:
      memory: "8Gi"
      cpu: "4000m"
```

### Multi-Region Expansion

To add a third datacenter:
1. Deploy OpenShift cluster in new region
2. Install EDB operator via AAP
3. Create PostgreSQL cluster
4. Configure logical replication from DC1
5. Update AAP inventory

## Compliance and Auditing

### Audit Logging

- All AAP operations logged
- Database query logging enabled
- OpenShift audit logs collected
- Centralized log aggregation

### Compliance Requirements

- Data encryption at rest (storage encryption)
- Data encryption in transit (TLS)
- Access control (RBAC, SCCs)
- Change tracking (GitOps workflow)
- Backup retention (configurable)

## Cost Optimization

### Resource Management

- Development clusters: Lower resources
- Staging clusters: Medium resources  
- Production clusters: Full resources
- Auto-scaling based on load

### Backup Storage

- Incremental backups to reduce storage
- Compression enabled
- Lifecycle policies for old backups
- Cross-region replication for critical data

## Architecture Benefits

### High Availability Advantages

**Multi-Level Redundancy:**
1. **Global Load Balancer**: Single point of access with automatic failover
2. **AAP Instances**: Active-Active across datacenters
3. **AAP Controller Pods**: 3 replicas per datacenter (6 total)
4. **AAP Databases**: 3-instance PostgreSQL clusters per datacenter
5. **Application Databases**: 3-instance PostgreSQL clusters per datacenter
6. **Multiple Replicas**: Within each cluster for local failover

**Failure Domains:**
- Pod-level: Kubernetes restarts
- Node-level: Kubernetes reschedules
- Cluster-level: Cross-datacenter failover
- Datacenter-level: Global load balancer redirect

### Geographic Distribution Benefits

**Reduced Latency:**
- Users connect to nearest datacenter via load balancer
- AAP operations execute from geographically optimal location
- Database queries can target nearest replica for reads

**Compliance:**
- Data residency requirements met (data in specific regions)
- Audit logs available in multiple locations
- Disaster recovery meets regulatory requirements

### Operational Benefits

**Simplified Operations:**
1. **Consistent Deployment**: Same AAP on both clusters
2. **Self-Service**: AAP can manage its own infrastructure
3. **GitOps Ready**: All configurations in Git, deployed by AAP
4. **Automated DR Testing**: AAP runs regular DR drills

**Cost Optimization:**
- Shared infrastructure (AAP manages multiple workloads)
- Efficient resource utilization across datacenters
- Automated scaling based on demand
- Reduced operational overhead with automation

### Security Benefits

**Defense in Depth:**
1. **Load Balancer**: DDoS protection, WAF integration
2. **OpenShift Security**: RBAC, SCCs, network policies
3. **AAP Security**: Role-based access, credential vaulting
4. **Database Security**: Encryption at rest and in transit
5. **Network Segmentation**: Isolated namespaces and networks

**Audit and Compliance:**
- Centralized audit logging in AAP
- All automation tracked and versioned
- Compliance reports generated automatically
- Immutable infrastructure (GitOps)

## Scaling Considerations

### Horizontal Scaling

**AAP Controller:**
```yaml
# Scale AAP controller replicas
kubectl scale deployment automation-controller \
  -n ansible-automation-platform --replicas=5
```

**PostgreSQL Clusters:**
```yaml
# Scale database replicas
kubectl patch cluster prod-db -n production \
  --type='json' -p='[{"op": "replace", "path": "/spec/instances", "value": 5}]'
```

### Vertical Scaling

**AAP Controller Resources:**
```yaml
resources:
  requests:
    cpu: "8000m"
    memory: "16Gi"
  limits:
    cpu: "16000m"
    memory: "32Gi"
```

### Geographic Scaling

**Adding Datacenter 3:**
1. Deploy OpenShift cluster in new region
2. Deploy AAP instance using Ansible playbook
3. Configure AAP database replication (tri-directional)
4. Add to global load balancer backend pool
5. Deploy EDB operator and PostgreSQL clusters
6. Configure logical replication from DC1

## Conclusion

This architecture provides:

✅ **Maximum High Availability**: AAP and databases redundant across datacenters  
✅ **Geographic Distribution**: Active-Active AAP instances for optimal performance  
✅ **Automatic Failover**: Global load balancer provides seamless failover  
✅ **Disaster Recovery**: Multiple DR scenarios covered with automated response  
✅ **Simplified Management**: AAP instances run on infrastructure they manage  
✅ **Security**: Restricted SCCs, encrypted connections, defense in depth  
✅ **Scalability**: Easy to scale vertically, horizontally, and geographically  
✅ **Automation**: Ansible playbooks for deployment, management, and DR  
✅ **Monitoring**: Comprehensive metrics and alerting across all layers  
✅ **Compliance**: Audit logging, access controls, and regulatory compliance  
✅ **Cost Efficiency**: Shared infrastructure with optimal resource utilization  
✅ **Operational Excellence**: GitOps, infrastructure as code, automated testing  

### Key Architectural Decisions

1. **AAP on OpenShift**: Running AAP on the infrastructure it manages enables:
   - Self-healing (OpenShift manages AAP pods)
   - Consistent deployment model
   - Resource efficiency
   - Simplified disaster recovery

2. **Global Load Balancer**: Single entry point provides:
   - Geographic routing
   - Automatic failover
   - Health-based routing
   - SSL/TLS termination

3. **Bi-directional AAP Database Replication**: Enables:
   - Active-Active operations
   - Shared state across datacenters
   - Continued operations during network partitions
   - Conflict resolution for edge cases

4. **EDB Postgres Operator**: Provides:
   - Automated PostgreSQL management
   - Built-in high availability
   - Backup and recovery automation
   - Consistent security policies (restricted-v2 SCC)

The combination of Global Load Balancing, distributed AAP instances, and EDB Postgres for Kubernetes provides an enterprise-grade, highly available, geographically distributed PostgreSQL database platform with comprehensive automation and disaster recovery capabilities.
