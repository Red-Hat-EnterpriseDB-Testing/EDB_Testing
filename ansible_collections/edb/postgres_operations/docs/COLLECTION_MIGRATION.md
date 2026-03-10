# Collection migration

## Current layout

All Ansible content is in the **collection** at project root:

- **Collection**: `ansible_collections/edb/postgres_operations/`
- **Inventory**: `ansible_collections/edb/postgres_operations/inventory/example-multi-datacenter.yml`
- **Playbooks**: `ansible_collections/edb/postgres_operations/playbooks/`
- **Examples**: `ansible_collections/edb/postgres_operations/playbooks/examples/`
- **EE build**: `execution-environment.yml`, `requirements-ee.yml`, `requirements.txt` in collection root

The former `ansible-examples` directory (standalone playbooks, separate inventory, and duplicate docs) has been removed. Use the collection and its inventory/examples only.

## Install and run (from project root)

```bash
ansible-galaxy collection install ./ansible_collections/edb/postgres_operations
INV="-i ansible_collections/edb/postgres_operations/inventory/example-multi-datacenter.yml"

# Deploy
ansible-playbook $INV ansible_collections/edb/postgres_operations/playbooks/deploy-cluster.yml \
  -e "cluster_name=test-db" -e "namespace=default"

# Health check
ansible-playbook $INV ansible_collections/edb/postgres_operations/playbooks/check-health.yml
```

## Equivalent playbooks

| Old (removed)              | Use instead |
|---------------------------|-------------|
| deploy-postgres-cluster.yml | `playbooks/deploy-cluster.yml` + `deploy_cluster` role |
| check-cluster-health.yml  | `playbooks/check-health.yml` + `check_health` role |
| execute-sql-query.yml     | `playbooks/execute-sql.yml` + `execute_sql` role |

Use the collection roles in your own playbooks:

```yaml
- hosts: openshift_clusters
  roles:
    - role: edb.postgres_operations.deploy_cluster
      vars:
        cluster_name: prod-db
        instances: 5
```

## Docs

- [GETTING_STARTED.md](GETTING_STARTED.md)
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
- [README.md](../README.md)
