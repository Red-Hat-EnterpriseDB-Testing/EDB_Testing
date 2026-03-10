# deploy_delayed_replica

Deploys a delayed replica (e.g. 8-hour apply delay) for a recovery window. Standalone strategy, minimal resources. Wraps `deploy_replica_cluster`. Override `replica_min_apply_delay`, `production_cluster`, `delayed_cluster`, `namespace`.
