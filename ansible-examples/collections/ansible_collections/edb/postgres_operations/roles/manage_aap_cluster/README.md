# Ansible Role: manage_aap_cluster

Manages Ansible Automation Platform (AAP) cluster operations including scaling OpenShift pods and managing RHEL systemd services.

## Description

This role provides automation for AAP cluster management in both OpenShift and RHEL-based deployments. It supports scaling operations for disaster recovery scenarios and automated failover procedures.

## Requirements

- Ansible 2.11 or higher
- For OpenShift deployments:
  - `kubernetes.core` collection
  - OpenShift CLI (`oc`) installed
  - Valid kubeconfig with appropriate RBAC permissions
- For RHEL deployments:
  - Root or sudo access
  - AAP installed via standard installer

## Role Variables

### Required Variables

- `manage_aap_cluster_action`: Action to perform
  - `scale_up`: Scale AAP pods to operational replica counts (OpenShift)
  - `scale_down`: Scale AAP pods to zero replicas (OpenShift)
  - `start`: Start AAP systemd services (RHEL)
  - `stop`: Stop AAP systemd services (RHEL)
  - `status`: Check AAP cluster status

### Optional Variables

```yaml
# Deployment type: openshift or rhel
manage_aap_cluster_deployment_type: openshift

# OpenShift settings
manage_aap_cluster_namespace: ansible-automation-platform
manage_aap_cluster_kubeconfig: "{{ lookup('env', 'KUBECONFIG') | default('~/.kube/config', true) }}"
manage_aap_cluster_context: ""  # Optional: specific context to use

# Target replica counts for scale_up action
manage_aap_cluster_replicas:
  aap_gateway: 3
  automation_controller_operator: 1
  automation_controller_task: 3
  automation_controller_web: 3
  automation_hub_operator: 1
  automation_hub_api: 2
  automation_hub_content: 2
  automation_hub_worker: 2

# Wait for pods to be ready after scale_up
manage_aap_cluster_wait_for_ready: true
manage_aap_cluster_wait_timeout: 300  # seconds

# RHEL systemd services
manage_aap_cluster_services:
  - postgresql
  - redis
  - receptor
  - automation-controller
  - automation-hub
  - nginx

# Logging
manage_aap_cluster_log_file: /var/log/aap-cluster-management.log
```

## Dependencies

None

## Example Playbook

### Scale Up AAP in OpenShift (Failover Scenario)

```yaml
---
- name: Scale up AAP cluster in DR datacenter
  hosts: localhost
  gather_facts: false
  roles:
    - role: edb.postgres_operations.manage_aap_cluster
      manage_aap_cluster_action: scale_up
      manage_aap_cluster_context: api-chadsno2026-fteam-local:6443
```

### Scale Down AAP in OpenShift (Failback Scenario)

```yaml
---
- name: Scale down AAP cluster to conserve resources
  hosts: localhost
  gather_facts: false
  roles:
    - role: edb.postgres_operations.manage_aap_cluster
      manage_aap_cluster_action: scale_down
      manage_aap_cluster_context: api-chadsno2026-fteam-local:6443
```

### Start AAP Services on RHEL

```yaml
---
- name: Start AAP cluster services
  hosts: aap_servers
  become: true
  roles:
    - role: edb.postgres_operations.manage_aap_cluster
      manage_aap_cluster_action: start
      manage_aap_cluster_deployment_type: rhel
```

### Check AAP Status

```yaml
---
- name: Check AAP cluster status
  hosts: localhost
  gather_facts: false
  roles:
    - role: edb.postgres_operations.manage_aap_cluster
      manage_aap_cluster_action: status
```

## Disaster Recovery Integration

This role can be integrated with EDB Failover Manager (EFM) or called from AAP workflows:

```yaml
---
- name: Complete failover procedure
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Scale up AAP in DR site
      ansible.builtin.include_role:
        name: edb.postgres_operations.manage_aap_cluster
      vars:
        manage_aap_cluster_action: scale_up
        manage_aap_cluster_context: api-dc2-cluster:6443
        
    - name: Wait for AAP to be operational
      ansible.builtin.uri:
        url: https://aap-dc2.example.com/api/v2/ping/
        validate_certs: false
        status_code: 200
      register: aap_health_check
      until: aap_health_check.status == 200
      retries: 30
      delay: 10
```

## Tags

- `manage_aap_cluster`: Main role tag
- `scale_up`: Only scale up operations
- `scale_down`: Only scale down operations
- `status`: Only status checks

## Return Values

The role registers the following variables:

- `manage_aap_cluster_result`: Result of the operation
  - `changed`: Whether changes were made
  - `status`: Current status of AAP cluster
  - `message`: Human-readable result message

## License

BSD-3-Clause

## Author Information

Created for EDB Postgres Multi-Datacenter Architecture
