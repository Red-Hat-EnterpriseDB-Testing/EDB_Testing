# Ansible Collection Migration Summary

## Overview

The Ansible examples have been restructured into a proper Ansible collection format: `edb.postgres_operations`

## What Changed

### Before (Legacy Structure)
```
ansible-examples/oneshot-playbooks
├── README.md
├── inventory.yml
├── deploy-postgres-cluster.yml      # Monolithic playbook
├── execute-sql-query.yml            # Monolithic playbook
└── check-cluster-health.yml         # Monolithic playbook
```

### After (Collection Structure)
```
ansible-examples/
├── collections/                                    # NEW
│   ├── ansible_collections/
│   │   └── edb/
│   │       └── postgres_operations/
│   │           ├── galaxy.yml                     # Collection metadata
│   │           ├── README.md                       # Collection docs
│   │           ├── CHANGELOG.md                    # Version history
│   │           ├── roles/                          # Reusable roles
│   │           │   ├── deploy_cluster/
│   │           │   │   ├── defaults/main.yml      # Default variables
│   │           │   │   ├── tasks/main.yml         # Role tasks
│   │           │   │   ├── meta/main.yml          # Role metadata
│   │           │   │   └── README.md              # Role documentation
│   │           │   ├── execute_sql/
│   │           │   │   ├── defaults/main.yml
│   │           │   │   ├── tasks/main.yml
│   │           │   │   ├── meta/main.yml
│   │           │   │   └── README.md
│   │           │   └── check_health/
│   │           │       ├── defaults/main.yml
│   │           │       ├── tasks/main.yml
│   │           │       ├── meta/main.yml
│   │           │       └── README.md
│   │           └── playbooks/                      # Playbooks using roles
│   │               ├── deploy-cluster.yml
│   │               ├── execute-sql.yml
│   │               ├── check-health.yml
│   │               └── site.yml
│   ├── ansible.cfg                                 # Ansible configuration
│   ├── inventory.yml                               # Updated inventory
│   ├── requirements.yml                            # Collection dependencies
│   ├── README.md                                   # Collection quick start
│   └── examples/                                   # Example playbooks
│       ├── deploy-production-cluster.yml
│       ├── run-database-migration.yml
│       ├── scheduled-health-monitoring.yml
│       └── vars/
│           ├── production.yml
│           └── development.yml
│
└── [Legacy files remain for reference]
```

## Key Improvements

### 1. Modularity
- **Before**: All logic in playbooks (hard to reuse)
- **After**: Logic in roles (import and reuse anywhere)

### 2. Defaults Management
- **Before**: Variables scattered across playbooks
- **After**: Centralized defaults in `roles/*/defaults/main.yml`

### 3. Documentation
- **Before**: One README for everything
- **After**: Dedicated README for each role + collection docs

### 4. Reusability
- **Before**: Copy/paste playbooks
- **After**: Install collection once, use everywhere

```yaml
# Now you can do this:
- hosts: servers
  roles:
    - role: edb.postgres_operations.deploy_cluster
```

### 5. Distribution
- **Before**: Manual file sharing
- **After**: `ansible-galaxy collection install edb.postgres_operations`

## New Roles

### Role: deploy_cluster

**Purpose**: Deploy PostgreSQL clusters with the EDB operator

**Key Features**:
- Namespace management
- Secret handling (pull secrets, credentials)
- Configurable cluster specs
- Resource management
- Monitoring setup
- High availability configuration
- Wait for ready logic

**Usage**:
```yaml
- role: edb.postgres_operations.deploy_cluster
  vars:
    cluster_name: prod-db
    instances: 5
    storage_size: 500Gi
```

### Role: execute_sql

**Purpose**: Execute SQL queries across multiple databases

**Key Features**:
- Single or multiple query execution
- SQL file support
- Transaction mode
- Host filtering (all, primary, production, etc.)
- Result display and saving
- Execution time measurement
- Error handling and retries

**Usage**:
```yaml
- role: edb.postgres_operations.execute_sql
  vars:
    sql_file: ./migration.sql
    transaction_mode: true
```

### Role: check_health

**Purpose**: Monitor cluster health and replication

**Key Features**:
- Operator health checks
- Cluster status monitoring
- Replication lag detection
- Pod issue detection
- PVC status checking
- Health report generation
- AAP webhook integration
- Configurable alerting

**Usage**:
```yaml
- role: edb.postgres_operations.check_health
  vars:
    enable_alerts: true
    save_report: true
```

## Installation

### 1. Install the Collection

```bash
cd ansible-examples/collections
ansible-galaxy collection install ./ansible_collections/edb/postgres_operations
```

Or install to custom path:
```bash
ansible-galaxy collection install ./ansible_collections/edb/postgres_operations \
  -p ~/.ansible/collections
```

### 2. Install Dependencies

```bash
ansible-galaxy collection install -r requirements.yml
```

### 3. Verify Installation

```bash
ansible-galaxy collection list | grep postgres_operations
```

Expected output:
```
edb.postgres_operations    1.0.0
```

## Usage Examples

### Example 1: Simple Deployment

```bash
cd collections
ansible-playbook ansible_collections/edb/postgres_operations/playbooks/deploy-cluster.yml \
  -e "cluster_name=test-db" \
  -e "namespace=default"
```

### Example 2: Production Deployment with Variable File

```bash
cd collections
ansible-playbook examples/deploy-production-cluster.yml \
  -e @examples/vars/production.yml
```

### Example 3: Custom Playbook Using Roles

Create `my-workflow.yml`:
```yaml
---
- name: PostgreSQL Deployment Workflow
  hosts: datacenter1
  
  tasks:
    - name: Deploy cluster
      include_role:
        name: edb.postgres_operations.deploy_cluster
      vars:
        cluster_name: prod-db
        instances: 5
    
    - name: Check health
      include_role:
        name: edb.postgres_operations.check_health
    
    - name: Initialize database
      include_role:
        name: edb.postgres_operations.execute_sql
      vars:
        sql_file: ./init.sql
```

Run it:
```bash
ansible-playbook my-workflow.yml
```

### Example 4: Health Monitoring in AAP

**Job Template Configuration**:
- Name: PostgreSQL Health Check
- Project: Your Git repo
- Playbook: `collections/ansible_collections/edb/postgres_operations/playbooks/check-health.yml`
- Schedule: Every 5 minutes
- Extra Variables:
  ```yaml
  enable_aap_notifications: true
  aap_webhook_url: "{{ webhook_url }}"
  ```

## Migration Steps

### For Existing Users

1. **Keep legacy playbooks** (they still work)
2. **Install the collection**:
   ```bash
   cd ansible-examples/collections
   ansible-galaxy collection install ./ansible_collections/edb/postgres_operations
   ```
3. **Try collection playbooks**:
   ```bash
   ansible-playbook ansible_collections/edb/postgres_operations/playbooks/check-health.yml
   ```
4. **Gradually migrate** custom playbooks to use roles

### Converting Legacy Playbooks

**Before**:
```bash
ansible-playbook deploy-postgres-cluster.yml -e "cluster_name=test"
```

**After**:
```bash
ansible-playbook collections/ansible_collections/edb/postgres_operations/playbooks/deploy-cluster.yml \
  -e "cluster_name=test"
```

Or create your own playbook:
```yaml
- hosts: openshift_clusters
  roles:
    - edb.postgres_operations.deploy_cluster
```

## Benefits Summary

| Benefit | Description |
|---------|-------------|
| **Reusability** | Use roles in multiple playbooks without duplication |
| **Maintainability** | Update in one place, affects all uses |
| **Testability** | Test roles independently with Molecule |
| **Documentation** | Each role has dedicated documentation |
| **Distribution** | Share via Ansible Galaxy |
| **Standards** | Follows Ansible best practices |
| **Defaults** | Sensible defaults reduce configuration |
| **Flexibility** | Override any variable as needed |

## Variables Overview

### Common Variables (All Roles)

```yaml
# Connection
kubeconfig_path: ~/.aap/kubeconfig.ocp1
datacenter: dc1

# Cluster identification
cluster_name: prod-db
namespace: production
```

### deploy_cluster Variables

```yaml
instances: 3
storage_size: 10Gi
postgres_version: "16.8"
monitoring_enabled: true
backup_enabled: false
```

See [defaults/main.yml](collections/ansible_collections/edb/postgres_operations/roles/deploy_cluster/defaults/main.yml) for all variables.

### execute_sql Variables

```yaml
sql_query: "SELECT version();"
sql_file: null
run_on: all  # all, primary, production
transaction_mode: false
```

See [defaults/main.yml](collections/ansible_collections/edb/postgres_operations/roles/execute_sql/defaults/main.yml) for all variables.

### check_health Variables

```yaml
check_operator: true
check_clusters: true
check_replication: true
enable_alerts: false
save_report: false
```

See [defaults/main.yml](collections/ansible_collections/edb/postgres_operations/roles/check_health/defaults/main.yml) for all variables.

## Documentation

- **Collection README**: [collections/README.md](collections/README.md)
- **Collection Docs**: [collections/ansible_collections/edb/postgres_operations/README.md](collections/ansible_collections/edb/postgres_operations/README.md)
- **Role: deploy_cluster**: [collections/ansible_collections/edb/postgres_operations/roles/deploy_cluster/README.md](collections/ansible_collections/edb/postgres_operations/roles/deploy_cluster/README.md)
- **Role: execute_sql**: [collections/ansible_collections/edb/postgres_operations/roles/execute_sql/README.md](collections/ansible_collections/edb/postgres_operations/roles/execute_sql/README.md)
- **Role: check_health**: [collections/ansible_collections/edb/postgres_operations/roles/check_health/README.md](collections/ansible_collections/edb/postgres_operations/roles/check_health/README.md)

## Examples

Comprehensive examples are in `collections/examples/`:
- `deploy-production-cluster.yml` - Production deployment example
- `run-database-migration.yml` - Database migration workflow
- `scheduled-health-monitoring.yml` - Health monitoring with reporting
- `vars/production.yml` - Production variable file
- `vars/development.yml` - Development variable file

## Support

For questions or issues:
1. Check role README files
2. Review examples
3. Check collection documentation
4. Consult EDB documentation

## Next Steps

1. ✅ Install the collection
2. ✅ Try the example playbooks
3. ✅ Review role documentation
4. ✅ Migrate custom playbooks to use roles
5. ✅ Create AAP job templates using collection playbooks
6. ✅ Set up health monitoring schedules

## Backwards Compatibility

The legacy playbooks remain functional and are kept for reference. You can continue using them, but we recommend migrating to the collection for:
- Better maintainability
- Enhanced reusability
- Improved documentation
- Easier updates

---

**Last Updated**: 2026-02-06
**Collection Version**: 1.0.0
