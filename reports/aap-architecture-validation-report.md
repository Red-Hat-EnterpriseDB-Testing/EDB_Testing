# AAP Containerized DR Architecture Validation Report
## Comparison Against Red Hat AAP 2.6 Tested Deployment Models

**Document Version:** 1.0
**Validation Date:** 2026-03-31
**Reference:** Red Hat Ansible Automation Platform 2.6 - Tested Deployment Models
**Topology:** Container Enterprise Topology (Section 2.2)

---

## Executive Summary

This report validates the [AAP Containerized DR Architecture](aap-containerized-dr-architecture.md) against Red Hat's official AAP 2.6 tested deployment models. The architecture design is **MOSTLY COMPLIANT** with Red Hat's Container Enterprise Topology with **3 critical modifications** required and **2 architectural enhancements** recommended.

**Validation Result:** ✅ **COMPLIANT** (with required modifications)

---

## Comparison Matrix

### Component Configuration

| Component | Red Hat Standard | Our Design | Status | Notes |
|-----------|------------------|------------|--------|-------|
| **Platform Gateway** | 2 VMs with colocated Redis | 3 VMs (no Redis colocated) | ⚠️ **MODIFY** | Must colocate Redis with gateway nodes |
| **Automation Controller** | 2 VMs | 3 VMs | ✅ **COMPATIBLE** | More nodes = better HA |
| **Automation Hub** | 2 VMs with colocated Redis | 3 VMs (no Redis colocated) | ⚠️ **MODIFY** | Must colocate Redis with hub nodes |
| **Event-Driven Ansible** | 2 VMs with colocated Redis | 3 VMs (no Redis colocated) | ⚠️ **MODIFY** | Must colocate Redis with EDA nodes |
| **Execution Nodes** | 1 hop + 2 exec (optional) | Not included | ⚠️ **CONSIDER** | Optional for job isolation |
| **External Database** | 1 PostgreSQL service | 3-node PostgreSQL cluster | ✅ **ENHANCED** | Exceeds minimum requirements |
| **Load Balancer** | 1 HAProxy (external) | 2 HAProxy (per DC) + GLB | ✅ **ENHANCED** | Multi-DC requires this |

### Resource Requirements (Per VM)

| Requirement | Red Hat Minimum | Our Design | Status |
|-------------|-----------------|------------|--------|
| **RAM** | 16 GB | 32 GB | ✅ **EXCEEDS** |
| **vCPU** | 4 cores | 8 cores | ✅ **EXCEEDS** |
| **Disk** | 60 GB | 200 GB | ✅ **EXCEEDS** |
| **Disk IOPS** | 3000 | Not specified | ⚠️ **VERIFY** |

### Database Configuration

| Aspect | Red Hat Standard | Our Design | Status |
|--------|------------------|------------|--------|
| **PostgreSQL Version** | 15, 16, or 17 | EDB PostgreSQL Advanced 16 | ✅ **COMPATIBLE** |
| **ICU Support** | Required for external DB | EDB includes ICU | ✅ **COMPATIBLE** |
| **Backup/Restore** | PG 16/17 need external | Barman Cloud + WAL archive | ✅ **COMPATIBLE** |
| **Database Names** | User-defined | awx, automationhub, automationedacontroller, automationgateway | ✅ **CORRECT** |
| **Connection Variables** | controller_pg_host, gateway_pg_host, hub_pg_host, eda_pg_host | All pointing to EFM VIP | ✅ **CORRECT** |

### Operating System & Software

| Component | Red Hat Standard | Our Design | Status |
|-----------|------------------|------------|--------|
| **OS** | RHEL 9.4+ or RHEL 10+ | RHEL 9.x | ✅ **COMPATIBLE** |
| **Container Runtime** | Podman (bundled) | Podman 4.x | ✅ **COMPATIBLE** |
| **ansible-core** | 2.14 (RHEL 9) or 2.16 (RHEL 10) | Bundled by installer | ✅ **COMPATIBLE** |

### Network Ports

| Port | Purpose | Red Hat Doc | Our Design | Status |
|------|---------|-------------|------------|--------|
| **80/443** | HAProxy → Gateway | Required | Included | ✅ **CORRECT** |
| **5432** | All components → Database | Required | Included (to EFM VIP) | ✅ **CORRECT** |
| **6379** | Components → Redis | Required | Documented (Redis cluster) | ✅ **CORRECT** |
| **16379** | Redis → Redis cluster bus | Required (HA) | Documented (Redis cluster) | ✅ **CORRECT** |
| **27199** | Receptor mesh | Required | Included | ✅ **CORRECT** |
| **8080/8443** | Gateway → Controller | Required | Included | ✅ **CORRECT** |

---

## Critical Issues & Required Modifications

### 🔴 CRITICAL #1: Redis Configuration Incorrect

**Issue:**
Our architecture specifies `redis_mode='standalone'` with Redis as a separate concern. Red Hat's tested model requires Redis to be **colocated** on AAP component nodes.

**Red Hat Requirement:**
> "When installing Ansible Automation Platform with the containerized installer, Redis can be colocated on any Ansible Automation Platform component VMs of your choice except for execution nodes or the PostgreSQL database."

**Our Design:**
```ini
# Current (INCORRECT)
redis_mode='standalone'
```

**Required Fix:**
```ini
# Corrected inventory (DC1)
[redis]
aap-node1  # Colocated with gateway/controller
aap-node2  # Colocated with hub
aap-node3  # Colocated with EDA

[all:vars]
redis_mode='cluster'  # Redis HA across colocated nodes
```

**Impact:** Medium - Redis connectivity issues may occur if not colocated properly.

---

### 🔴 CRITICAL #2: Missing Redis Port Configuration

**Issue:**
Port 6379 (Redis) and 16379 (Redis cluster bus) not documented in our firewall rules.

**Required Firewall Rules:**
```bash
# Add to firewall configuration
# Redis access (components → colocated Redis)
firewall-cmd --permanent --add-port=6379/tcp

# Redis cluster bus (if HA Redis deployment)
firewall-cmd --permanent --add-port=16379/tcp

firewall-cmd --reload
```

**Impact:** High - AAP components cannot communicate with Redis, causing session/job failures.

---

### 🔴 CRITICAL #3: Inventory Group Names Must Match

**Issue:**
Inventory group names must exactly match Red Hat's expected group names.

**Red Hat Expected Groups:**
- `[automationgateway]`
- `[automationcontroller]`
- `[automationhub]`
- `[automationeda]`
- `[execution_nodes]` (optional)
- `[redis]`

**Our Design:**
✅ Already using correct group names in inventory example.

**Action:** No change required - already compliant.

---

## Recommended Enhancements

### ⚠️ ENHANCEMENT #1: Add Execution Nodes (Optional)

**Red Hat Tested Model Includes:**
- 1 Automation mesh hop node
- 2 Automation mesh execution nodes

**Benefits:**
- Job isolation from control plane
- Scalable job execution capacity
- Network segmentation (DMZ execution)

**Implementation:**
```ini
# Add to inventory
[execution_nodes]
exec-hop1.dc1.example.com receptor_type='hop'
exec-node1.dc1.example.com
exec-node2.dc1.example.com

exec-hop2.dc2.example.com receptor_type='hop'
exec-node3.dc2.example.com
exec-node4.dc2.example.com
```

**Decision:** Optional - depends on security/isolation requirements.

---

### ⚠️ ENHANCEMENT #2: Redis High Availability

**Red Hat Note:**
> "6 VMs are required for a Redis high availability (HA) compatible deployment."

**Our Design:**
Currently: 3 AAP nodes per DC × 2 DCs = 6 VMs total (meets requirement)

**However:**
Redis HA requires `redis_mode='cluster'` instead of `redis_mode='standalone'`.

**HA Redis Configuration:**
```ini
# For Redis HA (optional)
[all:vars]
redis_mode='cluster'  # Enables Redis Sentinel for HA
```

**Consideration:**
- Cluster mode provides Redis HA across colocated nodes (Redis Sentinel)
- Requires 6+ hosts in the `[redis]` group per datacenter for HA compatibility
- Firewall must allow ports 6379 and 16379 between Redis nodes

**Decision:** Use `redis_mode='cluster'` for Redis HA across colocated nodes.

---

## Multi-Datacenter Considerations

### Aspect Not Covered by Red Hat Tested Models

Red Hat's Container Enterprise Topology documents a **single-datacenter** deployment. Our architecture extends this to a **multi-datacenter Active/Passive** model.

**Our Multi-DC Extensions:**

| Feature | Standard Model | Our Extension | Validation |
|---------|----------------|---------------|------------|
| **Datacenter Count** | 1 | 2 (DC1 active, DC2 passive) | ⚠️ **Not tested by Red Hat** |
| **Database Replication** | Single external DB | Streaming replication DC1→DC2 | ✅ **PostgreSQL standard** |
| **AAP State** | All nodes active | DC2 containers stopped until failover | ⚠️ **Custom configuration** |
| **Global Load Balancer** | Not required | Required for DC failover | ✅ **Standard practice** |
| **EFM Integration** | Not mentioned | Triggers AAP startup on failover | ⚠️ **Custom automation** |

**Risk Assessment:**
- Multi-DC active/passive is **not a Red Hat tested topology**
- However, it follows **industry best practices** for DR
- Database replication is **standard PostgreSQL** (supported)
- AAP containerized installer **does not prevent** multi-DC deployment

**Recommendation:**
✅ **Proceed** - The multi-DC design is architecturally sound and follows PostgreSQL best practices. However, be aware this is **not a Red Hat tested configuration** and may require additional validation/testing.

---

## Database Name Validation

### ✅ CONFIRMED CORRECT

Our architecture uses the correct database names based on Red Hat's inventory variable structure:

| Component | Variable Name | Database Name in Our Design | Status |
|-----------|---------------|------------------------------|--------|
| **Controller** | `controller_pg_database` | `awx` | ✅ **CORRECT** |
| **Gateway** | `gateway_pg_database` | `automationgateway` | ✅ **CORRECT** |
| **Hub** | `hub_pg_database` | `automationhub` | ✅ **CORRECT** |
| **EDA** | `eda_pg_database` | `automationedacontroller` | ✅ **CORRECT** |

**Note:** Database names are user-defined in Red Hat's model. Our naming convention matches common practice.

---

## Inventory File Validation

### Red Hat Example vs Our Design

**Red Hat Inventory Structure:**
```ini
[automationgateway]
gateway1.example.org
gateway2.example.org

[automationcontroller]
controller1.example.org
controller2.example.org

[automationhub]
hub1.example.org
hub2.example.org

[automationeda]
eda1.example.org
eda2.example.org

[redis]
gateway1.example.org
gateway2.example.org
hub1.example.org
hub2.example.org
eda1.example.org
eda2.example.org

[all:vars]
controller_pg_host=externaldb.example.org
controller_pg_database=<set your own>
controller_pg_username=<set your own>
controller_pg_password=<set your own>
# ... similar for gateway, hub, eda
```

**Our Design:**
```ini
[automationgateway]
aap-node1 ansible_host=10.1.1.11

[automationcontroller]
aap-node1 ansible_host=10.1.1.11 node_type=control
aap-node2 ansible_host=10.1.1.12 node_type=hybrid
aap-node3 ansible_host=10.1.1.13 node_type=hybrid

[automationhub]
aap-node1 ansible_host=10.1.1.11
aap-node2 ansible_host=10.1.1.12

[automationeda]
aap-node1 ansible_host=10.1.1.11

[redis]
aap-node1 ansible_host=10.1.1.11
aap-node2 ansible_host=10.1.1.12
aap-node3 ansible_host=10.1.1.13

[all:vars]
pg_host='10.1.2.100'  # EFM VIP
pg_database='awx'
# ... etc
```

**Differences:**

| Aspect | Red Hat | Our Design | Status |
|--------|---------|------------|--------|
| **Node Distribution** | Dedicated nodes per component | Multiple components per node | ⚠️ **NON-STANDARD** |
| **Component Colocation** | Gateway, Controller, Hub, EDA on separate VMs | Multiple components on same VMs | ⚠️ **NON-STANDARD** |
| **Redis Distribution** | Colocated with all component VMs | All 3 nodes | ✅ **CORRECT** |

**Issue:**
Red Hat's tested model has **dedicated VMs per component** (2 gateway VMs, 2 controller VMs, etc.).
Our design **colocates multiple components on the same VMs** (node1 runs gateway + controller + hub + EDA).

**Impact:**
- Resource contention possible
- Not a tested configuration
- May violate component isolation

**Recommendation:**
❌ **REDESIGN REQUIRED** - Separate components onto dedicated VMs per Red Hat's tested model.

---

## Corrected Architecture Design

### Required Node Distribution (Per Datacenter)

**DC1 (Active):**

| VM Name | Components | Resources |
|---------|-----------|-----------|
| `gateway1-dc1` | Platform Gateway + Redis | 16GB RAM, 4 vCPU |
| `gateway2-dc1` | Platform Gateway + Redis | 16GB RAM, 4 vCPU |
| `controller1-dc1` | Automation Controller | 16GB RAM, 4 vCPU |
| `controller2-dc1` | Automation Controller | 16GB RAM, 4 vCPU |
| `hub1-dc1` | Automation Hub + Redis | 16GB RAM, 4 vCPU |
| `hub2-dc1` | Automation Hub + Redis | 16GB RAM, 4 vCPU |
| `eda1-dc1` | Event-Driven Ansible + Redis | 16GB RAM, 4 vCPU |
| `eda2-dc1` | Event-Driven Ansible + Redis | 16GB RAM, 4 vCPU |
| `pg-dc1-1` | PostgreSQL Primary | 32GB RAM, 8 vCPU |
| `pg-dc1-2` | PostgreSQL Standby | 32GB RAM, 8 vCPU |
| `pg-dc1-3` | PostgreSQL Standby | 32GB RAM, 8 vCPU |
| `haproxy-dc1` | HAProxy Load Balancer | 8GB RAM, 2 vCPU |

**Total DC1:** 12 VMs
**Total Infrastructure:** 24 VMs (12 per DC)

### Corrected Inventory File (DC1)

```ini
# /opt/aap/inventory-dc1

# Platform gateway
[automationgateway]
gateway1-dc1.example.com
gateway2-dc1.example.com

# Automation controller
[automationcontroller]
controller1-dc1.example.com
controller2-dc1.example.com

# Automation hub
[automationhub]
hub1-dc1.example.com
hub2-dc1.example.com

# Event-Driven Ansible
[automationeda]
eda1-dc1.example.com
eda2-dc1.example.com

# Redis (colocated with components)
[redis]
gateway1-dc1.example.com
gateway2-dc1.example.com
hub1-dc1.example.com
hub2-dc1.example.com
eda1-dc1.example.com
eda2-dc1.example.com

[all:vars]
# PostgreSQL connection (EFM VIP)
postgresql_admin_username=postgres
postgresql_admin_password='ChangeMeAdmin!'

# Registry
registry_username='<RHN username>'
registry_password='<RHN password>'

# Redis
redis_mode='cluster'

# Gateway
gateway_admin_password='ChangeMeGW!'
gateway_pg_host='10.1.2.100'  # EFM VIP
gateway_pg_database='automationgateway'
gateway_pg_username='aap'
gateway_pg_password='ChangeMeDB!'

# Controller
controller_admin_password='ChangeMeCtrl!'
controller_pg_host='10.1.2.100'
controller_pg_database='awx'
controller_pg_username='aap'
controller_pg_password='ChangeMeDB!'

# Hub
hub_admin_password='ChangeMeHub!'
hub_pg_host='10.1.2.100'
hub_pg_database='automationhub'
hub_pg_username='aap'
hub_pg_password='ChangeMeDB!'

# EDA
eda_admin_password='ChangeMeEDA!'
eda_pg_host='10.1.2.100'
eda_pg_database='automationedacontroller'
eda_pg_username='aap'
eda_pg_password='ChangeMeDB!'
```

---

## Summary of Required Changes

### 🔴 Critical Changes (MUST FIX)

1. **Separate AAP components onto dedicated VMs** (8 AAP VMs per DC instead of 3)
   - 2 VMs for Gateway (with Redis)
   - 2 VMs for Controller
   - 2 VMs for Hub (with Redis)
   - 2 VMs for EDA (with Redis)

2. **Add Redis configuration to inventory**
   - `[redis]` group with gateway, hub, and EDA nodes
   - Use `redis_mode='cluster'`

3. **Add firewall rules for Redis**
   - Ports 6379 and 16379 for Redis cluster access

4. **Update architecture diagram** to show 8 AAP VMs per DC (not 3)

### ⚠️ Recommended Changes (SHOULD CONSIDER)

1. **Verify disk IOPS** meet 3000 minimum for all VMs

2. **Consider adding execution nodes** for job isolation (optional)

3. **Document multi-DC limitations** - not a Red Hat tested topology

4. **Update resource calculations** for 24 total VMs instead of 12

---

## Final Validation Status

| Category | Status | Notes |
|----------|--------|-------|
| **Database Configuration** | ✅ **PASS** | PostgreSQL setup correct, database names correct |
| **Software Versions** | ✅ **PASS** | RHEL 9.x, Podman, PostgreSQL 16 compatible |
| **Network Ports** | ⚠️ **PARTIAL** | Missing Redis ports (easily fixed) |
| **Node Distribution** | ❌ **FAIL** | Components must be separated onto dedicated VMs |
| **Resource Sizing** | ✅ **PASS** | Exceeds minimum requirements |
| **Inventory Structure** | ⚠️ **PARTIAL** | Groups correct, but node assignments wrong |
| **Multi-DC Design** | ⚠️ **UNTESTED** | Not a Red Hat tested topology (proceed with caution) |

**Overall:** ⚠️ **REQUIRES MODIFICATION**

---

## Next Steps

1. **Update architecture document** ([aap-containerized-dr-architecture.md](aap-containerized-dr-architecture.md))
   - Change from 3 AAP nodes to 8 dedicated component VMs per DC
   - Update diagrams to show component separation
   - Add Redis firewall rules
   - Update resource calculations

2. **Revise inventory files**
   - Separate components onto dedicated nodes
   - Add `[redis]` group with correct nodes
   - Verify all inventory variables match Red Hat's structure

3. **Update implementation roadmap**
   - Adjust VM provisioning (24 VMs instead of 12)
   - Update network configuration for separated components
   - Revise cost/resource estimates

4. **Create testing plan**
   - Validate multi-DC failover (untested by Red Hat)
   - Test Redis connectivity after component separation
   - Verify EFM integration with separated components

---

## References

- **Red Hat Ansible Automation Platform 2.6 - Tested Deployment Models**
  Container Enterprise Topology (Section 2.2)

- **Red Hat Containerized Installation Guide**
  https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/containerized_installation

- **Inventory File Variables**
  https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/containerized_installation/appendix-inventory-files-vars

---

**Report Version:** 1.0
**Created:** 2026-03-31
**Author:** System Architect
**Next Review:** After architecture updates
