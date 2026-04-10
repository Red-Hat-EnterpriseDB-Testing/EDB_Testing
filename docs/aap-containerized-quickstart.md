# AAP Containerized Multi-Datacenter Quick Start Guide
## Get Started with Ansible Automation Platform DR in 30 Minutes

**Last Updated:** 2026-03-31
**Estimated Time:** 30-60 minutes (planning and first deployment)

---

## Choose Your Deployment Model

First, select the right architecture for your needs:

### Decision Tree

```
Do you need production-grade component isolation?
│
├─ YES → Enterprise Topology (26 VMs)
│        • High-scale (>1000 jobs/hour)
│        • Full component separation
│        • Production-critical workloads
│
└─ NO → Growth Topology (16 VMs)
         • Cost-optimized deployment
         • Small-medium scale (<500 jobs/hour)
         • Faster deployment timeline
```

### Quick Comparison

| Question | Growth | Enterprise |
|----------|--------|------------|
| **Budget for infrastructure?** | Lower (16 VMs) | Higher (26 VMs) |
| **Expected automation jobs/hour?** | <500 | >1000 |
| **Component isolation required?** | No | Yes |
| **Time to deploy?** | 5-7 weeks | 7-12 weeks |
| **Operational complexity?** | Lower | Higher |

**Decision Made?**
- **Growth:** Continue to [Growth Deployment](#growth-topology-deployment)
- **Enterprise:** Continue to [Enterprise Deployment](#enterprise-topology-deployment)

---

## Prerequisites (Both Topologies)

### Infrastructure Requirements

- [ ] **2 datacenters** with network connectivity (VPN or Direct Connect)
- [ ] **RHEL 9.4+** subscription and installation media
- [ ] **EDB PostgreSQL Advanced** subscription and credentials
- [ ] **Red Hat AAP 2.6** subscription and credentials
- [ ] **Networking:**
  - Site-to-site connectivity (100 Mbps minimum, 1 Gbps recommended)
  - Latency < 100ms between datacenters
  - Public internet access for initial downloads (or offline installer)

### Access Requirements

- [ ] Root or sudo access on all VMs
- [ ] SSH key-based authentication configured
- [ ] DNS resolution for all hostnames
- [ ] Firewall rules can be modified
- [ ] Load balancer admin access (F5, HAProxy, or Route53)

### Credentials Checklist

- [ ] Red Hat subscription username/password
- [ ] EDB subscription credentials (docker.enterprisedb.com)
- [ ] PostgreSQL admin password (choose secure password)
- [ ] AAP admin passwords (must match between DC1 and DC2)
- [ ] Database passwords (must match between DC1 and DC2)

---

## Growth Topology Deployment

**Total Infrastructure:** 16 VMs (8 per datacenter)

### Step 1: Provision Infrastructure (Week 1)

**DC1 Virtual Machines:**

```text
AAP Layer (3 VMs):
  - aap-node1-dc1:  8 vCPU, 32GB RAM, 100GB disk  (10.1.1.11)
  - aap-node2-dc1:  8 vCPU, 32GB RAM, 100GB disk  (10.1.1.12)
  - aap-node3-dc1:  8 vCPU, 32GB RAM, 100GB disk  (10.1.1.13)

Database Layer (3 VMs):
  - pg-dc1-1:       8 vCPU, 32GB RAM, 500GB SSD   (10.1.2.21)
  - pg-dc1-2:       8 vCPU, 32GB RAM, 500GB SSD   (10.1.2.22)
  - pg-dc1-3:       8 vCPU, 32GB RAM, 500GB SSD   (10.1.2.23)

Infrastructure (2 VMs):
  - haproxy-dc1:    2 vCPU,  8GB RAM,  40GB disk  (10.1.1.10)
  - barman-dc1:     4 vCPU, 16GB RAM, 200GB disk  (10.1.2.30)
```

**DC2 Virtual Machines:** Same as DC1, with 10.2.x.x addresses

**Quick Provisioning (Example with VMware):**

```bash
# Export VM template variables
export TEMPLATE="rhel-9.4-template"
export DATACENTER="DC1"
export CLUSTER="Production"

# Provision AAP nodes
for i in {1..3}; do
  govc vm.clone -vm=$TEMPLATE -on=false \
    -c=8 -m=32768 -net="AAP-Network" \
    aap-node${i}-dc1
done

# Provision PostgreSQL nodes
for i in {1..3}; do
  govc vm.clone -vm=$TEMPLATE -on=false \
    -c=8 -m=32768 -net="Database-Network" \
    pg-dc1-${i}
  govc vm.disk.create -vm pg-dc1-${i} -size 500G
done

# Power on all VMs
govc vm.power -on aap-node*-dc1 pg-dc1-* haproxy-dc1 barman-dc1
```

### Step 2: Install PostgreSQL (Week 2)

**Download from [Growth Architecture - Phase 2](aap-containerized-growth-dr-architecture.md#phase-2-database-cluster-setup-week-2-3)**

**Quick Commands:**

```bash
# On all database nodes (pg-dc1-1, pg-dc1-2, pg-dc1-3)
# 1. Install EDB Postgres Advanced Server
sudo dnf install -y https://yum.enterprisedb.com/edbrepos/edb-repo-latest.noarch.rpm
sudo dnf -qy module disable postgresql
sudo EDB_SUBSCRIPTION_TOKEN='your-token' dnf install -y edb-as16-server

# 2. Initialize database (on pg-dc1-1 only)
sudo /usr/edb/as16/bin/edb-as-16-setup initdb

# 3. Create AAP databases
sudo -u enterprisedb psql <<EOF
CREATE DATABASE awx OWNER postgres;
CREATE DATABASE automationhub OWNER postgres;
CREATE DATABASE automationedacontroller OWNER postgres;
CREATE DATABASE automationgateway OWNER postgres;

\c automationhub
CREATE EXTENSION hstore;
EOF

# 4. Configure replication (pg-dc1-1)
sudo tee -a /var/lib/edb/as16/data/postgresql.conf <<EOF
listen_addresses = '*'
wal_level = replica
max_wal_senders = 10
max_replication_slots = 10
hot_standby = on
EOF

# 5. Start PostgreSQL
sudo systemctl enable --now edb-as-16

# 6. Create standbys (pg-dc1-2, pg-dc1-3)
sudo -u enterprisedb pg_basebackup -h pg-dc1-1 -U replicator \
  -D /var/lib/edb/as16/data -P -Xs -R
```

**Verify:**
```bash
# Check replication
sudo -u enterprisedb psql -c "SELECT * FROM pg_stat_replication;"
```

### Step 3: Install AAP (Week 3-4)

**Download AAP Containerized Installer:**

```bash
# On aap-node1-dc1
cd /opt
curl -O https://access.redhat.com/downloads/ansible-automation-platform-containerized-setup-2.6-1.tar.gz
tar -xzf ansible-automation-platform-containerized-setup-2.6-1.tar.gz
cd ansible-automation-platform-containerized-setup-2.6-1
```

**Create Inventory File:**

```bash
cat > inventory <<'EOF'
# Platform Gateway
[automationgateway]
aap-node1-dc1.example.com

# Automation Controller
[automationcontroller]
aap-node1-dc1.example.com
aap-node2-dc1.example.com
aap-node3-dc1.example.com

# Automation Hub
[automationhub]
aap-node1-dc1.example.com
aap-node2-dc1.example.com

# Event-Driven Ansible
[automationeda]
aap-node1-dc1.example.com
aap-node3-dc1.example.com

# Redis
[redis]
aap-node1-dc1.example.com
aap-node2-dc1.example.com
aap-node3-dc1.example.com

[all:vars]
postgresql_admin_username=postgres
postgresql_admin_password='YourSecurePassword'
registry_username='your-rhn-username'
registry_password='your-rhn-password'
redis_mode='standalone'

gateway_admin_password='AdminPassword123'
gateway_pg_host='10.1.2.100'
gateway_pg_database='automationgateway'
gateway_pg_username='postgres'
gateway_pg_password='YourSecurePassword'

controller_admin_password='AdminPassword123'
controller_pg_host='10.1.2.100'
controller_pg_database='awx'
controller_pg_username='postgres'
controller_pg_password='YourSecurePassword'

hub_admin_password='AdminPassword123'
hub_pg_host='10.1.2.100'
hub_pg_database='automationhub'
hub_pg_username='postgres'
hub_pg_password='YourSecurePassword'

eda_admin_password='AdminPassword123'
eda_pg_host='10.1.2.100'
eda_pg_database='automationedacontroller'
eda_pg_username='postgres'
eda_pg_password='YourSecurePassword'
EOF
```

**Install AAP:**

```bash
./setup.sh
```

**Verify Installation:**

```bash
# Check all containers are running
podman ps --format "table {{.Names}}\t{{.Status}}"

# Test API
curl -k https://localhost/api/v2/ping/
```

### Step 4: Configure DR (Week 5)

1. **Install EFM** on all database nodes
2. **Configure cross-DC replication** (pg-dc1-1 → pg-dc2-1)
3. **Install AAP on DC2** (same as DC1)
4. **Stop DC2 containers** (standby mode)
5. **Configure Global Load Balancer**
6. **Test failover**

**See Full Instructions:** [Growth Architecture - Phase 4](aap-containerized-growth-dr-architecture.md#phase-4-integration-and-testing-week-6-7)

### Step 5: Verify and Test (Week 6-7)

```bash
# Test manual failover
./scripts/manual-failover-dc2.sh

# Verify AAP accessible from DC2
curl -k https://aap.example.com/api/v2/ping/

# Test failback
./scripts/manual-failback-dc1.sh

# Measure RTO/RPO
./scripts/measure-rto-rpo.sh
```

---

## Enterprise Topology Deployment

**Total Infrastructure:** 26 VMs (13 per datacenter)

### Step 1: Provision Infrastructure (Week 1-2)

**DC1 Virtual Machines:**

```text
AAP Component Layer (8 VMs):
  Gateway:
    - gateway1-dc1:       4 vCPU, 16GB RAM, 60GB disk  (10.1.1.11)
    - gateway2-dc1:       4 vCPU, 16GB RAM, 60GB disk  (10.1.1.12)

  Controller:
    - controller1-dc1:    4 vCPU, 16GB RAM, 60GB disk  (10.1.1.13)
    - controller2-dc1:    4 vCPU, 16GB RAM, 60GB disk  (10.1.1.14)

  Hub:
    - hub1-dc1:           4 vCPU, 16GB RAM, 60GB disk  (10.1.1.15)
    - hub2-dc1:           4 vCPU, 16GB RAM, 60GB disk  (10.1.1.16)

  EDA:
    - eda1-dc1:           4 vCPU, 16GB RAM, 60GB disk  (10.1.1.17)
    - eda2-dc1:           4 vCPU, 16GB RAM, 60GB disk  (10.1.1.18)

Database Layer (3 VMs):
  - pg-dc1-1:             8 vCPU, 32GB RAM, 500GB SSD  (10.1.2.21)
  - pg-dc1-2:             8 vCPU, 32GB RAM, 500GB SSD  (10.1.2.22)
  - pg-dc1-3:             8 vCPU, 32GB RAM, 500GB SSD  (10.1.2.23)

Infrastructure (2 VMs):
  - haproxy-dc1:          2 vCPU,  8GB RAM,  40GB disk (10.1.1.10)
  - barman-dc1:           4 vCPU, 16GB RAM, 200GB disk (10.1.2.30)
```

**DC2 Virtual Machines:** Same as DC1, with 10.2.x.x addresses

### Step 2: Install PostgreSQL (Week 3-4)

**Same as Growth Topology** - See [Step 2 above](#step-2-install-postgresql-week-2)

### Step 3: Install AAP (Week 5-6)

**Key Difference:** Components installed on dedicated VMs

**Create Inventory File:**

```bash
cat > inventory <<'EOF'
# Platform Gateway (dedicated VMs with Redis)
[automationgateway]
gateway1-dc1.example.com
gateway2-dc1.example.com

# Automation Controller (dedicated VMs)
[automationcontroller]
controller1-dc1.example.com
controller2-dc1.example.com

# Automation Hub (dedicated VMs with Redis)
[automationhub]
hub1-dc1.example.com
hub2-dc1.example.com

# Event-Driven Ansible (dedicated VMs with Redis)
[automationeda]
eda1-dc1.example.com
eda2-dc1.example.com

# Redis (colocated on gateway, hub, EDA)
[redis]
gateway1-dc1.example.com
gateway2-dc1.example.com
hub1-dc1.example.com
hub2-dc1.example.com
eda1-dc1.example.com
eda2-dc1.example.com

[all:vars]
# ... same variables as Growth topology ...
EOF
```

**Install AAP:**

```bash
./setup.sh
```

### Step 4: Configure DR (Week 7-8)

**Same process as Growth Topology** - See [Growth Step 4](#step-4-configure-dr-week-5)

### Step 5: Verify and Test (Week 9-10)

**Same process as Growth Topology** - See [Growth Step 5](#step-5-verify-and-test-week-6-7)

---

## Post-Deployment Tasks

### Configure Monitoring

```bash
# Install Prometheus exporters
sudo dnf install -y postgres_exporter node_exporter

# Configure Grafana dashboards
# Import dashboard from monitoring/grafana-dashboards/dr-overview.json
```

### Schedule DR Testing

```bash
# Add to crontab for quarterly testing
0 2 * * 6 /path/to/scripts/dr-failover-test.sh quarterly-$(date +%Y-Q%q)
```

### Document Your Deployment

Create a deployment-specific document:

```bash
cat > DEPLOYMENT.md <<EOF
# AAP Deployment Details

**Deployment Date:** $(date +%Y-%m-%d)
**Topology:** [Growth/Enterprise]
**Total VMs:** [16/26]

## Access Information

- **AAP URL:** https://aap.example.com
- **DC1 HAProxy:** https://10.1.1.100
- **DC2 HAProxy:** https://10.2.1.100

## Admin Contacts

- Primary SRE: [name] <email>
- Database DBA: [name] <email>
- Network Admin: [name] <email>

## Emergency Procedures

- DR Failover: See [DR Testing Guide](docs/dr-testing-guide.md)
- Support Escalation: [ticket system URL]
EOF
```

---

## Troubleshooting

### Issue: AAP Installation Fails

**Symptom:** `./setup.sh` exits with error

**Solutions:**

1. **Check database connectivity:**
   ```bash
   psql -h 10.1.2.100 -U postgres -d awx -c "SELECT version();"
   ```

2. **Verify Red Hat registry credentials:**
   ```bash
   podman login registry.redhat.io -u 'your-username'
   ```

3. **Check disk space:**
   ```bash
   df -h /var/lib/containers
   ```

### Issue: Containers Won't Start

**Symptom:** `systemctl start automation-*` fails

**Solutions:**

1. **Check logs:**
   ```bash
   journalctl -u automation-controller-web -n 50
   ```

2. **Verify SELinux:**
   ```bash
   sestatus
   # If issues, set to permissive temporarily
   sudo setenforce 0
   ```

3. **Check PostgreSQL connection:**
   ```bash
   podman exec -it automation-controller-web \
     awx-manage check_db
   ```

### Issue: Replication Lag High

**Symptom:** `pg_stat_replication` shows lag > 60s

**Solutions:**

1. **Check network bandwidth:**
   ```bash
   iperf3 -c pg-dc2-1
   ```

2. **Verify WAL settings:**
   ```bash
   psql -c "SHOW wal_keep_size;"
   ```

3. **Check replication slot:**
   ```bash
   psql -c "SELECT * FROM pg_replication_slots;"
   ```

---

## Next Steps

### After Successful Deployment

1. ✅ **Review Documentation:**
   - [DR Scenarios](dr-scenarios.md) - Understand failure modes
   - [DR Testing Guide](dr-testing-guide.md) - Schedule quarterly tests
   - [Operations Runbook](manual-scripts-doc.md) - Day-to-day procedures

2. ✅ **Configure Automation:**
   - Set up monitoring alerts
   - Configure backup schedules
   - Create job templates in AAP

3. ✅ **Plan First DR Test:**
   - Schedule maintenance window
   - Notify stakeholders
   - Execute test failover
   - Document results

4. ✅ **Optimize:**
   - Tune PostgreSQL based on workload
   - Adjust AAP resource limits
   - Review and update runbooks

### Training Resources

- [AAP 2.6 Documentation](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/)
- [EDB Postgres Advanced](https://www.enterprisedb.com/docs/epas/latest/)
- [EDB Failover Manager](enterprisefailovermanager.md)

---

## Support and Feedback

### Getting Help

- **GitHub Issues:** [EDB_Testing Issues](https://github.com/Red-Hat-EnterpriseDB-Testing/EDB_Testing/issues)
- **Red Hat Support:** Open case via Red Hat Customer Portal
- **EDB Support:** support@enterprisedb.com

### Contributing

Found an issue or have improvements? Submit a PR!

```bash
git checkout -b docs/quickstart-improvements
# Make your changes
git commit -m "docs: Improve quickstart guide"
git push -u origin docs/quickstart-improvements
gh pr create
```

---

## Quick Reference Card

### Essential Commands

```bash
# Check AAP status
curl -k https://aap.example.com/api/v2/ping/

# Check database replication
psql -h 10.1.2.100 -U postgres -c "SELECT * FROM pg_stat_replication;"

# Check EFM cluster status
sudo /usr/edb/efm-4.7/bin/efm cluster-status efm-cluster

# Manual failover to DC2
sudo /usr/edb/efm-4.7/bin/efm promote efm-cluster -switchover

# Start AAP containers (DC2 after failover)
for node in aap-node{1..3}-dc2; do
  ssh $node "systemctl start automation-*"
done
```

### Important Files

```text
/opt/aap/inventory                          # AAP installer inventory
/var/lib/edb/as16/data/postgresql.conf     # PostgreSQL config
/etc/edb/efm-4.7/efm.properties            # EFM config
/etc/haproxy/haproxy.cfg                   # Load balancer config
```

---

## Architecture Reference

**Full Documentation:**
- **Growth (16 VMs):** [aap-containerized-growth-dr-architecture.md](aap-containerized-growth-dr-architecture.md)
- **Enterprise (26 VMs):** [aap-containerized-enterprise-dr-architecture.md](aap-containerized-enterprise-dr-architecture.md)
- **Validation Report:** [aap-architecture-validation-report.md](../reports/aap-architecture-validation-report.md)

---

**Document Version:** 1.0
**Last Updated:** 2026-03-31
**Estimated Completion Time:** 30-60 minutes (planning), 5-12 weeks (full deployment)

🚀 Ready to deploy? Start with [Prerequisites](#prerequisites-both-topologies)!
