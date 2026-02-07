# Role: execute_sql

Execute SQL queries on EnterpriseDB Postgres clusters.

## Description

This role executes SQL queries across multiple PostgreSQL databases. It supports single queries, multiple queries, SQL files, and transaction-based execution with comprehensive error handling and result logging.

## Requirements

- Ansible 2.14+
- `kubernetes.core` collection
- `community.postgresql` collection
- Valid kubeconfig for target OpenShift cluster
- Database access credentials

## Role Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `cluster_name` | PostgreSQL cluster name | `prod-db` |
| `namespace` | Kubernetes namespace | `production` |
| `kubeconfig_path` | Path to kubeconfig file | `~/.kube/config` |
| `pg_host` | Database host | `prod-db-rw.production.svc` |
| `pg_database` | Database name | `app` |

### Optional Variables (with defaults)

| Variable | Default | Description |
|----------|---------|-------------|
| `sql_query` | `SELECT version();` | SQL query to execute |
| `sql_file` | `null` | Path to SQL file |
| `run_on` | `all` | Target filter (all/primary/production) |
| `autocommit` | `true` | Enable autocommit |
| `display_results` | `true` | Display query results |

See [defaults/main.yml](defaults/main.yml) for all available variables.

## Dependencies

None.

## Example Playbook

```yaml
- hosts: postgres_clusters
  roles:
    - role: edb.postgres_operations.execute_sql
      vars:
        sql_query: "SELECT COUNT(*) FROM users;"
        run_on: production
```

## Example with SQL File

```yaml
- hosts: postgres_clusters
  roles:
    - role: edb.postgres_operations.execute_sql
      vars:
        sql_file: ./migrations/001_create_tables.sql
        transaction_mode: true
```

## Example with Multiple Queries

```yaml
- hosts: postgres_clusters
  roles:
    - role: edb.postgres_operations.execute_sql
      vars:
        sql_queries:
          - "CREATE TABLE IF NOT EXISTS users (id SERIAL PRIMARY KEY, name VARCHAR(100));"
          - "INSERT INTO users (name) VALUES ('Alice'), ('Bob');"
          - "SELECT * FROM users;"
```

## Output

The role sets the following facts:

- `processed_results` - Query execution results and metadata
- `sql_execution_time` - Query execution time in seconds

## License

Apache-2.0

## Author

EDB Engineering Team
