# health_monitoring_aggregate

Runs on **localhost** after a play that ran health checks on `openshift_clusters`. Collects `health_report` from hostvars, prints a summary, and optionally sends an aggregated payload to an AAP webhook when there are unhealthy datacenters.

## Requirements

- Run after a play that used `check_health` or `scheduled_health_monitoring` on `openshift_clusters` (so `health_report` is set in hostvars).

## Role Variables

- `openshift_clusters_group` (default: `openshift_clusters`) — inventory group name
- `enable_aap_notifications`, `aap_webhook_url`

## Example

See `scheduled_health_monitoring` README for a two-play example.
