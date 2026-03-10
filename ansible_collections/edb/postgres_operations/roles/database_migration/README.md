# database_migration

Runs a database migration workflow: pre-migration health check, backup placeholder, check if migration already applied, run migration SQL, record version, optional verify SQL, post-migration health check. Uses `check_health` and `execute_sql` roles.

## Requirements

- Target: `production_databases` (or group with `pg_host`, `cluster_name`, `namespace`, `kubeconfig_path`, `datacenter`)
- A `schema_migrations` table (or name via `migration_schema_table`) with columns `version`, `applied_at`
- Migration SQL in `./migrations/{{ migration_version }}/migration.sql` (or override `migration_file`)
- Optional: `./migrations/{{ migration_version }}/verify.sql` for verification

## Role Variables

See `defaults/main.yml`:

- `migration_version` (default: `v1.0`) — version key for this migration
- `migration_file` — path to migration SQL file
- `migration_verify_file` — optional path to verify SQL file
- `migration_schema_table` (default: `schema_migrations`) — table used to track applied versions
- `transaction_mode`, `fail_on_error`, `query_timeout`, etc.
- `migration_check_replication`, `migration_fail_on_unhealthy` — options for pre/post health checks

## Example

```yaml
- hosts: production_databases
  serial: 1
  roles:
    - role: edb.postgres_operations.database_migration
      vars:
        migration_version: v2.1
        migration_file: ./migrations/v2.1/migration.sql
```

Run with: `ansible-playbook playbook.yml -e "migration_version=v2.1"`
