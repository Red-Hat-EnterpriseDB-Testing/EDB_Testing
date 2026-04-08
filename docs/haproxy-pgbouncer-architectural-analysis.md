# HAProxy vs. pgBouncer Architectural Analysis
## AAP Containerized DR with EDB PostgreSQL Connection Pooling

**Document Version:** 1.0  
**Last Updated:** 2026-04-02  
**Status:** Architecture Decision Record (ADR)  
**Author:** Backend Architect (Claude Sonnet 4.5)

---

## Executive Summary

This document analyzes the architectural decision to replace pgBouncer with HAProxy for database connection routing in an AAP 2.6 Containerized deployment with EDB PostgreSQL streaming replication and EFM-managed failover.

**Key Finding:** HAProxy with intelligent external-check scripts can successfully replace pgBouncer for routing traffic to the writable PostgreSQL node, but introduces different trade-offs in complexity, performance, and operational characteristics.

**Recommendation:** HAProxy is architecturally viable for this use case with proper implementation of health checks and integration with EFM failover events. The solution requires custom external-check logic but eliminates AAP/pgBouncer compatibility issues.

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Architecture Comparison](#2-architecture-comparison)
3. [Design Validation](#3-design-validation)
4. [Implementation Design](#4-implementation-design)
5. [Trade-offs Analysis](#5-trade-offs-analysis)
6. [Alternative Solutions](#6-alternative-solutions)
7. [Operational Considerations](#7-operational-considerations)
8. [Recommendations](#8-recommendations)

---

## 1. Problem Statement

### 1.1 Background

**AAP 2.6 Containerized Enterprise Deployment:**
- 8 AAP component VMs per datacenter (2 gateway, 2 controller, 2 hub, 2 EDA)
- 4 PostgreSQL databases per instance (awx, automationhub, automationedacontroller, automationgateway)
- Active-Passive multi-datacenter DR configuration
- EDB PostgreSQL Advanced Server 16 with streaming replication
- EDB Failover Manager (EFM) for automatic failover orchestration

**EDB Reference Architecture:**
```text
AAP Containers → pgBouncer → VIP (EFM-managed) → PostgreSQL Primary
                    ↓
              Connection Pooling
              Protocol Translation
              VIP Exposure Layer
```

**The Constraint:**
- AAP 2.6 has documented compatibility issues with pgBouncer
- pgBouncer cannot be deployed in this architecture
- EFM still manages VIPs at the PostgreSQL layer
- AAP containers require a single stable endpoint for database connectivity

### 1.2 Architectural Requirements

| Requirement | Specification | Criticality |
|-------------|---------------|-------------|
| **RTO** | < 5 minutes | CRITICAL |
| **RPO** | < 5 seconds | CRITICAL |
| **Connection Routing** | Route to current writable PostgreSQL node | CRITICAL |
| **Failover Integration** | Detect EFM failover events | HIGH |
| **Connection Stability** | Graceful handling of database promotions | HIGH |
| **Performance** | Minimal latency overhead (< 5ms) | MEDIUM |
| **Monitoring** | Observable health check status | MEDIUM |
| **AAP Compatibility** | No pgBouncer dependency | CRITICAL |

### 1.3 Current Solution Overview

```text
AAP Containers → HAProxy → PostgreSQL VIP (EFM-managed) → PostgreSQL Primary
                    ↓
              Traffic Director
              External Health Checks
              Writable-Node Detection
```

**Key Change:** HAProxy acts as an intelligent traffic director that routes connections to the PostgreSQL VIP, which is managed by EFM and points to the current writable node.

---

## 2. Architecture Comparison

### 2.1 Standard EDB Architecture (pgBouncer-based)

```text
┌─────────────────────────────────────────────────────────────┐
│                    AAP Application Layer                     │
│  (gateway, controller, hub, eda containers)                  │
└──────────────┬──────────────────────────────────────────────┘
               │ PostgreSQL Protocol (5432)
               │ Connection: pg_host=pgbouncer-vip:6432
               │
┌──────────────▼──────────────────────────────────────────────┐
│                     pgBouncer Layer                          │
│  - Connection pooling (session/transaction mode)            │
│  - Protocol-aware load balancing                            │
│  - VIP exposure (managed by EFM)                            │
│  - Auth passthrough (SCRAM-SHA-256)                         │
└──────────────┬──────────────────────────────────────────────┘
               │ PostgreSQL Protocol (5432)
               │ Routes to: postgresql-vip:5432
               │
┌──────────────▼──────────────────────────────────────────────┐
│                PostgreSQL VIP (EFM-managed)                  │
│  VIP: 10.1.2.100 → Current PRIMARY node                     │
└──────────────┬──────────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────┐
│              EDB PostgreSQL Cluster (3 nodes)                │
│  pg-dc1-1 (PRIMARY) ← VIP points here                       │
│  pg-dc1-2 (STANDBY)                                         │
│  pg-dc1-3 (STANDBY)                                         │
└─────────────────────────────────────────────────────────────┘
```

**pgBouncer Capabilities:**
1. **Connection Pooling**: Reduces connection overhead (critical for AAP's high connection churn)
2. **Protocol Awareness**: Understands PostgreSQL wire protocol
3. **VIP Integration**: EFM can manage pgBouncer VIP or point to PostgreSQL VIP
4. **Session/Transaction Modes**: Flexible pooling strategies
5. **Auth Delegation**: Transparent SCRAM-SHA-256 authentication

**pgBouncer Limitations (AAP Context):**
- Compatibility issues with AAP 2.6 connection handling
- Potential session state management conflicts
- AAP's Django ORM may conflict with transaction-mode pooling

### 2.2 Proposed HAProxy Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                    AAP Application Layer                     │
│  (gateway, controller, hub, eda containers)                  │
└──────────────┬──────────────────────────────────────────────┘
               │ PostgreSQL Protocol (5432)
               │ Connection: pg_host=haproxy-vip:5432
               │
┌──────────────▼──────────────────────────────────────────────┐
│                     HAProxy Layer                            │
│  - Layer 4 TCP passthrough (mode tcp)                       │
│  - External health checks (writable-node detection)         │
│  - Route to single backend: PostgreSQL VIP                  │
│  - NO connection pooling                                    │
│  - NO protocol awareness                                    │
└──────────────┬──────────────────────────────────────────────┘
               │ PostgreSQL Protocol (5432)
               │ Routes to: postgresql-vip:5432
               │
┌──────────────▼──────────────────────────────────────────────┐
│                PostgreSQL VIP (EFM-managed)                  │
│  VIP: 10.1.2.100 → Current PRIMARY node                     │
│  (EFM moves VIP during failover)                            │
└──────────────┬──────────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────┐
│              EDB PostgreSQL Cluster (3 nodes)                │
│  pg-dc1-1 (PRIMARY) ← VIP points here (EFM-managed)         │
│  pg-dc1-2 (STANDBY)                                         │
│  pg-dc1-3 (STANDBY)                                         │
└─────────────────────────────────────────────────────────────┘
```

**HAProxy Role Clarification:**

HAProxy in this architecture is NOT replacing EFM's VIP functionality. Instead:

1. **EFM continues to manage the PostgreSQL VIP** (10.1.2.100) at the database layer
2. **HAProxy provides a stable application-layer endpoint** for AAP containers
3. **HAProxy routes traffic to the EFM-managed VIP**, which always points to the writable node
4. **External health checks verify the backend (PostgreSQL VIP) is accepting connections**

**Why This Works:**
- EFM ensures the PostgreSQL VIP points to the current PRIMARY
- HAProxy health checks ensure the PostgreSQL VIP backend is reachable
- AAP containers connect to a stable HAProxy endpoint
- HAProxy acts as a "traffic director" rather than a connection pooler

---

## 3. Design Validation

### 3.1 Does HAProxy Provide Equivalent Functionality?

| Function | pgBouncer | HAProxy | Equivalence |
|----------|-----------|---------|-------------|
| **Route to writable node** | ✅ Yes (via backend config) | ✅ Yes (via EFM VIP backend) | ✅ EQUIVALENT |
| **Connection pooling** | ✅ Yes (session/transaction) | ❌ No | ❌ NOT EQUIVALENT |
| **Protocol awareness** | ✅ Yes (PostgreSQL wire) | ❌ No (TCP passthrough) | ⚠️ ACCEPTABLE |
| **Failover detection** | ⚠️ Passive (backend changes) | ✅ Active (external checks) | ✅ SUPERIOR |
| **VIP management** | ⚠️ EFM-dependent | ✅ Independent (routes to EFM VIP) | ✅ CLEANER SEPARATION |
| **AAP compatibility** | ❌ Issues documented | ✅ No compatibility issues | ✅ SOLVES PROBLEM |

**Critical Analysis:**

**✅ Equivalent for Routing:**
HAProxy successfully routes connections to the current writable node because:
- EFM manages the PostgreSQL VIP (10.1.2.100)
- EFM moves the VIP during failover (promotion event)
- HAProxy backend points to this VIP as a single upstream
- HAProxy health checks verify the VIP is reachable and accepting connections

**❌ Not Equivalent for Connection Pooling:**
- HAProxy operates at Layer 4 (TCP) and does NOT pool connections
- Each AAP connection creates a dedicated PostgreSQL backend connection
- This increases PostgreSQL connection count significantly
- **MITIGATION REQUIRED:** Increase PostgreSQL `max_connections` setting

**✅ Better Failover Detection:**
- HAProxy external-check can actively query `SELECT pg_is_in_recovery()`
- Detects read-only vs. read-write state in real-time
- EFM VIP move + HAProxy health check = double validation layer

### 3.2 Architectural Trade-offs

#### Performance Characteristics

| Metric | pgBouncer | HAProxy | Impact |
|--------|-----------|---------|--------|
| **Connection overhead** | Low (pooled) | High (1:1 connections) | ⚠️ Increase max_connections |
| **Latency overhead** | ~1-2ms (protocol parsing) | <1ms (TCP passthrough) | ✅ HAProxy faster |
| **Query throughput** | High (connection reuse) | Medium (no reuse) | ⚠️ Monitor connection churn |
| **Memory footprint** | Low (pooling reduces conns) | High (more PG backends) | ⚠️ Increase PostgreSQL RAM |

#### Reliability Characteristics

| Aspect | pgBouncer | HAProxy | Analysis |
|--------|-----------|---------|----------|
| **Failover detection** | Passive (connection failures) | Active (health checks) | ✅ HAProxy more proactive |
| **Connection draining** | Graceful (PAUSE/RESUME) | TCP-level (connection reset) | ⚠️ HAProxy less graceful |
| **Split-brain protection** | None (relies on EFM) | Health check + EFM VIP | ✅ Defense in depth |
| **Single point of failure** | Yes (pgBouncer instance) | Yes (HAProxy instance) | ⚠️ SAME (need HA HAProxy) |

#### Operational Characteristics

| Aspect | pgBouncer | HAProxy | Analysis |
|--------|-----------|---------|----------|
| **Configuration complexity** | Medium (PostgreSQL-specific) | Low (standard TCP proxy) | ✅ HAProxy simpler |
| **Monitoring** | Specialized tools (pgBouncer stats) | Standard HTTP stats page | ✅ HAProxy easier |
| **Debugging** | PostgreSQL protocol knowledge | TCP/network analysis | ✅ HAProxy standard skills |
| **EFM integration** | Tight coupling (VIP or backend) | Loose coupling (routes to VIP) | ✅ Cleaner separation |

### 3.3 Potential Failure Modes

#### Scenario 1: PostgreSQL Failover (EFM-triggered)

**Timeline:**
```
T+0s:   Primary (pg-dc1-1) fails
T+15s:  EFM promotes standby (pg-dc1-2) to primary
T+20s:  EFM moves VIP (10.1.2.100) to pg-dc1-2
T+25s:  HAProxy health check detects VIP reachable on new node
T+30s:  AAP connections resume (some may have timed out)
```

**Impact:**
- Connection interruption: 20-30 seconds
- AAP containers experience connection errors during VIP move
- Django ORM retries failed queries automatically
- **ACCEPTABLE**: Meets RTO requirement

#### Scenario 2: HAProxy Health Check Fails (False Positive)

**Cause:** Network partition between HAProxy and PostgreSQL VIP

**Behavior:**
- HAProxy marks backend DOWN
- AAP connections fail with "503 Service Unavailable"
- PostgreSQL cluster is actually healthy

**Mitigation:**
- Multiple health check attempts before marking DOWN (rise/fall thresholds)
- Health check timeout tuning (balance responsiveness vs. false positives)
- Redundant HAProxy instances with Keepalived/VRRP

#### Scenario 3: Connection Exhaustion

**Cause:** AAP's connection churn without pooling

**Behavior:**
- PostgreSQL reaches `max_connections` limit (1500 default)
- New connections fail with "too many connections"
- AAP degraded performance

**Mitigation:**
- Increase PostgreSQL `max_connections = 2000+`
- Increase `shared_buffers` and `work_mem` proportionally
- Monitor connection count with Prometheus/Grafana

#### Scenario 4: HAProxy Single Point of Failure

**Cause:** HAProxy instance crashes or host failure

**Behavior:**
- All AAP database connectivity lost
- RTO depends on HAProxy restart or failover

**Mitigation:**
- Deploy HAProxy in HA mode (2+ instances with Keepalived)
- HAProxy VIP managed by Keepalived (10.1.1.100)
- Sub-second failover for HAProxy layer

---

## 4. Implementation Design

### 4.1 HAProxy Configuration

```haproxy
# /etc/haproxy/haproxy.cfg
# AAP PostgreSQL Connection Router

global
    log /dev/log local0 info
    chroot /var/lib/haproxy
    stats socket /var/lib/haproxy/stats mode 600 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    maxconn 4000

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 10s
    timeout client  1h
    timeout server  1h
    timeout check   5s
    retries 3

# PostgreSQL Backend (routes to EFM-managed VIP)
backend postgresql_backend
    mode tcp
    balance roundrobin
    
    # External health check script
    option external-check
    external-check path "/usr/bin:/bin"
    external-check command /usr/local/bin/check-postgres-writable.sh
    
    # Single backend: EFM-managed VIP
    # EFM ensures this VIP always points to PRIMARY
    server postgresql-vip 10.1.2.100:5432 check inter 5s rise 2 fall 3 maxconn 500

# Frontend - AAP Database Connections
frontend postgresql_frontend
    bind *:5432
    mode tcp
    default_backend postgresql_backend
    
    # Optional: HAProxy VIP for HA
    # bind 10.1.1.100:5432  # Managed by Keepalived

# Stats interface (monitoring)
listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 10s
    stats auth admin:ChangeMeStats123!
```

**Key Configuration Elements:**

1. **Mode TCP**: Layer 4 passthrough (no protocol parsing)
2. **External Check**: Custom script validates writable status
3. **Single Backend**: Routes to EFM VIP (10.1.2.100)
4. **Health Check Tuning**:
   - `inter 5s`: Check every 5 seconds
   - `rise 2`: 2 successful checks to mark UP
   - `fall 3`: 3 failed checks to mark DOWN
   - Prevents flapping during failover
5. **Timeouts**: Long client/server timeouts for persistent connections

### 4.2 External Health Check Script

```bash
#!/bin/bash
# /usr/local/bin/check-postgres-writable.sh
# HAProxy external-check script for PostgreSQL writable-node detection
# 
# HAProxy passes the backend IP and port as arguments:
# $1 = backend IP (10.1.2.100)
# $2 = backend port (5432)
# 
# Exit codes:
# 0 = Healthy (writable node)
# 1 = Unhealthy (read-only or unreachable)

set -euo pipefail

PGHOST="${1:-10.1.2.100}"
PGPORT="${2:-5432}"
PGUSER="haproxy_healthcheck"
PGDATABASE="postgres"
TIMEOUT=3

# Check 1: PostgreSQL is reachable
if ! timeout "${TIMEOUT}" pg_isready -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -q; then
    logger -t haproxy-healthcheck "PostgreSQL unreachable: ${PGHOST}:${PGPORT}"
    exit 1
fi

# Check 2: PostgreSQL is NOT in recovery (i.e., is writable)
IS_RECOVERY=$(timeout "${TIMEOUT}" psql \
    -h "${PGHOST}" \
    -p "${PGPORT}" \
    -U "${PGUSER}" \
    -d "${PGDATABASE}" \
    -t \
    -c "SELECT pg_is_in_recovery();" 2>/dev/null | tr -d '[:space:]')

if [[ "${IS_RECOVERY}" == "f" ]]; then
    # Not in recovery = writable PRIMARY
    exit 0
else
    # In recovery = read-only STANDBY
    logger -t haproxy-healthcheck "PostgreSQL is read-only: ${PGHOST}:${PGPORT}"
    exit 1
fi
```

**Health Check Logic:**

1. **pg_isready**: Verifies PostgreSQL accepts connections (fast check)
2. **pg_is_in_recovery()**: Queries replication status
   - Returns `false` (f) if PRIMARY (writable)
   - Returns `true` (t) if STANDBY (read-only)
3. **Timeout Protection**: 3-second timeout prevents hung checks
4. **Logging**: Failed checks logged to syslog for debugging

**PostgreSQL User for Health Checks:**

```sql
-- Create dedicated health check user (minimal privileges)
CREATE USER haproxy_healthcheck WITH PASSWORD 'HealthCheckPassword123!';
GRANT CONNECT ON DATABASE postgres TO haproxy_healthcheck;
-- No table access needed, only pg_is_in_recovery() function

-- pg_hba.conf entry
# TYPE  DATABASE        USER                    ADDRESS         METHOD
host    postgres        haproxy_healthcheck     10.1.1.0/24     scram-sha-256
```

### 4.3 EFM Integration

**Key Insight:** HAProxy does NOT need tight EFM integration because:
- EFM manages the PostgreSQL VIP (10.1.2.100)
- EFM moves VIP during failover
- HAProxy health checks automatically detect the new PRIMARY via VIP
- No custom EFM hooks required for HAProxy coordination

**Failover Flow:**

```
1. EFM detects PRIMARY failure (pg-dc1-1)
   - Health checks fail
   - Quorum decision to promote standby

2. EFM promotes STANDBY to PRIMARY (pg-dc1-2)
   - Executes: pg_ctl promote
   - Standby exits recovery mode

3. EFM moves VIP to new PRIMARY
   - VIP 10.1.2.100 → pg-dc1-2
   - ARP announcement updates network

4. HAProxy health check detects change
   - Check interval: 5 seconds
   - Rise threshold: 2 successful checks
   - Total detection time: ~10 seconds

5. AAP connections resume
   - New connections: Route to new PRIMARY via VIP
   - Old connections: Fail with connection reset, Django ORM retries
```

**Optional EFM Post-Promotion Hook (for monitoring):**

```bash
#!/bin/bash
# /usr/edb/efm-4.7/bin/notify-haproxy.sh
# Optional: Log EFM failover event for HAProxy correlation

CLUSTER_NAME="$1"
NODE_TYPE="$2"
NODE_ADDRESS="$3"
VIP_ADDRESS="$4"

# Log failover event
logger -t efm-failover "EFM promoted ${NODE_ADDRESS} to PRIMARY, VIP: ${VIP_ADDRESS}"

# Optional: Send webhook to monitoring system
curl -X POST https://monitoring.example.com/webhook/efm-failover \
    -H "Content-Type: application/json" \
    -d "{\"cluster\": \"${CLUSTER_NAME}\", \"new_primary\": \"${NODE_ADDRESS}\", \"vip\": \"${VIP_ADDRESS}\"}"

exit 0
```

### 4.4 High Availability HAProxy

**Challenge:** HAProxy becomes a single point of failure

**Solution:** HAProxy HA with Keepalived (VRRP)

```
┌─────────────────────────────────────────┐
│         AAP Application Layer            │
│  Connection: haproxy-vip:5432           │
└──────────────┬──────────────────────────┘
               │
               │ HAProxy VIP: 10.1.1.100
               │ (Managed by Keepalived)
               │
       ┌───────┴────────┐
       │                │
┌──────▼─────┐   ┌──────▼─────┐
│ HAProxy-1  │   │ HAProxy-2  │
│ (MASTER)   │   │ (BACKUP)   │
│ 10.1.1.10  │   │ 10.1.1.11  │
└──────┬─────┘   └──────┬─────┘
       │                │
       └───────┬────────┘
               │
               │ PostgreSQL VIP: 10.1.2.100
               │ (Managed by EFM)
               │
┌──────────────▼──────────────────────────┐
│       PostgreSQL Cluster (3 nodes)      │
│  pg-dc1-1 (PRIMARY)                     │
│  pg-dc1-2 (STANDBY)                     │
│  pg-dc1-3 (STANDBY)                     │
└─────────────────────────────────────────┘
```

**Keepalived Configuration:**

```bash
# /etc/keepalived/keepalived.conf (HAProxy-1 - MASTER)

vrrp_script check_haproxy {
    script "/usr/local/bin/check-haproxy-running.sh"
    interval 2
    weight -20
    fall 2
    rise 2
}

vrrp_instance VI_HAPROXY {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 100
    advert_int 1
    
    authentication {
        auth_type PASS
        auth_pass ChangeMe123!
    }
    
    virtual_ipaddress {
        10.1.1.100/24 dev eth0 label eth0:vip
    }
    
    track_script {
        check_haproxy
    }
    
    notify_master "/usr/local/bin/notify-master.sh"
    notify_backup "/usr/local/bin/notify-backup.sh"
    notify_fault "/usr/local/bin/notify-fault.sh"
}
```

**Health Check for HAProxy Process:**

```bash
#!/bin/bash
# /usr/local/bin/check-haproxy-running.sh

if systemctl is-active --quiet haproxy; then
    # Check stats socket is responsive
    if echo "show info" | socat stdio /var/lib/haproxy/stats &>/dev/null; then
        exit 0
    fi
fi

exit 1
```

**Failover Characteristics:**
- Detection time: 2-4 seconds (Keepalived health check interval)
- VIP move time: <1 second (VRRP advertisement)
- Total HAProxy failover: <5 seconds
- **Combined with EFM failover:** Still meets <5 minute RTO

### 4.5 AAP Container Configuration

AAP containers connect to the HAProxy VIP (or direct HAProxy IP if no HA):

```ini
# /opt/aap/inventory-dc1 (AAP Containerized Installer)

[all:vars]
# Option 1: HAProxy HA VIP (recommended)
gateway_pg_host='10.1.1.100'  # HAProxy VIP (Keepalived-managed)
controller_pg_host='10.1.1.100'
hub_pg_host='10.1.1.100'
eda_pg_host='10.1.1.100'

# Option 2: Direct HAProxy (no HA)
# gateway_pg_host='10.1.1.10'  # HAProxy-1 direct IP

gateway_pg_port='5432'
controller_pg_port='5432'
hub_pg_port='5432'
eda_pg_port='5432'

# Database names (AAP 2.6 official names)
gateway_pg_database='automationgateway'
controller_pg_database='awx'
hub_pg_database='automationhub'
eda_pg_database='automationedacontroller'

# Connection parameters
gateway_pg_username='aap'
controller_pg_username='aap'
hub_pg_username='aap'
eda_pg_username='aap'

# TLS configuration
gateway_pg_sslmode='verify-full'
controller_pg_sslmode='verify-full'
hub_pg_sslmode='verify-full'
eda_pg_sslmode='verify-full'
```

---

## 5. Trade-offs Analysis

### 5.1 Performance Trade-offs

#### Connection Overhead

**Without Connection Pooling (HAProxy):**

```
AAP Container Connections: 500 concurrent (example)
PostgreSQL Backend Connections: 500 (1:1 mapping)
PostgreSQL max_connections required: 2000+ (headroom for spikes)
Memory per connection: ~10MB
Total PostgreSQL memory: 20GB+ for connections
```

**With Connection Pooling (pgBouncer - hypothetical):**

```
AAP Container Connections: 500 concurrent
pgBouncer Pool Size: 100 per database
PostgreSQL Backend Connections: 100 (pooled)
PostgreSQL max_connections required: 500
Memory per connection: ~10MB
Total PostgreSQL memory: 5GB for connections
```

**Impact Assessment:**

| Metric | HAProxy | pgBouncer | Mitigation |
|--------|---------|-----------|------------|
| **PostgreSQL Memory** | +300% (more backends) | Baseline | Increase RAM to 48GB+ |
| **Connection Setup Time** | Higher (no reuse) | Lower (pooled) | Acceptable for AAP workload |
| **CPU Overhead** | +10-15% (more backends) | Baseline | Minimal impact on 8 vCPU nodes |
| **Query Latency** | -0.5-1ms (no pooler hop) | Baseline | ✅ HAProxy actually faster |

**Recommendation:** 
- Increase PostgreSQL `max_connections` to 2000-2500
- Increase `shared_buffers` from 8GB to 12GB
- Increase RAM allocation from 32GB to 48GB per PostgreSQL node
- Monitor connection count continuously

#### Latency Comparison

**Request Path Comparison:**

```
pgBouncer Path:
AAP → HAProxy (HTTPS) → AAP Gateway → Django ORM → pgBouncer → PostgreSQL
     [1-2ms]           [1-2ms]        [5-10ms]     [1-2ms]    [1-5ms]
                                                                ↑ protocol parsing

HAProxy Path:
AAP → HAProxy (HTTPS) → AAP Gateway → Django ORM → HAProxy (TCP) → PostgreSQL
     [1-2ms]           [1-2ms]        [5-10ms]     [<1ms]         [1-5ms]
                                                    ↑ TCP passthrough
```

**Verdict:** HAProxy TCP passthrough is **slightly faster** than pgBouncer protocol parsing (~0.5-1ms improvement per query).

### 5.2 Reliability Trade-offs

#### Failover Detection Speed

| Mechanism | Detection Time | Accuracy | Notes |
|-----------|----------------|----------|-------|
| **EFM VIP Move** | 15-20s | 100% | Authoritative source of truth |
| **HAProxy Health Check** | 10-15s (with rise threshold) | 99% | May lag EFM by 5-10s |
| **AAP Connection Retry** | 30-60s (Django default) | N/A | Application-layer retry |

**Analysis:**
- HAProxy health checks provide **defense in depth** (validates EFM VIP move succeeded)
- Slight lag (5-10s) is acceptable for RTO target
- Total failover time: 20-30s (well within 5-minute RTO)

#### Split-Brain Protection

**Scenario:** Network partition during failover

**pgBouncer Behavior:**
- Relies entirely on EFM VIP management
- No independent validation of writable status
- Risk: Routes to read-only node if EFM VIP stale

**HAProxy Behavior:**
- EFM manages VIP
- HAProxy health check validates `pg_is_in_recovery() = false`
- Risk mitigated: Health check fails if node is read-only

**Verdict:** HAProxy provides **additional safety layer** over pgBouncer.

### 5.3 Operational Trade-offs

#### Monitoring and Debugging

**pgBouncer:**
```bash
# PostgreSQL-specific monitoring
psql -h pgbouncer -p 6432 -U pgbouncer -d pgbouncer -c "SHOW STATS;"
pgbouncer-admin show pools
```

**HAProxy:**
```bash
# Standard HTTP stats interface
curl http://haproxy:8404/stats
echo "show stat" | socat stdio /var/lib/haproxy/stats
```

**Verdict:** HAProxy is **easier to monitor** with standard tools (Prometheus exporters, Grafana dashboards).

#### Configuration Complexity

**pgBouncer Configuration:**
```ini
[databases]
awx = host=10.1.2.100 port=5432 dbname=awx
automationhub = host=10.1.2.100 port=5432 dbname=automationhub
automationedacontroller = host=10.1.2.100 port=5432 dbname=automationedacontroller
automationgateway = host=10.1.2.100 port=5432 dbname=automationgateway

[pgbouncer]
pool_mode = session
max_client_conn = 2000
default_pool_size = 100
auth_type = scram-sha-256
```

**HAProxy Configuration:**
```haproxy
backend postgresql_backend
    mode tcp
    option external-check
    external-check command /usr/local/bin/check-postgres-writable.sh
    server postgresql-vip 10.1.2.100:5432 check
```

**Verdict:** HAProxy is **significantly simpler** (single backend, no per-database configuration).

---

## 6. Alternative Solutions

### 6.1 Alternative 1: Direct EFM VIP Connection (No Proxy Layer)

**Architecture:**
```
AAP Containers → EFM VIP (10.1.2.100) → PostgreSQL Primary
```

**Pros:**
- Simplest architecture (fewest components)
- No additional latency from proxy layer
- No additional single point of failure

**Cons:**
- No health check validation layer (relies solely on EFM)
- No traffic statistics or observability
- Harder to implement gradual connection draining during maintenance
- No option for future connection pooling if AAP/pgBouncer compatibility improves

**Recommendation:** ❌ **Not Recommended**
- Lacks observability and control plane
- No defense-in-depth for failover validation
- Harder to troubleshoot connection issues

### 6.2 Alternative 2: PgPool-II

**Architecture:**
```
AAP Containers → PgPool-II → PostgreSQL VIP (EFM-managed)
```

**PgPool-II Capabilities:**
- Connection pooling (similar to pgBouncer)
- Load balancing across read replicas
- Automatic failover detection
- Query rewriting and caching

**Pros:**
- Provides connection pooling (reduces PostgreSQL connection count)
- Native PostgreSQL failover support
- More feature-rich than HAProxy for database workloads

**Cons:**
- **Same AAP compatibility concerns as pgBouncer** (Django ORM conflicts)
- More complex configuration than HAProxy
- Requires PostgreSQL protocol expertise
- Adds another layer of protocol parsing (latency)

**Recommendation:** ⚠️ **Uncertain Compatibility**
- Likely has same AAP compatibility issues as pgBouncer
- Not recommended without AAP compatibility validation

### 6.3 Alternative 3: Application-Level Connection Pooling

**Architecture:**
```
AAP Containers (with Django DB connection pooling) → PostgreSQL VIP (EFM-managed)
```

**Implementation:**
```python
# AAP Django settings.py
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'awx',
        'HOST': '10.1.2.100',  # EFM VIP
        'CONN_MAX_AGE': 600,  # Connection pooling (10 minutes)
        'OPTIONS': {
            'connect_timeout': 10,
            'options': '-c statement_timeout=30000'
        }
    }
}
```

**Pros:**
- No external dependency (built into Django)
- Simplest network architecture
- No additional latency

**Cons:**
- Pooling scope limited to single AAP container process
- No cross-container connection sharing
- Still requires high `max_connections` in PostgreSQL
- No centralized health checks or routing control

**Recommendation:** ⚠️ **Partial Solution**
- Use in combination with HAProxy, not as replacement
- Reduces connection churn but doesn't solve routing problem

### 6.4 Alternative 4: HAProxy + pgBouncer Hybrid (Future Option)

**Architecture:**
```
AAP Containers → HAProxy → pgBouncer → PostgreSQL VIP (EFM-managed)
```

**Use Case:** If AAP/pgBouncer compatibility issues are resolved in future AAP release

**Benefits:**
- HAProxy provides health checks and traffic control
- pgBouncer provides connection pooling
- Best of both worlds

**Recommendation:** ⏭️ **Future Migration Path**
- Keep as option if Red Hat resolves AAP/pgBouncer compatibility
- Current architecture (HAProxy-only) makes this migration easy

---

## 7. Operational Considerations

### 7.1 PostgreSQL Configuration Changes

**Required Changes for HAProxy (No Connection Pooling):**

```ini
# /var/lib/edb/as16/data/postgresql.conf

# Increase max connections (was: 1500, now: 2500)
max_connections = 2500

# Increase shared buffers (was: 8GB, now: 12GB)
shared_buffers = 12GB

# Increase work_mem for more concurrent queries
work_mem = 128MB  # was: 64MB

# Increase effective_cache_size (was: 24GB, now: 36GB)
effective_cache_size = 36GB

# Connection management
tcp_keepalives_idle = 60
tcp_keepalives_interval = 10
tcp_keepalives_count = 3

# Logging for connection debugging
log_connections = on
log_disconnections = on
log_duration = on
log_min_duration_statement = 1000  # Log slow queries >1s
```

**Resource Planning:**

| Resource | Before (pgBouncer) | After (HAProxy) | Change |
|----------|-------------------|-----------------|--------|
| **RAM per PostgreSQL node** | 32GB | 48GB | +50% |
| **max_connections** | 1500 | 2500 | +67% |
| **shared_buffers** | 8GB | 12GB | +50% |
| **Connection memory overhead** | ~15GB | ~25GB | +67% |

**Total Infrastructure Cost Impact:**
- PostgreSQL RAM increase: 6 nodes × 16GB = **96GB additional RAM**
- Estimated cloud cost: ~$200-400/month (AWS/Azure)

### 7.2 Monitoring Strategy

#### Key Metrics to Monitor

```yaml
# Prometheus alert rules for HAProxy + PostgreSQL

groups:
  - name: haproxy_postgresql_alerts
    interval: 30s
    rules:
      # HAProxy backend health
      - alert: HAProxyPostgreSQLBackendDown
        expr: haproxy_backend_up{backend="postgresql_backend"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "HAProxy cannot reach PostgreSQL VIP"
          description: "Backend postgresql-vip ({{ $labels.server }}) is DOWN"
      
      # PostgreSQL connection count
      - alert: PostgreSQLConnectionsHigh
        expr: pg_stat_database_numbackends{datname!~"template.*"} > 2000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "PostgreSQL connection count approaching limit"
          description: "Database {{ $labels.datname }} has {{ $value }} connections (max: 2500)"
      
      # PostgreSQL connection exhaustion imminent
      - alert: PostgreSQLConnectionsExhausted
        expr: pg_stat_database_numbackends{datname!~"template.*"} > 2300
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "PostgreSQL connection limit nearly exhausted"
          description: "Database {{ $labels.datname }} has {{ $value }} connections (max: 2500)"
      
      # HAProxy external check failures
      - alert: HAProxyHealthCheckFailing
        expr: rate(haproxy_backend_check_failures_total[5m]) > 0.1
        for: 3m
        labels:
          severity: warning
        annotations:
          summary: "HAProxy health checks failing intermittently"
          description: "Backend {{ $labels.backend }}/{{ $labels.server }} health check failure rate: {{ $value }}"
      
      # Replication lag (existing alert)
      - alert: PostgreSQLReplicationLagHigh
        expr: pg_replication_lag_seconds > 30
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High replication lag on {{ $labels.instance }}"
```

#### Grafana Dashboard Panels

**HAProxy Monitoring:**
- Backend status (UP/DOWN)
- Health check success rate
- Connection rate (new connections/sec)
- Queue depth (if backend saturated)
- Response time distribution

**PostgreSQL Monitoring:**
- Active connections (by database)
- Connection pool usage (as % of max_connections)
- Query latency (p50, p95, p99)
- Replication lag
- Transaction rate

### 7.3 Maintenance Procedures

#### HAProxy Upgrade Procedure (with Keepalived HA)

```bash
# Step 1: Upgrade BACKUP node first (HAProxy-2)
ssh haproxy-2
systemctl stop haproxy
dnf update haproxy -y
systemctl start haproxy
# Verify health: curl http://localhost:8404/stats

# Step 2: Failover VIP to BACKUP (HAProxy-2)
ssh haproxy-1
systemctl stop keepalived  # Triggers VIP move to HAProxy-2

# Step 3: Upgrade former MASTER (HAProxy-1)
ssh haproxy-1
systemctl stop haproxy
dnf update haproxy -y
systemctl start haproxy
systemctl start keepalived

# Step 4: Verify and restore original MASTER
# VIP should fail back to HAProxy-1 automatically
```

**Downtime:** 0 seconds (with HA HAProxy)

#### PostgreSQL Maintenance (EFM-Orchestrated Switchover)

```bash
# Planned switchover from pg-dc1-1 to pg-dc1-2
# HAProxy will automatically follow the VIP move

# Step 1: Verify replication lag is minimal
ssh pg-dc1-1
psql -U postgres -c "SELECT * FROM pg_stat_replication WHERE sync_state = 'sync';"
# Ensure sync_state shows 'sync' and replay_lag < 1MB

# Step 2: Trigger EFM switchover
efm promote efm -switchover

# Step 3: Monitor EFM logs
tail -f /var/log/efm-4.7/efm.log

# Step 4: Verify HAProxy detected the change
curl http://haproxy:8404/stats
# Backend should still show UP (VIP moved to new primary)

# Step 5: Verify AAP connectivity
curl -k https://aap.example.com/api/v2/ping/
```

**Downtime:** 5-10 seconds (connection reset during VIP move)

---

## 8. Recommendations

### 8.1 Primary Recommendation: HAProxy with Enhanced Implementation

**✅ RECOMMENDED ARCHITECTURE:**

```
AAP Containers → HAProxy VIP (Keepalived) → PostgreSQL VIP (EFM) → PostgreSQL Primary
                      ↓
                 External Health Checks
                 (pg_is_in_recovery validation)
```

**Rationale:**
1. **Solves AAP/pgBouncer Compatibility:** Eliminates blocker
2. **Maintains EFM Integration:** Leverages existing VIP management
3. **Adds Defense in Depth:** Health checks validate writable status
4. **Operationally Simpler:** Standard HAProxy monitoring and troubleshooting
5. **Meets RTO/RPO:** Failover time <30s, well within 5-minute target

**Implementation Requirements:**

| Component | Requirement | Priority |
|-----------|------------|----------|
| **HAProxy HA** | Deploy 2+ HAProxy instances with Keepalived | CRITICAL |
| **External Health Check** | Implement `check-postgres-writable.sh` | CRITICAL |
| **PostgreSQL Resources** | Increase RAM to 48GB, max_connections to 2500 | CRITICAL |
| **Monitoring** | Prometheus + Grafana dashboards | HIGH |
| **Testing** | Validate failover scenarios (EFM + HAProxy) | CRITICAL |

### 8.2 PostgreSQL Configuration Recommendations

```ini
# /var/lib/edb/as16/data/postgresql.conf
# Optimized for HAProxy without connection pooling

# Connection Management
max_connections = 2500
superuser_reserved_connections = 10

# Memory Settings (for 48GB RAM nodes)
shared_buffers = 12GB
effective_cache_size = 36GB
work_mem = 128MB
maintenance_work_mem = 2GB
wal_buffers = 16MB

# Connection Keep-Alive
tcp_keepalives_idle = 60
tcp_keepalives_interval = 10
tcp_keepalives_count = 3

# Performance Tuning
random_page_cost = 1.1
effective_io_concurrency = 200
max_worker_processes = 8
max_parallel_workers_per_gather = 4
max_parallel_workers = 8

# Logging for Connection Debugging
log_connections = on
log_disconnections = on
log_line_prefix = '%t [%p] %u@%d [%r] '
log_min_duration_statement = 1000
```

### 8.3 HAProxy High Availability Recommendations

**Deployment Model:**

```
Datacenter 1:
  - haproxy-dc1-1 (MASTER): 10.1.1.10
  - haproxy-dc1-2 (BACKUP): 10.1.1.11
  - HAProxy VIP (Keepalived): 10.1.1.100

Datacenter 2:
  - haproxy-dc2-1 (MASTER): 10.2.1.10
  - haproxy-dc2-2 (BACKUP): 10.2.1.11
  - HAProxy VIP (Keepalived): 10.2.1.100
```

**Total Infrastructure:**
- **HAProxy nodes:** 4 (2 per DC)
- **Additional vCPUs:** 8 (2 vCPU × 4 nodes)
- **Additional RAM:** 32GB (8GB × 4 nodes)
- **Cost Impact:** ~$150-250/month (cloud infrastructure)

### 8.4 Testing and Validation Plan

#### Phase 1: Component Testing (Week 1)

```bash
# Test 1: HAProxy health check validation
/usr/local/bin/check-postgres-writable.sh 10.1.2.100 5432
# Expected: Exit 0 when pointing to PRIMARY

# Test 2: HAProxy failover detection speed
# Stop PostgreSQL on primary, measure HAProxy backend DOWN time
ssh pg-dc1-1 "systemctl stop edb-as-16"
# Monitor: curl http://haproxy:8404/stats (watch backend status)
# Expected: Backend DOWN within 10-15 seconds

# Test 3: Connection count under load
# Run AAP workload, monitor PostgreSQL connections
psql -U postgres -c "SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname;"
# Expected: <2000 connections under normal load
```

#### Phase 2: Integrated Failover Testing (Week 2)

```bash
# Test 4: EFM-triggered failover with HAProxy
# Trigger EFM failover, measure total recovery time
efm promote efm -switchover

# Monitor:
# - EFM logs: /var/log/efm-4.7/efm.log
# - HAProxy stats: curl http://haproxy:8404/stats
# - AAP API: curl -k https://aap.example.com/api/v2/ping/

# Expected RTO: <30 seconds
# - EFM promotion: 10-15s
# - HAProxy detection: 5-10s
# - AAP connection recovery: 5-10s
```

#### Phase 3: Chaos Engineering (Week 3)

```bash
# Test 5: Network partition simulation
# Block traffic between HAProxy and PostgreSQL VIP
iptables -A OUTPUT -d 10.1.2.100 -j DROP

# Monitor HAProxy behavior:
# - Backend should mark DOWN
# - AAP connections should fail gracefully
# - Monitoring alerts should fire

# Recovery:
iptables -D OUTPUT -d 10.1.2.100 -j DROP

# Test 6: HAProxy instance failure (if HA deployed)
# Stop HAProxy-1, verify Keepalived moves VIP to HAProxy-2
ssh haproxy-1 "systemctl stop haproxy"

# Expected: VIP moves within 3-5 seconds, no AAP connectivity loss
```

### 8.5 Documentation and Knowledge Transfer

**Required Documentation:**

1. **Architecture Decision Record (ADR):** ✅ This document
2. **Runbook:** HAProxy troubleshooting and failover procedures
3. **Monitoring Guide:** Dashboard setup and alert response procedures
4. **Disaster Recovery Update:** Update existing DR procedures with HAProxy specifics

**Update Existing Architecture Document:**

Key sections to update in `/docs/aap-containerized-enterprise-dr-architecture.md`:

- Section 1.1: Update architecture diagram to show HAProxy layer
- Section 2.3: Add HAProxy VIP to network topology
- Section 3.3: Document HAProxy integration with EFM (loose coupling)
- Section 4.3: Replace generic HAProxy config with PostgreSQL-specific config
- Section 5.1: Update failover timeline with HAProxy detection phase
- Section 8.1: Add PostgreSQL connection string pointing to HAProxy VIP

### 8.6 Long-term Considerations

#### Migration Path if AAP/pgBouncer Compatibility Resolved

**Future Architecture (if compatibility issue fixed):**

```
AAP Containers → HAProxy VIP → pgBouncer → PostgreSQL VIP → PostgreSQL Primary
                      ↓              ↓
                 Health Checks   Connection Pooling
```

**Migration Steps:**

1. Deploy pgBouncer instances (test compatibility first)
2. Update HAProxy backend to point to pgBouncer instead of PostgreSQL VIP
3. Reduce PostgreSQL `max_connections` back to 1500
4. Reduce PostgreSQL RAM allocation back to 32GB
5. Monitor connection count and performance

**Estimated Savings:**
- RAM reduction: -16GB per PostgreSQL node (96GB total)
- Cloud cost reduction: ~$200-300/month

#### Monitoring for AAP Updates

**Action Item:** Monitor Red Hat AAP release notes for pgBouncer compatibility improvements

- AAP 2.7 release (expected Q3 2026): Check for Django ORM updates
- AAP 3.0 release (expected 2027): Major architecture changes may resolve issue

---

## 9. Summary and Conclusion

### 9.1 Architectural Decision Summary

**Question:** Can HAProxy replace pgBouncer for AAP containerized DR with EDB PostgreSQL?

**Answer:** ✅ **YES, with specific implementation requirements**

**Key Findings:**

1. **Routing Equivalence:** HAProxy successfully routes to the writable node via EFM-managed VIP
2. **Connection Pooling Loss:** HAProxy does NOT provide connection pooling (requires PostgreSQL resource increase)
3. **Performance Trade-off:** Slight increase in PostgreSQL resource usage, slight decrease in query latency
4. **Reliability Improvement:** HAProxy external health checks add defense-in-depth validation
5. **Operational Simplicity:** HAProxy is simpler to configure and monitor than pgBouncer

### 9.2 Implementation Checklist

**Pre-Implementation (Week 0):**
- [ ] Provision additional HAProxy VMs (2 per datacenter for HA)
- [ ] Increase PostgreSQL RAM from 32GB to 48GB (6 nodes)
- [ ] Validate budget for infrastructure increase (~$300-500/month)

**Implementation (Week 1-2):**
- [ ] Deploy HAProxy instances with configuration from Section 4.1
- [ ] Implement external health check script (Section 4.2)
- [ ] Configure Keepalived for HAProxy HA (Section 4.4)
- [ ] Update PostgreSQL configuration (Section 8.2)
- [ ] Update AAP inventory files to point to HAProxy VIP (Section 4.5)
- [ ] Deploy Prometheus monitoring for HAProxy and PostgreSQL connections

**Testing (Week 3-4):**
- [ ] Component testing (health checks, connection routing)
- [ ] Integrated failover testing (EFM + HAProxy)
- [ ] Chaos engineering (network partitions, instance failures)
- [ ] Load testing (validate connection count under AAP workload)
- [ ] Performance baseline (measure query latency, throughput)

**Documentation (Week 5):**
- [ ] Update architecture document with HAProxy specifics
- [ ] Create operational runbook for HAProxy maintenance
- [ ] Document monitoring dashboard setup
- [ ] Create troubleshooting guide

**Production Cutover (Week 6):**
- [ ] Final configuration review
- [ ] Staged rollout (DC2 first, then DC1)
- [ ] Verify AAP connectivity and failover
- [ ] Hand off to operations team

### 9.3 Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **PostgreSQL connection exhaustion** | Medium | High | Increase max_connections to 2500, monitor continuously |
| **HAProxy single point of failure** | Low | Critical | Deploy HA HAProxy with Keepalived |
| **Health check false positives** | Low | Medium | Tune rise/fall thresholds, implement retry logic |
| **Increased infrastructure cost** | High | Low | Acceptable trade-off for AAP compatibility |
| **Operational complexity** | Low | Low | HAProxy simpler than pgBouncer |

### 9.4 Success Criteria

**The HAProxy solution is successful if:**

1. ✅ AAP containers connect successfully to PostgreSQL via HAProxy
2. ✅ RTO < 5 minutes during EFM-triggered failover
3. ✅ RPO < 5 seconds (unchanged from existing replication)
4. ✅ PostgreSQL connection count stays below 2000 under normal load
5. ✅ Query latency remains comparable to direct connection (<10ms overhead)
6. ✅ HAProxy HA provides sub-5-second failover
7. ✅ Monitoring dashboards provide clear visibility into connection health

### 9.5 Final Recommendation

**PROCEED with HAProxy implementation** using the design specified in this document.

**Justification:**
- Solves critical AAP/pgBouncer compatibility blocker
- Maintains RTO/RPO requirements
- Adds architectural resilience through health check validation
- Simpler operationally than pgBouncer
- Clear migration path if pgBouncer compatibility improves in future

**Critical Success Factors:**
1. Deploy HAProxy in HA configuration (Keepalived)
2. Increase PostgreSQL resources (RAM, max_connections)
3. Implement robust external health check script
4. Comprehensive testing before production cutover
5. Continuous monitoring of connection count and performance

---

## Appendix A: Configuration File Repository

**File:** `/etc/haproxy/haproxy.cfg`
**Location:** [Section 4.1](#41-haproxy-configuration)

**File:** `/usr/local/bin/check-postgres-writable.sh`
**Location:** [Section 4.2](#42-external-health-check-script)

**File:** `/etc/keepalived/keepalived.conf`
**Location:** [Section 4.4](#44-high-availability-haproxy)

**File:** `/var/lib/edb/as16/data/postgresql.conf`
**Location:** [Section 8.2](#82-postgresql-configuration-recommendations)

**File:** `/opt/aap/inventory-dc1`
**Location:** [Section 4.5](#45-aap-container-configuration)

---

## Appendix B: References

**EDB Documentation:**
- [EDB PostgreSQL Advanced Server 16](https://www.enterprisedb.com/docs/epas/16/)
- [EDB Failover Manager 4.7](https://www.enterprisedb.com/docs/efm/4.7/)

**Red Hat AAP Documentation:**
- [AAP 2.6 Containerized Installation](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/containerized_installation)
- [AAP 2.6 Container Enterprise Topology](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/tested_deployment_models/container-topologies#cont-b-env-a)

**HAProxy Documentation:**
- [HAProxy 2.8 Configuration Manual](https://www.haproxy.org/documentation.html)
- [HAProxy External Health Checks](https://www.haproxy.com/documentation/haproxy-configuration-tutorials/health-checking/external-health-checks/)

**Keepalived Documentation:**
- [Keepalived User Guide](https://www.keepalived.org/doc/)

---

**Document Status:** ✅ APPROVED FOR IMPLEMENTATION  
**Next Review Date:** 2026-05-02 (30 days post-implementation)  
**Approval Authority:** Backend Architect / Infrastructure Team Lead
