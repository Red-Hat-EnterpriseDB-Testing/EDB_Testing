---
# Ansible Role: efm_integration

Integrates AAP cluster management scripts with EDB Failover Manager (EFM) for automated failover orchestration.

## Description

This role installs and configures scripts that enable EDB Failover Manager to automatically scale up or activate AAP clusters during database failover events. It provides seamless coordination between database failover and AAP cluster activation.

## Requirements

- Ansible 2.11 or higher
- EDB Failover Manager 4.x installed
- For OpenShift deployments:
  - OpenShift CLI (`oc`) installed on EFM nodes
  - Valid kubeconfig accessible to `efm` user
- Root or sudo access on EFM nodes

## Role Variables

### Required Variables

- `efm_integration_action`: Action to perform
  - `install`: Install EFM integration scripts
  - `configure`: Configure EFM to call scripts
  - `test`: Test the integration
  - `uninstall`: Remove EFM integration

### Optional Variables

```yaml
# EFM configuration
efm_integration_efm_version: "4.7"
efm_integration_efm_base_dir: "/usr/edb/efm-{{ efm_integration_efm_version }}"
efm_integration_efm_config_dir: "/etc/edb/efm-{{ efm_integration_efm_version }}"
efm_integration_efm_cluster_name: "efm-cluster"

# Script locations
efm_integration_script_source_dir: "{{ playbook_dir }}/../../scripts"
efm_integration_script_target_dir: "{{ efm_integration_efm_base_dir }}/bin"

# Deployment type for AAP
efm_integration_aap_deployment_type: openshift

# OpenShift configuration
efm_integration_openshift_namespace: ansible-automation-platform
efm_integration_openshift_contexts:
  dc1: api-crc-testing:6443
  dc2: api-chadsno2026-fteam-local:6443

# Kubeconfig for efm user
efm_integration_kubeconfig_source: "{{ lookup('env', 'KUBECONFIG') | default('~/.kube/config', true) }}"
efm_integration_kubeconfig_target: /var/lib/efm/.kube/config

# Script timeout (seconds)
efm_integration_script_timeout: 300

# Enable orchestrated failover (advanced)
efm_integration_use_orchestrated_failover: false

# Notification settings
efm_integration_enable_notifications: true
efm_integration_notification_email: ""
efm_integration_notification_slack_webhook: ""

# Logging
efm_integration_log_dir: /var/log
efm_integration_wrapper_log: "{{ efm_integration_log_dir }}/efm-aap-failover.log"
efm_integration_orchestrated_log: "{{ efm_integration_log_dir }}/efm-orchestrated-failover.log"
```

## Dependencies

- `edb.postgres_operations.manage_aap_cluster` (when testing)

## Example Playbook

### Install EFM Integration Scripts

```yaml
---
- name: Install EFM integration for AAP failover
  hosts: efm_nodes
  become: true
  roles:
    - role: edb.postgres_operations.efm_integration
      efm_integration_action: install
      efm_integration_aap_deployment_type: openshift
```

### Configure EFM to Use Scripts

```yaml
---
- name: Configure EFM with AAP failover scripts
  hosts: efm_nodes
  become: true
  roles:
    - role: edb.postgres_operations.efm_integration
      efm_integration_action: configure
      efm_integration_efm_cluster_name: prod-db-cluster
      efm_integration_script_timeout: 600
```

### Complete Setup (Install + Configure)

```yaml
---
- name: Complete EFM AAP integration setup
  hosts: efm_nodes
  become: true
  roles:
    - role: edb.postgres_operations.efm_integration
      efm_integration_action: install
      
    - role: edb.postgres_operations.efm_integration
      efm_integration_action: configure
```

### Test EFM Integration

```yaml
---
- name: Test EFM AAP integration
  hosts: efm_nodes
  become: true
  roles:
    - role: edb.postgres_operations.efm_integration
      efm_integration_action: test
      efm_integration_test_datacenter: dc2
      efm_integration_test_node_type: standby
```

### Advanced: Orchestrated Failover

```yaml
---
- name: Setup orchestrated failover with notifications
  hosts: efm_nodes
  become: true
  roles:
    - role: edb.postgres_operations.efm_integration
      efm_integration_action: install
      efm_integration_use_orchestrated_failover: true
      efm_integration_enable_notifications: true
      efm_integration_notification_email: ops-team@example.com
      efm_integration_notification_slack_webhook: "{{ vault_slack_webhook }}"
      
    - role: edb.postgres_operations.efm_integration
      efm_integration_action: configure
```

## Post-Installation Tasks

After running this role, you must:

1. Ensure the `efm` user has access to OpenShift (for OpenShift deployments)
2. Test the integration manually before relying on automatic failover
3. Schedule a failover drill to verify end-to-end functionality

## Testing

The role includes built-in testing capabilities:

```yaml
# Test script execution
- include_role:
    name: edb.postgres_operations.efm_integration
  vars:
    efm_integration_action: test
    efm_integration_test_datacenter: dc2
```

This will simulate an EFM call and verify:
- Scripts are executable
- Kubeconfig is accessible
- AAP can be scaled up/started
- Logging is working correctly

## Uninstallation

To remove EFM integration:

```yaml
---
- name: Remove EFM AAP integration
  hosts: efm_nodes
  become: true
  roles:
    - role: edb.postgres_operations.efm_integration
      efm_integration_action: uninstall
```

## Tags

- `efm_integration`: Main role tag
- `install`: Only installation tasks
- `configure`: Only configuration tasks
- `test`: Only testing tasks
- `uninstall`: Only uninstallation tasks

## Files Created

- `{{ efm_integration_script_target_dir }}/aap-failover.sh`
- `{{ efm_integration_script_target_dir }}/aap-failback.sh`
- `{{ efm_integration_script_target_dir }}/efm-aap-failover-wrapper.sh`
- `{{ efm_integration_script_target_dir }}/efm-orchestrated-failover.sh` (optional)
- `{{ efm_integration_kubeconfig_target }}` (OpenShift only)
- `{{ efm_integration_efm_config_dir }}/efm.properties` (modified)

## Security Considerations

- Scripts are owned by `efm:efm` user
- Kubeconfig contains credentials - protect accordingly
- Log files may contain sensitive information
- Consider using Ansible Vault for webhook URLs and tokens

## License

BSD-3-Clause

## Author Information

Created for EDB Postgres Multi-Datacenter Architecture
