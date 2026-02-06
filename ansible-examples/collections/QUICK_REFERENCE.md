# Quick Reference Card - edb.postgres_operations

## 🚀 Installation

```bash
cd /home/cferman/Documents/GitHub/EDB_Testing/ansible-examples/collections
ansible-galaxy collection install -r requirements.yml
ansible-galaxy collection install ./ansible_collections/edb/postgres_operations
```

## ✅ Verify Installation

```bash
ansible-galaxy collection list | grep postgres_operations
# Expected: edb.postgres_operations    1.0.0
```

## 📋 Common Commands

### Check Health

```bash
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/check-health.yml \
  -i inventory.yml
```

### Deploy Cluster

```bash
# Development cluster (1 instance)
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/deploy-cluster.yml \
  -i inventory.yml -e "cluster_name=dev-db" -e "instances=1"

# Production cluster (5 instances)
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/deploy-cluster.yml \
  -i inventory.yml -e "cluster_name=prod-db" -e "instances=5" -e "storage_size=500Gi"
```

### Execute SQL

```bash
# Single query
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/execute-sql.yml \
  -i inventory.yml -e "sql_query='SELECT version();'"

# SQL file
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/execute-sql.yml \
  -i inventory.yml -e "sql_file=./migration.sql" -e "transaction_mode=true"
```

## 📝 Custom Playbook Template

```yaml
---
- name: PostgreSQL Operations
  hosts: openshift_clusters
  gather_facts: false
  
  roles:
    - role: edb.postgres_operations.deploy_cluster
      vars:
        cluster_name: my-cluster
        namespace: production
        instances: 3
        storage_size: 100Gi
```

## 🎯 Role Quick Reference

### deploy_cluster

**Purpose**: Deploy PostgreSQL clusters

**Key Variables**:
- `cluster_name` - Cluster name (required)
- `namespace` - Kubernetes namespace (required)
- `instances` - Number of instances (default: 3)
- `storage_size` - Storage size (default: 10Gi)
- `postgres_version` - PostgreSQL version (default: 16.8)

**Example**:
```yaml
- role: edb.postgres_operations.deploy_cluster
  vars:
    cluster_name: prod-db
    instances: 5
```

### execute_sql

**Purpose**: Execute SQL queries

**Key Variables**:
- `sql_query` - SQL query to execute
- `sql_file` - Path to SQL file
- `run_on` - Target filter (all/primary/production)
- `transaction_mode` - Use transactions (default: false)

**Example**:
```yaml
- role: edb.postgres_operations.execute_sql
  vars:
    sql_file: ./migration.sql
    transaction_mode: true
```

### check_health

**Purpose**: Monitor cluster health

**Key Variables**:
- `check_operator` - Check operator health (default: true)
- `check_clusters` - Check clusters (default: true)
- `check_replication` - Check replication (default: true)
- `enable_alerts` - Enable alerting (default: false)
- `save_report` - Save health report (default: false)

**Example**:
```yaml
- role: edb.postgres_operations.check_health
  vars:
    enable_alerts: true
    save_report: true
```

## 🔧 Inventory Targeting

```bash
# All clusters
ansible-playbook playbook.yml -i inventory.yml

# Specific datacenter
ansible-playbook playbook.yml -i inventory.yml -l datacenter1

# Production databases only
ansible-playbook playbook.yml -i inventory.yml -l production_databases

# Single host
ansible-playbook playbook.yml -i inventory.yml -l ocp1
```

## 📁 File Locations

| File | Location |
|------|----------|
| **Collection** | `ansible_collections/edb/postgres_operations/` |
| **Roles** | `ansible_collections/edb/postgres_operations/roles/` |
| **Playbooks** | `ansible_collections/edb/postgres_operations/playbooks/` |
| **Examples** | `examples/` |
| **Variables** | `examples/vars/` |
| **Inventory** | `inventory.yml` |

## 🐛 Troubleshooting

### Collection Not Found
```bash
ansible-galaxy collection list
ansible-galaxy collection install ./ansible_collections/edb/postgres_operations --force
```

### Cannot Connect
```bash
kubectl --kubeconfig ~/.aap/kubeconfig.ocp1 get nodes
ansible ocp1 -i inventory.yml -m ping
```

### Debug Mode
```bash
ansible-playbook playbook.yml -vvv
```

## 📖 Documentation

- **Getting Started**: [GETTING_STARTED.md](GETTING_STARTED.md)
- **Full Guide**: [README.md](README.md)
- **Collection Docs**: [ansible_collections/edb/postgres_operations/README.md](ansible_collections/edb/postgres_operations/README.md)
- **Role Docs**: Check `ansible_collections/edb/postgres_operations/roles/*/README.md`

## 💡 Tips

1. **Use variable files** for environment-specific settings:
   ```bash
   ansible-playbook playbook.yml -e @examples/vars/production.yml
   ```

2. **Check mode** before applying changes:
   ```bash
   ansible-playbook playbook.yml --check
   ```

3. **Save credentials** with Ansible Vault:
   ```bash
   ansible-vault create vars/secrets.yml
   ansible-playbook playbook.yml -e @vars/secrets.yml --ask-vault-pass
   ```

4. **Filter by tags** (when defined):
   ```bash
   ansible-playbook playbook.yml --tags deploy,health
   ```

## 🎯 Common Workflows

### Deploy → Check Health
```bash
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/deploy-cluster.yml \
  -i inventory.yml -e "cluster_name=test-db"
  
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/check-health.yml \
  -i inventory.yml
```

### Health Check → SQL → Verify
```bash
# 1. Check health
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/check-health.yml -i inventory.yml

# 2. Execute SQL
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/execute-sql.yml \
  -i inventory.yml -e "sql_file=./migration.sql"

# 3. Verify again
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/check-health.yml -i inventory.yml
```

---

**Version**: 1.0.0 | **Last Updated**: 2026-02-06
