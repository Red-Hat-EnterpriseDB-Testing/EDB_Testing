# AAP with EDB Postgres Multi-Datacenter Architecture

**Complete architecture documentation for Ansible Automation Platform with EnterpriseDB PostgreSQL**

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Component Details](#component-details)
  - [Global Load Balancer](#global-load-balancer)
  - [Ansible Automation Platform (AAP)](#ansible-automation-platform-aap)
  - [AAP Database Replication](#aap-database-replication)
  - [EDB-Managed PostgreSQL Cluster Replication](#edb-managed-postgresql-cluster-replication)
- [Network Connectivity](#network-connectivity)
  - [User to AAP (via Global Load Balancer)](#user-to-aap-via-global-load-balancer)
  - [AAP to PostgreSQL Databases](#aap-to-postgresql-databases)
  - [Inter-Datacenter Replication](#inter-datacenter-replication)
- [Data Flow](#data-flow)
  - [Write Operations (Normal State)](#write-operations-normal-state)
  - [Read Operations](#read-operations)
  - [Backup Flow](#backup-flow)
- [AAP Deployment Architecture](#aap-deployment-architecture)
- [AAP Cluster Management](#aap-cluster-management)
- [Disaster Recovery Scenarios](#disaster-recovery-scenarios)
- [Scaling Considerations](#scaling-considerations)
- [Related Architecture Documentation](#related-architecture-documentation)

---

## Architecture Overview

This architecture implements EnterpriseDB Postgres deployed Active/Passive across two clusters in
different datacenters with in-datacenter replication for the Ansible Automation Platform (AAP).
This achieves a **NEAR** HA type architecture, especially for failover to the databases syncing
in region/datacenter.

**Key characteristics:**
- **Topology:** Active-Passive multi-datacenter
- **HA Strategy:** In-datacenter automatic failover, cross-datacenter manual failover
- **Replication:** Physical streaming replication + WAL archiving
- **RTO Target:** <1 minute (in-datacenter), <5 minutes (cross-datacenter)
- **RPO Target:** <5 seconds (streaming replication)

A DR scenario should be used when there is a catastrophic failure. Failing to an in-site database
should cause little to no intervention needed at the application layer. The main thing to note is
for a DR failover any running jobs will be lost, however if it fails in-site, the jobs should
continue to run UNLESS the controller has a failure.

### Architecture Diagram

![EDB Postgres Multi-Datacenter Architecture](../images/AAP_EDB.drawio.png)

---

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

**Implementation options:**
- **Cloud:** AWS Route 53, Azure Traffic Manager, Google Cloud Load Balancing
- **On-premises:** F5 BIG-IP, HAProxy, NGINX Plus
- **Hybrid:** Cloudflare Load Balancing, Akamai Global Traffic Management

---

### Ansible Automation Platform (AAP)

**Operator install with external EDB Postgres** (sample namespace / cluster: `edb-postgres` / `postgresql`):
- See **[`aap-deploy/README.md`](../aap-deploy/README.md)** (overview)
- See **[`aap-deploy/openshift/README.md`](../aap-deploy/openshift/README.md)** (subscription + `AnsibleAutomationPlatform` CR)

For OpenShift, AAP is deployed on **separate OpenShift clusters** for high availability and
geographic distribution. For RHEL you can do a single install across datacenters however you
**MUST TURN OFF THE SERVICES ON THE SECONDARY SITE**.

#### Datacenter 1 - AAP Instance (Active)

- **Namespace**: `ansible-automation-platform`
- **AAP Gateway**: 3 replicas for HA
- **AAP Controller**: 3 replicas for HA
- **Automation Hub**: 2 replicas
- **Database**: PostgreSQL cluster (1 primary + 2 replicas) managed by EDB operator
- **Route**: `aap-dc1.apps.ocp1.example.com`
- **State**: Active, serving production traffic

#### Datacenter 2 - AAP Instance (Passive)

- **Namespace**: `ansible-automation-platform`
- **AAP Gateway**: Scaled to 0 (or 3 replicas if pre-warmed)
- **AAP Controller**: Scaled to 0 (or 3 replicas if pre-warmed)
- **Automation Hub**: Scaled to 0 (or 2 replicas if pre-warmed)
- **Database**: PostgreSQL cluster (1 designated primary + 2 replicas) managed by EDB operator
- **Route**: `aap-dc2.apps.ocp2.example.com`
- **State**: Standby, ready for failover

**Scaling strategy:**
- **Cold standby:** AAP scaled to 0, database replicating (5-10 min activation time)
- **Warm standby:** AAP running with 1 replica each, scaled up during failover (2-3 min activation)
- **Hot standby:** AAP fully scaled, ready for immediate traffic (30 sec activation)

---

### AAP Database Replication

The AAP databases are replicated from active to passive datacenter:

- **Method**: PostgreSQL logical replication (Active → Passive)
  - *Note: AAP's internal database uses logical replication for flexibility*
- **Direction**: DC1 (Active) → DC2 (Passive)
- **Mode**: Asynchronous replication with minimal lag
- **Shared Data**:
  - Job templates
  - Inventory and host information
  - Credentials (encrypted)
  - Execution history and logs
  - RBAC settings
  - Workflow definitions
- **Failover**: DC2 database promoted to read-write during failover
- **Failback**: Data synchronized back to DC1 when it recovers

**Lag monitoring:**
- Monitor `pg_stat_replication` for lag metrics
- Alert if lag exceeds 30 seconds
- Dashboard display of replication health

---

### EDB-Managed PostgreSQL Cluster Replication

EDB-managed application database clusters use physical replication:

- **Method**: PostgreSQL physical replication via streaming replication and WAL shipping
- **Primary Method**: Streaming replication from Primary to Designated Primary
- **Fallback Method**: WAL shipping via S3/object store (continuous WAL archiving)
- **Within Cluster**: Hot standby replicas use streaming replication from primary/designated primary
- **Mode**: Asynchronous streaming with optional synchronous mode
- **Benefits**:
  - Block-level replication (exact byte-for-byte replica)
  - Faster failover times
  - Lower overhead than logical replication
  - Supports all PostgreSQL features

**Replication topology:**
```
DC1 Primary Cluster:
  postgresql-1 (primary) → postgresql-2 (hot standby)
                        → postgresql-3 (hot standby)
                        → DC2 Designated Primary (streaming)
                        → S3 bucket (WAL archive)

DC2 Replica Cluster:
  postgresql-replica-1 (designated primary) → postgresql-replica-2 (hot standby)
                                           → postgresql-replica-3 (hot standby)
                                           → S3 bucket (WAL archive)
```

---

## Network Connectivity

### User to AAP (via Global Load Balancer)

Users and automation clients connect to AAP through the global load balancer:

- **URL**: `https://aap.example.com`
- **Protocol**: HTTPS/443 with WebSocket support
- **Load Balancing**: Active-Passive (priority-based)
- **Active Target**: DC1 AAP (100% traffic when healthy)
- **Passive Target**: DC2 AAP (standby, only receives traffic during failover)
- **Health Checks**:
  - Layer 7 health checks to AAP Controller `/api/v2/ping/` endpoint
  - Frequency: Every 10 seconds
  - Threshold: 3 consecutive failures trigger failover
- **Session Affinity**: Sticky sessions for long-running jobs
- **TLS Termination**: At load balancer or end-to-end encryption
- **Failover Time**: 30-60 seconds (health check detection + DNS propagation)

**Network requirements:**
- **Bandwidth**: 100 Mbps minimum, 1 Gbps recommended
- **Latency**: <50ms user-to-GLB, <100ms GLB-to-AAP
- **Availability**: 99.99% uptime SLA

---

### AAP to PostgreSQL Databases

AAP can only talk to one Read-Write (RW) database at a time:

- **Protocol**: PostgreSQL wire protocol (port 5432)
- **Access**:
  - **Within OpenShift cluster:** Via ClusterIP Services (`postgresql-rw.edb-postgres.svc.cluster.local`)
  - **Cross-cluster:** Via OpenShift Routes with TLS passthrough or LoadBalancer services
- **Authentication**:
  - Certificate-based (mutual TLS) - recommended
  - Password authentication (stored in Kubernetes secrets)
- **Encryption**: TLS/SSL enforced for all connections
- **Connection Pooling**: PgBouncer for efficient connection management
  - Pool size: 100 connections per AAP instance
  - Pool mode: Transaction pooling
  - Idle timeout: 600 seconds

**Connection failover:**
- AAP uses `-rw` service which automatically points to current primary
- During failover, EDB operator updates service endpoints
- AAP reconnects automatically on connection failure
- Connection retry logic: 3 attempts with exponential backoff

---

### Inter-Datacenter Replication

#### EDB-Managed Application Database Replication

- **Method**: PostgreSQL physical replication (streaming + WAL shipping)
- **Primary Mechanism**: Streaming replication from Primary to Designated Secondaries
- **Fallback Mechanism**: WAL shipping via S3/object store
- **Direction**: DC1 (Primary Cluster) → DC2 (Replica Cluster)
- **Network**:
  - Encrypted tunnel (VPN/Direct Connect/WAN) for streaming replication
  - HTTPS for S3 WAL archiving
  - Dedicated VLAN or VPC peering recommended
- **Replication Type**:
  - Asynchronous (default) - better performance
  - Synchronous (optional) - zero data loss guarantee
- **Lag Monitoring**:
  - Both AAP instances monitor replication lag via EDB operator metrics
  - Prometheus metrics: `cnpg_pg_replication_lag`
  - Grafana dashboards display real-time lag
- **Alerting**:
  - Alerts triggered if lag exceeds threshold (e.g., 30 seconds)
  - PagerDuty integration for critical alerts
- **Automatic Service Updates**:
  - EDB operator automatically updates `-rw` service during failover
  - Service endpoints updated within 5-10 seconds
- **Cross-Cluster Limitation**:
  - Automated failover across OpenShift clusters must be handled externally
  - Integration via AAP automation or EDB Failover Manager (EFM)

**Network requirements for replication:**
- **Bandwidth**: 10 Mbps minimum, 100 Mbps recommended
- **Latency**: <100ms for streaming replication
- **Jitter**: <10ms
- **Packet loss**: <0.1%

**Replication slot configuration:**
```yaml
# In DC1 primary cluster
spec:
  replicationSlots:
    highAvailability:
      enabled: true
      slotPrefix: _cnpg_
    updateInterval: 30
```

---

## Data Flow

### Write Operations (Normal State)

**For EDB-Managed Application Databases:**

1. **Application → AAP Controller**
   - User or API client submits job/workflow
   - AAP Controller receives request

2. **AAP Controller → DC1 Primary Database** (via `-rw` service)
   - AAP writes job data, inventory updates, credentials
   - Connection via `postgresql-rw.edb-postgres.svc.cluster.local:5432`

3. **DC1 Primary → DC1 Hot Standby Replicas** (streaming replication within cluster)
   - Primary replicates to 2 hot standby instances
   - Replication lag: <100ms
   - Used for read-only queries and HA

4. **DC1 Primary → DC2 Designated Primary** (streaming replication across clusters)
   - Replication via OpenShift Route with TLS passthrough
   - Typical lag: 1-5 seconds (depends on WAN latency)
   - Used for DR failover

5. **DC1 Primary → S3/Object Store** (continuous WAL archiving - fallback)
   - WAL files uploaded every 60 seconds or 16MB (whichever first)
   - Used for PITR and fallback replication
   - Retention: 30 days

6. **DC2 Designated Primary → DC2 Hot Standby Replicas** (streaming replication within cluster)
   - DC2 designated primary replicates to 2 hot standby instances
   - Ensures DC2 can serve reads and has HA ready for promotion

**Data flow diagram:**
```
User/API → GLB → AAP DC1 → PostgreSQL DC1 Primary
                                 ↓
                          ┌──────┴──────┬──────────┬─────────┐
                          ↓             ↓          ↓         ↓
                      DC1 Standby  DC1 Standby  DC2 DP    S3 WAL
                          1            2          ↓       Archive
                                                  ├─────────┬─────────┐
                                                  ↓         ↓         ↓
                                            DC2 Standby DC2 Standby  (backup)
                                                1          2
```

---

### Read Operations

**EDB-Managed Clusters:**

**DC1 Primary Cluster:**
- **Write operations:** Via `postgresql-rw` service (routes to primary instance)
- **Read operations (HA):** Via `postgresql-ro` service (routes to hot standby replicas)
- **Read operations (any):** Via `postgresql-r` service (routes to any instance including primary)

**DC2 Replica Cluster:**
- **Read operations only:** Via `postgresql-replica-ro` service (routes to designated primary or replicas)
- **Cannot accept writes** unless promoted during failover
- Used for:
  - Read-only analytics queries (offload from DC1)
  - DR testing and validation
  - Backup source (to reduce load on DC1)

**Load Balancing:**
- EDB operator manages service routing automatically
- Round-robin load balancing across available read replicas
- Health checks ensure only healthy instances receive traffic

**Service Behavior During Failover:**
- EDB operator automatically updates `-rw` service to point to newly promoted primary
- Applications experience seamless redirection without connection string changes
- Read-only services updated to reflect new topology
- Typical service update time: 5-10 seconds

**Query routing strategy:**
```
Write queries → Always to -rw service → Primary instance
Read queries (low latency) → -r service → Any instance (including primary)
Read queries (HA) → -ro service → Hot standby replicas only
Analytics queries → DC2 -replica-ro → Offload from production
```

---

### Backup Flow

**EDB-Managed PostgreSQL Backups:**

1. **Scheduled backup job** (initiated by AAP or CronJob via EDB operator)
   - Daily full backup: 2:00 AM UTC
   - Hourly incremental backups (optional)
   - Triggered by `Backup` custom resource

2. **Backup pod created by EDB operator**
   - Temporary pod spins up with Barman Cloud tools
   - Mounts persistent volume for staging (if needed)
   - Authenticates to PostgreSQL and S3

3. **Database backup streamed to S3/object store** (using Barman Cloud)
   - Full backup or incremental based on schedule
   - Compression: gzip (reduces size by ~70%)
   - Encryption: AES-256 (S3 server-side or client-side)

4. **WAL files continuously archived to S3** (automatic by EDB operator)
   - Continuous archiving every 60 seconds or 16MB
   - Parallel upload for high write workloads
   - Checksum validation on upload

5. **WAL archiving serves dual purpose:**
   - **Point-in-time recovery (PITR):** Restore to any second within retention window
   - **Fallback replication mechanism:** Replica clusters can recover from WAL archive if streaming replication fails

6. **Replica clusters can recover from WAL archive** if streaming replication fails
   - Automatic fallback when streaming connection lost
   - Catchup from WAL archive until streaming restored
   - Alerts sent if relying on WAL archive for >5 minutes

7. **AAP monitors backup completion** via operator metrics
   - Prometheus metrics: `cnpg_pg_backup_last_succeeded`
   - Grafana dashboard: Backup status panel
   - Integration with external monitoring (PagerDuty, Slack)

8. **Alerts sent if backup fails**
   - Immediate alert on backup failure
   - Warning alert if backup >36 hours old
   - Runbook links provided in alerts

**Backup Strategy per Datacenter:**

**DC1 (Primary):**
- Full backups daily + continuous WAL archiving
- S3 bucket: `s3://edb-backups-dc1-prod` (primary region: us-east-1)
- Retention: 30 days operational, 365 days compliance (Glacier transition)
- Backup source: Prefer hot standby replica (reduce load on primary)

**DC2 (Disaster Recovery):**
- Independent backups to separate S3 bucket for redundancy
- S3 bucket: `s3://edb-backups-dc2-dr` (DR region: us-west-2)
- Retention: 30 days
- Backup source: Designated primary (already in read-only mode)
- Cross-region replication from DC1 S3 bucket (optional)

**Backup validation:**
- Monthly restore test to verify backup integrity
- Automated via `CronJob` and validation scripts
- Test restores to separate namespace
- Validation: Data integrity checks, connectivity tests, query execution

**Recovery scenarios:**
- **Recent data loss:** PITR from WAL archive (RPO: <60 seconds)
- **Database corruption:** Restore from latest full backup + WAL replay
- **Datacenter loss:** Restore DC1 from DC2 backups or vice versa

---

## AAP Deployment Architecture

Detailed architecture documentation for AAP on different platforms:

- **[RHEL AAP Architecture](rhel-aap-architecture.md)** - AAP on RHEL with systemd services
  - Systemd service management
  - HAProxy for load balancing
  - PostgreSQL on bare metal/VMs
  - Manual service orchestration during failover

- **[OpenShift AAP Architecture](openshift-aap-architecture.md)** - AAP on OpenShift with operator
  - Operator-based lifecycle management
  - Native Kubernetes Services for load balancing
  - CloudNativePG for PostgreSQL
  - Automated pod orchestration during failover

**Choosing deployment type:**
- **Use RHEL** if you have existing VM/bare metal infrastructure and prefer traditional management
- **Use OpenShift** if you want cloud-native orchestration and have Kubernetes expertise

---

## AAP Cluster Management

### Integration with EDB EFM (Enterprise Failover Manager)

**See:** [EDB Failover Manager Documentation](enterprisefailovermanager.md)

EFM provides automated database failover detection and orchestration:

**Key features:**
- Automatic detection of primary database failure
- Promotion of standby to primary within 30-60 seconds
- Virtual IP (VIP) failover for seamless client reconnection
- Integration with AAP scaling scripts
- Email/SNMP notifications

**Failover trigger:**
1. EFM detects primary database failure (3 consecutive health check failures)
2. EFM promotes best standby replica to primary
3. EFM calls AAP orchestration script: [`efm-orchestrated-failover.sh`](../scripts/efm-orchestrated-failover.sh)
4. Script scales down AAP in DC1, scales up AAP in DC2
5. GLB health checks detect DC2 AAP healthy, route traffic to DC2
6. RTO achieved: <5 minutes

**Configuration:**
```bash
# /etc/edb/efm-4.x/efm.properties
enable.custom.scripts=true
script.post.promotion=/usr/edb/efm-4.x/bin/efm-orchestrated-failover.sh %h %s %a %v
```

### AAP Cluster Scripts

**See:** [AAP Cluster Scripts Documentation](../scripts/README.md)

**Operational scripts:**
- [`scale-aap-up.sh`](../scripts/scale-aap-up.sh) - Scale AAP to operational state in target datacenter
- [`scale-aap-down.sh`](../scripts/scale-aap-down.sh) - Scale AAP to zero in inactive datacenter
- [`efm-orchestrated-failover.sh`](../scripts/efm-orchestrated-failover.sh) - Full DR failover orchestration
- [`validate-aap-data.sh`](../scripts/validate-aap-data.sh) - Post-failover data validation
- [`monitor-efm-scripts.sh`](../scripts/monitor-efm-scripts.sh) - EFM integration monitoring

**Runbook:**
- [AAP Cluster Management Runbook](manual-scripts-doc.md) - Step-by-step operational procedures

---

## Disaster Recovery Scenarios

**See:** [DR Scenarios Documentation](dr-scenarios.md)

**Documented failure scenarios:**

1. **Single Pod Failure (Database or AAP)** - Automatic Kubernetes restart
   - RTO: <30 seconds
   - RPO: 0 (no data loss)
   - Automation: Kubernetes liveness/readiness probes

2. **Database Cluster Failure (DC1)** - EFM automated failover
   - RTO: <1 minute
   - RPO: <5 seconds
   - Automation: EFM promotion + service updates

3. **Complete Datacenter Failure (DC1)** - Manual failover to DC2
   - RTO: <5 minutes
   - RPO: <5 seconds
   - Automation: AAP playbook or manual script execution

4. **Data Corruption (Logical)** - Point-in-time recovery
   - RTO: 2-4 hours
   - RPO: <1 minute (depends on backup schedule)
   - Automation: PITR scripts

5. **Network Partition (Split-Brain)** - Prevention via database role checks
   - RTO: N/A (prevention measure)
   - RPO: N/A
   - Automation: Pre-startup validation scripts

6. **Cascading Failures (Both DCs)** - Recovery from S3 backups
   - RTO: <24 hours
   - RPO: <5 minutes
   - Automation: Disaster recovery runbook

**DR Testing:**
- **Quarterly DR drills:** Automated via `CronJob` - see [DR Testing Guide](dr-testing-guide.md)
- **Validation scripts:** Data integrity checks post-failover
- **RTO/RPO measurement:** Automated metrics collection during tests

---

## Scaling Considerations

### Horizontal Scaling (Adding Instances)

**PostgreSQL (OpenShift):**

```yaml
# Edit cluster.yaml
spec:
  instances: 3  # Increase from 2 to 3
```

Apply changes:
```bash
oc apply -k db-deploy/sample-cluster/
```

**Benefits:**
- Increased read capacity (more read replicas)
- Higher availability (more failover candidates)
- Better resource distribution

**Considerations:**
- More instances = more replication overhead
- Diminishing returns beyond 3-5 instances per cluster
- Network bandwidth requirements increase

---

### Vertical Scaling (Resource Limits)

**PostgreSQL (OpenShift):**

```yaml
# Edit cluster.yaml
spec:
  resources:
    requests:
      cpu: "2"
      memory: "4Gi"
    limits:
      cpu: "4"
      memory: "8Gi"
```

**AAP (OpenShift):**

```yaml
# Edit ansibleautomationplatform.yaml
spec:
  controller:
    resources:
      requests:
        cpu: "2"
        memory: "4Gi"
      limits:
        cpu: "4"
        memory: "8Gi"
```

**Recommendations:**
- **PostgreSQL:** 2-4 CPU cores, 4-8 GB RAM per instance (typical)
- **AAP Controller:** 2-4 CPU cores, 4-8 GB RAM per replica
- **AAP Hub:** 1-2 CPU cores, 2-4 GB RAM per replica
- **Monitor resource utilization** before scaling up

---

### Storage Scaling

**Resize PostgreSQL PVCs:**

```bash
# Check current size
oc get pvc -n edb-postgres

# Edit PVC (if StorageClass supports expansion)
oc edit pvc postgresql-1 -n edb-postgres
# Increase storage size in spec.resources.requests.storage

# Operator automatically handles resize
```

**Best practices:**
- Plan for 3-6 months of data growth
- Monitor disk usage weekly
- Keep 20% free space minimum
- Use separate volumes for WAL if high write workload

---

### Geographic Distribution

**Multi-region deployment:**

1. **Deploy primary cluster** in primary region (DC1)
2. **Deploy replica cluster** in DR region (DC2)
3. **Configure cross-region replication** via OpenShift Routes or VPN
4. **Set up S3 buckets** in both regions for backups
5. **Configure cross-region S3 replication** for backup redundancy

**Latency considerations:**
- **Streaming replication:** Works well up to 100ms latency
- **High latency (>100ms):** Consider asynchronous replication only
- **Very high latency (>500ms):** Use WAL shipping as primary method

**See:** [OpenShift Installation Guide - Scaling](install-kubernetes-manual.md#scaling-considerations)

---

## Related Architecture Documentation

### Core Architecture
- **[Main README](../README.md)** - Architecture overview and quick links
- **[RHEL AAP Architecture](rhel-aap-architecture.md)** - AAP on RHEL detailed architecture
- **[OpenShift AAP Architecture](openshift-aap-architecture.md)** - AAP on OpenShift detailed architecture

### Deployment Guides
- **[OpenShift Installation](install-kubernetes-manual.md)** - Detailed OpenShift deployment
- **[RHEL Installation with TPA](install-tpa.md)** - Automated RHEL deployment
- **[Cross-Cluster Replication](../db-deploy/cross-cluster/README.md)** - DC1→DC2 replication setup

### Operations & DR
- **[DR Scenarios](dr-scenarios.md)** - 6 documented failure scenarios
- **[DR Testing Guide](dr-testing-guide.md)** - Complete testing framework
- **[EDB Failover Manager](enterprisefailovermanager.md)** - EFM integration
- **[Split-Brain Prevention](split-brain-prevention.md)** - Database role validation
- **[Operations Runbook](manual-scripts-doc.md)** - Day-to-day procedures
- **[Troubleshooting](troubleshooting.md)** - Common issues and diagnostics

### Scripts & Automation
- **[Scripts Reference](../scripts/README.md)** - All automation scripts
- **[AAP Scaling Scripts](../scripts/)** - scale-aap-up.sh, scale-aap-down.sh
- **[DR Failover Scripts](../scripts/)** - efm-orchestrated-failover.sh, dr-failover-test.sh
- **[Validation Scripts](../scripts/)** - validate-aap-data.sh, measure-rto-rpo.sh

---

**Architecture Documentation Complete**

For questions or improvements, see [CONTRIBUTING.md](../CONTRIBUTING.md) or open an issue on GitHub.
