# AAP 2.6 Deployment Reference - OpenShift with External PostgreSQL

**Document Version:** 1.0  
**AAP Version:** 2.6  
**Last Updated:** 2026-04-03  
**Deployment Target:** OpenShift with AAP Operator and EDB PostgreSQL

---

## Purpose

This reference documents the deployment-specific configuration, database setup, verification procedures, and troubleshooting for AAP 2.6 on OpenShift using external EDB PostgreSQL. For general AAP component capabilities and features, see the [Red Hat AAP 2.6 Documentation](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6).

**What this guide covers:**

- Database architecture (one PostgreSQL instance, four databases)
- Component-specific deployment configuration
- Verification procedures after deployment
- Troubleshooting deployment issues
- Scaling and resource sizing

**What this guide does NOT cover (see Red Hat docs instead):**

- General component capabilities and features
- Using AAP components (job templates, collections, rulebooks)
- Authentication configuration (LDAP, SAML, OAuth)
- Backup and restore procedures (covered in operator documentation)

---

## Table of Contents

- [What Gets Deployed](#what-gets-deployed)
- [Database Architecture](#database-architecture)
- [Deployment Configuration](#deployment-configuration)
- [Verification Procedures](#verification-procedures)
- [Troubleshooting](#troubleshooting)
- [Scaling and Resources](#scaling-and-resources)

---

## What Gets Deployed

The default `ansibleautomationplatform.yaml` in this repository deploys **all four AAP 2.6 components**:

| Component | Purpose | Red Hat Documentation |
|-----------|---------|----------------------|
| **Platform Gateway** | Unified authentication and UI | [Gateway docs](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html-single/installing_on_openshift_container_platform/index#platform-gateway) |
| **Automation Controller** | Job execution and workflows | [Controller docs](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html-single/using_automation_controller/index) |
| **Automation Hub** | Content and collection management | [Hub docs](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html-single/managing_red_hat_certified_and_ansible_galaxy_collections_in_automation_hub/index) |
| **Event-Driven Ansible (EDA)** | Reactive automation and rulebooks | [EDA docs](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html-single/using_event-driven_ansible_controller/index) |

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Platform Gateway                          │
│              (Authentication & Unified UI)                   │
└────────┬──────────────┬──────────────┬─────────────────┬────┘
         │              │              │                 │
    ┌────▼────┐   ┌────▼────┐   ┌────▼────┐      ┌────▼────┐
    │ Gateway │   │Controller│   │   Hub   │      │   EDA   │
    │   DB    │   │    DB    │   │   DB    │      │   DB    │
    └─────────┘   └──────────┘   └─────────┘      └─────────┘
         │              │              │                 │
         └──────────────┴──────────────┴─────────────────┘
                              │
                    ┌─────────▼──────────┐
                    │  PostgreSQL Server  │
                    │   (EDB on OpenShift) │
                    │    4 databases       │
                    └─────────────────────┘
```

---

## Database Architecture

### One Instance, Four Databases

This deployment uses a **single PostgreSQL instance** (EDB Postgres for Kubernetes Cluster) with four separate databases:

| Component | Database Name | Owner | Extensions | Secret Name |
|-----------|--------------|-------|------------|-------------|
| Gateway | `platform_gateway` | `aap` | None | `external-postgres-configuration-gateway` |
| Controller | `automation_controller` | `aap` | None | `external-postgres-configuration-controller` |
| Hub | `automation_hub` | `aap` | **hstore** (required) | `external-postgres-configuration-hub` |
| EDA | `automation_eda` | `aap` | None | `external-postgres-configuration-eda` |

### Database Creation

The `create-aap-databases.sql` script creates all databases and the required `hstore` extension:

```sql
CREATE ROLE aap LOGIN PASSWORD 'REPLACE_WITH_STRONG_PASSWORD';

CREATE DATABASE platform_gateway OWNER aap;
CREATE DATABASE automation_controller OWNER aap;
CREATE DATABASE automation_hub OWNER aap;
CREATE DATABASE automation_eda OWNER aap;

\c automation_hub
CREATE EXTENSION IF NOT EXISTS hstore;
```

**Critical:** The `hstore` extension **must exist** on the `automation_hub` database before the Hub operator starts migrations. If missing, Hub pods will fail.

**Run the script:**

```bash
oc exec -n edb-postgres -it postgresql-1 -- psql -U postgres -v ON_ERROR_STOP=1 \
  -c "CREATE ROLE aap LOGIN PASSWORD 'YOUR_PASSWORD';" \
  -c "CREATE DATABASE platform_gateway OWNER aap;" \
  -c "CREATE DATABASE automation_controller OWNER aap;" \
  -c "CREATE DATABASE automation_hub OWNER aap;" \
  -c "CREATE DATABASE automation_eda OWNER aap;"

oc exec -n edb-postgres -it postgresql-1 -- psql -U postgres -d automation_hub -v ON_ERROR_STOP=1 \
  -c "CREATE EXTENSION IF NOT EXISTS hstore;"
```

### Connection Secrets

The `generate-postgres-secrets.sh` script creates all four connection secrets:

```bash
aap-deploy/openshift/scripts/generate-postgres-secrets.sh 'YOUR_PASSWORD' | oc apply -f -
```

**Secret structure** (all four secrets follow this pattern):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: external-postgres-configuration-<component>
  namespace: ansible-automation-platform
type: Opaque
stringData:
  host: postgresql-rw.edb-postgres.svc.cluster.local
  port: "5432"
  database: <database_name>
  username: aap
  password: <password>
  sslmode: prefer
  target_session_attrs: read-write  # Ensures primary connection, not replica
  type: unmanaged
```

**Password constraints:** AAP requires passwords without `'`, `"`, or `\` characters.

---

## Deployment Configuration

### Minimal AnsibleAutomationPlatform CR

The default `ansibleautomationplatform.yaml` includes all four components:

```yaml
apiVersion: aap.ansible.com/v1alpha1
kind: AnsibleAutomationPlatform
metadata:
  name: aap
  namespace: ansible-automation-platform
spec:
  # Gateway
  database:
    database_secret: external-postgres-configuration-gateway

  # Controller
  controller:
    postgres_configuration_secret: external-postgres-configuration-controller

  # Hub
  hub:
    storage_type: file
    file_storage_storage_class: ocs-storagecluster-cephfs  # MUST be RWX
    file_storage_size: 10Gi
    postgres_configuration_secret: external-postgres-configuration-hub

  # EDA
  eda:
    database:
      database_secret: external-postgres-configuration-eda
```

### Component-Specific Requirements

#### Automation Hub: RWX Storage Required

Hub requires **ReadWriteMany (RWX)** file storage for artifact storage (collections, execution environments).

**Find an RWX StorageClass on your cluster:**

```bash
oc get storageclass
```

**Common RWX options:**

| Platform | StorageClass | Notes |
|----------|--------------|-------|
| OpenShift Data Foundation | `ocs-storagecluster-cephfs` | CephFS |
| AWS with EFS CSI | `efs-sc` | Requires EFS provisioner |
| Azure | `azurefile` | Azure Files |
| On-premises | `nfs-client`, `cephfs`, `glusterfs` | File storage |

**RWO storage will NOT work** (e.g., `gp2`, `gp3`, `lvms-vg1`). Hub needs multiple pods accessing the same volume.

**Alternative: S3 storage**

For cloud deployments, Hub can use S3-compatible object storage:

```yaml
hub:
  storage_type: s3
  object_storage_s3_secret: hub-s3-credentials
  postgres_configuration_secret: external-postgres-configuration-hub
```

The S3 secret requires: `s3-access-key-id`, `s3-secret-access-key`, `s3-bucket-name`, `s3-region`.

### Field Name Differences (AAP 2.6 API)

Note the **inconsistent field paths** for database secrets (this is the documented API):

| Component | Secret Field Path |
|-----------|------------------|
| Gateway | `spec.database.database_secret` |
| Controller | `spec.controller.postgres_configuration_secret` |
| Hub | `spec.hub.postgres_configuration_secret` |
| EDA | `spec.eda.database.database_secret` |

Use these exact field names - they are not errors.

### Deployment Steps

See [`aap-deploy/openshift/README.md`](../aap-deploy/openshift/README.md) for complete steps:

1. Install AAP Operator
2. Create PostgreSQL databases (run SQL script)
3. Generate connection secrets
4. Update Hub storage class if needed
5. Deploy AnsibleAutomationPlatform CR
6. Retrieve routes

**Typical timeline:** 8-12 minutes from CR creation to fully operational.

---

## Verification Procedures

### Check All Resources

```bash
# View custom resources
oc get ansibleautomationplatform,automationcontroller,automationhub,automationeda \
  -n ansible-automation-platform

# View pods
oc get pods -n ansible-automation-platform
```

**Expected pods:**

```
aap-operator-controller-manager-<id>              2/2     Running
aap-platform-gateway-<id>                         1/1     Running
aap-controller-web-<id>                           1/1     Running
aap-controller-task-<id>                          1/1     Running
aap-hub-api-<id>                                  1/1     Running
aap-hub-content-<id>                              1/1     Running
aap-hub-worker-<id>                               1/1     Running
aap-eda-api-<id>                                  1/1     Running
aap-eda-worker-<id>                               1/1     Running
aap-eda-scheduler-<id>                            1/1     Running
```

### Access Platform Gateway

```bash
# Get gateway URL
GATEWAY_URL=$(oc get route -n ansible-automation-platform \
  -o jsonpath='{.items[?(@.metadata.labels.app\.kubernetes\.io/component=="platform-gateway")].spec.host}')

echo "Platform Gateway: https://$GATEWAY_URL"
```

**Expected UI sections:**

- **Overview/Dashboard**
- **Automation Execution** (Controller)
- **Automation Content** (Hub)
- **Automation Decisions** (EDA)
- **Access Management** (Users, Teams, RBAC)

### Verify Database Connectivity

Check each component successfully migrated its database:

```bash
# Gateway
oc logs -n ansible-automation-platform deployment/aap-platform-gateway | grep -i migration

# Controller
oc logs -n ansible-automation-platform deployment/aap-controller-web | grep -i migration

# Hub (check for hstore extension success)
oc logs -n ansible-automation-platform deployment/aap-hub-api | grep -i migration

# EDA
oc logs -n ansible-automation-platform deployment/aap-eda-api | grep -i migration
```

You should see successful migration logs, not connection errors.

### Verify Hub Storage

```bash
# Check PVC is bound with RWX access mode
oc get pvc -n ansible-automation-platform
```

**Expected:**

```
NAME                           STATUS   VOLUME        CAPACITY   ACCESS MODES   STORAGECLASS
aap-hub-file-storage           Bound    pvc-abc123    10Gi       RWX            ocs-storagecluster-cephfs
```

**Critical:** `ACCESS MODES` must show `RWX`. If it shows `RWO`, Hub will fail.

### Component Health Checks

**Controller:**

```bash
# Access via gateway, navigate to Automation Execution
# Run a test job template (or create a simple one)
```

**Hub:**

```bash
# Navigate to Automation Content → Collections
# Verify no "storage configuration error" messages
# (Collections list may be empty initially - that's fine)
```

**EDA:**

```bash
# Navigate to Automation Decisions → Projects
# Verify no database connection errors
# (Projects list may be empty initially - that's fine)
```

---

## Troubleshooting

### Hub Pod Stuck in Pending

**Symptom:**

```
aap-hub-api-<id>    0/1     Pending   0          5m
```

**Diagnosis:**

```bash
oc describe pvc -n ansible-automation-platform | grep -A 10 Events
```

**Common causes:**

- StorageClass does not support RWX
- StorageClass name typo in CR
- Storage provisioner not running
- Storage quota exceeded

**Fix:**

```bash
# Update to correct RWX StorageClass
oc patch ansibleautomationplatform aap -n ansible-automation-platform --type=merge \
  -p '{"spec":{"hub":{"file_storage_storage_class":"CORRECT_RWX_CLASS"}}}'
```

### Hub Migration Failure: hstore Extension Missing

**Symptom:**

```
oc logs deployment/aap-hub-api | tail
# Shows: ERROR: type "hstore" does not exist
```

**Diagnosis:**

```bash
# Check if hstore exists
oc exec -n edb-postgres -it postgresql-1 -- psql -U postgres -d automation_hub \
  -c "\dx" | grep hstore
```

**Fix:**

```bash
# Create hstore extension
oc exec -n edb-postgres -it postgresql-1 -- psql -U postgres -d automation_hub \
  -c "CREATE EXTENSION IF NOT EXISTS hstore;"

# Restart Hub pods to retry migrations
oc rollout restart deployment -n ansible-automation-platform -l app.kubernetes.io/component=hub
```

### EDA Cannot Trigger Controller Jobs

**Symptom:** Rulebook activations show "failed to call job template" errors.

**Diagnosis:**

```bash
# Check automation server URL configuration
oc get automationeda -n ansible-automation-platform -o yaml | grep automation_server_url
```

**Fix:**

The `automation_server_url` should be auto-configured via the platform gateway. If incorrect:

```yaml
eda:
  automation_server_url: https://<gateway-route>
  database:
    database_secret: external-postgres-configuration-eda
```

Alternatively, verify all routes are correct:

```bash
oc get routes -n ansible-automation-platform
```

### Database Connection Failures

**Symptom:** Pods crash with "could not connect to database" errors.

**Common causes:**

- Database secret incorrect or missing
- Database does not exist
- PostgreSQL service unreachable
- Wrong database name in secret

**Diagnosis:**

```bash
# Verify secrets exist
oc get secrets -n ansible-automation-platform | grep external-postgres

# Verify databases exist
oc exec -n edb-postgres -it postgresql-1 -- psql -U postgres -l | grep aap

# Test connection from AAP namespace
oc run -it --rm psql-test --image=registry.redhat.io/rhel8/postgresql-13 \
  -n ansible-automation-platform -- bash
# Inside pod: psql -h postgresql-rw.edb-postgres.svc.cluster.local -U aap -d automation_hub
```

**Fix:** Verify secret values match database configuration and recreate secrets if needed.

### Operator Not Creating Child CRs

**Symptom:** `AnsibleAutomationPlatform` exists but no `AutomationHub` or `AutomationEDA` CRs.

**Diagnosis:**

```bash
# Check operator logs
oc logs -n ansible-automation-platform deployment/automation-platform-operator-controller-manager -c manager

# Check parent CR status
oc get ansibleautomationplatform aap -n ansible-automation-platform -o yaml | grep -A 20 status
```

**Common causes:**

- Operator pod not healthy (restart it)
- CR validation failure (check `status.conditions` for errors)
- Missing required fields (e.g., Hub without storage class)

**Fix:** Address validation errors and ensure operator pod is running.

### Component Missing from Gateway UI

**Symptom:** Log into Gateway but Hub or EDA section is missing.

**Diagnosis:**

```bash
# Check if child CRs are ready
oc get automationhub,automationeda -n ansible-automation-platform

# Check CR status
oc get ansibleautomationplatform aap -n ansible-automation-platform -o jsonpath='{.status}' | jq
```

**Fix:** Ensure child CRs show "Running" or "Successful" status. If failing, check component pod logs.

---

## Scaling and Resources

### Resource Sizing Guidelines

| Deployment Size | Controller Task Replicas | EDA Workers | Hub Storage | Controller Memory |
|----------------|------------------------|-------------|-------------|-------------------|
| **Small** (< 100 jobs/day) | 2 | 2 | 10-20Gi | 4Gi |
| **Medium** (100-500 jobs/day) | 4 | 5 | 50-100Gi | 8Gi |
| **Large** (> 500 jobs/day) | 8+ | 10+ | 200Gi+ | 16Gi+ |

### Horizontal Scaling Example

```yaml
spec:
  controller:
    postgres_configuration_secret: external-postgres-configuration-controller
    replicas: 2          # Web UI pods (HA)
    task_replicas: 4     # Job executor pods (concurrency)
    
  hub:
    postgres_configuration_secret: external-postgres-configuration-hub
    storage_type: file
    file_storage_storage_class: ocs-storagecluster-cephfs
    file_storage_size: 50Gi
    replicas: 2          # Hub API pods (HA)
    
  eda:
    database:
      database_secret: external-postgres-configuration-eda
    replicas: 2          # EDA API pods (HA)
    worker_replicas: 5   # Event processing workers
```

### Resource Limits Example

```yaml
spec:
  controller:
    postgres_configuration_secret: external-postgres-configuration-controller
    web_resource_requirements:
      requests:
        cpu: "2000m"
        memory: "4Gi"
      limits:
        cpu: "4000m"
        memory: "8Gi"
    task_resource_requirements:
      requests:
        cpu: "1000m"
        memory: "2Gi"
      limits:
        cpu: "2000m"
        memory: "4Gi"
```

See [`ansibleautomationplatform-advanced.yaml`](../aap-deploy/openshift/ansibleautomationplatform-advanced.yaml) for complete examples.

### Hub Storage Expansion

```bash
# Check current usage
oc exec -n ansible-automation-platform deployment/aap-hub-api -- df -h /var/lib/pulp

# Expand PVC (if StorageClass supports volume expansion)
oc patch pvc aap-hub-file-storage -n ansible-automation-platform \
  -p '{"spec":{"resources":{"requests":{"storage":"50Gi"}}}}'
```

### Platform-Wide Idle Mode (DR Standby)

For DR standby sites, scale all components to zero while preserving configuration:

```yaml
spec:
  idle_aap: true  # Scales all components to zero replicas
```

Set to `false` to bring services back up.

---

## Summary

This deployment reference covers the deployment-specific details for AAP 2.6 on OpenShift with external EDB PostgreSQL:

**Key Points:**

1. Default deployment includes **all four components** (Gateway, Controller, Hub, EDA)
2. Uses **one PostgreSQL instance, four databases** for isolation
3. Hub **requires RWX storage** (critical deployment prerequisite)
4. Hub **requires hstore extension** on its database before migrations
5. All components share authentication via Platform Gateway
6. Typical deployment time: 8-12 minutes

**For detailed component capabilities, usage, and configuration options, see:**

- [Red Hat AAP 2.6 Documentation](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6)
- [Installing on OpenShift Container Platform](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html-single/installing_on_openshift_container_platform/index)

**Repository-specific deployment guides:**

- [AAP OpenShift Deployment](../aap-deploy/openshift/README.md) - Deployment procedures
- [Database Bootstrap SQL](../aap-deploy/edb-bootstrap/create-aap-databases.sql) - Database creation
- [Secret Generation Script](../aap-deploy/openshift/scripts/generate-postgres-secrets.sh) - Automated secrets
- [Advanced Configuration Example](../aap-deploy/openshift/ansibleautomationplatform-advanced.yaml) - HA and scaling options
