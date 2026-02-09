# EDB Postgres Operations Playbooks

This directory contains playbooks for managing PostgreSQL clusters using the EDB Postgres for Kubernetes operator.

## Available Playbooks

### Core Playbooks

| Playbook | Description | Use Case |
|----------|-------------|----------|
| `deploy-cluster.yml` | Deploy primary PostgreSQL cluster | Initial cluster deployment |
| `deploy-replica-cluster.yml` | Deploy replica cluster | DR, HA, read replicas |
| `check-health.yml` | Check cluster health and status | Monitoring, troubleshooting |
| `execute-sql.yml` | Execute SQL queries against cluster | Database operations |
| `site.yml` | Main orchestration playbook | Interactive operations menu |

### Example Playbooks

Located in the `examples/` directory:

| Playbook | Description |
|----------|-------------|
| `deploy-dr-replica.yml` | Deploy DR replica with distributed topology |
| `deploy-analytics-replica.yml` | Deploy standalone replica for analytics |
| `deploy-delayed-replica.yml` | Deploy delayed replica for data protection |
| `deploy-cross-region-replica.yml` | Deploy cross-region replica with snapshot |

## Quick Start

### 1. Deploy Primary Cluster

```bash
ansible-playbook deploy-cluster.yml \
  -i inventory/production.yml \
  -e "cluster_name=prod-db" \
  -e "namespace=production" \
  -e "instances=3" \
  -e "storage_size=100Gi"
```

### 2. Deploy Replica Cluster for DR

```bash
ansible-playbook deploy-replica-cluster.yml \
  -i inventory/replica-example.yml \
  -e "replica_cluster_name=prod-db-replica" \
  -e "source_cluster_name=prod-db" \
  -e "replica_strategy=distributed_topology" \
  -e "global_primary_cluster=prod-db"
```

### 3. Check Cluster Health

```bash
ansible-playbook check-health.yml \
  -i inventory/production.yml \
  -e "cluster_name=prod-db" \
  -e "namespace=production"
```

### 4. Interactive Site Playbook

```bash
ansible-playbook site.yml -i inventory/production.yml
```

## Replica Cluster Deployment Scenarios

### Scenario 1: Disaster Recovery (Distributed Topology)

Deploy a replica cluster for disaster recovery with controlled switchover capability:

```bash
ansible-playbook examples/deploy-dr-replica.yml \
  -i inventory/replica-example.yml \
  --limit dc2_clusters
```

**Key Features:**
- Symmetric architecture (both clusters can be primary)
- Zero data loss switchover
- Bidirectional failover capability
- Independent backups per datacenter

### Scenario 2: Analytics Workloads (Standalone Replica)

Deploy a dedicated replica for analytics and reporting:

```bash
ansible-playbook examples/deploy-analytics-replica.yml \
  -i inventory/replica-example.yml \
  --limit analytics_clusters
```

**Key Features:**
- Read-only replica optimized for queries
- Scaled horizontally (more instances)
- Larger memory allocation for caching
- No impact on production cluster

### Scenario 3: Data Protection (Delayed Replica)

Deploy a delayed replica for protection against accidental data modifications:

```bash
ansible-playbook examples/deploy-delayed-replica.yml \
  -i inventory/production.yml \
  -e "replica_min_apply_delay=8h"
```

**Key Features:**
- 8-hour recovery window
- Protection against human errors
- Minimal resources required
- Same datacenter for fast recovery

### Scenario 4: Cross-Region Replication

Deploy a replica in a different region using volume snapshots:

```bash
ansible-playbook examples/deploy-cross-region-replica.yml \
  -i inventory/multi-region.yml \
  --limit region_west
```

**Key Features:**
- Fast bootstrap via volume snapshot
- Cross-region disaster recovery
- Hybrid replication (streaming + WAL archive)
- Region-specific backup buckets

## Inventory Configuration

### Basic Inventory Structure

```yaml
all:
  children:
    openshift_clusters:
      hosts:
        dc1:
          kubeconfig_path: ~/.kube/dc1-config
          datacenter: dc1
        dc2:
          kubeconfig_path: ~/.kube/dc2-config
          datacenter: dc2
```

See `inventory/replica-example.yml` for a complete example.

## Common Variables

### Primary Cluster Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `cluster_name` | Yes | - | PostgreSQL cluster name |
| `namespace` | Yes | - | Kubernetes namespace |
| `kubeconfig_path` | Yes | - | Path to kubeconfig |
| `datacenter` | Yes | - | Datacenter identifier |
| `instances` | No | `3` | Number of instances |
| `storage_size` | No | `10Gi` | Storage size |
| `postgres_version` | No | `16.8` | PostgreSQL version |

### Replica Cluster Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `replica_cluster_name` | Yes | - | Replica cluster name |
| `source_cluster_name` | Yes | - | Source cluster name |
| `replica_strategy` | Yes | `distributed_topology` | `distributed_topology` or `standalone` |
| `bootstrap_method` | Yes | `pg_basebackup` | Bootstrap method |
| `global_primary_cluster` | Conditional | - | Current global primary (distributed only) |

For complete variable documentation, see role-specific README files in `roles/*/README.md`.

## Controlled Switchover Process

For distributed topology clusters, perform a controlled switchover:

### Step 1: Demote Current Primary (DC1)

```bash
# Update DC1 cluster configuration to designate DC2 as new primary
ansible-playbook deploy-cluster.yml \
  -i inventory/replica-example.yml \
  --limit dc1_clusters \
  -e "global_primary_cluster=prod-db-replica"
```

### Step 2: Get Demotion Token

```bash
# Retrieve demotion token from demoted cluster
kubectl get cluster prod-db -n production \
  -o jsonpath='{.status.demotionToken}'
```

### Step 3: Promote Replica (DC2)

```bash
# Promote DC2 replica with demotion token
ansible-playbook deploy-replica-cluster.yml \
  -i inventory/replica-example.yml \
  --limit dc2_clusters \
  -e "global_primary_cluster=prod-db-replica" \
  -e "promotion_token=<TOKEN_FROM_STEP_2>"
```

## Monitoring and Health Checks

### Check Cluster Status

```bash
ansible-playbook check-health.yml \
  -i inventory/production.yml \
  -e "cluster_name=prod-db"
```

### Check Replication Lag

```bash
kubectl get cluster prod-db-replica -n production \
  -o jsonpath='{.status.instances}'
```

### Check Primary Status

```bash
kubectl cnp status prod-db -n production
kubectl cnp status prod-db-replica -n production
```

## Troubleshooting

### Replica Not Syncing

1. Check network connectivity:
   ```bash
   kubectl exec -n production prod-db-replica-1 -- \
     pg_isready -h prod-db-rw.production.svc -p 5432
   ```

2. Check replication user permissions:
   ```bash
   kubectl logs -n production prod-db-replica-1 | grep replication
   ```

3. Verify WAL archive access:
   ```bash
   kubectl logs -n production prod-db-replica-1 | grep "restore_command"
   ```

### Secrets Not Synchronized

```bash
# Manually copy secrets if sync fails
kubectl get secret prod-db-superuser -n production -o yaml | \
  sed 's/name: prod-db-superuser/name: prod-db-replica-superuser/' | \
  kubectl apply -f -
```

### Bootstrap Failures

1. Check source cluster accessibility
2. Verify S3 credentials (for object store bootstrap)
3. Confirm volume snapshot exists and is ready (for snapshot bootstrap)
4. Review cluster logs:
   ```bash
   kubectl logs -n production prod-db-replica-1
   ```

## Best Practices

1. **Distributed Topology**: Always use symmetric architectures with identical configurations
2. **Secret Management**: Keep role definitions and secrets synchronized across clusters
3. **Monitoring**: Monitor replication lag continuously
4. **Testing**: Regularly test controlled switchover procedures
5. **Backups**: Configure independent backups for each cluster in distributed topology
6. **Network**: Ensure reliable connectivity for streaming replication
7. **Resources**: Size replica clusters appropriately for their workload (DR, analytics, etc.)

## References

- [EDB Replica Clusters Documentation](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/replica_cluster/)
- [EDB Architecture Guide](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/architecture/)
- [Collection README](../README.md)

## Support

For issues or questions:
1. Check role-specific README in `roles/*/README.md`
2. Review example playbooks in `examples/`
3. Consult EDB documentation
4. Contact EDB support
