# EDB Postgres for Kubernetes — Manual Installation

This guide covers installing the **EDB Postgres for Kubernetes** operator and deploying **`Cluster`** resources manually (`oc` / `kubectl`, YAML, or GitOps) on OpenShift or Kubernetes. Manifest examples use the EDB API group **`postgresql.k8s.enterprisedb.io`** (same family as CloudNativePG; confirm exact `apiVersion`/`kind` for your installed operator).

[← Back to main README](../README.md#installation)

<a id="ansible-gitops"></a>

## Ansible and GitOps

This repository does **not** ship a vendored Ansible collection for the EDB Kubernetes operator. You can apply the same objects with **`kubernetes.core.k8s`**, **`kubernetes.core.k8s_info`**, or `oc`/`kubectl` from **your** playbooks or **Ansible Automation Platform**, using an execution environment that includes `kubernetes.core` and a valid kubeconfig.

Suggested automation flow:

1. **Install the operator** — [§1](#1-install-the-edb-postgres-for-openshift-operator) below, or Kustomize: [`db-deploy/operator`](../db-deploy/README.md#install-operator).
2. **Apply `Cluster` and related CRs** — [§2](#2-deploy-a-postgresql-cluster-manual); samples: [`db-deploy/sample-cluster/`](../db-deploy/README.md#apply-sample-cluster).
3. **Passive streaming replica across clusters** — [`db-deploy/cross-cluster/README.md`](../db-deploy/cross-cluster/README.md).

For **Postgres on hosts** (VMs / bare metal), use **[TPA](install-tpa.md)** — not the in-cluster operator. For execution environments tailored to TPA, see the [TPA repo `tpa-ee/`](https://github.com/EnterpriseDB/tpa/tree/main/tpa-ee).

## Prerequisites

- OpenShift 4.x or Kubernetes 1.21+
- Cluster admin or namespace admin privileges
- `kubectl` or `oc` CLI installed
- Valid EDB subscription and pull secret

## 1. Install the EDB Postgres for OpenShift Operator

```bash
# Create namespace
oc create namespace postgresql-operator-system

# Install operator via OperatorHub (OpenShift) or Helm
oc apply -f https://get.enterprisedb.io/cnp/postgresql-operator-1.23.1.yaml
```

## 2. Deploy a PostgreSQL cluster (manual)

### Registry pull secret (EDB images)

Pods need credentials to pull from `docker.enterprisedb.com`. Create a `kubernetes.io/dockerconfigjson` secret in the **same namespace** as the cluster (use your EDB subscription username and token; the name can be whatever you already use—replace `edb-pull-secret` below if yours differs):

```bash
oc create secret docker-registry edb-pull-secret \
  --docker-server=docker.enterprisedb.com \
  --docker-username='YOUR_EDB_SUBSCRIPTION_USER' \
  --docker-password='YOUR_EDB_TOKEN_OR_PASSWORD' \
  -n production
```

If you already created this secret under another name in that namespace, reference that name in `spec.imagePullSecrets` instead.

### Cluster manifest

Create a cluster definition file:

```yaml
apiVersion: postgresql.k8s.enterprisedb.io/v1
kind: Cluster
metadata:
  name: postgres-cluster
  namespace: production
spec:
  instances: 3
  imageName: docker.enterprisedb.com/edb/edb-postgres-advanced:16
  imagePullSecrets:
    - name: edb-pull-secret
  postgresql:
    parameters:
      max_connections: "1500"
      shared_buffers: "256MB"
  storage:
    size: 100Gi
    storageClass: gp3
  backup:
    barmanObjectStore:
      destinationPath: s3://my-backup-bucket/
      s3Credentials:
        accessKeyId:
          name: aws-creds
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: aws-creds
          key: ACCESS_SECRET_KEY
```

Apply the cluster:

```bash
oc apply -f postgres-cluster.yaml
```

## 3. Verify installation

```bash
# Check operator status
oc get pods -n postgresql-operator-system

# Check cluster status
oc get cluster -n production

# Check pods
oc get pods -n production
```

## Quick start resources

- **Git-ready manifests (Kustomize)**: [db-deploy/README.md](../db-deploy/README.md) — operator base from `get.enterprisedb.io` and a sample `Cluster` in `db-deploy/sample-cluster/`
- **Cross-cluster passive replica (anonymized placeholders)**: [db-deploy/cross-cluster/README.md](../db-deploy/cross-cluster/README.md) — Route + TLS secret sync + replica `Cluster` between two kube contexts
- **OpenShift smoke test (anonymized)**: [openshift-edb-operator-smoke-test.md](openshift-edb-operator-smoke-test.md) — operator install, SCC, example `Cluster`, verification (`KUBECONFIG` example: `${HOME}/kube.kubeconfig`)
- **EDB Postgres for Kubernetes Documentation**: [https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/)
- **EDB Installation Guide**: [https://www.enterprisedb.com/docs/epas/latest/installing/](https://www.enterprisedb.com/docs/epas/latest/installing/)

## Next steps

After installation:

1. **Configure High Availability**: Set up replication and failover (see [EDB Postgres for Kubernetes Architecture](#edb-postgres-for-kubernetes-architecture) below)
2. **Set Up Monitoring**: Deploy monitoring tools (Prometheus, Grafana)
3. **Configure Backups**: Set up automated backup schedules
4. **Implement Security**: Configure TLS, authentication, and network policies
5. **Deploy AAP**: Install Ansible Automation Platform for cluster management (see [AAP Deployment Architecture](../README.md#aap-deployment-architecture))

## EDB Postgres for Kubernetes Architecture

### Distributed PostgreSQL Topology

This architecture implements EDB Postgres for Kubernetes (CloudNativePG) distributed topology with replica clusters across two separate Kubernetes/OpenShift clusters, as documented in the [EDB official architecture guide](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/architecture/#deployments-across-kubernetes-clusters).

**Key Concepts:**

1. **Primary Cluster (DC1)**:
   - Contains one primary instance accepting read/write operations
   - Contains hot standby replicas for local HA
   - Automatically managed by EDB operator within DC1

2. **Replica Cluster (DC2)**:
   - Contains a "designated primary" - a standby server in continuous recovery
   - Contains hot standby replicas cascading from designated primary
   - In read-only mode until manually promoted
   - Automatically managed by EDB operator within DC2

3. **Physical Replication**:
   - Uses PostgreSQL's native WAL-based replication
   - Primary method: Streaming replication (network-based)
   - Fallback method: WAL shipping via S3/object store
   - Byte-for-byte exact replica, faster than logical replication

4. **Automatic Service Management**:
   EDB operator automatically creates and maintains these services:
   - `<cluster>-rw`: Routes to current primary (read/write)
   - `<cluster>-ro`: Routes to hot standby replicas (read-only)
   - `<cluster>-r`: Routes to any instance (read-only)
   - During failover, operator updates `-rw` service automatically

5. **Cross-Cluster Limitations**:
   - Each EDB operator manages only its local Kubernetes cluster
   - Cross-cluster failover must be coordinated externally (via AAP, GitOps, or higher-level orchestration)
   - Promotion of replica cluster to primary is declarative but requires external trigger

### Datacenter 1 (Primary)

**OpenShift Cluster**: `ocp1.example.com`

#### Production Namespace

- **Cluster**: `prod-db` (3 instances - Primary Cluster)
  - 1 Primary Instance (read/write) + 2 Hot Standby Replicas
  - PostgreSQL 16.8
  - Auto-failover enabled within cluster
  - Continuous WAL archiving to S3/object store
  - Services automatically managed by EDB operator:
    - `-rw`: Routes to current primary (read/write)
    - `-ro`: Routes to hot standby replicas (read-only)
    - `-r`: Routes to any instance (read-only)

### Datacenter 2 (DR Site)

**OpenShift Cluster**: `ocp2.example.com`

#### Production Namespace

- **Cluster**: `prod-db-replica` (3 instances - Replica Cluster)
  - 1 Designated Primary (standby server in continuous recovery)
  - 2 Hot Standby Replicas
  - Replicated from DC1 via streaming replication and WAL shipping
  - Can be promoted to primary cluster during DR
  - Independent backup to S3
  - Services: `-ro` (read-only), `-r` (any instance read-only)


## Scaling Considerations

### Horizontal Scaling

**AAP Controller:**
```yaml
# Scale AAP controller replicas
kubectl scale deployment automation-controller \
  -n ansible-automation-platform --replicas=5
```

**PostgreSQL Clusters:**
```yaml
# Scale database replicas
kubectl patch cluster prod-db -n production \
  --type='json' -p='[{"op": "replace", "path": "/spec/instances", "value": 5}]'
```

### Vertical Scaling

**AAP Controller Resources:**
```yaml
resources:
  requests:
    cpu: "8000m"
    memory: "16Gi"
  limits:
    cpu: "16000m"
    memory: "32Gi"
```
