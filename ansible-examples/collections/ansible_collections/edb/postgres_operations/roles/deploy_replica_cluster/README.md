# Role: deploy_replica_cluster

Deploy PostgreSQL replica clusters using EDB Postgres for Kubernetes with support for distributed topology and standalone replica strategies.

## Description

This role automates the deployment of PostgreSQL replica clusters for disaster recovery, high availability, and read-only workloads. It supports multiple bootstrap methods, replication strategies, and can handle both distributed topologies (bidirectional switchover) and standalone replicas.

**Key Features:**
- **Distributed Topology**: Enable controlled switchover between datacenters with zero data loss
- **Standalone Replicas**: Create read-only replicas for analytics and reporting
- **Multiple Bootstrap Methods**: pg_basebackup, object store recovery, or volume snapshots
- **Hybrid Replication**: Combine streaming replication with WAL archive fallback
- **Delayed Replicas**: Protection against accidental data modifications
- **Symmetric Architectures**: Both clusters capable of serving as primary
- **Automatic Secret Synchronization**: Role and credential management across clusters

Reference: [EDB Replica Clusters Documentation](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/replica_cluster/)

## Requirements

- Ansible 2.14+
- `kubernetes.core` collection
- `community.postgresql` collection (optional for database operations)
- Valid kubeconfig for target OpenShift cluster
- Source PostgreSQL cluster already deployed
- Network connectivity for streaming replication (if enabled)
- S3/object store access (if using WAL archive or object store bootstrap)
- EDB subscription credentials

## Role Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `replica_cluster_name` | Name of the replica cluster | `prod-db-replica` |
| `replica_namespace` | Kubernetes namespace for replica | `production` |
| `kubeconfig_path` | Path to kubeconfig file | `~/.kube/config` |
| `source_cluster_name` | Name of source cluster to replicate from | `prod-db` |
| `source_namespace` | Namespace of source cluster | `production` |
| `replica_datacenter` | Datacenter identifier | `dc2` |

### Strategy Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `replica_strategy` | `distributed_topology` | Replication strategy: `distributed_topology` or `standalone` |
| `global_primary_cluster` | `{{ source_cluster_name }}` | Name of current global primary (distributed topology only) |
| `standalone_enabled` | `true` | Enable continuous recovery (standalone replicas only) |

### Bootstrap Method Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `bootstrap_method` | `pg_basebackup` | Bootstrap method: `pg_basebackup`, `recovery_object_store`, or `recovery_volume_snapshot` |
| `volume_snapshot_name` | `""` | Volume snapshot name (for snapshot bootstrap) |
| `barman_object_name` | `{{ source_cluster_name }}` | Barman object name (for object store) |
| `barman_destination_path` | `""` | S3 bucket path (for object store) |

### Replication Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `enable_streaming_replication` | `true` | Enable streaming replication |
| `enable_wal_archive_replication` | `true` | Enable WAL archive replication |
| `streaming_replica_user` | `streaming_replica` | Replication user name |
| `streaming_replica_ssl_mode` | `verify-full` | SSL mode for replication connection |

### Delayed Replica Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `enable_delayed_replica` | `false` | Enable delayed replica |
| `replica_min_apply_delay` | `0s` | Delay duration (e.g., `8h`, `2h`) |

### Secret Management Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `sync_secrets_from_source` | `true` | Automatically copy secrets from source cluster |
| `create_replication_secrets` | `true` | Create replication certificates |

### Optional Variables

See [defaults/main.yml](defaults/main.yml) for complete list including storage, resources, PostgreSQL parameters, backup configuration, and monitoring settings.

## Replica Strategies

### Distributed Topology

Use for disaster recovery with bidirectional switchover capability:

```yaml
replica_strategy: distributed_topology
global_primary_cluster: prod-db  # Current global primary
enable_promotion_token: true
```

**Characteristics:**
- Symmetric architecture support
- Zero data loss switchover
- Bidirectional failover capability
- Both clusters can serve as primary
- Requires identical role definitions

### Standalone Replica

Use for read-only workloads (analytics, reporting):

```yaml
replica_strategy: standalone
standalone_enabled: true
enable_delayed_replica: false  # Optional: enable for delayed replica
replica_min_apply_delay: "8h"  # Optional: delay for data protection
```

**Characteristics:**
- Continuous recovery mode
- Read-only operations
- One-way promotion (no switchover back without re-clone)
- Can use delayed replay for protection
- Simpler configuration

## Bootstrap Methods

### Method 1: pg_basebackup (Streaming)

Clone from source via streaming replication:

```yaml
bootstrap_method: pg_basebackup
enable_streaming_replication: true
```

**Best for:** Fast networks, low latency environments

### Method 2: Recovery from Object Store

Bootstrap from Barman Cloud backup:

```yaml
bootstrap_method: recovery_object_store
barman_destination_path: s3://my-backups/prod-db/
barman_s3_credentials_secret: prod-db-backup-s3
```

**Best for:** Cross-region, cross-cloud, no direct connectivity

### Method 3: Recovery from Volume Snapshot

Bootstrap from Kubernetes VolumeSnapshot:

```yaml
bootstrap_method: recovery_volume_snapshot
volume_snapshot_name: prod-db-snapshot-20260209
```

**Best for:** Large databases, fast cloning, same storage backend

## Example Playbooks

### Example 1: Distributed Topology for Disaster Recovery

```yaml
---
- name: Deploy Replica Cluster for DR (Distributed Topology)
  hosts: dc2_openshift
  gather_facts: false
  
  roles:
    - role: edb.postgres_operations.deploy_replica_cluster
      vars:
        # Replica cluster configuration
        replica_cluster_name: prod-db-replica
        replica_namespace: production
        replica_datacenter: dc2
        replica_instances: 3
        replica_postgres_version: "16.8"
        
        # Source cluster
        source_cluster_name: prod-db
        source_namespace: production
        source_kubeconfig_path: ~/.kube/dc1-config
        
        # Distributed topology strategy
        replica_strategy: distributed_topology
        global_primary_cluster: prod-db  # DC1 is current primary
        
        # Bootstrap via streaming
        bootstrap_method: pg_basebackup
        
        # Hybrid replication (streaming + WAL archive)
        enable_streaming_replication: true
        enable_wal_archive_replication: true
        
        # Barman Cloud configuration
        barman_destination_path: s3://prod-backups-dc1/prod-db/
        barman_s3_credentials_secret: prod-db-backup-s3
        
        # Symmetric architecture - enable backup on replica
        replica_backup_enabled: true
        replica_backup_bucket: s3://prod-backups-dc2/prod-db-replica/
        
        # Storage configuration
        replica_storage_size: 100Gi
        replica_storage_class: gp3-csi
        
        # Resource configuration
        replica_resource_requests_memory: 4Gi
        replica_resource_requests_cpu: "2"
        replica_resource_limits_memory: 8Gi
        replica_resource_limits_cpu: "4"
        
        # Secret management
        sync_secrets_from_source: true
        create_replication_secrets: true
```

### Example 2: Standalone Replica for Analytics

```yaml
---
- name: Deploy Standalone Replica for Analytics
  hosts: analytics_cluster
  gather_facts: false
  
  roles:
    - role: edb.postgres_operations.deploy_replica_cluster
      vars:
        replica_cluster_name: analytics-db
        replica_namespace: analytics
        replica_datacenter: dc1
        replica_instances: 5
        
        source_cluster_name: prod-db
        source_namespace: production
        
        # Standalone replica strategy
        replica_strategy: standalone
        standalone_enabled: true
        
        # Bootstrap from object store
        bootstrap_method: recovery_object_store
        barman_destination_path: s3://prod-backups/prod-db/
        
        # Read-only workload optimization
        replica_resource_requests_memory: 8Gi
        replica_resource_requests_cpu: "4"
        replica_pg_shared_buffers: "2GB"
        replica_pg_effective_cache_size: "6GB"
```

### Example 3: Delayed Replica for Data Protection

```yaml
---
- name: Deploy Delayed Replica for Protection
  hosts: openshift_clusters
  gather_facts: false
  
  roles:
    - role: edb.postgres_operations.deploy_replica_cluster
      vars:
        replica_cluster_name: prod-db-delayed
        replica_namespace: production
        replica_datacenter: dc1
        replica_instances: 1
        
        source_cluster_name: prod-db
        source_namespace: production
        
        # Standalone with delay
        replica_strategy: standalone
        standalone_enabled: true
        enable_delayed_replica: true
        replica_min_apply_delay: "8h"  # 8-hour recovery window
        
        bootstrap_method: pg_basebackup
```

### Example 4: Cross-Region with Volume Snapshot

```yaml
---
- name: Deploy Replica from Volume Snapshot
  hosts: dc2_openshift
  gather_facts: false
  
  roles:
    - role: edb.postgres_operations.deploy_replica_cluster
      vars:
        replica_cluster_name: prod-db-replica
        replica_namespace: production
        replica_datacenter: dc2
        
        source_cluster_name: prod-db
        source_namespace: production
        
        replica_strategy: distributed_topology
        global_primary_cluster: prod-db
        
        # Bootstrap from snapshot (fastest for large databases)
        bootstrap_method: recovery_volume_snapshot
        volume_snapshot_name: prod-db-snapshot-20260209-120000
        
        # Continue with hybrid replication after bootstrap
        enable_streaming_replication: true
        enable_wal_archive_replication: true
```

## Command Line Usage

```bash
# Distributed topology for DR
ansible-playbook deploy-replica.yml \
  -e "replica_cluster_name=prod-db-replica" \
  -e "source_cluster_name=prod-db" \
  -e "replica_strategy=distributed_topology" \
  -e "global_primary_cluster=prod-db"

# Standalone replica for analytics
ansible-playbook deploy-replica.yml \
  -e "replica_cluster_name=analytics-db" \
  -e "source_cluster_name=prod-db" \
  -e "replica_strategy=standalone" \
  -e "replica_instances=5"

# Delayed replica for protection
ansible-playbook deploy-replica.yml \
  -e "replica_cluster_name=prod-db-delayed" \
  -e "source_cluster_name=prod-db" \
  -e "replica_strategy=standalone" \
  -e "enable_delayed_replica=true" \
  -e "replica_min_apply_delay=8h"
```

## Output Facts

The role sets the following facts:

- `replica_cluster_primary` - Name of the designated primary pod
- `replica_cluster_phase` - Current cluster phase
- `replica_cluster_instances` - Total number of instances
- `replica_cluster_ready_instances` - Number of ready instances
- `replica_cluster_ro_service` - Read-only service endpoint
- `replica_cluster_r_service` - Read service endpoint (any instance)
- `replica_cluster_rw_service` - Read-write service (only if promoted to primary)
- `replica_is_primary` - Boolean indicating if this is the global primary

## Switchover Process

For distributed topology, use separate playbooks to orchestrate switchover:

### Step 1: Demote Current Primary

```yaml
# Update DC1 cluster to point to DC2 as new primary
- role: edb.postgres_operations.deploy_replica_cluster
  vars:
    replica_cluster_name: prod-db
    global_primary_cluster: prod-db-replica  # Changed!
```

### Step 2: Get Demotion Token

```bash
kubectl get cluster prod-db -n production -o jsonpath='{.status.demotionToken}'
```

### Step 3: Promote Replica

```yaml
# Update DC2 cluster with promotion token
- role: edb.postgres_operations.deploy_replica_cluster
  vars:
    replica_cluster_name: prod-db-replica
    global_primary_cluster: prod-db-replica  # Now primary
    promotion_token: "<TOKEN_FROM_STEP_2>"
```

## Dependencies

None.

## License

Apache-2.0

## Author

EDB Engineering Team

## References

- [EDB Replica Clusters Documentation](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/replica_cluster/)
- [EDB Architecture Guide](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/architecture/)
- [EDB Bootstrap Documentation](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/bootstrap/)
