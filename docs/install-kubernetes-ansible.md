# EDB Postgres for Kubernetes — Ansible Installation

Deploy PostgreSQL clusters on OpenShift or Kubernetes using the `edb.postgres_operations` Ansible collection. This approach is recommended for repeatable, multi-datacenter deployments and integration with AAP.

[← Back to main README](../README.md#installation) · [Manual installation](install-kubernetes-manual.md)

## Prerequisites

- **EDB Postgres for Kubernetes operator** installed on the cluster (see [Manual installation](install-kubernetes-manual.md#1-install-the-edb-postgres-for-openshift-operator)).
- **Inventory and kubeconfig** for your OpenShift/Kubernetes cluster(s).
- **EDB pull secret**: Docker config file or existing Kubernetes secret. See [EDB pull secret](../ansible_collections/edb/postgres_operations/roles/deploy_cluster/README.md#edb-pull-secret).

## 1. Install the collection

```bash
# From project root
ansible-galaxy collection install ./ansible_collections/edb/postgres_operations
```

Install dependencies if needed:

```bash
ansible-galaxy collection install -r ansible_collections/edb/postgres_operations/requirements.yml
```

## 2. Configure inventory

Use the example inventory or your own. Ensure each host has `kubeconfig_path`, `datacenter`, and (for deploy) `cluster_name`, `namespace` as needed.

Example location: `ansible_collections/edb/postgres_operations/inventory/example-multi-datacenter.yml`. Edit with your clusters and kubeconfig paths.

## 3. Deploy a PostgreSQL cluster

From project root:

```bash
# Deploy a cluster (set edb_pull_secret_file if not using default path)
ansible-playbook -i ansible_collections/edb/postgres_operations/inventory/example-multi-datacenter.yml \
  ansible_collections/edb/postgres_operations/playbooks/deploy-cluster.yml \
  -e "cluster_name=prod-db" \
  -e "namespace=production" \
  -e "instances=3" \
  -e "storage_size=100Gi" \
  -e "postgres_version=16.8"
```

## Other playbooks

| Playbook | Purpose |
|----------|---------|
| [deploy-replica-cluster.yml](../ansible_collections/edb/postgres_operations/playbooks/deploy-replica-cluster.yml) | Deploy a replica cluster in a second datacenter |
| [check-health.yml](../ansible_collections/edb/postgres_operations/playbooks/check-health.yml) | Verify cluster health and replication |
| [execute-sql.yml](../ansible_collections/edb/postgres_operations/playbooks/execute-sql.yml) | Run ad-hoc or file-based SQL |
| [playbooks/examples/](../ansible_collections/edb/postgres_operations/playbooks/examples/) | Example playbooks (production, migration, monitoring, replica types) |

## Full collection documentation

- **Setup, inventory, variables**: [Collection README](../ansible_collections/edb/postgres_operations/README.md)
- **Quick start**: [GETTING_STARTED](../ansible_collections/edb/postgres_operations/docs/GETTING_STARTED.md)
- **Execution environment (AAP)**: See “Execution environment (AAP)” in the collection README.

Inventory, example playbooks, and EE build files live under `ansible_collections/edb/postgres_operations/`.

## Architecture reference

For distributed topology, primary/replica clusters, and services, see [EDB Postgres for Kubernetes Architecture](install-kubernetes-manual.md#edb-postgres-for-kubernetes-architecture) in the manual installation guide.
