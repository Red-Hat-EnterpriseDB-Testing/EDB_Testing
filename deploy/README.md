# Deploy — EDB Postgres for Kubernetes (CloudNativePG)

YAML layout to install the **EnterpriseDB** operator distribution and a small sample `Cluster`.

## Layout

| Path | Purpose |
|------|---------|
| `operator/kustomization.yaml` | Pulls the pinned operator manifest from `get.enterprisedb.io` (includes `postgresql-operator-system` namespace and CRDs). |
| `sample-cluster/` | Demo namespace, app credentials secret, and `Cluster` CR (`edb-pg-demo` / `demo-pg`). |

## Prerequisites

- `kubectl` configured for the target cluster (cluster-admin for CRDs).
- For **OpenShift**: if the operator controller pod fails on SCC, grant a suitable SCC to `postgresql-operator-manager` in `postgresql-operator-system` and restart the deployment — see [docs/openshift-edb-operator-smoke-test.md](../docs/openshift-edb-operator-smoke-test.md).

## Install operator

Use **server-side apply** so large CRDs apply cleanly:

```bash
kubectl apply --server-side --force-conflicts -k deploy/operator
kubectl rollout status deployment/postgresql-operator-controller-manager \
  -n postgresql-operator-system --timeout=300s
```

## Edit sample workload

1. Set a strong password in `sample-cluster/app-db-credentials.secret.yaml`.
2. Set `spec.storage.storageClass` in `sample-cluster/cluster.yaml` if your cluster has no default `StorageClass`.

For **EDB registry images**, create `edb-pull-secret` (or your name) and either edit `cluster.yaml` to match `cluster-edb-registry.yaml`, or swap the filename in `sample-cluster/kustomization.yaml` resources.

## Apply sample cluster

```bash
kubectl apply -k deploy/sample-cluster
kubectl get cluster,pods -n edb-pg-demo -w
```

Official reference: [EDB Postgres for Kubernetes](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/).
