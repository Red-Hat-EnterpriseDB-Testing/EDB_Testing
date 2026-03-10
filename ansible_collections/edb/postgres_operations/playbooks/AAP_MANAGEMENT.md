# AAP Cluster Management with Ansible

This document describes the Ansible automation for managing Ansible Automation Platform (AAP) clusters and integrating with EDB Failover Manager (EFM).

## Overview

The `edb.postgres_operations` collection now includes comprehensive AAP cluster management capabilities:

- **manage_aap_cluster**: Role for scaling and managing AAP clusters
- **efm_integration**: Role for integrating AAP management with EFM
- **Playbooks**: Ready-to-use playbooks for common operations

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Disaster Recovery Event (Database Failure)                │
│                                                             │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       v
┌─────────────────────────────────────────────────────────────┐
│  EDB Failover Manager (EFM)                                 │
│  - Detects primary database failure                         │
│  - Promotes standby to primary                             │
│  - Calls custom post-promotion script                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       v
┌─────────────────────────────────────────────────────────────┐
│  EFM Integration Scripts (efm_integration role)             │
│  - efm-aap-failover-wrapper.sh                             │
│  - Determines datacenter (DC1/DC2)                          │
│  - Calls appropriate AAP management script                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       v
┌─────────────────────────────────────────────────────────────┐
│  AAP Management Actions (manage_aap_cluster role)           │
│                                                             │
│  OpenShift:                    RHEL:                        │
│  - Scale pods to target        - Start systemd services    │
│  - Wait for ready state        - Verify services running   │
│  - Health check AAP API        - Health check AAP API      │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Scale Up AAP in DR Datacenter (OpenShift)

```bash
ansible-playbook edb.postgres_operations.manage-aap-cluster \
  -e 'manage_aap_cluster_action=scale_up' \
  -e 'manage_aap_cluster_context=your-cluster-context'  # from kubeconfig: kubectl config get-contexts
```

### 2. Setup EFM Integration

```bash
ansible-playbook edb.postgres_operations.setup-efm-integration \
  -i inventory \
  -l efm_nodes
```

### 3. Complete DR Failover

```bash
ansible-playbook edb.postgres_operations.disaster-recovery-failover \
  -e 'failover_source_dc=dc1' \
  -e 'failover_target_dc=dc2'
```

## Roles

### manage_aap_cluster

Manages AAP cluster operations for both OpenShift and RHEL deployments.

**Actions:**
- `scale_up`: Scale AAP pods to operational replica counts (OpenShift)
- `scale_down`: Scale AAP pods to zero replicas (OpenShift)
- `start`: Start AAP systemd services (RHEL)
- `stop`: Stop AAP systemd services (RHEL)
- `status`: Check AAP cluster status

**Example:**

```yaml
- hosts: localhost
  roles:
    - role: edb.postgres_operations.manage_aap_cluster
      manage_aap_cluster_action: scale_up
      manage_aap_cluster_namespace: ansible-automation-platform
      manage_aap_cluster_context: api-dc2-cluster:6443
```

### efm_integration

Integrates AAP management with EDB Failover Manager for automated failover.

**Actions:**
- `install`: Install EFM integration scripts
- `configure`: Configure EFM to call scripts
- `test`: Test the integration
- `uninstall`: Remove EFM integration

**Example:**

```yaml
- hosts: efm_nodes
  become: true
  roles:
    - role: edb.postgres_operations.efm_integration
      efm_integration_action: install
      efm_integration_aap_deployment_type: openshift
```

## Playbooks

### manage-aap-cluster.yml

General-purpose playbook for AAP cluster management.

**Usage:**

```bash
# Scale up AAP in DC2
ansible-playbook edb.postgres_operations.manage-aap-cluster \
  -e 'manage_aap_cluster_action=scale_up' \
  -e 'manage_aap_cluster_context=your-cluster-context'  # from kubeconfig: kubectl config get-contexts

# Check AAP status
ansible-playbook edb.postgres_operations.manage-aap-cluster \
  -e 'manage_aap_cluster_action=status'

# Start AAP services on RHEL
ansible-playbook edb.postgres_operations.manage-aap-cluster \
  -i rhel_inventory \
  -l aap_servers \
  -e 'manage_aap_cluster_action=start' \
  -e 'manage_aap_cluster_deployment_type=rhel' \
  -e 'aap_require_become=true'
```

### setup-efm-integration.yml

Complete EFM integration setup including installation, configuration, and testing.

**Usage:**

```bash
# Install and configure
ansible-playbook edb.postgres_operations.setup-efm-integration \
  -i inventory \
  -l efm_nodes

# Install, configure, and test
ansible-playbook edb.postgres_operations.setup-efm-integration \
  -i inventory \
  -l efm_nodes \
  -e 'run_test=true'

# With orchestrated failover (includes notifications)
ansible-playbook edb.postgres_operations.setup-efm-integration \
  -i inventory \
  -l efm_nodes \
  -e 'use_orchestrated=true' \
  -e 'efm_integration_notification_email=ops@example.com'
```

### disaster-recovery-failover.yml

Complete disaster recovery failover orchestration.

**Usage:**

```bash
# Manual failover with confirmation
ansible-playbook edb.postgres_operations.disaster-recovery-failover \
  -e 'failover_source_dc=dc1' \
  -e 'failover_target_dc=dc2'

# Automatic failover (no confirmation)
ansible-playbook edb.postgres_operations.disaster-recovery-failover \
  -e 'failover_source_dc=dc1' \
  -e 'failover_target_dc=dc2' \
  -e 'dr_failover_mode=automatic' \
  -e 'dr_require_confirmation=false'

# Failback to DC1
ansible-playbook edb.postgres_operations.disaster-recovery-failover \
  -e 'failover_source_dc=dc2' \
  -e 'failover_target_dc=dc1'
```

## Configuration Examples

### Inventory Configuration

```yaml
# inventory.yml
all:
  children:
    efm_nodes:
      hosts:
        efm-dc1:
          ansible_host: 192.168.1.10
          datacenter: dc1
        efm-dc2:
          ansible_host: 192.168.2.10
          datacenter: dc2
      vars:
        efm_integration_efm_version: "4.7"
        efm_integration_aap_deployment_type: openshift
    
    aap_rhel_servers:
      hosts:
        aap-rhel-1:
          ansible_host: 192.168.1.20
      vars:
        manage_aap_cluster_deployment_type: rhel
```

### Group Variables

```yaml
# group_vars/efm_nodes.yml
efm_integration_efm_version: "4.7"
efm_integration_efm_cluster_name: prod-db-cluster
efm_integration_aap_deployment_type: openshift
efm_integration_openshift_namespace: ansible-automation-platform
# Update to your cluster contexts from kubeconfig (kubectl config get-contexts)
efm_integration_openshift_contexts:
  dc1: your-dc1-cluster-context
  dc2: your-dc2-cluster-context
efm_integration_script_timeout: 600
efm_integration_use_orchestrated_failover: true
efm_integration_enable_notifications: true
```

## Integration with AAP Workflows

These playbooks can be called from AAP Workflow Templates:

### Workflow Example

1. **Check Source DC Status** (Optional)
   - Playbook: `check-health.yml`
   - Extra Vars: `target_dc: dc1`

2. **Initiate Failover**
   - Playbook: `disaster-recovery-failover.yml`
   - Extra Vars: `failover_source_dc: dc1, failover_target_dc: dc2`

3. **Verify Target DC Health**
   - Playbook: `check-health.yml`
   - Extra Vars: `target_dc: dc2`

4. **Notify Stakeholders**
   - Playbook: Custom notification playbook
   - Extra Vars: `message: "Failover to DC2 complete"`

## Testing

### Unit Testing

Test individual role functionality:

```bash
# Test AAP scale up
ansible-playbook -i localhost, edb.postgres_operations.manage-aap-cluster \
  -e 'manage_aap_cluster_action=scale_up' \
  -e 'manage_aap_cluster_context=api-test-cluster:6443' \
  --check

# Test EFM integration
ansible-playbook edb.postgres_operations.setup-efm-integration \
  -i inventory \
  -l efm_nodes \
  --tags test
```

### Integration Testing

Test complete failover procedure in non-production:

```bash
# Run in check mode first
ansible-playbook edb.postgres_operations.disaster-recovery-failover \
  -e 'failover_source_dc=dc1' \
  -e 'failover_target_dc=dc2' \
  --check

# Run actual test failover
ansible-playbook edb.postgres_operations.disaster-recovery-failover \
  -e 'failover_source_dc=dc1' \
  -e 'failover_target_dc=dc2' \
  -e 'require_confirmation=false'
```

## Troubleshooting

### AAP Pods Not Scaling

```bash
# Check deployment status
ansible-playbook edb.postgres_operations.manage-aap-cluster \
  -e 'manage_aap_cluster_action=status' \
  -e 'manage_aap_cluster_context=api-dc2-cluster:6443'

# Check for resource quotas
oc get resourcequota -n ansible-automation-platform

# Check events
oc get events -n ansible-automation-platform --sort-by='.lastTimestamp'
```

### EFM Scripts Not Executing

```bash
# Verify scripts are installed
ansible efm_nodes -m shell -a "ls -la /usr/edb/efm-4.7/bin/efm-aap-*"

# Check EFM configuration
ansible efm_nodes -m shell -a "grep script /etc/edb/efm-4.7/efm.properties"

# Test script manually
ansible efm_nodes -m shell -a \
  "sudo -u efm /usr/edb/efm-4.7/bin/efm-aap-failover-wrapper.sh test standby dc2-node 10.0.2.100"

# Check logs
ansible efm_nodes -m shell -a "tail -50 /var/log/efm-aap-failover.log"
```

### Kubeconfig Access Issues

```bash
# Verify kubeconfig exists
ansible efm_nodes -m stat -a "path=/var/lib/efm/.kube/config"

# Test OC access as efm user
ansible efm_nodes -m shell -a \
  "sudo -u efm oc --kubeconfig=/var/lib/efm/.kube/config whoami"

# Check permissions
ansible efm_nodes -m shell -a "ls -la /var/lib/efm/.kube/"
```

## Best Practices

1. **Testing**: Always test in non-production before using in production
2. **Documentation**: Document your specific DC contexts and configurations
3. **Monitoring**: Set up monitoring for AAP cluster status
4. **Logging**: Regularly review EFM integration logs
5. **Drills**: Schedule quarterly DR failover drills
6. **Version Control**: Store your inventory and variables in Git
7. **Secrets**: Use Ansible Vault for sensitive data
8. **Idempotency**: All roles support check mode and are idempotent

## Related Documentation

- [manage_aap_cluster Role README](../roles/manage_aap_cluster/README.md)
- [efm_integration Role README](../roles/efm_integration/README.md)
- [Main Collection README](../README.md)
- [EDB Postgres Operations Guide](https://www.enterprisedb.com/docs)

## Support

For issues or questions:
1. Check role README files
2. Review troubleshooting section
3. Check EFM and AAP logs
4. Open an issue in the collection repository
