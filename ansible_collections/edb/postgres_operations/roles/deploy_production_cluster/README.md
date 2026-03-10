# deploy_production_cluster

Deploys a production PostgreSQL cluster with production-oriented defaults (HA, backups, tuning). Wraps the `deploy_cluster` role.

## Requirements

- `edb.postgres_operations.deploy_cluster` (same collection)
- Target: `openshift_clusters` or a child group (e.g. `datacenter1`)

## Role Variables

See `defaults/main.yml`. Key overrides:

- `cluster_name` (default: `prod-db`)
- `namespace` (default: `production`)
- `instances` (default: `5`)
- `storage_size`, `backup_bucket`, `postgres_version`, etc.

## Example

```yaml
- hosts: datacenter1
  roles:
    - role: edb.postgres_operations.deploy_production_cluster
      vars:
        cluster_name: my-prod-db
        backup_bucket: s3://my-backups/my-prod-db
```
