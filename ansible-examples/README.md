# Ansible Automation Examples for EDB Postgres

This directory contains example Ansible playbooks for managing EnterpriseDB Postgres for Kubernetes clusters across multiple OpenShift datacenters using Ansible Automation Platform (AAP).

## Files

- **`inventory.yml`** - Ansible inventory defining OpenShift clusters and PostgreSQL databases
- **`deploy-postgres-cluster.yml`** - Deploy a new PostgreSQL cluster
- **`execute-sql-query.yml`** - Execute SQL queries across multiple databases
- **`check-cluster-health.yml`** - Monitor cluster health across datacenters

## Prerequisites

### 1. Ansible Collections

Install required collections:

```bash
ansible-galaxy collection install kubernetes.core
ansible-galaxy collection install community.postgresql
```

### 2. Python Dependencies

```bash
pip install kubernetes psycopg2-binary
```

### 3. Kubeconfig Files

Ensure you have kubeconfig files for both OpenShift clusters:
- `~/.aap/kubeconfig.ocp1` - Datacenter 1
- `~/.aap/kubeconfig.ocp2` - Datacenter 2

### 4. Credentials

Store sensitive credentials in AAP credential store or Ansible Vault:
- EDB subscription token
- PostgreSQL superuser passwords
- S3 access keys (for backups)

## Usage Examples

### Deploy PostgreSQL Cluster

Deploy a 3-instance cluster in production namespace:

```bash
ansible-playbook deploy-postgres-cluster.yml \
  -i inventory.yml \
  -l datacenter1 \
  -e "cluster_name=prod-db" \
  -e "namespace=production" \
  -e "instances=3" \
  -e "storage_size=100Gi"
```

Deploy to both datacenters:

```bash
ansible-playbook deploy-postgres-cluster.yml \
  -i inventory.yml \
  -e "cluster_name=prod-db" \
  -e "namespace=production"
```

### Execute SQL Query

Run query on all databases:

```bash
ansible-playbook execute-sql-query.yml \
  -i inventory.yml \
  -e "sql_query='SELECT COUNT(*) FROM users;'"
```

Run query only on production databases:

```bash
ansible-playbook execute-sql-query.yml \
  -i inventory.yml \
  -l production_databases \
  -e "sql_query='SELECT version();'"
```

Execute SQL script from file:

```bash
ansible-playbook execute-sql-query.yml \
  -i inventory.yml \
  -e "sql_file=./migrations/001_create_tables.sql"
```

### Check Cluster Health

Check health of all clusters in both datacenters:

```bash
ansible-playbook check-cluster-health.yml \
  -i inventory.yml
```

Check specific datacenter:

```bash
ansible-playbook check-cluster-health.yml \
  -i inventory.yml \
  -l datacenter1
```

## Inventory Structure

The inventory is organized hierarchically:

```
all
├── openshift_clusters
│   ├── datacenter1 (ocp1)
│   └── datacenter2 (ocp2)
└── postgres_clusters
    ├── production_databases
    │   ├── prod_db_dc1
    │   └── prod_db_dc2
    ├── staging_databases
    │   └── stage_db_dc1
    └── development_databases
        └── dev_db_dc2
```

### Targeting Specific Groups

```bash
# All OpenShift clusters
ansible-playbook playbook.yml -l openshift_clusters

# All PostgreSQL databases
ansible-playbook playbook.yml -l postgres_clusters

# Only production databases
ansible-playbook playbook.yml -l production_databases

# Specific datacenter
ansible-playbook playbook.yml -l datacenter1

# Specific database
ansible-playbook playbook.yml -l prod_db_dc1
```

## AAP Integration

### Creating Job Templates in AAP

1. **Deploy PostgreSQL Cluster**
   - Name: Deploy PostgreSQL Cluster
   - Inventory: Multi-Datacenter Inventory
   - Playbook: deploy-postgres-cluster.yml
   - Credentials: OpenShift Credentials
   - Extra Variables:
     ```yaml
     cluster_name: my-db
     namespace: production
     instances: 3
     ```

2. **Execute SQL Query**
   - Name: Execute SQL Query
   - Inventory: Multi-Datacenter Inventory
   - Playbook: execute-sql-query.yml
   - Prompt on Launch: sql_query, run_on

3. **Health Check**
   - Name: PostgreSQL Health Check
   - Inventory: Multi-Datacenter Inventory
   - Playbook: check-cluster-health.yml
   - Schedule: Every 5 minutes

### Using AAP Workflows

Create a workflow to:
1. Deploy cluster in DC1
2. Wait for cluster ready
3. Deploy cluster in DC2
4. Configure replication
5. Run health check
6. Send notification

### AAP Surveys

Add surveys to job templates for user-friendly execution:

**Deploy Cluster Survey:**
- Cluster Name (text)
- Namespace (choice: production, staging, development)
- Number of Instances (integer, 1-5)
- Storage Size (text, default: 10Gi)
- Datacenter (choice: datacenter1, datacenter2, both)

**Execute SQL Survey:**
- SQL Query (textarea)
- Target (choice: all, production, staging)
- Datacenter (choice: datacenter1, datacenter2, both)

## Security Best Practices

### 1. Use AAP Credential Store

Never hardcode credentials in playbooks. Use AAP credential types:
- **Machine Credential** for kubeconfig
- **Custom Credential** for database passwords
- **Amazon Web Services** for S3 backups

### 2. Ansible Vault

For local development, use Ansible Vault:

```bash
# Encrypt sensitive vars
ansible-vault encrypt_string 'mypassword' --name 'db_password'

# Run with vault password
ansible-playbook playbook.yml --ask-vault-pass
```

### 3. No-Log for Sensitive Data

Always use `no_log: true` for tasks handling passwords:

```yaml
- name: Get database password
  kubernetes.core.k8s_info:
    kind: Secret
    name: db-secret
  register: secret
  no_log: true
```

### 4. RBAC

Ensure service accounts have minimal required permissions:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: postgres-manager
rules:
  - apiGroups: ["postgresql.k8s.enterprisedb.io"]
    resources: ["clusters", "backups"]
    verbs: ["get", "list", "create", "patch"]
```

## Monitoring Integration

### Prometheus Metrics

Query PostgreSQL metrics from Prometheus:

```yaml
- name: Get database metrics
  uri:
    url: "http://prometheus:9090/api/v1/query"
    method: GET
    body_format: json
    body:
      query: "pg_stat_database_tup_inserted{namespace='production'}"
  register: metrics
```

### Alerting

Configure AAP to respond to Prometheus alerts:

1. Create AAP webhook
2. Configure Alertmanager to call webhook
3. Playbook auto-remediates issues

## Troubleshooting

### Common Issues

**Issue**: Connection timeout to database

```bash
# Check pod status
ansible-playbook -i inventory.yml -m kubernetes.core.k8s_info \
  -a "kind=Pod namespace=production label_selectors=postgresql=prod-db"

# Check service endpoints
ansible-playbook -i inventory.yml -m kubernetes.core.k8s_info \
  -a "kind=Service namespace=production name=prod-db-rw"
```

**Issue**: Authentication failure

```bash
# Verify secret exists
ansible-playbook -i inventory.yml -m kubernetes.core.k8s_info \
  -a "kind=Secret namespace=production name=prod-db-superuser"
```

**Issue**: Operator not responding

```bash
# Check operator logs
kubectl logs -n postgresql-operator-system \
  deployment/postgresql-operator-controller-manager
```

### Debug Mode

Run playbooks with verbose output:

```bash
ansible-playbook playbook.yml -vvv
```

## Advanced Examples

### Automated Backup and Restore

```yaml
- name: Backup database
  kubernetes.core.k8s:
    definition:
      apiVersion: postgresql.k8s.enterprisedb.io/v1
      kind: Backup
      metadata:
        name: "backup-{{ ansible_date_time.epoch }}"
        namespace: production
      spec:
        cluster:
          name: prod-db
```

### Database Migration

```yaml
- name: Run database migration
  include_role:
    name: database_migration
  vars:
    migration_dir: ./migrations
    target_database: prod_db_dc1
```

### High Availability Testing

```yaml
- name: Simulate primary failure
  kubernetes.core.k8s:
    kubeconfig: "{{ kubeconfig_path }}"
    state: absent
    kind: Pod
    namespace: production
    name: "{{ current_primary }}"
  
- name: Wait for failover
  pause:
    seconds: 30
  
- name: Verify new primary elected
  kubernetes.core.k8s_info:
    kind: Cluster
    namespace: production
    name: prod-db
  register: cluster_status
```

## Contributing

When creating new playbooks:

1. Follow Ansible best practices
2. Include error handling
3. Add documentation comments
4. Test in staging first
5. Use tags for selective execution
6. Include rollback procedures

## Resources

- [Ansible Automation Platform Documentation](https://docs.ansible.com/automation.html)
- [Kubernetes Collection](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/)
- [EDB Postgres for Kubernetes](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/)
- [PostgreSQL Collection](https://docs.ansible.com/ansible/latest/collections/community/postgresql/)
