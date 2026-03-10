# deploy_development_cluster

Deploys a development PostgreSQL cluster with minimal defaults. Wraps the `deploy_cluster` role.

## Requirements

- `edb.postgres_operations.deploy_cluster` (same collection)
- Target: `openshift_clusters` or a child group

## Role Variables

See `defaults/main.yml`. Override `cluster_name`, `namespace`, `instances`, etc. as needed.

## Example

```yaml
- hosts: datacenter1
  roles:
    - role: edb.postgres_operations.deploy_development_cluster
      vars:
        cluster_name: my-dev-db
```
