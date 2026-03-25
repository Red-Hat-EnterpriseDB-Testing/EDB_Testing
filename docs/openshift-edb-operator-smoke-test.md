# OpenShift — EDB Postgres for Kubernetes operator (smoke test)

Anonymized lab checklist: install the operator, fix common OpenShift constraints, deploy a tiny cluster, and run one SQL check. Replace placeholders (`demo-postgres`, storage class, passwords) with your own values.

[← Manual install guide](install-kubernetes-manual.md)

## Prerequisites

- `kubectl` and `oc` configured for the target cluster
- Cluster-admin (or sufficient RBAC for namespaces, CRDs, SCC bindings)
- **Always** point at the intended kubeconfig so you do not hit the wrong cluster (equivalent: `export KUBECONFIG=~/kube.kubeconfig`):

```bash
export KUBECONFIG=~/kube.kubeconfig
kubectl config current-context
```

## 1. Operator install

Create the operator namespace and apply the manifest. On recent Kubernetes/OpenShift, use **server-side apply** so large CRDs (for example poolers) do not exceed client-side annotation limits:

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
DEMO_STORAGE_CLASS="your-storage-class-here"
```

## 4. Demo namespace, app secret, and cluster

Use a generic workload namespace and cluster name. For a **non-production** check without an EDB registry login, you can use a public PostgreSQL image from the CloudNativePG project; switch `imageName` to an EDB-supported image and add pull secrets when you move to a subscribed deployment.

```bash
kubectl create namespace demo-postgres

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: demo-app-secret
  namespace: demo-postgres
type: kubernetes.io/basic-auth
stringData:
  username: app
  password: "REPLACE_WITH_A_STRONG_PASSWORD"
---
apiVersion: postgresql.k8s.enterprisedb.io/v1
kind: Cluster
metadata:
  name: demo-pg
  namespace: demo-postgres
spec:
  instances: 1
  imageName: ghcr.io/cloudnative-pg/postgresql:16.6
  bootstrap:
    initdb:
      database: app
      owner: app
      secret:
        name: demo-app-secret
  storage:
    size: 5Gi
    storageClass: ${DEMO_STORAGE_CLASS}
EOF
```

## 5. Wait and verify

```bash
kubectl get cluster,pvc,pods -n demo-postgres -w
# Ctrl-C when the cluster phase is healthy

kubectl get cluster demo-pg -n demo-postgres \
  -o jsonpath='{.status.phase}{"\n"}'
```

Run one query from inside the primary pod (pod name follows the instance name):

```bash
PRIMARY_POD="$(kubectl get pods -n demo-postgres \
  -l k8s.enterprisedb.io/cluster=demo-pg \
  -o jsonpath='{.items[0].metadata.name}')"
PASS="$(kubectl get secret demo-app-secret -n demo-postgres -o jsonpath='{.data.password}' | base64 -d)"
kubectl exec -n demo-postgres pod/"${PRIMARY_POD}" -- \
  env PGPASSWORD="${PASS}" psql -h 127.0.0.1 -U app -d app \
  -c 'SELECT current_database(), current_user;'
```

Read/write service (in-cluster): `demo-pg-rw.demo-postgres.svc:5432`.

## 6. Cleanup (optional)

```bash
kubectl delete cluster demo-pg -n demo-postgres
kubectl delete namespace demo-postgres
# Operator uninstall is environment-specific; remove CRDs and
# postgresql-operator-system only if you intend to drop the operator cluster-wide.
```

## Reference

- [EDB Postgres for Kubernetes documentation](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/)
