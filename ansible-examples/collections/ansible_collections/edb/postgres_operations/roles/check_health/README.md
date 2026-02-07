# Role: check_health

Monitor health of EnterpriseDB Postgres clusters.

## Description

This role performs comprehensive health checks on PostgreSQL clusters across multiple datacenters. It monitors operator status, cluster health, replication lag, pod issues, and generates detailed health reports with optional alerting.

## Requirements

- Ansible 2.14+
- `kubernetes.core` collection
- Valid kubeconfig for target OpenShift cluster

## Role Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `datacenter` | Datacenter identifier | `dc1` |
| `kubeconfig_path` | Path to kubeconfig file | `~/.kube/config` |

### Optional Variables (with defaults)

| Variable | Default | Description |
|----------|---------|-------------|
| `check_operator` | `true` | Check operator health |
| `check_clusters` | `true` | Check cluster health |
| `check_replication` | `true` | Check replication status |
| `enable_alerts` | `false` | Enable alerting |
| `generate_report` | `true` | Generate health report |

See [defaults/main.yml](defaults/main.yml) for all available variables.

## Dependencies

None.

## Example Playbook

```yaml
- hosts: openshift_clusters
  roles:
    - role: edb.postgres_operations.check_health
      vars:
        check_replication: true
        enable_alerts: true
```

## Example with AAP Webhooks

```yaml
- hosts: openshift_clusters
  roles:
    - role: edb.postgres_operations.check_health
      vars:
        enable_aap_notifications: true
        aap_webhook_url: "https://aap.example.com/api/v2/job_templates/123/webhook/"
```

## Example with Report Generation

```yaml
- hosts: openshift_clusters
  roles:
    - role: edb.postgres_operations.check_health
      vars:
        save_report: true
        report_format: json
        report_output_dir: /var/log/postgres-health
```

## Output

The role sets the following facts:

- `health_check_passed` - Boolean indicating if health check passed
- `health_report` - Comprehensive health report data
- `health_issues` - List of identified issues
- `health_warnings` - List of warnings

## Health Check Criteria

### Operator Health
- Deployment is running
- All replicas are ready

### Cluster Health
- Cluster phase is "Cluster in healthy state"
- All expected instances are ready
- Primary pod is identified

### Replication Health
- Replication lag is within threshold (default: 10MB)
- All replicas are in sync
- No replication errors

### Pod Health
- Restart count is below threshold
- No pods in CrashLoopBackOff
- All containers are ready

## License

Apache-2.0

## Author

EDB Engineering Team
