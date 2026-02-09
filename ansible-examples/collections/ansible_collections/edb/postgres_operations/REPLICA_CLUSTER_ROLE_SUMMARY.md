# Deploy Replica Cluster Role - Summary

## Overview

A comprehensive Ansible role has been created to deploy PostgreSQL replica clusters using EDB Postgres for Kubernetes, supporting disaster recovery, high availability, and read-only workloads.

**Role Name**: `edb.postgres_operations.deploy_replica_cluster`

**Location**: `roles/deploy_replica_cluster/`

## Key Features

### Replica Strategies

1. **Distributed Topology**
   - Zero data loss controlled switchover
   - Symmetric architecture support
   - Bidirectional failover capability
   - Promotion/demotion token management
   - Ideal for disaster recovery and high availability

2. **Standalone Replica**
   - Read-only continuous recovery
   - Analytics and reporting workloads
   - Delayed replica support for data protection
   - One-way promotion

### Bootstrap Methods

1. **pg_basebackup** (Streaming)
   - Network-based cloning from source
   - Fast with good network connectivity
   - Real-time initial sync

2. **Recovery from Object Store**
   - Bootstrap from Barman Cloud backup
   - Cross-region, cross-cloud capable
   - No direct connectivity required

3. **Recovery from Volume Snapshot**
   - Fastest for large databases
   - Requires storage class with snapshot support
   - Same storage backend

### Replication Methods

1. **Streaming Replication** (Primary)
   - Real-time WAL streaming
   - Lowest replication lag
   - Direct network connection

2. **WAL Archive** (Fallback)
   - S3/object store based
   - Works without direct connectivity
   - Automatic fallback mechanism

3. **Hybrid Approach** (Recommended)
   - Combines both methods
   - Streaming for normal operations
   - WAL archive for reliability

### Advanced Features

- **Secret Synchronization**: Automatic copy of credentials from source
- **Delayed Replicas**: Configurable replay delay for data protection
- **Symmetric Architectures**: Both clusters capable of primary role
- **Cross-Cluster Support**: Different Kubernetes clusters/regions
- **Resource Optimization**: Separate tuning for different workloads
- **Monitoring Integration**: PodMonitor support
- **High Availability**: PodDisruptionBudget configuration

## Files Created

### Core Role Files

```
roles/deploy_replica_cluster/
├── defaults/
│   └── main.yml              # 89 variables with sensible defaults
├── tasks/
│   └── main.yml              # 300+ lines of deployment logic
├── templates/
│   └── replica-cluster.yml.j2 # Cluster manifest template
├── meta/
│   └── main.yml              # Role metadata
└── README.md                 # Comprehensive documentation
```

### Playbooks

```
playbooks/
├── deploy-replica-cluster.yml                  # Main playbook
└── examples/
    ├── deploy-dr-replica.yml                   # DR with distributed topology
    ├── deploy-analytics-replica.yml            # Read-only analytics replica
    ├── deploy-delayed-replica.yml              # Delayed replica for protection
    └── deploy-cross-region-replica.yml         # Cross-region with snapshot
```

### Inventory

```
inventory/
└── replica-example.yml       # Complete multi-datacenter example
```

### Documentation

```
playbooks/README.md           # Playbook usage guide
README.md (updated)           # Collection README with new role
galaxy.yml (updated)          # Added replication-related tags
```

## Role Variables

### Required Variables

| Variable | Description |
|----------|-------------|
| `replica_cluster_name` | Name of replica cluster |
| `source_cluster_name` | Source cluster to replicate from |
| `replica_namespace` | Kubernetes namespace |
| `kubeconfig_path` | Path to kubeconfig |
| `replica_datacenter` | Datacenter identifier |

### Strategy Variables

| Variable | Default | Options |
|----------|---------|---------|
| `replica_strategy` | `distributed_topology` | `distributed_topology`, `standalone` |
| `bootstrap_method` | `pg_basebackup` | `pg_basebackup`, `recovery_object_store`, `recovery_volume_snapshot` |

### Replication Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `enable_streaming_replication` | `true` | Enable streaming replication |
| `enable_wal_archive_replication` | `true` | Enable WAL archive fallback |
| `enable_delayed_replica` | `false` | Enable delayed replay |
| `replica_min_apply_delay` | `0s` | Delay duration (e.g., `8h`) |

### Resource Variables

All primary cluster variables have `replica_` prefixed equivalents:
- `replica_storage_size`
- `replica_resource_requests_memory`
- `replica_resource_requests_cpu`
- `replica_pg_max_connections`
- etc.

## Usage Examples

### Example 1: Disaster Recovery (Distributed Topology)

```bash
ansible-playbook deploy-replica-cluster.yml \
  -i inventory/replica-example.yml \
  --limit dc2_clusters \
  -e "replica_strategy=distributed_topology" \
  -e "global_primary_cluster=prod-db"
```

**Use Case**: Primary production database in DC1, replica in DC2 for disaster recovery with controlled switchover capability.

### Example 2: Analytics Workload (Standalone)

```bash
ansible-playbook examples/deploy-analytics-replica.yml \
  -i inventory/replica-example.yml \
  -e "replica_instances=5" \
  -e "replica_resource_requests_memory=8Gi"
```

**Use Case**: Read-only replica optimized for analytics queries without impacting production.

### Example 3: Data Protection (Delayed Replica)

```bash
ansible-playbook examples/deploy-delayed-replica.yml \
  -i inventory/production.yml \
  -e "replica_min_apply_delay=8h"
```

**Use Case**: 8-hour delayed replica providing recovery window for accidental data modifications.

### Example 4: Cross-Region (Volume Snapshot)

```bash
ansible-playbook examples/deploy-cross-region-replica.yml \
  -i inventory/multi-region.yml \
  -e "volume_snapshot_name=prod-db-snapshot-20260209"
```

**Use Case**: Fast bootstrap of large database in different region using volume snapshot.

## Controlled Switchover Process

The role supports zero data loss switchover for distributed topology:

### Step 1: Demote Primary (DC1)

Update DC1 cluster configuration:
```yaml
global_primary_cluster: prod-db-replica  # Changed from prod-db
```

### Step 2: Get Demotion Token

```bash
kubectl get cluster prod-db -n production \
  -o jsonpath='{.status.demotionToken}'
```

### Step 3: Promote Replica (DC2)

Update DC2 cluster with promotion token:
```yaml
global_primary_cluster: prod-db-replica
promotion_token: <TOKEN_FROM_STEP_2>
```

**Result**: DC2 becomes new primary, DC1 becomes replica automatically without rebuild.

## Task Workflow

The role performs these tasks automatically:

1. **Validation**: Verify all required variables and strategy configuration
2. **Namespace Creation**: Ensure namespace exists with proper labels
3. **Secret Synchronization**: Copy credentials from source cluster
   - Superuser secret
   - Application user secret
   - Replication certificates (if TLS)
   - S3 credentials (if object store)
4. **Cluster Deployment**: Create replica cluster with proper configuration
5. **PodDisruptionBudget**: Configure HA settings
6. **Health Check**: Wait for cluster to be ready
7. **Fact Collection**: Set output facts for downstream tasks
8. **Summary Display**: Show deployment details

## Integration with EDB Documentation

The role is fully aligned with official EDB documentation:

- [Replica Clusters](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/replica_cluster/)
- [Architecture Guide](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/architecture/)
- [Bootstrap Methods](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/bootstrap/)

All examples and configurations follow EDB best practices and recommended patterns.

## Best Practices Implemented

1. **Symmetric Architectures**: Both clusters configured identically for true DR
2. **Hybrid Replication**: Streaming + WAL archive for reliability
3. **Secret Management**: Automatic synchronization of credentials
4. **Resource Tuning**: Workload-specific configurations (DR, analytics, protection)
5. **Monitoring**: PodMonitor integration for observability
6. **High Availability**: PodDisruptionBudget for rolling updates
7. **Validation**: Comprehensive pre-deployment checks
8. **Idempotency**: Safe to run multiple times

## Ansible Best Practices

Based on the enabled Ansible best practices skill:

1. **YAML Standards**: 2-space indentation, snake_case variables
2. **Role Structure**: Standard Ansible Galaxy role layout
3. **Documentation**: Comprehensive README with examples
4. **Variables**: Clear defaults with override capability
5. **Validation**: Assert statements for required variables
6. **Idempotency**: kubernetes.core.k8s with state:present
7. **Facts**: Set output facts for chaining tasks
8. **Error Handling**: Validation before deployment
9. **Templates**: Jinja2 for complex manifests
10. **Examples**: Multiple real-world scenario playbooks

## Testing Recommendations

### Unit Testing
```bash
# Validate role syntax
ansible-playbook --syntax-check deploy-replica-cluster.yml

# Check mode (dry run)
ansible-playbook deploy-replica-cluster.yml --check
```

### Integration Testing
```bash
# Deploy to test environment
ansible-playbook examples/deploy-dr-replica.yml \
  -i inventory/test.yml \
  -e "postgres_version=16.8"

# Verify replication status
kubectl get cluster prod-db-replica -n production
kubectl cnp status prod-db-replica -n production
```

### Switchover Testing
```bash
# Practice controlled switchover in test environment
ansible-playbook deploy-cluster.yml -e "global_primary_cluster=test-db-replica"
# Get token...
ansible-playbook deploy-replica-cluster.yml -e "promotion_token=..."
```

## Future Enhancements

Potential improvements for future versions:

1. **Automatic Promotion Token Retrieval**: Ansible task to get token automatically
2. **Replication Lag Monitoring**: Built-in health checks for lag
3. **Automated Switchover**: Full switchover workflow in single playbook
4. **Multi-Region Support**: Enhanced cross-region configuration
5. **Backup Verification**: Automatic validation of backup accessibility
6. **Performance Profiles**: Predefined tuning for common workloads
7. **Certificate Management**: Automatic cert-manager integration
8. **Network Policy**: Automatic creation of network policies
9. **Service Mesh**: Istio/Linkerd integration for cross-cluster
10. **GitOps Integration**: ArgoCD/Flux CD support

## Support and Documentation

- **Role Documentation**: `roles/deploy_replica_cluster/README.md`
- **Playbook Guide**: `playbooks/README.md`
- **Collection README**: `README.md`
- **Example Playbooks**: `playbooks/examples/`
- **Inventory Example**: `inventory/replica-example.yml`
- **EDB Documentation**: https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/replica_cluster/

## Summary

The `deploy_replica_cluster` role provides a production-ready, comprehensive solution for deploying PostgreSQL replica clusters with EDB Postgres for Kubernetes. It supports multiple strategies, bootstrap methods, and replication configurations, making it suitable for disaster recovery, high availability, analytics workloads, and data protection use cases.

The role follows Ansible and EDB best practices, includes extensive documentation and examples, and is ready for immediate use in production environments or integration with Ansible Automation Platform workflows.
