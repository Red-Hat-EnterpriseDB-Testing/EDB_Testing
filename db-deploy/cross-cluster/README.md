# Cross-cluster passive replica (streaming)

This directory holds **example manifests** and a **helper script** for a common pattern: one **primary** EDB Postgres for Kubernetes / CloudNativePG `Cluster` on an OpenShift cluster, and a **passive replica** `Cluster` on a second Kubernetes/OpenShift cluster that streams changes over the network.

All names, kubeconfig paths, and DNS examples below are **placeholders** — replace them with your environment. Do not commit real credentials, Route hostnames, or kubeconfigs.

## What gets created

| Site | Purpose | Objects (example names) |
|------|---------|---------------------------|
| Primary OpenShift | Serves reads/writes; in-cluster HA can use multiple instances. | Existing `Cluster` (e.g. `postgresql`), Service `<cluster>-rw`, optional `Route` from `primary-site/route-replication.yaml` |
| Replica cluster | Continuous recovery: read-only until promoted (see EDB docs). | `Cluster` (e.g. `postgresql-replica`), TLS secrets copied from primary, PVCs on replica storage class |

The replica uses the **standalone replica cluster** pattern: `spec.bootstrap.pg_basebackup` and `spec.replica.enabled: true` with an entry in `spec.externalClusters`. See the official guide: [Replica clusters](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/replica_cluster/).

## Prerequisites

1. **Operator** installed on **both** clusters with a **compatible major** version (mixing very different versions can cause API or webhook issues).
2. **Primary** `Cluster` is **healthy** (e.g. `kubectl get cluster -n <namespace>`).
3. **Network**: replica cluster nodes (or egress) must reach the primary’s **exposed** endpoint — for OpenShift, usually the **Route hostname** and the **port** the router advertises (often **443** with TLS passthrough; some environments use **5432** — check `oc get route <name> -o yaml`).
4. **TLS secrets** on the primary, created by the operator: `<primary-cluster>-replication` and `<primary-cluster>-ca`. The script copies these into the replica namespace on the second cluster.
5. **Storage** on the replica cluster: set `spec.storage.storageClass` in `replica-site/replica-cluster.template.yaml` to a class that can provision volumes (edit before or after first apply).

## One-time: choose contexts

Use **explicit** `--context` (and different `--kubeconfig` files if needed) so you never apply to the wrong API server:

```bash
oc config get-contexts
```

Export the context names you will use:

```bash
export PRIMARY_CONTEXT='<your-primary-cluster-context>'
export REPLICA_CONTEXT='<your-replica-cluster-context>'
```

Optional: split kubeconfigs:

```bash
export PRIMARY_KUBECONFIG="${PRIMARY_KUBECONFIG:-$HOME/.kube/config}"
export REPLICA_KUBECONFIG="${REPLICA_KUBECONFIG:-$HOME/.kube/config}"
```

## Run the helper script

```bash
chmod +x db-deploy/cross-cluster/scripts/sync-passive-replica.sh

export PRIMARY_CONTEXT='<primary-context>'
export REPLICA_CONTEXT='<replica-context>'

db-deploy/cross-cluster/scripts/sync-passive-replica.sh
```

### Environment variables (optional)

| Variable | Default | Meaning |
|----------|---------|---------|
| `PRIMARY_KUBECONFIG` | `$KUBECONFIG` or `~/.kube/config` | Kubeconfig file for primary |
| `REPLICA_KUBECONFIG` | same as primary | Kubeconfig file for replica |
| `PRIMARY_CONTEXT` | *(required)* | Context name for primary |
| `REPLICA_CONTEXT` | *(required)* | Context name for replica |
| `NS` | `edb-postgres` | Namespace on **both** clusters |
| `PRIMARY_CLUSTER_NAME` | `postgresql` | Primary `Cluster` name (drives secret names `<name>-replication` / `-ca`) |
| `REPLICA_CLUSTER_NAME` | `postgresql-replica` | Passive replica `Cluster` name |
| `ROUTE_NAME` | `postgresql-replication` | Must match `metadata.name` in `primary-site/route-replication.yaml` |

If your primary name is **not** `postgresql`, update:

- `primary-site/route-replication.yaml` (`spec.to.name` → `<primary>-rw`, and optionally `metadata.name` + `ROUTE_NAME`), and
- TLS secret references in `replica-site/replica-cluster.template.yaml`.

## TLS and the OpenShift Route

The committed Route uses **TLS passthrough** to the CNPG `-rw` Service. The PostgreSQL server certificate is usually issued for **in-cluster DNS**, not the Route hostname. The replica manifest therefore uses **`sslmode: verify-ca`** (encrypt and verify chain, not strict hostname match). For stricter trust, issue server certificates that include the Route hostname (or use a different exposure path such as load balancer + custom DNS).

If streaming fails with connection or TLS errors, try adjusting `port` under `connectionParameters` (e.g. `5432` vs `443`) per your router behavior.

## Anonymity and documentation

- Example workload and namespace names (`postgresql`, `edb-postgres`) are defaults only; rename them for your standards.
- Do not paste real **Route hosts**, **tokens**, or **kubeconfig** fragments into issues or commits.
- For a minimal operator smoke test with a **single** anonymous kubeconfig path pattern, see `docs/openshift-edb-operator-smoke-test.md`.

## Layout

```
cross-cluster/
  primary-site/
    route-replication.yaml    # OpenShift Route → primary Service (edit if not postgresql)
  replica-site/
    replica-cluster.template.yaml   # Passive replica; host placeholder filled by script
  scripts/
    sync-passive-replica.sh   # Route + secret copy + apply replica
```

## Files in this repository (related)

- `db-deploy/sample-cluster/` — primary-style single-cluster example (`initdb`, two instances optional).
- `db-deploy/olm-openshift/` — OperatorHub subscription on full OpenShift.
- `db-deploy/operator/` — Manifest install when OLM is unavailable (e.g. some compact clusters).
