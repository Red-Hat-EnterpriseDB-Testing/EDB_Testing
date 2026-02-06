# EnterpriseDB Postgres Operator Installation Summary

## Installation Date
Friday, February 6, 2026

## Cluster Details
- **Cluster Type**: MicroShift
- **Cluster Domain**: 127.0.0.1.nip.io
- **Kubeconfig**: `~/.aap/kubeconfig.microshift`

## Operator Details
- **Operator Name**: EDB Postgres for Kubernetes (CloudNativePG)
- **Version**: 1.28.0
- **Namespace**: `postgresql-operator-system`
- **Image**: `docker.enterprisedb.com/k8s/edb-postgres-for-cloudnativepg:1.28.0`

## Installation Steps Performed

### 1. Created Namespace
```bash
kubectl create namespace postgresql-operator-system
```

### 2. Created Pull Secret
Created `edb-pull-secret` in the `postgresql-operator-system` namespace using the EDB subscription token to access the private container registry at `docker.enterprisedb.com`.

### 3. Installed Operator
Applied the official EDB Postgres for Kubernetes manifest:
```bash
kubectl apply --server-side -f https://get.enterprisedb.io/pg4k/pg4k-1.28.0.yaml
```

### 4. Resolved Security Context Constraints (SCC)
MicroShift enforces OpenShift-style Security Context Constraints. The default manifest tried to use hardcoded UID 10001, which is outside the allowed namespace UID range.

**Secure Solution**: Modified the deployment to work within the default `restricted-v2` SCC:
- Removed hardcoded `runAsUser: 10001` and `runAsGroup: 10001`
- OpenShift automatically assigns UID from namespace range (1000190000-1000199999)
- Kept seccomp profile `RuntimeDefault` (allowed by restricted-v2)
- Bound service account to `restricted-v2` SCC explicitly

**Security Context Used**:
- SCC: `restricted-v2` (most restrictive, default)
- UID: `1000190000` (auto-assigned)
- Privilege Escalation: Disabled
- Capabilities: All dropped
- Root Filesystem: Read-only
- SELinux: Enforced

See [SECURE_INSTALL.md](SECURE_INSTALL.md) for detailed security information.

### 5. Verified Installation
- Operator pod is running and healthy
- All Custom Resource Definitions (CRDs) are installed
- Controllers are active (cluster, backup, pooler, scheduled-backup, etc.)

## Installed Custom Resource Definitions (CRDs)

The following CRDs are now available for creating PostgreSQL resources:

- `backups.postgresql.k8s.enterprisedb.io`
- `clusterimagecatalogs.postgresql.k8s.enterprisedb.io`
- `clusters.postgresql.k8s.enterprisedb.io`
- `databases.postgresql.k8s.enterprisedb.io`
- `failoverquorums.postgresql.k8s.enterprisedb.io`
- `imagecatalogs.postgresql.k8s.enterprisedb.io`
- `poolers.postgresql.k8s.enterprisedb.io`
- `publications.postgresql.k8s.enterprisedb.io`
- `scheduledbackups.postgresql.k8s.enterprisedb.io`
- `subscriptions.postgresql.k8s.enterprisedb.io`

## Verifying the Installation

Check operator status:
```bash
export KUBECONFIG=~/.aap/kubeconfig.microshift
kubectl get pods -n postgresql-operator-system
kubectl get deployment -n postgresql-operator-system
```

View operator logs:
```bash
kubectl logs -n postgresql-operator-system deployment/postgresql-operator-controller-manager
```

List available CRDs:
```bash
kubectl get crd | grep postgresql
```

## Next Steps

### Create a PostgreSQL Cluster
You can now create PostgreSQL clusters using the `Cluster` CRD. Example:

```yaml
apiVersion: postgresql.k8s.enterprisedb.io/v1
kind: Cluster
metadata:
  name: my-postgres-cluster
  namespace: default
spec:
  instances: 3
  storage:
    size: 1Gi
```

Apply with:
```bash
kubectl apply -f my-postgres-cluster.yaml
```

### Monitor the Cluster
```bash
kubectl get clusters -A
kubectl get pods -l "postgresql=my-postgres-cluster"
```

### Additional Resources
- [EDB Postgres for Kubernetes Documentation](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/)
- [Quickstart Guide](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/quickstart/)
- [OpenShift Deployment](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/openshift/)

## Troubleshooting

If you encounter issues:

1. Check operator logs:
   ```bash
   kubectl logs -n postgresql-operator-system deployment/postgresql-operator-controller-manager
   ```

2. Check SCC permissions:
   ```bash
   oc describe scc edb-operator-scc
   ```

3. Verify pull secret:
   ```bash
   kubectl get secret edb-pull-secret -n postgresql-operator-system
   ```

## Files Created
- `INSTALL_SUMMARY.md` - This installation summary (current file)
- `SECURE_INSTALL.md` - Detailed security configuration documentation
- `GETTING_STARTED.md` - Guide for creating PostgreSQL clusters
- `example-postgres-cluster.yaml` - Sample cluster configuration
