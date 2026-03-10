# deploy_cross_region_replica

Deploys a replica in another region using volume snapshot for bootstrap. Verifies the snapshot exists before calling `deploy_replica_cluster`. Override `snapshot_name`, `primary_cluster`, `replica_cluster`, and S3 paths.
