# Deploy — EDB Postgres for Kubernetes (CloudNativePG)

YAML layout to install the **EnterpriseDB** operator distribution and a small sample `Cluster`.

On **Red Hat OpenShift**, prefer **Operator Lifecycle Manager (OLM)** via `deploy/olm-openshift/` (OperatorHub subscription flow). Use the manifest bundle under `deploy/operator/` for **plain Kubernetes** or when you need a pinned YAML install instead of OLM.

## Layout

| Path | Purpose |
|------|---------|
| `olm-openshift/` | **Preferred on OpenShift:** OLM `Subscription` (cluster-wide) and an example `OperatorGroup` + `Subscription` for scoped installs — [EDB OpenShift / oc CLI](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/openshift/#installation-via-the-oc-cli). See [olm-openshift/README.md](olm-openshift/README.md). |
| `operator/kustomization.yaml` | **Kubernetes (or non-OLM):** pinned operator manifest from `get.enterprisedb.io` (creates `postgresql-operator-system` and CRDs). |
| `sample-cluster/` | Demo namespace, app credentials secret, and `Cluster` CR (`edb-pg-demo` / `demo-pg`). |

## Prerequisites

- `kubectl` / `oc` configured for the target cluster (cluster-admin or equivalent to install operators and CRDs).
- **OpenShift (OLM):** EDB pull secret in `openshift-operators` and subscription steps — [olm-openshift/README.md](olm-openshift/README.md).
- **OpenShift (manifest install from `operator/` only):** if the controller pod fails on SCC, grant a suitable SCC to `postgresql-operator-manager` in `postgresql-operator-system` and restart the deployment — [docs/openshift-edb-operator-smoke-test.md](../docs/openshift-edb-operator-smoke-test.md).

## Install operator

### OpenShift — OLM (recommended)

```bash
oc apply -k deploy/olm-openshift
```

Verify and complete pull-secret / CSV approval steps in [olm-openshift/README.md](olm-openshift/README.md). For multi-namespace or single-namespace operator placement, use `olm-openshift/operatorgroup-multinamespace.example.yaml` instead of the kustomize overlay.

### Kubernetes — manifest bundle

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

Apply after the operator install is healthy (`Cluster` CRD available):

```bash
kubectl apply -k deploy/sample-cluster
kubectl get cluster,pods -n edb-pg-demo -w
```

Official reference: [EDB Postgres for Kubernetes](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/).
