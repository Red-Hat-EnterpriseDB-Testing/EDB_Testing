# Role: deploy_cluster

Deploy EnterpriseDB Postgres for Kubernetes clusters on OpenShift.

## Description

This role automates the deployment of PostgreSQL clusters using the EDB Postgres for Kubernetes operator. It handles namespace creation, secret management, cluster configuration, and monitoring setup.

## Requirements

- Ansible 2.14+
- `kubernetes.core` collection
- `community.postgresql` collection
- Valid kubeconfig for target OpenShift cluster
- EDB subscription credentials

## Role Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `cluster_name` | Name of the PostgreSQL cluster | `prod-db` |
| `namespace` | Kubernetes namespace | `production` |
| `kubeconfig_path` | Path to kubeconfig file | `~/.kube/config` |
| `datacenter` | Datacenter identifier | `dc1` |

### Optional Variables (with defaults)

| Variable | Default | Description |
|----------|---------|-------------|
| `instances` | `3` | Number of PostgreSQL instances |
| `postgres_version` | `16.8` | PostgreSQL version |
| `storage_size` | `10Gi` | Storage size for data |
| `storage_class` | `local-path` | Storage class name |
| `monitoring_enabled` | `true` | Enable monitoring |

See [defaults/main.yml](defaults/main.yml) for all available variables.

## Dependencies

None.

## Example Playbook

```yaml
- hosts: openshift_clusters
  roles:
    - role: edb.postgres_operations.deploy_cluster
      vars:
        cluster_name: prod-db
        namespace: production
        instances: 5
        storage_size: 100Gi
```

## Example Usage with Extra Vars

```bash
ansible-playbook playbook.yml \
  -e "cluster_name=prod-db" \
  -e "namespace=production" \
  -e "instances=5"
```

## Output

The role sets the following facts:

- `cluster_primary` - Name of the primary pod
- `cluster_phase` - Current cluster phase
- `cluster_instances` - Total number of instances
- `cluster_ready_instances` - Number of ready instances
- `cluster_rw_service` - Read-write service endpoint
- `cluster_ro_service` - Read-only service endpoint

## License

Apache-2.0

## Author

EDB Engineering Team
