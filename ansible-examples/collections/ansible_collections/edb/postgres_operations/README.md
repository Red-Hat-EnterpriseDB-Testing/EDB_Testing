# Ansible Collection: edb.postgres_operations

This collection provides roles and playbooks for managing EnterpriseDB Postgres for Kubernetes clusters across multiple OpenShift datacenters using Ansible Automation Platform (AAP).

## Description

The `edb.postgres_operations` collection simplifies PostgreSQL cluster management with comprehensive roles:

### Database Management
- **deploy_cluster** - Deploy and configure PostgreSQL clusters
- **deploy_replica_cluster** - Deploy replica clusters for DR and HA
- **execute_sql** - Execute SQL queries across multiple databases
- **check_health** - Monitor cluster health and replication status

### AAP Cluster Management & DR
- **manage_aap_cluster** - Manage AAP cluster scaling and services (OpenShift/RHEL)
- **efm_integration** - Integrate AAP management with EDB Failover Manager

## Requirements

### Ansible Version

- Ansible Core 2.14 or later

### Collections

```bash
ansible-galaxy collection install kubernetes.core
ansible-galaxy collection install community.postgresql
```

### Python Dependencies

```bash
pip install kubernetes psycopg2-binary
```

### OpenShift/Kubernetes

- Valid kubeconfig files for target clusters
- EDB Postgres for Kubernetes operator installed
- Appropriate RBAC permissions

## Installation

### From Ansible Galaxy (when published)

```bash
ansible-galaxy collection install edb.postgres_operations
```

### From Local Directory

```bash
# Navigate to the collections directory
cd ansible-examples/collections

# Install the collection
ansible-galaxy collection install ./ansible_collections/edb/postgres_operations -p ~/.ansible/collections
```

### From Git Repository

```bash
ansible-galaxy collection install git+https://github.com/your-org/postgres-operations.git
```

## Quick Start

### 1. Configure Inventory

Create an inventory file with your OpenShift clusters and databases:

```yaml
# inventory.yml
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

### 2. Deploy a Cluster

```bash
ansible-playbook edb.postgres_operations.deploy-cluster \
  -i inventory.yml \
  -e "cluster_name=prod-db" \
  -e "namespace=production" \
  -e "instances=3"
```

### 3. Check Health

```bash
ansible-playbook edb.postgres_operations.check-health \
  -i inventory.yml
```

### 4. Execute SQL

```bash
ansible-playbook edb.postgres_operations.execute-sql \
  -i inventory.yml \
  -e "sql_query='SELECT version();'"
```

## Roles

### deploy_cluster

Deploy PostgreSQL clusters with customizable configuration.

```yaml
- hosts: openshift_clusters
  roles:
    - role: edb.postgres_operations.deploy_cluster
      vars:
        cluster_name: my-postgres
        namespace: production
        instances: 5
        storage_size: 100Gi
        postgres_version: "16.8"
```

[Full documentation](roles/deploy_cluster/README.md)

### execute_sql

Execute SQL queries across multiple databases.

```yaml
- hosts: postgres_clusters
  roles:
    - role: edb.postgres_operations.execute_sql
      vars:
        sql_query: "SELECT COUNT(*) FROM users;"
        run_on: production
```

[Full documentation](roles/execute_sql/README.md)

### check_health

Monitor cluster health with detailed reporting.

```yaml
- hosts: openshift_clusters
  roles:
    - role: edb.postgres_operations.check_health
      vars:
        check_replication: true
        enable_alerts: true
```

[Full documentation](roles/check_health/README.md)

## Playbooks

The collection includes ready-to-use playbooks:

| Playbook | Description |
|----------|-------------|
| `deploy-cluster.yml` | Deploy PostgreSQL clusters |
| `execute-sql.yml` | Execute SQL queries |
| `check-health.yml` | Check cluster health |
| `site.yml` | Main orchestration playbook |

### Using Playbooks

```bash
# Deploy cluster
ansible-playbook edb.postgres_operations.deploy-cluster -i inventory.yml

# Check health
ansible-playbook edb.postgres_operations.check-health -i inventory.yml

# Execute SQL
ansible-playbook edb.postgres_operations.execute-sql -i inventory.yml \
  -e "sql_query='SELECT version();'"
```

## AAP Integration

### Creating Job Templates

1. **Deploy PostgreSQL Cluster**
   - Project: Your Git repository with this collection
   - Inventory: Multi-Datacenter Inventory
   - Playbook: `edb.postgres_operations.deploy-cluster`
   - Extra Variables:
     ```yaml
     cluster_name: prod-db
     namespace: production
     instances: 3
     ```

2. **Health Check**
   - Playbook: `edb.postgres_operations.check-health`
   - Schedule: Every 5 minutes
   - Enable notifications on failure

3. **SQL Execution**
   - Playbook: `edb.postgres_operations.execute-sql`
   - Survey enabled for query input

### Workflows

Create workflows to orchestrate complex operations:

```
1. Deploy Cluster (DC1)
   ↓
2. Wait for Ready
   ↓
3. Deploy Cluster (DC2)
   ↓
4. Configure Replication
   ↓
5. Health Check
   ↓
6. Send Notification
```

## Examples

### Deploy Production Cluster with Backups

```yaml
- hosts: datacenter1
  roles:
    - role: edb.postgres_operations.deploy_cluster
      vars:
        cluster_name: prod-db
        namespace: production
        instances: 5
        storage_size: 500Gi
        postgres_version: "16.8"
        backup_enabled: true
        backup_bucket: s3://my-backups/prod-db
        monitoring_enabled: true
```

### Execute Database Migration

```yaml
- hosts: postgres_clusters
  roles:
    - role: edb.postgres_operations.execute_sql
      vars:
        sql_file: ./migrations/v2.0/001_add_users_table.sql
        transaction_mode: true
        run_on: primary
        fail_on_error: true
```

### Scheduled Health Monitoring

```yaml
- hosts: openshift_clusters
  roles:
    - role: edb.postgres_operations.check_health
      vars:
        check_replication: true
        enable_aap_notifications: true
        aap_webhook_url: "{{ lookup('env', 'AAP_WEBHOOK_URL') }}"
        save_report: true
        report_format: json
```

## Security

### Credentials Management

Use Ansible Vault or AAP credential store for sensitive data:

```bash
# Encrypt database password
ansible-vault encrypt_string 'mypassword' --name 'db_password'

# Run with vault password
ansible-playbook playbook.yml --ask-vault-pass
```

### RBAC

Ensure service accounts have minimal required permissions. Example Role:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: postgres-operator
rules:
  - apiGroups: ["postgresql.k8s.enterprisedb.io"]
    resources: ["clusters", "backups"]
    verbs: ["get", "list", "create", "patch", "delete"]
```

## Testing

### Molecule Testing (if configured)

```bash
cd roles/deploy_cluster
molecule test
```

### Manual Testing

```bash
# Test in development environment
ansible-playbook test-playbook.yml -i test-inventory.yml --check

# Run in check mode first
ansible-playbook playbook.yml -i inventory.yml --check

# Then execute
ansible-playbook playbook.yml -i inventory.yml
```

## Troubleshooting

### Common Issues

**Issue**: Cannot connect to cluster

```bash
# Verify kubeconfig
kubectl --kubeconfig ~/.aap/kubeconfig.ocp1 get nodes

# Check operator status
kubectl get deployment -n postgresql-operator-system
```

**Issue**: Role not found

```bash
# List installed collections
ansible-galaxy collection list

# Reinstall collection
ansible-galaxy collection install edb.postgres_operations --force
```

**Issue**: Authentication failure

```bash
# Verify secrets exist
kubectl get secrets -n production | grep postgres
```

### Debug Mode

```bash
# Run with verbose output
ansible-playbook playbook.yml -vvv

# Enable role debugging
ansible-playbook playbook.yml -e "verbose_output=true"
```

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Update documentation
6. Submit a pull request

## Support

- **Documentation**: [EDB Postgres for Kubernetes Docs](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/)
- **Issues**: [GitHub Issues](https://github.com/enterprisedb/postgres-operator/issues)
- **Community**: [EDB Community Forum](https://www.enterprisedb.com/community)

## License

Apache-2.0

## Authors

- EDB Engineering Team

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and changes.

## Related Collections

- [kubernetes.core](https://galaxy.ansible.com/kubernetes/core)
- [community.postgresql](https://galaxy.ansible.com/community/postgresql)
- [awx.awx](https://galaxy.ansible.com/awx/awx) - For AAP integration
