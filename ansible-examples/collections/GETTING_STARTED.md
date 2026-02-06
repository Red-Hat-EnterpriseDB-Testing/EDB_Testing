# Getting Started with edb.postgres_operations Collection

This guide will help you quickly get started with the `edb.postgres_operations` Ansible collection for managing PostgreSQL clusters across multiple OpenShift datacenters.

## 📋 Prerequisites

Before you begin, ensure you have:

- [ ] Ansible 2.14 or later installed
- [ ] Access to OpenShift/Kubernetes clusters
- [ ] EDB Postgres for Kubernetes operator installed on target clusters
- [ ] Valid kubeconfig files for your clusters
- [ ] Python packages: `kubernetes`, `psycopg2-binary`

## 🚀 Installation

### Step 1: Install Required Collections

```bash
cd /home/cferman/Documents/GitHub/EDB_Testing/ansible-examples/collections
ansible-galaxy collection install -r requirements.yml
```

This installs:
- `kubernetes.core`
- `community.postgresql`

### Step 2: Install the edb.postgres_operations Collection

```bash
# Install from local directory
ansible-galaxy collection install ./ansible_collections/edb/postgres_operations

# Or install to specific path
ansible-galaxy collection install ./ansible_collections/edb/postgres_operations \
  -p ~/.ansible/collections
```

### Step 3: Verify Installation

```bash
ansible-galaxy collection list | grep postgres_operations
```

Expected output:
```
edb.postgres_operations    1.0.0
```

## 🔧 Configuration

### 1. Configure Inventory

Edit `inventory.yml` with your cluster details:

```yaml
all:
  children:
    openshift_clusters:
      children:
        datacenter1:
          hosts:
            ocp1:
              ansible_host: api.ocp1.example.com
              kubeconfig_path: ~/.aap/kubeconfig.ocp1
              datacenter: dc1
              location: "Primary Datacenter"
```

### 2. Test Connectivity

```bash
# Test kubeconfig access
kubectl --kubeconfig ~/.aap/kubeconfig.ocp1 get nodes

# Test Ansible connectivity
ansible openshift_clusters -i inventory.yml -m ping
```

## 🎯 Your First Playbook

### Option 1: Use Pre-built Playbooks

#### Check Cluster Health

```bash
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/check-health.yml \
  -i inventory.yml
```

#### Deploy a Test Cluster

```bash
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/deploy-cluster.yml \
  -i inventory.yml \
  -l datacenter1 \
  -e "cluster_name=test-db" \
  -e "namespace=default" \
  -e "instances=1"
```

#### Execute SQL Query

```bash
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/execute-sql.yml \
  -i inventory.yml \
  -e "sql_query='SELECT version();'"
```

### Option 2: Create Custom Playbook

Create `my-first-playbook.yml`:

```yaml
---
- name: My First PostgreSQL Automation
  hosts: openshift_clusters
  gather_facts: false
  
  roles:
    - role: edb.postgres_operations.check_health
      vars:
        check_operator: true
        check_clusters: true
```

Run it:
```bash
ansible-playbook my-first-playbook.yml -i inventory.yml
```

## 📚 Learn by Example

### Example 1: Deploy Development Cluster

```bash
ansible-playbook examples/deploy-production-cluster.yml \
  -i inventory.yml \
  -e @examples/vars/development.yml \
  -e "cluster_name=dev-db"
```

### Example 2: Deploy Production Cluster

```bash
ansible-playbook examples/deploy-production-cluster.yml \
  -i inventory.yml \
  -e @examples/vars/production.yml \
  -e "cluster_name=prod-db"
```

### Example 3: Run Database Migration

Create `migrations/v1.0/migration.sql`:
```sql
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
```

Run migration:
```bash
ansible-playbook examples/run-database-migration.yml \
  -i inventory.yml \
  -e "migration_version=v1.0"
```

### Example 4: Scheduled Health Monitoring

```bash
ansible-playbook examples/scheduled-health-monitoring.yml \
  -i inventory.yml \
  -e "save_report=true" \
  -e "enable_alerts=true"
```

## 🔑 Common Tasks

### Deploy a 5-Instance Production Cluster

```bash
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/deploy-cluster.yml \
  -i inventory.yml \
  -l datacenter1 \
  -e "cluster_name=prod-db" \
  -e "namespace=production" \
  -e "instances=5" \
  -e "storage_size=500Gi" \
  -e "postgres_version=16.8"
```

### Check Health Across All Datacenters

```bash
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/check-health.yml \
  -i inventory.yml \
  -e "check_replication=true" \
  -e "save_report=true"
```

### Execute SQL on Production Databases

```bash
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/execute-sql.yml \
  -i inventory.yml \
  -l production_databases \
  -e "sql_query='SELECT COUNT(*) FROM users;'" \
  -e "display_results=true"
```

### Run SQL File in Transaction

```bash
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/execute-sql.yml \
  -i inventory.yml \
  -e "sql_file=./my-script.sql" \
  -e "transaction_mode=true" \
  -e "fail_on_error=true"
```

## 🎨 Using Roles in Your Playbooks

### Basic Role Usage

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
```

### Multiple Roles in Workflow

```yaml
---
- name: Complete Deployment Workflow
  hosts: openshift_clusters
  gather_facts: false
  
  tasks:
    - name: Deploy PostgreSQL cluster
      include_role:
        name: edb.postgres_operations.deploy_cluster
      vars:
        cluster_name: prod-db
        instances: 5
    
    - name: Health check after deployment
      include_role:
        name: edb.postgres_operations.check_health
      vars:
        fail_on_unhealthy: true
    
    - name: Initialize database
      include_role:
        name: edb.postgres_operations.execute_sql
      vars:
        sql_file: ./init.sql
```

### Conditional Role Execution

```yaml
---
- name: Conditional Operations
  hosts: openshift_clusters
  gather_facts: false
  
  roles:
    - role: edb.postgres_operations.deploy_cluster
      when: deploy_cluster | default(false)
    
    - role: edb.postgres_operations.check_health
      when: check_health | default(true)
```

## 🔐 Security Best Practices

### Use Ansible Vault

```bash
# Create vault file
ansible-vault create vars/secrets.yml

# Add sensitive variables:
# db_superuser_password: "your_secure_password"
# edb_pull_secret_file: "path/to/dockerconfig.json"

# Use in playbook
ansible-playbook playbook.yml --ask-vault-pass -e @vars/secrets.yml
```

### Environment Variables

```bash
# Set environment variables
export AAP_WEBHOOK_URL="https://aap.example.com/webhook"
export KUBECONFIG=~/.aap/kubeconfig.ocp1

# Use in playbook with lookup
ansible-playbook playbook.yml -e "aap_webhook_url={{ lookup('env', 'AAP_WEBHOOK_URL') }}"
```

## 🐛 Troubleshooting

### Collection Not Found

```bash
# List installed collections
ansible-galaxy collection list

# Reinstall if needed
ansible-galaxy collection install ./ansible_collections/edb/postgres_operations --force
```

### Cannot Connect to Cluster

```bash
# Verify kubeconfig
kubectl --kubeconfig ~/.aap/kubeconfig.ocp1 cluster-info

# Test with Ansible
ansible ocp1 -i inventory.yml -m kubernetes.core.k8s_info -a "kind=Namespace"
```

### Role Not Found

```bash
# Check ansible.cfg
cat ansible.cfg | grep collections_paths

# Verify role exists
ls -l ~/.ansible/collections/ansible_collections/edb/postgres_operations/roles/
```

### Debug Mode

```bash
# Run with verbose output
ansible-playbook playbook.yml -vvv

# Enable debug in playbook
ansible-playbook playbook.yml -e "verbose_output=true"
```

## 📖 Next Steps

1. **Read Role Documentation**
   - [deploy_cluster](ansible_collections/edb/postgres_operations/roles/deploy_cluster/README.md)
   - [execute_sql](ansible_collections/edb/postgres_operations/roles/execute_sql/README.md)
   - [check_health](ansible_collections/edb/postgres_operations/roles/check_health/README.md)

2. **Review Examples**
   - Check `examples/` directory for more complex scenarios

3. **Customize Variables**
   - Review `roles/*/defaults/main.yml` for all available options

4. **Set Up AAP Integration**
   - Create job templates in AAP
   - Configure workflows
   - Set up schedules

5. **Advanced Topics**
   - Multi-datacenter deployments
   - Backup and restore
   - Performance tuning
   - DR scenarios

## 🆘 Getting Help

- **Collection README**: [README.md](README.md)
- **Migration Guide**: [../COLLECTION_MIGRATION.md](../COLLECTION_MIGRATION.md)
- **EDB Documentation**: https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/
- **Ansible Documentation**: https://docs.ansible.com/

## ✅ Quick Reference

### File Locations

```
ansible-examples/collections/
├── ansible.cfg                          # Ansible configuration
├── inventory.yml                        # Cluster inventory
├── requirements.yml                     # Collection dependencies
├── examples/                            # Example playbooks
│   ├── deploy-production-cluster.yml
│   ├── run-database-migration.yml
│   ├── scheduled-health-monitoring.yml
│   └── vars/
│       ├── production.yml
│       └── development.yml
└── ansible_collections/edb/postgres_operations/
    ├── galaxy.yml                       # Collection metadata
    ├── README.md                        # Collection docs
    ├── CHANGELOG.md                     # Version history
    ├── roles/                           # Ansible roles
    │   ├── deploy_cluster/
    │   ├── execute_sql/
    │   └── check_health/
    └── playbooks/                       # Ready-to-use playbooks
        ├── deploy-cluster.yml
        ├── execute-sql.yml
        ├── check-health.yml
        └── site.yml
```

### Common Commands

```bash
# Install collection
ansible-galaxy collection install ./ansible_collections/edb/postgres_operations

# List installed collections
ansible-galaxy collection list

# Deploy cluster
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/deploy-cluster.yml \
  -i inventory.yml -e "cluster_name=test"

# Check health
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/check-health.yml \
  -i inventory.yml

# Execute SQL
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/execute-sql.yml \
  -i inventory.yml -e "sql_query='SELECT 1;'"
```

---

**Version**: 1.0.0  
**Last Updated**: 2026-02-06  
**Questions?** Check the [README](README.md) or [migration guide](../COLLECTION_MIGRATION.md)
