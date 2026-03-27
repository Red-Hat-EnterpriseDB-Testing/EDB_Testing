# AAP 2.6 operator on OpenShift — external Postgres in `edb-pg-demo`

This flow installs the **Ansible Automation Platform operator** (`stable-2.6`) and an **`AnsibleAutomationPlatform`** instance that uses the CloudNativePG / EDB **`demo-pg`** read-write Service **`demo-pg-rw.edb-pg-demo.svc.cluster.local`** as a single PostgreSQL server with **four databases** (gateway, controller, hub, EDA).

Confirm fields and prerequisites in [Installing on OpenShift Container Platform 2.6](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html-single/installing_on_openshift_container_platform/index).

## Prerequisites

1. **Cluster:** OpenShift with `redhat-operators` / `openshift-marketplace` (OperatorHub).
2. **EDB primary:** `Cluster/demo-pg` healthy in `edb-pg-demo` ([`db-deploy/sample-cluster`](../../db-deploy/sample-cluster)).
3. **Databases:** Create role `aap`, databases, and **`hstore`** on the hub DB — see [`../edb-bootstrap/create-aap-databases.sql`](../edb-bootstrap/create-aap-databases.sql).
4. **Automation Hub storage:** `spec.hub.file_storage_storage_class` must be a **ReadWriteMany** `StorageClass`. The sample value `ocs-storagecluster-cephfs` suits OpenShift Data Foundation; replace with your cluster’s RWX class (`oc get storageclass`).
5. **Password rules:** DB password for AAP unmanaged secrets must **not** contain `'`, `"`, or `\`.

## Install order

Use explicit **`--kubeconfig`** and **`--context`** for the target cluster (e.g. production OpenShift).

### 1. Operator (namespace + subscription)

```bash
oc apply -k aap-deploy/openshift
oc get csv -n ansible-automation-platform -w
```

Wait until the AAP operator CSV is **Succeeded**.

### 2. PostgreSQL objects on `demo-pg`

Edit the password in `aap-deploy/edb-bootstrap/create-aap-databases.sql`, then run against the primary (adjust pod name if needed):

```bash
oc exec -n edb-pg-demo -it demo-pg-1 -- psql -U postgres -v ON_ERROR_STOP=1 \
  -c "CREATE ROLE aap LOGIN PASSWORD 'YOUR_PASSWORD';" \
  -c "CREATE DATABASE platform_gateway OWNER aap;" \
  -c "CREATE DATABASE automation_controller OWNER aap;" \
  -c "CREATE DATABASE automation_hub OWNER aap;" \
  -c "CREATE DATABASE automation_eda OWNER aap;"
oc exec -n edb-pg-demo -it demo-pg-1 -- psql -U postgres -d automation_hub -v ON_ERROR_STOP=1 \
  -c "CREATE EXTENSION IF NOT EXISTS hstore;"
```

(Or paste the SQL file contents in `psql` after substitution.)

### 3. Connection secrets in `ansible-automation-platform`

```bash
chmod +x aap-deploy/openshift/scripts/generate-postgres-secrets.sh
aap-deploy/openshift/scripts/generate-postgres-secrets.sh 'YOUR_PASSWORD' \
  | oc apply -f -
```

Use the **same** password as in step 2. To tune TLS, set `SSLMODE=verify-ca` (or per docs) when running the script.

### 4. Fix Hub file storage class (if needed)

Edit **`ansibleautomationplatform.yaml`** `spec.hub.file_storage_storage_class` to an RWX class, or patch after apply:

```bash
oc patch ansibleautomationplatform aap -n ansible-automation-platform --type=merge \
  -p '{"spec":{"hub":{"file_storage_storage_class":"YOUR_RWX_STORAGECLASS"}}}'
```

### 5. Create the platform instance

```bash
oc apply -f aap-deploy/openshift/ansibleautomationplatform.yaml
oc get ansibleautomationplatform,pods -n ansible-automation-platform -w
```

### 6. Licensing and routes

Apply your subscription/license per Red Hat documentation; retrieve routes:

```bash
oc get routes -n ansible-automation-platform
```

## Layout

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, `OperatorGroup`, `Subscription` |
| `ansibleautomationplatform.yaml` | Parent CR with external DB secret refs |
| `scripts/generate-postgres-secrets.sh` | Prints four `Secret` manifests |
| `postgres-configuration-secret.example.yaml` | Optional single-secret structural template (placeholders; most flows use the generator script above) |
| `../edb-bootstrap/create-aap-databases.sql` | Reference SQL (edit password before use) |

## Private CA (optional)

If the controller must trust a custom CA for Postgres TLS, create **`bundle-ca.crt`** in a Secret and set **`spec.bundle_cacert_secret`** on `AnsibleAutomationPlatform` per product docs.
