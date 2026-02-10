# EDB Postgres Multi-Datacenter Architecture

## Overview

This document describes the architecture of EnterpriseDB Postgres for Kubernetes deployed across two OpenShift clusters in different datacenters, with Ansible Automation Platform (AAP) providing centralized management and automation.

## Table of Contents

- [Architecture Diagram](#architecture-diagram)
- [Component Details](#component-details)
- [EDB Postgres for Kubernetes Architecture](#edb-postgres-for-kubernetes-architecture)
- [Network Connectivity](#network-connectivity)
- [AAP Deployment Architecture](#aap-deployment-architecture)
- [Disaster Recovery Scenarios](#disaster-recovery-scenarios)
- [Scaling Considerations](#scaling-considerations)
- [Compliance and Auditing](#compliance-and-auditing)
- [Conclusion](#conclusion)

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

AAP is deployed on **both OpenShift clusters** for high availability and geographic distribution:

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

## EDB Postgres for Kubernetes Architecture

### Distributed PostgreSQL Topology

This architecture implements EDB Postgres for Kubernetes (CloudNativePG) distributed topology with replica clusters across two separate Kubernetes/OpenShift clusters, as documented in the [EDB official architecture guide](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/architecture/#deployments-across-kubernetes-clusters).

**Key Concepts:**

1. **Primary Cluster (DC1)**: 
   - Contains one primary instance accepting read/write operations
   - Contains hot standby replicas for local HA
   - Automatically managed by EDB operator within DC1

2. **Replica Cluster (DC2)**:
   - Contains a "designated primary" - a standby server in continuous recovery
   - Contains hot standby replicas cascading from designated primary
   - In read-only mode until manually promoted
   - Automatically managed by EDB operator within DC2

3. **Physical Replication**:
   - Uses PostgreSQL's native WAL-based replication
   - Primary method: Streaming replication (network-based)
   - Fallback method: WAL shipping via S3/object store
   - Byte-for-byte exact replica, faster than logical replication

4. **Automatic Service Management**:
   EDB operator automatically creates and maintains these services:
   - `<cluster>-rw`: Routes to current primary (read/write)
   - `<cluster>-ro`: Routes to hot standby replicas (read-only)
   - `<cluster>-r`: Routes to any instance (read-only)
   - During failover, operator updates `-rw` service automatically

5. **Cross-Cluster Limitations**:
   - Each EDB operator manages only its local Kubernetes cluster
   - Cross-cluster failover must be coordinated externally (via AAP, GitOps, or higher-level orchestration)
   - Promotion of replica cluster to primary is declarative but requires external trigger

### Datacenter 1 (Primary)

**OpenShift Cluster**: `ocp1.example.com`

#### Production Namespace
- **Cluster**: `prod-db` (3 instances - Primary Cluster)
  - 1 Primary Instance (read/write) + 2 Hot Standby Replicas
  - PostgreSQL 16.8
  - Auto-failover enabled within cluster
  - Continuous WAL archiving to S3/object store
  - Services automatically managed by EDB operator:
    - `-rw`: Routes to current primary (read/write)
    - `-ro`: Routes to hot standby replicas (read-only)
    - `-r`: Routes to any instance (read-only)

### Datacenter 2 (DR Site)

**OpenShift Cluster**: `ocp2.example.com`

#### Production Namespace
- **Cluster**: `prod-db-replica` (3 instances - Replica Cluster)
  - 1 Designated Primary (standby server in continuous recovery)
  - 2 Hot Standby Replicas
  - Replicated from DC1 via streaming replication and WAL shipping
  - Can be promoted to primary cluster during DR
  - Independent backup to S3
  - Services: `-ro` (read-only), `-r` (any instance read-only)

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

### AAP on OpenShift

#### Resource Requirements

**Per Datacenter:**
- **AAP Controller**: 3 pods × (4 CPU, 8GB RAM)
- **Automation Hub**: 2 pods × (2 CPU, 4GB RAM)
- **AAP Database**: 3 pods × (2 CPU, 4GB RAM)
- **Total**: ~18 CPUs, 36GB RAM per datacenter

## Disaster Recovery Scenarios

### Scenario 1: Datacenter 1 Complete Failure

1. **Detection**: Global load balancer health checks fail for DC1 AAP (3 consecutive failures = 15 seconds)
2. **Traffic Shift**: GLB automatically routes all traffic to DC2 AAP instance
3. **Database Promotion**: DC2 AAP database promoted from read-only replica to read-write primary
4. **AAP Activation**: DC2 AAP takes over management of both OpenShift clusters
5. **Production Databases**: DC2 production database can be promoted if needed
6. **Recovery**: When DC1 returns:
   - Synchronize data from DC2 back to DC1
   - Rebuild replication DC1 → DC2
   - Failback to DC1 (manual or automatic)
7. **RTO**: < 1 minute (15s detection + 45s promotion/cutover)
8. **RPO**: Depends on replication lag (typically < 5 seconds)

### Scenario 2: AAP Instance Failure in DC1 (OpenShift restarts pods)

1. **Detection**: Load balancer marks DC1 AAP as unhealthy
2. **Automatic Failover**: Traffic shifted to DC2 AAP (passive becomes active)
3. **Local Recovery**: OpenShift recreates failed AAP pods in DC1
4. **Database Intact**: AAP database in DC1 remains operational, continues replication
5. **Service Restoration**: Once DC1 AAP pods are healthy and pass health checks
6. **Failback**: 
   - **Option A (Manual)**: Administrator triggers failback to DC1
   - **Option B (Automatic)**: GLB automatically fails back after DC1 stable for X minutes
7. **Impact**: Users experience brief interruption (< 15 seconds) during failover

### Scenario 3: Database Failure in DC1 (Within Cluster)

**For EDB-Managed Databases:**
1. **EDB Operator**: Detects primary PostgreSQL failure
2. **Automatic Failover**: Hot standby replica promoted to primary within DC1 cluster
3. **Service Update**: EDB operator automatically updates `-rw` service to point to new primary
4. **AAP Controller**: Reconnects to new primary automatically (via unchanged service name)
5. **Replication**: Continues to DC2 from new primary
6. **Both AAP Instances**: Continue operating normally
7. **Downtime**: < 30 seconds for database failover

**Important**: This is automatic failover within a single Kubernetes cluster. Cross-cluster failover (DC1 → DC2) requires external coordination.

### Scenario 4: Complete Network Partition

**Scenario**: DC1 and DC2 lose connectivity

1. **GLB Behavior**: 
   - If GLB can reach DC1: Continues routing to DC1 (active)
   - If GLB can reach DC2 only: Fails over to DC2
   - If both reachable but partitioned from each other: Routes to DC1 (priority)
2. **AAP Instances**: 
   - DC1 (Active): Continues normal operations
   - DC2 (Passive): Remains in standby mode (read-only database)
3. **Split-Brain Prevention**: 
   - DC2 AAP database remains read-only unless manually promoted
   - No automatic writes to DC2 database during partition
4. **Replication**: 
   - Stops during partition (DC2 falls behind)
   - Resumes when connectivity restored
   - Catch-up replication brings DC2 current
5. **Manual Intervention**: 
   - If DC1 confirmed down, manually promote DC2
   - When connectivity restored, assess and resynchronize
6. **Prevention**: Network monitoring, redundant links, and health check tuning

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
3. Create PostgreSQL replica cluster (designated primary + replicas)
4. Configure physical replication from DC1:
   - Streaming replication from DC1 primary
   - WAL shipping from shared S3/object store as fallback
5. Update AAP inventory
6. Configure cross-cluster promotion procedures (manual or via GitOps)

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
2. **AAP Instances**: Active-Passive across datacenters
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

**Disaster Recovery:**
- Complete standby datacenter ready for failover
- RPO < 5 seconds (replication lag)
- RTO < 1 minute (automated failover)
- Regular DR testing capability

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
- Shared infrastructure (AAP Manages multiple workloads)
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
3. Configure AAP database replication (logical replication for AAP state)
4. Add to global load balancer backend pool
5. Deploy EDB operator and PostgreSQL replica clusters
6. Configure physical replication from DC1:
   - Primary replication: Streaming from DC1 primary cluster
   - Fallback: WAL shipping via S3/object store
7. Configure replica cluster promotion procedures

## Conclusion

This architecture provides:

✅ **High Availability**: AAP active in DC1 with ready standby in DC2  
✅ **Disaster Recovery**: Complete passive DR site with automatic failover  
✅ **Automatic Failover**: Global load balancer provides seamless failover (RTO < 1 min)  
✅ **Low RPO**: Asynchronous replication with < 5 second lag  
✅ **Simplified Management**: AAP instances run on infrastructure they manage  
✅ **Security**: Restricted SCCs, encrypted connections, defense in depth  
✅ **Scalability**: Easy to scale vertically, horizontally, and geographically  
✅ **Automation**: Ansible playbooks for deployment, management, and DR  
✅ **Monitoring**: Comprehensive metrics and alerting across all layers  
✅ **Compliance**: Audit logging, access controls, and regulatory compliance  
✅ **Cost Efficiency**: Shared infrastructure with optimal resource utilization  
✅ **Operational Excellence**: GitOps, infrastructure as code, automated testing  

### Key Architectural Decisions

1. **AAP on OpenShift**: Running AAP on the infrastructure it Manages enables:
   - Self-healing (OpenShift Manages AAP pods)
   - Consistent deployment model
   - Resource efficiency
   - Simplified disaster recovery

2. **Global Load Balancer**: Single entry point provides:
   - Geographic routing
   - Automatic failover
   - Health-based routing
   - SSL/TLS termination

3. **Active-Passive AAP Database Replication**: Provides:
   - Simple, predictable failover model
   - No split-brain scenarios
   - Clear data flow (DC1 → DC2)
   - Reduced complexity in conflict resolution
   - Lower cost (DC2 can be smaller for standby)

4. **EDB Postgres Operator**: Provides:
   - Automated PostgreSQL management
   - Built-in high availability with automatic failover
   - Physical replication (streaming + WAL shipping)
   - Automatic service management and routing updates
   - Backup and recovery automation with Barman Cloud
   - Distributed topology support with replica clusters
   - Consistent security policies (restricted-v2 SCC)

5. **Physical Replication for EDB Clusters**: Using PostgreSQL's native WAL-based replication:
   - Byte-for-byte exact replicas (no schema conflicts)
   - Faster than logical replication
   - Supports streaming (primary) and WAL shipping (fallback)
   - Battle-tested by millions of PostgreSQL deployments
   - Automatic continuous recovery for replica clusters
   - Point-in-time recovery (PITR) capability

The combination of Global Load Balancing, distributed AAP instances, and EDB Postgres for Kubernetes provides an enterprise-grade, highly available, geographically distributed PostgreSQL database platform with comprehensive automation and disaster recovery capabilities. The architecture follows EDB's recommended patterns for distributed PostgreSQL topologies across multiple Kubernetes clusters.
