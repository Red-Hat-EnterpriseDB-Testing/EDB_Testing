# Getting Started with EDB Postgres for Kubernetes

## Prerequisites
- MicroShift cluster is running
- EDB Postgres operator is installed (v1.28.0)
- `kubectl` or `oc` CLI is configured
- EDB pull secret (see [Obtaining the EDB pull secret](#obtaining-the-edb-pull-secret) below)

## Set Up Environment

```bash
export KUBECONFIG=~/.aap/kubeconfig
```

## Create Your First PostgreSQL Cluster

### Step 1: Review the Example Cluster

The `example-postgres-cluster.yaml` file contains a basic PostgreSQL cluster configuration with:
- 3 instances (1 primary + 2 replicas)
- PostgreSQL 16.8
- 1Gi storage per instance
- Basic authentication
- Resource limits

### Obtaining the EDB pull secret

Access to EDB container images (`docker.enterprisedb.com`) requires an EDB account and a valid [subscription plan](https://www.enterprisedb.com/products/plans-comparison#selfmanagedenterpriseplan).

1. **Get your EDB account token** from the [EDB portal: Get your token](https://www.enterprisedb.com/docs/repos/getting_started/with_web/get_your_token/).
2. **Create a Kubernetes pull secret** (replace `<namespace>` and use your token):

   ```bash
   kubectl create secret docker-registry edb-pull-secret \
     -n <namespace> \
     --docker-server=docker.enterprisedb.com \
     --docker-username=k8s \
     --docker-password="YOUR_EDB_ACCOUNT_TOKEN"
   ```

   Or copy an existing secret from the operator namespace (e.g. after installing the operator with Helm and a pull secret) as in Step 2 below.

For more options (Docker config file, Ansible role usage), see the [deploy_cluster role README](ansible-examples/collections/ansible_collections/edb/postgres_operations/roles/deploy_cluster/README.md#edb-pull-secret) and [EDB private container registry](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/private_edb_registries/).

### Step 2: Copy Pull Secret to Default Namespace

The example cluster uses the default namespace, so we need to copy the pull secret (if you already have it in the operator namespace):

```bash
kubectl get secret edb-pull-secret -n postgresql-operator-system -o yaml | \
  sed 's/namespace: postgresql-operator-system/namespace: default/' | \
  kubectl apply -f -
```

### Step 3: Deploy the Cluster

```bash
kubectl apply -f example-postgres-cluster.yaml
```

### Step 4: Monitor the Deployment

Watch the cluster being created:

```bash
kubectl get clusters -w
```

Check the pods:

```bash
kubectl get pods -l postgresql=example-postgres
```

View cluster details:

```bash
kubectl describe cluster example-postgres
```

### Step 5: Wait for Cluster to be Ready

The cluster is ready when you see:

```
NAME               AGE   INSTANCES   READY   STATUS                     PRIMARY
example-postgres   2m    3           3       Cluster in healthy state   example-postgres-1
```

## Connect to PostgreSQL

### Get Connection Information

The operator creates several services:

```bash
kubectl get services -l postgresql=example-postgres
```

Services created:
- `example-postgres-rw` - Read-Write service (connects to primary)
- `example-postgres-ro` - Read-Only service (connects to replicas)
- `example-postgres-r` - Read service (connects to any instance)

### Connect Using psql

Connect from within the cluster:

```bash
kubectl run -it --rm psql-client \
  --image=postgres:16 \
  --restart=Never \
  --env="PGPASSWORD=app-password-change-me" \
  -- psql -h example-postgres-rw -U app -d app
```

### Get Superuser Password

The operator creates a superuser secret:

```bash
kubectl get secret example-postgres-superuser -o jsonpath='{.data.password}' | base64 -d
echo
```

## Common Operations

### Scale the Cluster

Edit the cluster to change instance count:

```bash
kubectl patch cluster example-postgres --type='json' \
  -p='[{"op": "replace", "path": "/spec/instances", "value": 5}]'
```

### View Cluster Status

```bash
kubectl get cluster example-postgres -o yaml
```

### Check Logs

View primary pod logs:

```bash
kubectl logs -l postgresql=example-postgres,role=primary
```

View replica pod logs:

```bash
kubectl logs -l postgresql=example-postgres,role=replica
```

### Backup and Recovery

Create an on-demand backup:

```yaml
apiVersion: postgresql.k8s.enterprisedb.io/v1
kind: Backup
metadata:
  name: example-backup
  namespace: default
spec:
  cluster:
    name: example-postgres
```

Apply:

```bash
kubectl apply -f backup.yaml
```

Check backup status:

```bash
kubectl get backups
```

### Delete the Cluster

**Warning**: This will delete all data!

```bash
kubectl delete cluster example-postgres
```

To also delete PVCs:

```bash
kubectl delete pvc -l postgresql=example-postgres
```

## Advanced Configuration

### Enable Monitoring

To enable Prometheus monitoring, modify the cluster spec:

```yaml
spec:
  monitoring:
    enablePodMonitor: true
```

### Configure Connection Pooling

Create a PgBouncer pooler:

```yaml
apiVersion: postgresql.k8s.enterprisedb.io/v1
kind: Pooler
metadata:
  name: example-pooler
  namespace: default
spec:
  cluster:
    name: example-postgres
  instances: 3
  type: rw
  pgbouncer:
    poolMode: transaction
```

### Scheduled Backups

Configure automatic backups:

```yaml
apiVersion: postgresql.k8s.enterprisedb.io/v1
kind: ScheduledBackup
metadata:
  name: daily-backup
  namespace: default
spec:
  schedule: "0 2 * * *"  # 2 AM daily
  cluster:
    name: example-postgres
```

## Troubleshooting

### Cluster Not Starting

Check operator logs:

```bash
kubectl logs -n postgresql-operator-system \
  deployment/postgresql-operator-controller-manager
```

Check cluster events:

```bash
kubectl describe cluster example-postgres
```

### Pod ImagePullBackOff

Verify pull secret exists in the namespace:

```bash
kubectl get secret edb-pull-secret
```

Check pod events:

```bash
kubectl describe pod <pod-name>
```

### Connection Issues

Verify services exist:

```bash
kubectl get svc -l postgresql=example-postgres
```

Check if pods are ready:

```bash
kubectl get pods -l postgresql=example-postgres
```

Test DNS resolution:

```bash
kubectl run -it --rm test \
  --image=busybox \
  --restart=Never \
  -- nslookup example-postgres-rw
```

## Additional Resources

- [EDB Postgres for Kubernetes Documentation](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/)
- [API Reference](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/api_reference/)
- [Samples Repository](https://github.com/EnterpriseDB/edb-postgres-for-kubernetes-charts)
- [Troubleshooting Guide](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/troubleshooting/)

## Next Steps

1. Create a test database cluster using the example
2. Practice connecting and running queries
3. Test backup and restore operations
4. Explore high availability by simulating failures
5. Set up connection pooling with PgBouncer
