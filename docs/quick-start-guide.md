# Quick Start Guide

Get up and running with Ansible Automation Platform (AAP) and EDB PostgreSQL in 15-30 minutes.

## Table of Contents

- [Choose Your Path](#choose-your-path)
- [Prerequisites](#prerequisites)
- [Quick Start: OpenShift (15 minutes)](#quick-start-openshift-15-minutes)
- [Quick Start: RHEL with TPA (20 minutes)](#quick-start-rhel-with-tpa-20-minutes)
- [Quick Start: Local Testing with CRC (30 minutes)](#quick-start-local-testing-with-crc-30-minutes)
- [Verification Checklist](#verification-checklist)
- [Common Use Cases](#common-use-cases)
- [Next Steps](#next-steps)
- [Troubleshooting Quick Start Issues](#troubleshooting-quick-start-issues)

---

## Choose Your Path

| Deployment Target | Time | Best For | Guide |
|-------------------|------|----------|-------|
| **OpenShift cluster** | 15 min | Production, HA deployments | [OpenShift Quick Start](#quick-start-openshift-15-minutes) |
| **RHEL VMs/bare metal** | 20 min | Traditional infrastructure | [RHEL with TPA](#quick-start-rhel-with-tpa-20-minutes) |
| **Local laptop (CRC)** | 30 min | Testing, development, demos | [CRC Quick Start](#quick-start-local-testing-with-crc-30-minutes) |

**Not sure?**
- **Have OpenShift?** → Use OpenShift path
- **Have RHEL servers?** → Use TPA path
- **Just exploring?** → Use CRC path

---

## Prerequisites

### All Deployments

- `git` installed
- `oc` CLI (OpenShift) or `tpaexec` (RHEL) or `kubectl`
- Basic understanding of Kubernetes/OpenShift or Linux administration
- Access to container registry (or EDB subscription for private images)

### OpenShift Specific

```bash
# Required
oc version  # OpenShift CLI 4.12+
kubectl version  # Kubernetes CLI

# Cluster access
oc whoami  # Should show your username
oc project  # Should show current project

# Permissions needed
oc auth can-i create namespace  # Should return "yes"
oc auth can-i create subscription  # Should return "yes"
```

### RHEL Specific

```bash
# Required
python3 --version  # Python 3.6+
ansible --version  # Ansible 2.9+

# TPA installed
tpaexec --version

# SSH access to target hosts
ssh user@target-host  # Should connect without password (key-based auth)
```

### Storage Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| PostgreSQL data | 10 GiB | 50 GiB |
| PostgreSQL WAL | 5 GiB | 20 GiB |
| AAP file storage | 20 GiB | 100 GiB |
| Backup storage (S3) | 50 GiB | 500 GiB |

---

## Quick Start: OpenShift (15 minutes)

Deploy EDB PostgreSQL and AAP on OpenShift using Kustomize.

### Step 1: Clone Repository (1 minute)

```bash
git clone https://github.com/Red-Hat-EnterpriseDB-Testing/EDB_Testing.git
cd EDB_Testing
```

### Step 2: (Optional) Create EDB Registry Pull Secret

**Only required if using EDB subscription images from `docker.enterprisedb.com`**

```bash
# Create pull secret for EDB registry
oc create secret docker-registry edb-pull-secret \
  --docker-server=docker.enterprisedb.com \
  --docker-username='YOUR_EDB_SUBSCRIPTION_USER' \
  --docker-password='YOUR_EDB_TOKEN_OR_PASSWORD' \
  -n edb-postgres
```

**Note:** This quick start uses the community CloudNativePG operator image, so this step is optional. However, if you plan to use EDB PostgreSQL Advanced Server images (see [`db-deploy/sample-cluster/base/cluster-edb-registry.yaml`](../db-deploy/sample-cluster/base/cluster-edb-registry.yaml)), you'll need this pull secret.

### Step 3: Deploy EDB PostgreSQL Operator (2 minutes)

```bash
# Deploy CloudNativePG operator with server-side apply for large CRDs
oc apply --server-side --force-conflicts -k db-deploy/operator/

# Wait for operator to be ready
oc wait --for=condition=Ready pod \
  -l app.kubernetes.io/name=cloudnativepg \
  -n postgresql-operator-system \
  --timeout=120s
```

**Expected output:**
```text
namespace/postgresql-operator-system created
customresourcedefinition.apiextensions.k8s.io/clusters.postgresql.k8s.enterprisedb.io created
deployment.apps/postgresql-operator-controller-manager created
pod/postgresql-operator-controller-manager-xxxxxxxxx-xxxxx condition met
```

**Note:** The `--server-side --force-conflicts` flags are required because the CRDs are large and may exceed annotation size limits.

### Step 4: Deploy PostgreSQL Cluster (5 minutes)

```bash
# Create namespace and cluster
oc apply -k db-deploy/sample-cluster/

# Watch cluster creation
oc get clusters -n edb-postgres -w
```

**Wait for:**
```text
NAME         AGE   INSTANCES   READY   STATUS                     PRIMARY
postgresql   1m    2           0       Creating primary instance  postgresql-1
postgresql   2m    2           1       Cluster in healthy state   postgresql-1
postgresql   3m    2           2       Cluster in healthy state   postgresql-1
```

Press `Ctrl+C` when `READY` shows `2`.

### Step 5: Verify PostgreSQL (2 minutes)

```bash
# Check cluster status
oc describe cluster postgresql -n edb-postgres | grep -A 10 "Status:"

# Test database connection
oc exec -n edb-postgres postgresql-1 -- \
  psql -U postgres -c "SELECT version();"
```

**Expected:** PostgreSQL version output showing EDB PostgreSQL Advanced Server.

### Step 6: Deploy AAP (5 minutes)

```bash
# Set required environment variables
export AAP_DB_PASSWORD="$(openssl rand -base64 32)"
export HUB_STORAGE_CLASS="gp3-csi"  # Adjust for your cluster

# Bootstrap AAP databases
oc exec -n edb-postgres postgresql-1 -- \
  psql -U postgres < aap-deploy/edb-bootstrap/create-aap-databases.sql

# Deploy AAP operator and instance
cd aap-deploy/openshift
./scripts/deploy-aap-lab-external-pg.sh
```

**Wait for AAP pods to be ready** (~10 minutes):

```bash
oc get pods -n ansible-automation-platform -w
```

### Step 7: Access AAP (1 minute)

```bash
# Get AAP route
AAP_ROUTE=$(oc get route -n ansible-automation-platform \
  -o jsonpath='{.items[0].spec.host}')

echo "AAP URL: https://$AAP_ROUTE"

# Get admin password
AAP_PASSWORD=$(oc get secret aap-admin-password \
  -n ansible-automation-platform \
  -o jsonpath='{.data.password}' | base64 -d)

echo "Admin password: $AAP_PASSWORD"
```

**Open in browser:** `https://$AAP_ROUTE`

✅ **Done!** You now have AAP with external EDB PostgreSQL running on OpenShift.

---

## Quick Start: RHEL with TPA (20 minutes)

Deploy EDB PostgreSQL on RHEL using Trusted Postgres Architect (TPA).

### Step 1: Install TPA (5 minutes)

```bash
# Clone TPA repository
git clone https://github.com/EnterpriseDB/tpa.git
cd tpa

# Install TPA
sudo python3 setup.py install

# Verify installation
tpaexec --version
```

### Step 2: Create TPA Configuration (3 minutes)

```bash
# Create cluster configuration
tpaexec configure cluster-name \
  --architecture M1 \
  --platform bare \
  --postgres-flavour epas \
  --postgres-version 16 \
  --enable-replication \
  --location-names dc1 dc2

cd cluster-name
```

**Edit `config.yml`** to add your host IPs:

```yaml
cluster_vars:
  postgres_version: 16
  postgres_flavour: epas
  enable_pg_backup_api: true

locations:
  - Name: dc1
  - Name: dc2

instances:
  - Name: postgres-dc1-primary
    location: dc1
    role: primary
    node: 1
    vars:
      ansible_host: 192.168.1.10

  - Name: postgres-dc1-replica
    location: dc1
    role: replica
    upstream: postgres-dc1-primary
    node: 2
    vars:
      ansible_host: 192.168.1.11

  - Name: postgres-dc2-replica
    location: dc2
    role: replica
    upstream: postgres-dc1-primary
    node: 3
    vars:
      ansible_host: 192.168.2.10
```

### Step 3: Deploy with TPA (10 minutes)

```bash
# Provision infrastructure (configure OS, install packages)
tpaexec provision cluster-name

# Deploy PostgreSQL cluster
tpaexec deploy cluster-name

# Test deployment
tpaexec test cluster-name
```

### Step 4: Verify Deployment (2 minutes)

```bash
# Check cluster status
ssh postgres-dc1-primary "sudo -u postgres psql -c 'SELECT version();'"

# Check replication
ssh postgres-dc1-primary "sudo -u postgres psql -c 'SELECT * FROM pg_stat_replication;'"
```

**Expected:** 2 replication connections (DC1-replica and DC2-replica).

✅ **Done!** You now have a multi-datacenter PostgreSQL cluster on RHEL.

**Next:** Deploy AAP on RHEL following [docs/rhel-aap-architecture.md](rhel-aap-architecture.md).

---

## Quick Start: Local Testing with CRC (30 minutes)

Test the deployment locally using CodeReady Containers (CRC).

### Step 1: Install CRC (10 minutes)

```bash
# Download CRC from https://developers.redhat.com/products/codeready-containers

# Extract and install
tar -xvf crc-*.tar.xz
sudo cp crc /usr/local/bin/

# Setup CRC
crc setup

# Start CRC (requires 9GB RAM, 35GB disk)
crc start -p /path/to/pull-secret.txt

# Configure oc CLI
eval $(crc oc-env)
oc login -u kubeadmin https://api.crc.testing:6443
```

### Step 2: Increase CRC Resources (2 minutes)

```bash
# Stop CRC
crc stop

# Configure resources for AAP
crc config set cpus 6
crc config set memory 16384
crc config set disk-size 50

# Restart CRC
crc start
```

### Step 3: Deploy EDB PostgreSQL (5 minutes)

```bash
# Clone repository
git clone https://github.com/Red-Hat-EnterpriseDB-Testing/EDB_Testing.git
cd EDB_Testing

# Login to CRC
eval $(crc oc-env)
oc login -u kubeadmin https://api.crc.testing:6443

# (Optional) Create EDB pull secret if using EDB images
# oc create secret docker-registry edb-pull-secret \
#   --docker-server=docker.enterprisedb.com \
#   --docker-username='YOUR_EDB_SUBSCRIPTION_USER' \
#   --docker-password='YOUR_EDB_TOKEN_OR_PASSWORD' \
#   -n edb-postgres

# Deploy operator with server-side apply for large CRDs
oc apply --server-side --force-conflicts -k db-deploy/operator/

# Wait for operator
oc wait --for=condition=Ready pod \
  -l app.kubernetes.io/name=cloudnativepg \
  -n postgresql-operator-system \
  --timeout=300s

# Deploy cluster (use CRC storage class)
oc apply -k db-deploy/sample-cluster/
```

### Step 4: Deploy AAP (10 minutes)

```bash
# Set environment variables
export AAP_DB_PASSWORD="$(openssl rand -base64 32)"
export HUB_STORAGE_CLASS="crc-csi-hostpath-provisioner"

# Bootstrap databases
oc exec -n edb-postgres postgresql-1 -- \
  psql -U postgres < aap-deploy/edb-bootstrap/create-aap-databases.sql

# Deploy AAP
cd aap-deploy/openshift
./scripts/deploy-aap-lab-external-pg.sh
```

### Step 5: Access AAP (3 minutes)

```bash
# Wait for AAP to be ready
oc wait --for=condition=Ready pod \
  -l app.kubernetes.io/component=aap-controller \
  -n ansible-automation-platform \
  --timeout=600s

# Get AAP URL
crc console --credentials
# Note: AAP will be at a route in ansible-automation-platform namespace
```

✅ **Done!** You have a local test environment running.

**Note:** CRC limitations:
- Single-node cluster (no true HA)
- Limited to RWO storage (AAP Hub may have issues)
- Not suitable for performance testing
- Great for feature testing and development

---

## Verification Checklist

After deployment, verify everything is working:

### PostgreSQL Verification

```bash
# ✅ Check cluster health
oc get cluster postgresql -n edb-postgres
# Expected: STATUS = "Cluster in healthy state"

# ✅ Check pods are running
oc get pods -n edb-postgres
# Expected: 2 pods in Running state (1 primary + 1 replica)

# ✅ Test database connection
oc exec -n edb-postgres postgresql-1 -- \
  psql -U postgres -c "SELECT pg_is_in_recovery();"
# Expected: "f" on primary, "t" on replica

# ✅ Check replication lag
oc exec -n edb-postgres postgresql-1 -- \
  psql -U postgres -c "SELECT client_addr, state, sync_state, replay_lag
                        FROM pg_stat_replication;"
# Expected: 1 row showing active replication with low lag
```

### AAP Verification

```bash
# ✅ Check AAP pods
oc get pods -n ansible-automation-platform
# Expected: All pods in Running state
#   - aap-controller-* (3 replicas)
#   - aap-gateway-* (3 replicas)
#   - aap-hub-* (2 replicas)

# ✅ Test AAP API
AAP_ROUTE=$(oc get route -n ansible-automation-platform \
  -o jsonpath='{.items[0].spec.host}')
curl -k https://$AAP_ROUTE/api/v2/ping/
# Expected: {"version":"...", "active_node":"..."}

# ✅ Check AAP database connectivity
oc logs -n ansible-automation-platform -l app.kubernetes.io/component=aap-controller \
  --tail=50 | grep -i database
# Expected: No database connection errors

# ✅ Login to AAP web UI
# Open browser to https://$AAP_ROUTE
# Login with admin credentials
# Expected: AAP dashboard loads successfully
```

### Replication Verification (Multi-DC)

```bash
# ✅ Check replication status
oc exec -n edb-postgres postgresql-1 -- \
  psql -U postgres -c "
    SELECT application_name, client_addr, state, sync_state,
           pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes
    FROM pg_stat_replication;"

# Expected: Replication active with lag_bytes < 1MB

# ✅ Test failover readiness
oc get cluster postgresql -n edb-postgres -o yaml | grep -A 5 instances
# Expected: Shows primary + replicas ready
```

---

## Common Use Cases

### Use Case 1: Single Datacenter HA Deployment

**Goal:** High availability within one datacenter.

**Quick setup:**

```bash
# Deploy 1 primary + 2 replicas in same datacenter
oc apply -k db-deploy/sample-cluster/

# Verify HA
oc get pods -n edb-postgres
# Expected: 3 pods (1 primary + 2 replicas)
```

**Features:**
- Automatic failover within cluster
- ~30 second RTO for pod failures
- 0 RPO (synchronous replication)

### Use Case 2: Multi-Datacenter DR

**Goal:** Disaster recovery across two datacenters.

**Quick setup:**

```bash
# DC1: Deploy primary cluster
oc apply -k db-deploy/sample-cluster/

# DC2: Deploy replica cluster pointing to DC1
cd db-deploy/cross-cluster/replica-site
# Edit replica-cluster.template.yaml with DC1 details
oc apply -f replica-cluster.yaml
```

**Features:**
- Cross-datacenter async replication
- ~5 minute RTO for DC failover
- <5 second RPO

**See:** [docs/dr-scenarios.md](dr-scenarios.md) for failover procedures.

### Use Case 3: Development/Testing Environment

**Goal:** Quick environment for testing changes.

**Quick setup:**

```bash
# Use CRC or minikube
crc start

# Deploy minimal config (1 instance, no replicas)
oc apply -f db-deploy/sample-cluster/base/cluster.yaml

# Reduce AAP replicas for testing
# Edit aap-deploy/openshift/ansibleautomationplatform.yaml
# Set replicas to 1 for all components
oc apply -k aap-deploy/openshift/
```

**Features:**
- Minimal resource usage
- Fast deployment (<10 minutes)
- Good for CI/CD testing

### Use Case 4: Production with Backup

**Goal:** Production deployment with automated backups.

**Quick setup:**

```bash
# Create S3 bucket for backups
aws s3 mb s3://edb-backups-prod

# Create S3 credentials secret
oc create secret generic barman-s3-credentials \
  -n edb-postgres \
  --from-literal=ACCESS_KEY_ID=$AWS_ACCESS_KEY \
  --from-literal=SECRET_ACCESS_KEY=$AWS_SECRET_KEY

# Update cluster.yaml with backup config
# (See db-deploy/sample-cluster/base/cluster.yaml)
# Add backup section:
#   backup:
#     barmanObjectStore:
#       destinationPath: s3://edb-backups-prod/postgresql/
#       ...

# Deploy with backups
oc apply -k db-deploy/sample-cluster/
```

**Features:**
- Daily automated backups
- 30-day retention
- Point-in-time recovery (PITR)

**See:** [docs/dr-scenarios.md](dr-scenarios.md) for PITR procedures.

---

## Next Steps

After completing the quick start:

### 1. Configure Monitoring (Week 2 priority)

```bash
# Enable Prometheus monitoring
oc apply -f monitoring/prometheus/servicemonitor.yaml

# Import Grafana dashboards
# See: docs/monitoring-and-alerting-guide.md (coming soon)
```

### 2. Set Up Disaster Recovery Testing

```bash
# Schedule quarterly DR tests
oc apply -f openshift/dr-testing/cronjob-dr-test.yaml

# Run manual DR test
./scripts/dr-failover-test.sh --test-id manual-test-001
```

**See:** [docs/dr-testing-guide.md](dr-testing-guide.md)

### 3. Configure Backups

```bash
# Set up S3 backups
# See: docs/backup-and-restore-guide.md (coming soon)

# Test backup restore
./scripts/restore-point-in-time.sh --timestamp "2026-03-31 10:00:00"
```

### 4. Implement Security Hardening

- Enable TLS for PostgreSQL connections
- Configure RBAC policies
- Set up audit logging
- Implement network policies

**See:** [docs/security-hardening-guide.md](security-hardening-guide.md) (coming soon)

### 5. Scale for Production

**Horizontal scaling (OpenShift):**

```bash
# Edit cluster.yaml
spec:
  instances: 3  # Increase from 2 to 3

oc apply -k db-deploy/sample-cluster/
```

**Vertical scaling:**

```bash
# Edit cluster.yaml
spec:
  resources:
    requests:
      cpu: "2"
      memory: "4Gi"
    limits:
      cpu: "4"
      memory: "8Gi"
```

**See:** [docs/install-kubernetes-manual.md#scaling-considerations](install-kubernetes-manual.md#scaling-considerations)

### 6. Production Readiness Checklist

Before going to production, complete:

- [ ] Backups configured and tested
- [ ] Monitoring and alerting set up
- [ ] DR procedures documented and tested
- [ ] Security hardening applied
- [ ] Performance testing completed
- [ ] Runbooks created for operations team
- [ ] Access controls configured
- [ ] Network policies implemented
- [ ] Resource quotas and limits set
- [ ] Disaster recovery plan documented

---

## Troubleshooting Quick Start Issues

### PostgreSQL Cluster Won't Start

**Symptom:** Cluster stays in "Creating primary instance" state.

**Check:**

```bash
# Check pod events
oc describe pod postgresql-1 -n edb-postgres

# Check operator logs
oc logs -n postgresql-operator-system -l app.kubernetes.io/name=cloudnativepg --tail=100
```

**Common causes:**
- Insufficient storage available
- No default StorageClass configured
- Network policies blocking pod-to-pod communication

**Fix:**

```bash
# Check StorageClass
oc get storageclass
# Ensure one is marked as (default)

# If no default, set one:
oc patch storageclass gp3-csi -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### AAP Pods CrashLooping

**Symptom:** AAP pods restart repeatedly.

**Check:**

```bash
# Check pod logs
oc logs -n ansible-automation-platform -l app.kubernetes.io/component=aap-controller --tail=50

# Check events
oc get events -n ansible-automation-platform --sort-by='.lastTimestamp'
```

**Common causes:**
- Database not accessible
- Incorrect database credentials
- Insufficient resources

**Fix:**

```bash
# Verify database connectivity from AAP pod
oc exec -n ansible-automation-platform deployment/aap-controller -- \
  nc -zv postgresql-rw.edb-postgres.svc.cluster.local 5432

# Check secrets
oc get secret -n ansible-automation-platform | grep postgres

# Verify AAP database created
oc exec -n edb-postgres postgresql-1 -- \
  psql -U postgres -c "\l" | grep awx
```

### CRC Out of Resources

**Symptom:** Pods pending or evicted due to insufficient resources.

**Check:**

```bash
# Check node resources
oc describe node

# Check pod resource requests
oc get pods -A -o custom-columns=\
NAME:.metadata.name,\
CPU_REQ:.spec.containers[*].resources.requests.cpu,\
MEM_REQ:.spec.containers[*].resources.requests.memory
```

**Fix:**

```bash
# Stop CRC
crc stop

# Increase resources
crc config set cpus 8
crc config set memory 20480

# Restart
crc start
```

### Replication Not Working

**Symptom:** Replica not showing in `pg_stat_replication`.

**Check:**

```bash
# Check replica status
oc exec -n edb-postgres postgresql-2 -- \
  psql -U postgres -c "SELECT pg_is_in_recovery();"
# Expected: "t" (true)

# Check replica logs
oc logs -n edb-postgres postgresql-2 --tail=100 | grep -i replication
```

**Common causes:**
- Primary not accessible from replica
- Incorrect replication credentials
- Firewall blocking PostgreSQL port

**Fix:**

```bash
# Test connectivity from replica to primary
oc exec -n edb-postgres postgresql-2 -- \
  nc -zv postgresql-rw.edb-postgres.svc.cluster.local 5432

# Check replication user exists
oc exec -n edb-postgres postgresql-1 -- \
  psql -U postgres -c "SELECT * FROM pg_user WHERE usename = 'streaming_replica';"
```

### More Help

- **Troubleshooting Guide:** [docs/troubleshooting.md](troubleshooting.md)
- **Component Testing:** [docs/component-testing-results.md](component-testing-results.md)
- **GitHub Issues:** https://github.com/Red-Hat-EnterpriseDB-Testing/EDB_Testing/issues
- **Documentation Index:** [docs/INDEX.md](INDEX.md)

---

## Additional Resources

### Documentation

- **[Complete Documentation Index](INDEX.md)** - All documentation organized by topic
- **[Installation Guides](INDEX.md#installation-guides)** - Detailed installation procedures
- **[Architecture Documentation](INDEX.md#architecture-documentation)** - System design and components
- **[DR Testing Guide](dr-testing-guide.md)** - Disaster recovery procedures
- **[Troubleshooting](troubleshooting.md)** - Common issues and solutions

### External Resources

- **[EDB PostgreSQL Documentation](https://www.enterprisedb.com/docs/)** - Official EDB docs
- **[CloudNativePG Documentation](https://cloudnative-pg.io/)** - Operator documentation
- **[AAP Documentation](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/)** - Red Hat AAP docs
- **[OpenShift Documentation](https://docs.openshift.com/)** - OpenShift platform docs
- **[TPA Documentation](https://www.enterprisedb.com/docs/tpa/latest/)** - Trusted Postgres Architect

### Community

- **[EDB Community](https://www.enterprisedb.com/community)** - Forums and support
- **[CloudNativePG Slack](https://cloudnative-pg.io/community/)** - Operator community
- **[Ansible Community](https://www.ansible.com/community)** - AAP community resources

---

**Quick Start Complete!** 🎉

You now have a working AAP + EDB PostgreSQL deployment. Continue with [Next Steps](#next-steps) to
prepare for production use.
