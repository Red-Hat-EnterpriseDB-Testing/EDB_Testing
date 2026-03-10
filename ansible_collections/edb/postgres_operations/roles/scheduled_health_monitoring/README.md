# scheduled_health_monitoring

Runs cluster health checks with monitoring-oriented defaults (alerts, reporting, AAP webhook). Wraps the `check_health` role. Use with `health_monitoring_aggregate` in a second play to aggregate results and send a summary (e.g. in AAP).

## Requirements

- Target: `openshift_clusters`
- Optional: `AAP_WEBHOOK_URL` environment variable for notifications

## Role Variables

See `defaults/main.yml`. Override `aap_webhook_url`, `report_format`, `report_output_dir`, etc.

## Example (two plays)

```yaml
- hosts: openshift_clusters
  roles:
    - role: edb.postgres_operations.scheduled_health_monitoring

- hosts: localhost
  roles:
    - role: edb.postgres_operations.health_monitoring_aggregate
```
