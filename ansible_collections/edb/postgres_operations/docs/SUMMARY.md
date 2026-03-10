# Collection Summary — edb.postgres_operations

All automation and docs live under `ansible_collections/edb/postgres_operations/` (at project root).

## Layout

```
ansible_collections/edb/postgres_operations/
├── galaxy.yml, README.md, CHANGELOG.md
├── requirements.yml, requirements.txt      # Dependencies
├── execution-environment.yml               # AAP EE build
├── requirements-ee.yml
├── config/
│   └── ansible.cfg.example
├── docs/
│   ├── GETTING_STARTED.md
│   ├── QUICK_REFERENCE.md
│   ├── SUMMARY.md
│   └── COLLECTION_MIGRATION.md
├── inventory/
│   ├── example-multi-datacenter.yml
│   └── replica-example.yml
├── playbooks/
│   ├── deploy-cluster.yml, check-health.yml, execute-sql.yml, site.yml
│   ├── install-postgres-rhel.yml, deploy-replica-cluster.yml, ...
│   └── examples/
│       ├── deploy-production-cluster.yml
│       ├── run-database-migration.yml
│       ├── scheduled-health-monitoring.yml
│       └── vars/ (production.yml, development.yml)
└── roles/
    ├── deploy_cluster, execute_sql, check_health
    ├── install_postgres_rhel, deploy_replica_cluster, efm_integration, manage_aap_cluster
    ├── deploy_production_cluster, deploy_development_cluster
    ├── database_migration
    ├── scheduled_health_monitoring, health_monitoring_aggregate
    ├── deploy_analytics_replica, deploy_dr_replica, deploy_cross_region_replica, deploy_delayed_replica
    └── ...
```

## Main roles

| Role                | Purpose |
|---------------------|--------|
| deploy_cluster      | Deploy PostgreSQL clusters (EDB operator) |
| execute_sql         | Run SQL / migrations |
| check_health        | Health and replication checks |
| install_postgres_rhel | Install Postgres on RHEL |
| deploy_replica_cluster | Replica clusters (DR/HA) |
| efm_integration     | EDB Failover Manager |
| manage_aap_cluster | AAP cluster scaling (OpenShift/RHEL) |
| deploy_production_cluster | Production cluster with HA/backup defaults |
| deploy_development_cluster | Development cluster with minimal defaults |
| database_migration  | Migration workflow (health, migrate, verify) |
| scheduled_health_monitoring | Health checks with alerting/reporting |
| health_monitoring_aggregate | Aggregate health reports (run on localhost) |
| deploy_analytics_replica | Analytics read-only replica |
| deploy_dr_replica   | DR replica (distributed topology) |
| deploy_cross_region_replica | Cross-region replica (volume snapshot bootstrap) |
| deploy_delayed_replica | Delayed replica (recovery window) |

## Docs

| Doc                  | Description |
|----------------------|-------------|
| [README.md](../README.md) | Full collection docs |
| [GETTING_STARTED.md](GETTING_STARTED.md) | Install and first runs |
| [QUICK_REFERENCE.md](QUICK_REFERENCE.md) | Commands and variables |
| [COLLECTION_MIGRATION.md](COLLECTION_MIGRATION.md) | Legacy → collection |

## Run from project root

```bash
INV="-i ansible_collections/edb/postgres_operations/inventory/example-multi-datacenter.yml"
ansible-galaxy collection install ./ansible_collections/edb/postgres_operations
ansible-playbook $INV ansible_collections/edb/postgres_operations/playbooks/check-health.yml
```
