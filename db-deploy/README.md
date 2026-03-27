# Deploy — EDB Postgres for Kubernetes (CloudNativePG)

YAML layout to install the **EnterpriseDB** operator distribution and a small sample `Cluster`.

On **Red Hat OpenShift**, prefer **Operator Lifecycle Manager (OLM)** via `db-deploy/olm-openshift/` (OperatorHub subscription flow). Use the manifest bundle under `db-deploy/operator/` for **plain Kubernetes** or when you need a pinned YAML install instead of OLM.

## Layout

| Path | Purpose |
|------|---------|
| `olm-openshift/` | **Preferred on OpenShift:** OLM `Subscription` (cluster-wide) and an example `OperatorGroup` + `Subscription` for scoped installs — [EDB OpenShift / oc CLI](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/openshift/#installation-via-the-oc-cli). See [olm-openshift/README.md](olm-openshift/README.md). |
| `operator/kustomization.yaml` | **Kubernetes (or non-OLM):** pinned operator manifest from `get.enterprisedb.io` (creates `postgresql-operator-system` and CRDs). |
| `sample-cluster/` | Demo namespace, app credentials secret, and `Cluster` CR (`edb-pg-demo` / `demo-pg`). |
| `cross-cluster/` | **Passive replica (streaming)** across two clusters: Route on primary + replica `Cluster` + script — see [cross-cluster/README.md](cross-cluster/README.md). |

## Prerequisites

- `kubectl` / `oc` configured for the target cluster (cluster-admin or equivalent to install operators and CRDs).
- **OpenShift (OLM):** EDB pull secret in `openshift-operators` and subscription steps — [olm-openshift/README.md](olm-openshift/README.md).
- **OpenShift (manifest install from `operator/` only):** if the controller pod fails on SCC, grant a suitable SCC to `postgresql-operator-manager` in `postgresql-operator-system` and restart the deployment — [docs/openshift-edb-operator-smoke-test.md](../docs/openshift-edb-operator-smoke-test.md).

## Install operator

### OpenShift — OLM (recommended)

```bash
oc apply -k db-deploy/olm-openshift
```

Verify and complete pull-secret / CSV approval steps in [olm-openshift/README.md](olm-openshift/README.md). For multi-namespace or single-namespace operator placement, use `olm-openshift/operatorgroup-multinamespace.example.yaml` instead of the kustomize overlay.

### Kubernetes — manifest bundle

Use **server-side apply** so large CRDs apply cleanly:

```bash
kubectl apply --server-side --force-conflicts -k db-deploy/operator
kubectl rollout status deployment/postgresql-operator-controller-manager \
  -n postgresql-operator-system --timeout=300s
```

## Edit sample workload

1. Set a strong password in `sample-cluster/base/app-db-credentials.secret.yaml`.
2. Set `spec.storage.storageClass` in `sample-cluster/base/cluster.yaml` if your cluster has no default `StorageClass`.

For **EDB registry images**, create `edb-pull-secret` (or your name) and either edit `base/cluster.yaml` to match `base/cluster-edb-registry.yaml`, or swap the filename in `sample-cluster/base/kustomization.yaml` resources.

## Apply sample cluster

Apply after the operator install is healthy (`Cluster` CRD available). The sample **`demo-pg`** cluster uses **`spec.instances: 2`** (primary + one hot standby in the same OpenShift cluster).

**Base** (omit `storageClass` and rely on the cluster default `StorageClass`):

```bash
kubectl apply -k db-deploy/sample-cluster
kubectl get cluster,pods -n edb-pg-demo -w
```

**Overlays** (set `spec.storage.storageClass` for clusters without a suitable default). Kustomize’s default **load restrictor** blocks `kubectl apply -k` on these paths because they reference `../../base`. Build with **`LoadRestrictionsNone`**, then apply:

```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone db-deploy/sample-cluster/overlays/overlay-lvms-vg1 | kubectl apply -f -
# or CRC-style default SC:
kubectl kustomize --load-restrictor LoadRestrictionsNone db-deploy/sample-cluster/overlays/overlay-topolvm-provisioner | kubectl apply -f -
```

OpenShift’s `oc kustomize` supports the same flag, for example:  
`oc kustomize --load-restrictor LoadRestrictionsNone db-deploy/sample-cluster/overlays/overlay-lvms-vg1 | oc apply -f -`.

| Path | `StorageClass` |
|------|----------------|
| `db-deploy/sample-cluster/overlays/overlay-lvms-vg1` | `lvms-vg1` |
| `db-deploy/sample-cluster/overlays/overlay-topolvm-provisioner` | `topolvm-provisioner` |

Repeat OLM install + sample overlay on **each** OpenShift if you want two independent two-node Postgres clusters — use explicit `--kubeconfig` / `--context` per cluster. See [olm-openshift/README.md](olm-openshift/README.md).

## Cross-cluster passive replica

Use **[`cross-cluster/README.md`](cross-cluster/README.md)** for prerequisites, anonymity notes, and the full flow. Short version:

1. Install the operator on **both** clusters; create a healthy primary `Cluster` (e.g. `db-deploy/sample-cluster/` overlays).
2. Export **`PRIMARY_CONTEXT`** and **`REPLICA_CONTEXT`** (and optional split kubeconfigs).
3. Run **`db-deploy/cross-cluster/scripts/sync-passive-replica.sh`**.

Official reference: [EDB — Replica clusters](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/replica_cluster/) and [EDB Postgres for Kubernetes](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/).
