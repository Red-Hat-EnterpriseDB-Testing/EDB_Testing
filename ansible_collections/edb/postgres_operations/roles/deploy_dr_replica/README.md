# deploy_dr_replica

Deploys a disaster recovery replica in a second datacenter with distributed topology and symmetric backup. Wraps `deploy_replica_cluster`.

## Requirements

- Target: DC2 OpenShift host(s) (e.g. `dc2_openshift`)
- Source primary in DC1; S3 buckets for each DC

## Role Variables

See `defaults/main.yml`. Override `primary_cluster_name`, `replica_cluster_name`, `s3_backup_bucket_dc1`, `s3_backup_bucket_dc2`, etc.
