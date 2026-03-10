# Getting Started with edb.postgres_operations Collection

Quick start for the `edb.postgres_operations` Ansible collection (PostgreSQL clusters across OpenShift datacenters).

## Prerequisites

- Ansible 2.14+
- Access to OpenShift/Kubernetes clusters; EDB Postgres for Kubernetes operator installed
- Valid kubeconfig files; Python: `kubernetes`, `psycopg2-binary`

## Installation

```bash
# From project root (EDB_Testing)
ansible-galaxy collection install -r ansible_collections/edb/postgres_operations/requirements.yml
ansible-galaxy collection install ./ansible_collections/edb/postgres_operations
ansible-galaxy collection list | grep postgres_operations
```

## Inventory

Use the example inventory or your own. From project root:

```bash
INV="-i ansible_collections/edb/postgres_operations/inventory/example-multi-datacenter.yml"
```

Edit `ansible_collections/edb/postgres_operations/inventory/example-multi-datacenter.yml` with your clusters and kubeconfig paths.

## Run playbooks (from project root)

```bash
INV="-i ansible_collections/edb/postgres_operations/inventory/example-multi-datacenter.yml"

# Check health
ansible-playbook $INV ansible_collections/edb/postgres_operations/playbooks/check-health.yml

# Deploy cluster
ansible-playbook $INV ansible_collections/edb/postgres_operations/playbooks/deploy-cluster.yml \
  -e "cluster_name=test-db" -e "namespace=default" -e "instances=1"

# Execute SQL
ansible-playbook $INV ansible_collections/edb/postgres_operations/playbooks/execute-sql.yml \
  -e "sql_query='SELECT version();'"
```

## Example playbooks and vars

- `playbooks/examples/deploy-production-cluster.yml`
- `playbooks/examples/run-database-migration.yml`
- `playbooks/examples/scheduled-health-monitoring.yml`
- `playbooks/examples/vars/production.yml`, `development.yml`

Example:

```bash
ansible-playbook $INV ansible_collections/edb/postgres_operations/playbooks/examples/deploy-production-cluster.yml
```

## File locations (project root)

| Item        | Path |
|------------|------|
| Collection | `ansible_collections/edb/postgres_operations/` |
| Inventory  | `ansible_collections/edb/postgres_operations/inventory/` |
| Playbooks  | `ansible_collections/edb/postgres_operations/playbooks/` |
| Examples   | `ansible_collections/edb/postgres_operations/playbooks/examples/` |
| EE build   | `execution-environment.yml`, `requirements-ee.yml`, `requirements.txt` in collection root |

## Next steps

- Role docs: `roles/deploy_cluster/README.md`, `roles/execute_sql/README.md`, `roles/check_health/README.md`
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) — commands and variables
- [README.md](../README.md) — full collection documentation
