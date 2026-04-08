# OpenShift — EDB PostgreSQL operator (smoke test)

Anonymized lab checklist: install the operator, fix common OpenShift constraints, deploy a tiny cluster, and run one SQL check. Replace placeholders (namespace, cluster name, storage class, passwords) with your own values.

[← Manual install guide](install-kubernetes-manual.md) · [Kustomize manifests (`db-deploy/`)](../db-deploy/README.md)

## Prerequisites

- `kubectl` and `oc` configured for the target cluster
- Cluster-admin (or sufficient RBAC for namespaces, CRDs, SCC bindings)
- **Always** point at the intended kubeconfig so you do not hit the wrong cluster (equivalent: `export KUBECONFIG=~/kube.kubeconfig`):

```bash
export KUBECONFIG=~/kube.kubeconfig
kubectl config current-context
```

## 1. Operator install

Create the operator namespace and apply the manifest. On recent OpenShift releases, use **server-side apply** so large CRDs (for example poolers) do not exceed client-side annotation limits:

```bash
kubectl create namespace postgresql-operator-system

curl -sL -o /tmp/edb-cnp-operator.yaml \
  "https://get.enterprisedb.io/cnp/postgresql-operator-1.23.1.yaml"

kubectl apply --server-side --force-conflicts -f /tmp/edb-cnp-operator.yaml
```

## 2. OpenShift: SCC for the operator

If the controller deployment scales but **no pod** appears, inspect the ReplicaSet events. When the failure mentions **security context constraints** and a fixed `runAsUser` outside the namespace UID range, grant a suitable SCC to the operator’s service account (adjust SCC name to your cluster policy if required):

```bash
oc adm policy add-scc-to-user nonroot-v2 \
  -z postgresql-operator-manager \
  -n postgresql-operator-system
```

Then restart the deployment:

```bash
kubectl rollout restart deployment/postgresql-operator-controller-manager \
  -n postgresql-operator-system
kubectl rollout status deployment/postgresql-operator-controller-manager \
  -n postgresql-operator-system --timeout=300s
```

## 3. Pick a storage class

Choose a **bound** `StorageClass` that exists on **your** cluster (names vary by platform):

```bash
kubectl get storageclass
```

Set a shell variable for the next steps, for example:

```bash
PG_STORAGE_CLASS="your-storage-class-here"
```

## 4. Example namespace, app secret, and cluster

Use a dedicated workload namespace and cluster name (below matches [`db-deploy/sample-cluster`](../db-deploy/sample-cluster) defaults for consistency).

- **Public image (no registry login):** uses the CloudNativePG community image below.
- **Subscribed EDB image:** create your EDB registry pull secret in that namespace, set `imageName` to your `docker.enterprisedb.com/...` image, and set `spec.imagePullSecrets` to that secret’s name (example: `edb-pull-subscription`).

```bash
kubectl create namespace edb-postgres

# Optional: only if you use docker.enterprisedb.com images (skip for the public ghcr.io image below).
kubectl create secret docker-registry edb-pull-subscription \
  --docker-server=docker.enterprisedb.com \
  --docker-username='YOUR_EDB_SUBSCRIPTION_USER' \
  --docker-password='YOUR_EDB_TOKEN_OR_PASSWORD' \
  -n edb-postgres

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: app-db-credentials
  namespace: edb-postgres
type: kubernetes.io/basic-auth
stringData:
  username: app
  password: "REPLACE_WITH_A_STRONG_PASSWORD"
---
apiVersion: postgresql.k8s.enterprisedb.io/v1
kind: Cluster
metadata:
  name: postgresql
  namespace: edb-postgres
spec:
  instances: 1
  imageName: ghcr.io/cloudnative-pg/postgresql:16.6
  # When using an EDB image from docker.enterprisedb.com, uncomment and match your secret name:
  # imagePullSecrets:
  #   - name: edb-pull-subscription
  bootstrap:
    initdb:
      database: app
      owner: app
      secret:
        name: app-db-credentials
  storage:
    size: 5Gi
    storageClass: ${PG_STORAGE_CLASS}
EOF
```

## 5. Wait and verify

```bash
kubectl get cluster,pvc,pods -n edb-postgres -w
# Ctrl-C when the cluster phase is healthy

kubectl get cluster postgresql -n edb-postgres \
  -o jsonpath='{.status.phase}{"\n"}'
```

Run one query from inside the primary pod (pod name follows the instance name):

```bash
PRIMARY_POD="$(kubectl get pods -n edb-postgres \
  -l k8s.enterprisedb.io/cluster=postgresql \
  -o jsonpath='{.items[0].metadata.name}')"
PASS="$(kubectl get secret app-db-credentials -n edb-postgres -o jsonpath='{.data.password}' | base64 -d)"
kubectl exec -n edb-postgres pod/"${PRIMARY_POD}" -- \
  env PGPASSWORD="${PASS}" psql -h 127.0.0.1 -U app -d app \
  -c 'SELECT current_database(), current_user;'
```

Read/write service (in-cluster): `postgresql-rw.edb-postgres.svc:5432`.

## 6. Cleanup (optional)

```bash
kubectl delete cluster postgresql -n edb-postgres
kubectl delete namespace edb-postgres
# Operator uninstall is environment-specific; remove CRDs and
# postgresql-operator-system only if you intend to drop the operator cluster-wide.
```

## Reference

- [EDB PostgreSQL on OpenShift (operator documentation)](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/)
