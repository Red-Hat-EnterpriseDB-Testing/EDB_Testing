# Quick Reference — edb.postgres_operations

Run from **project root**. Set:

```bash
INV="-i ansible_collections/edb/postgres_operations/inventory/example-multi-datacenter.yml"
```

## Install

```bash
ansible-galaxy collection install -r ansible_collections/edb/postgres_operations/requirements.yml
ansible-galaxy collection install ./ansible_collections/edb/postgres_operations
```

## Common commands

```bash
# Check health
ansible-playbook $INV ansible_collections/edb/postgres_operations/playbooks/check-health.yml

# Deploy (dev)
ansible-playbook $INV ansible_collections/edb/postgres_operations/playbooks/deploy-cluster.yml \
  -e "cluster_name=dev-db" -e "instances=1"

# Deploy (prod)
ansible-playbook $INV ansible_collections/edb/postgres_operations/playbooks/deploy-cluster.yml \
  -e "cluster_name=prod-db" -e "instances=5" -e "storage_size=500Gi"

# Execute SQL
ansible-playbook $INV ansible_collections/edb/postgres_operations/playbooks/execute-sql.yml \
  -e "sql_query='SELECT version();'"
ansible-playbook $INV ansible_collections/edb/postgres_operations/playbooks/execute-sql.yml \
  -e "sql_file=./migration.sql" -e "transaction_mode=true"
```

## Role quick reference

| Role           | Key vars |
|----------------|----------|
| deploy_cluster | `cluster_name`, `namespace`, `instances`, `storage_size`, `postgres_version` |
| execute_sql    | `sql_query`, `sql_file`, `run_on`, `transaction_mode` |
| check_health   | `check_operator`, `check_clusters`, `check_replication`, `enable_alerts`, `save_report` |

## Targeting

```bash
-l datacenter1           # One datacenter
-l production_databases  # Production DBs only
-l ocp1                  # Single host
```

## Docs

- [GETTING_STARTED.md](GETTING_STARTED.md)
- [README.md](../README.md)
- [COLLECTION_MIGRATION.md](COLLECTION_MIGRATION.md)
