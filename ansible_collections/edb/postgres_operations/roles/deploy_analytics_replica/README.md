# deploy_analytics_replica

Deploys a standalone read-only replica cluster optimized for analytics (more instances, memory, and cache). Bootstrap from object store. Wraps `deploy_replica_cluster`.

## Requirements

- Target: group with OpenShift/kubeconfig (e.g. `analytics_clusters` or a single host)
- Source cluster and Barman/object store configured

## Role Variables

See `defaults/main.yml`. Override `production_cluster`, `analytics_cluster`, `analytics_namespace`, `barman_destination_path`, etc.
