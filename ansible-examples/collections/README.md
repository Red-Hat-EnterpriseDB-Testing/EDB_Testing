# EDB PostgreSQL Operations - Ansible Collection

This directory contains the `edb.postgres_operations` Ansible collection for managing EnterpriseDB Postgres for Kubernetes clusters across multiple OpenShift datacenters.

## 🚀 Quick Start

### 1. Install the Collection

```bash
# From this directory
ansible-galaxy collection install ./ansible_collections/edb/postgres_operations -p ~/.ansible/collections

# Or install system-wide
ansible-galaxy collection install ./ansible_collections/edb/postgres_operations
```

### 2. Verify Installation

```bash
ansible-galaxy collection list | grep postgres_operations
```

Expected output:
```
edb.postgres_operations    1.0.0
```

### 3. Configure Inventory

Edit `inventory.yml` with your cluster details:

```yaml
openshift_clusters:
  children:
    datacenter1:
      hosts:
        ocp1:
          kubeconfig_path: ~/.aap/kubeconfig.ocp1
          datacenter: dc1
```

### 4. Run Your First Playbook

```bash
# Check cluster health
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/check-health.yml

# Deploy a cluster
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/deploy-cluster.yml \
  -e "cluster_name=test-db" \
  -e "namespace=default"

# Execute SQL query
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/execute-sql.yml \
  -e "sql_query='SELECT version();'"
```

## 📁 Directory Structure

```
collections/
├── ansible.cfg                    # Ansible configuration
├── inventory.yml                  # Multi-datacenter inventory
├── README.md                      # This file
└── ansible_collections/
    └── edb/
        └── postgres_operations/
            ├── galaxy.yml         # Collection metadata
            ├── README.md          # Collection documentation
            ├── roles/             # Ansible roles
            │   ├── deploy_cluster/
            │   │   ├── defaults/main.yml
            │   │   ├── tasks/main.yml
            │   │   ├── meta/main.yml
            │   │   └── README.md
            │   ├── execute_sql/
            │   │   ├── defaults/main.yml
            │   │   ├── tasks/main.yml
            │   │   ├── meta/main.yml
            │   │   └── README.md
            │   └── check_health/
            │       ├── defaults/main.yml
            │       ├── tasks/main.yml
            │       ├── meta/main.yml
            │       └── README.md
            └── playbooks/         # Ready-to-use playbooks
                ├── deploy-cluster.yml
                ├── execute-sql.yml
                ├── check-health.yml
                └── site.yml
```

## 📚 Collection Components

### Roles

The collection includes three main roles:

| Role | Description | Documentation |
|------|-------------|---------------|
| `deploy_cluster` | Deploy PostgreSQL clusters | [README](ansible_collections/edb/postgres_operations/roles/deploy_cluster/README.md) |
| `execute_sql` | Execute SQL queries | [README](ansible_collections/edb/postgres_operations/roles/execute_sql/README.md) |
| `check_health` | Monitor cluster health | [README](ansible_collections/edb/postgres_operations/roles/check_health/README.md) |

### Playbooks

| Playbook | Description | Usage |
|----------|-------------|-------|
| `deploy-cluster.yml` | Deploy new clusters | `ansible-playbook edb.postgres_operations.deploy-cluster` |
| `execute-sql.yml` | Run SQL queries | `ansible-playbook edb.postgres_operations.execute-sql` |
| `check-health.yml` | Health monitoring | `ansible-playbook edb.postgres_operations.check-health` |
| `site.yml` | Main orchestration | `ansible-playbook edb.postgres_operations.site` |

## 🔧 Usage Examples

### Example 1: Deploy Production Cluster

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

### Example 2: Run Health Check

```bash
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/check-health.yml \
  -i inventory.yml \
  -e "check_replication=true" \
  -e "enable_alerts=true"
```

### Example 3: Execute SQL Migration

```bash
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/execute-sql.yml \
  -i inventory.yml \
  -l production_databases \
  -e "sql_file=./migrations/v2.0.sql" \
  -e "transaction_mode=true"
```

### Example 4: Using Roles in Custom Playbook

Create your own playbook:

```yaml
# my-playbook.yml
---
- name: Custom PostgreSQL Operations
  hosts: openshift_clusters
  gather_facts: false
  
  tasks:
    - name: Deploy test cluster
      include_role:
        name: edb.postgres_operations.deploy_cluster
      vars:
        cluster_name: test-cluster
        namespace: testing
        instances: 1
        storage_size: 10Gi
    
    - name: Check health
      include_role:
        name: edb.postgres_operations.check_health
      vars:
        check_replication: false
```

Run it:
```bash
ansible-playbook my-playbook.yml -i inventory.yml
```

## 🎯 Common Use Cases

### Use Case 1: Multi-Datacenter Deployment

Deploy clusters to both datacenters:

```bash
# Deploy to DC1
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/deploy-cluster.yml \
  -i inventory.yml -l datacenter1 -e "cluster_name=prod-db"

# Deploy to DC2
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/deploy-cluster.yml \
  -i inventory.yml -l datacenter2 -e "cluster_name=prod-db"

# Verify both
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/check-health.yml \
  -i inventory.yml
```

### Use Case 2: Scheduled Health Monitoring

Set up in AAP as a scheduled job:

```yaml
# health-check-job.yml
---
- name: Scheduled Health Check
  hosts: openshift_clusters
  roles:
    - role: edb.postgres_operations.check_health
      vars:
        save_report: true
        report_output_dir: /var/log/postgres-health
        enable_aap_notifications: true
```

Schedule: Every 5 minutes

### Use Case 3: Database Migration Workflow

```yaml
# migration-workflow.yml
---
- name: Database Migration Workflow
  hosts: production_databases
  serial: 1  # One at a time
  
  tasks:
    - name: Health check before migration
      include_role:
        name: edb.postgres_operations.check_health
    
    - name: Run migration
      include_role:
        name: edb.postgres_operations.execute_sql
      vars:
        sql_file: ./migrations/{{ migration_version }}.sql
        transaction_mode: true
        fail_on_error: true
    
    - name: Verify migration
      include_role:
        name: edb.postgres_operations.execute_sql
      vars:
        sql_query: "SELECT * FROM schema_version ORDER BY version DESC LIMIT 1;"
    
    - name: Health check after migration
      include_role:
        name: edb.postgres_operations.check_health
```

## 🔐 Security Best Practices

### 1. Credentials Management

Never commit credentials. Use Ansible Vault:

```bash
# Create vault file
ansible-vault create vars/secrets.yml

# Add to secrets.yml:
# db_superuser_password: "secure_password_here"
# edb_pull_secret_file: "path/to/dockerconfig.json"

# Use in playbook
ansible-playbook playbook.yml --ask-vault-pass -e @vars/secrets.yml
```

### 2. AAP Credential Types

In AAP, create custom credentials:
- **Type**: OpenShift or Kubernetes API Bearer Token
- **Type**: PostgreSQL Database
- **Type**: Custom (for EDB pull secrets)

### 3. RBAC Configuration

Ensure your service account has minimal permissions:

```yaml
# rbac.yml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: postgres-automation
  namespace: production
rules:
  - apiGroups: ["postgresql.k8s.enterprisedb.io"]
    resources: ["clusters"]
    verbs: ["get", "list", "create", "patch"]
  - apiGroups: [""]
    resources: ["secrets", "services"]
    verbs: ["get", "list"]
```

## 🧪 Testing

### Syntax Check

```bash
ansible-playbook playbook.yml --syntax-check
```

### Dry Run (Check Mode)

```bash
ansible-playbook playbook.yml --check -i inventory.yml
```

### Test in Development Environment

```bash
ansible-playbook playbook.yml -i inventory.yml -l development_databases
```

### Validate Roles

```bash
# Check role syntax
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/deploy-cluster.yml \
  --syntax-check

# List tasks
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/deploy-cluster.yml \
  --list-tasks
```

## 📊 AAP Integration

### Setting Up Job Templates

1. **Navigate to AAP**: Templates → Add → Add job template

2. **Configure Deploy Template**:
   - Name: `PostgreSQL - Deploy Cluster`
   - Job Type: Run
   - Inventory: Multi-Datacenter Inventory
   - Project: Your Git repository
   - Playbook: `ansible_collections/edb/postgres_operations/playbooks/deploy-cluster.yml`
   - Credentials: OpenShift credentials
   - Variables:
     ```yaml
     cluster_name: "{{ cluster_name }}"
     namespace: "{{ namespace }}"
     instances: 3
     ```
   - Survey: Enable and add fields for cluster_name, namespace, instances

3. **Configure Health Check Template**:
   - Name: `PostgreSQL - Health Check`
   - Schedule: Every 5 minutes
   - Enable notifications on failure

### Workflow Templates

Create a deployment workflow:

```
┌─────────────────────┐
│ Deploy to DC1       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Health Check DC1    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Deploy to DC2       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Health Check DC2    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Send Notification   │
└─────────────────────┘
```

## 🐛 Troubleshooting

### Issue: Collection not found

```bash
# Check installed collections
ansible-galaxy collection list

# Reinstall
ansible-galaxy collection install ./ansible_collections/edb/postgres_operations --force
```

### Issue: Role not found

```bash
# Verify collection path in ansible.cfg
cat ansible.cfg | grep collections_paths

# Should include: ./ansible_collections
```

### Issue: Cannot connect to cluster

```bash
# Test kubeconfig
kubectl --kubeconfig ~/.aap/kubeconfig.ocp1 get nodes

# Test with ansible
ansible ocp1 -i inventory.yml -m kubernetes.core.k8s_info \
  -a "kind=Namespace"
```

### Issue: Python module missing

```bash
# Install required Python modules
pip install kubernetes psycopg2-binary

# Or for AAP execution environment
pip install kubernetes psycopg2-binary -t /usr/lib/python3.9/site-packages
```

### Debug Mode

```bash
# Run with maximum verbosity
ansible-playbook playbook.yml -vvvv

# Enable callback
export ANSIBLE_STDOUT_CALLBACK=debug
ansible-playbook playbook.yml
```

## 📖 Additional Documentation

- [Collection README](ansible_collections/edb/postgres_operations/README.md) - Detailed collection documentation
- [deploy_cluster Role](ansible_collections/edb/postgres_operations/roles/deploy_cluster/README.md)
- [execute_sql Role](ansible_collections/edb/postgres_operations/roles/execute_sql/README.md)
- [check_health Role](ansible_collections/edb/postgres_operations/roles/check_health/README.md)
- [EDB Postgres for Kubernetes Docs](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/)

## 🤝 Contributing

See the collection README for contribution guidelines.

## 📝 License

Apache-2.0

## 👥 Authors

EDB Engineering Team

## 📞 Support

- **Issues**: GitHub Issues
- **Community**: EDB Community Forum
- **Documentation**: [EDB Documentation](https://www.enterprisedb.com/docs/)
