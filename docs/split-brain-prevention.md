# Split-Brain Prevention in AAP Failover Architecture

**Version:** 1.0
**Date:** 2026-03-30
**Status:** ✅ IMPLEMENTED

---

## Overview

Split-brain is a critical failure scenario in distributed systems where two nodes in a cluster simultaneously believe they are the primary, leading to data divergence and corruption. In the AAP + EnterpriseDB architecture, this could occur if AAP pods are scaled up against a **replica database** instead of the **primary database**.

This document describes the split-brain prevention mechanism implemented in the failover scripts.

---

## The Split-Brain Scenario

### How It Could Happen

**Scenario:** Cross-datacenter failover without proper validation

1. **Initial State:**
   - DC1: Primary database + AAP running
   - DC2: Replica database + AAP scaled to zero

2. **Network Partition:**
   - DC1 and DC2 lose connectivity
   - EFM in DC1 thinks DC2 is down
   - EFM in DC2 thinks DC1 is down

3. **Dual Promotion (Without Protection):**
   - EFM in DC1 keeps DC1 database as primary
   - EFM in DC2 promotes DC2 database to primary
   - Both run post-promotion scripts

4. **AAP Scaled Up in Both DCs:**
   - DC1 AAP writes to DC1 database
   - DC2 AAP writes to DC2 database
   - **Data divergence begins** 💥

5. **Network Restored:**
   - Two primary databases exist
   - Data conflicts cannot be reconciled
   - Manual intervention required

### Impact

- **Data Loss:** Conflicting writes cannot be merged
- **Data Corruption:** Inconsistent state across databases
- **Service Disruption:** Hours or days to manually reconcile
- **Compliance Risk:** Audit trail broken

---

## Prevention Mechanism

### Implementation

The split-brain prevention mechanism is implemented in **`/scripts/scale-aap-up.sh`** and validates the database role before scaling AAP pods.

#### Database Role Check

```bash
# Get the primary database pod
DB_POD=$(oc get pods -n "$DB_NAMESPACE" \
  -l "cnpg.io/cluster=$DB_CLUSTER,role=primary" \
  -o name 2>/dev/null | head -1)

# Verify the database is not in recovery (not a replica)
IN_RECOVERY=$(oc exec -n "$DB_NAMESPACE" "$DB_POD" \
  -- psql -U postgres -t -c "SELECT pg_is_in_recovery();" \
  2>/dev/null | tr -d '[:space:]')

if [ "$IN_RECOVERY" = "t" ]; then
    echo "❌ CRITICAL ERROR: Database is in RECOVERY mode (acting as a REPLICA)"
    exit 1
fi
```

#### PostgreSQL Recovery Check

**`pg_is_in_recovery()` Function:**

| Return Value | Database Role | Meaning |
|--------------|---------------|---------|
| `f` (false) | **Primary** | Database accepts read/write operations |
| `t` (true) | **Replica** | Database is in recovery mode (read-only) |

A database in recovery mode (`t`) is a **standby/replica** and should **never** have AAP scaled up against it.

---

## How It Works

### Execution Flow

```text
┌─────────────────────────────────────┐
│ scale-aap-up.sh invoked             │
│ (manually or via EFM hook)          │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│ Switch to target cluster context    │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│ Query: Get primary DB pod           │
│ Label: role=primary                 │
└────────────┬────────────────────────┘
             │
             ▼
        ┌────┴────┐
        │ Found?  │
        └────┬────┘
             │
       ┌─────┴─────┐
       │           │
      NO          YES
       │           │
       │           ▼
       │    ┌──────────────────────────────┐
       │    │ Query: pg_is_in_recovery()   │
       │    └──────────┬───────────────────┘
       │               │
       │         ┌─────┴─────┐
       │         │ Result?   │
       │         └─────┬─────┘
       │               │
       │         ┌─────┴────────────────┐
       │         │                      │
       │        't'                    'f'
       │    (REPLICA)              (PRIMARY)
       │         │                      │
       ▼         ▼                      ▼
   ┌────────────────┐          ┌──────────────────┐
   │ EXIT 1         │          │ Proceed with     │
   │ DO NOT SCALE   │          │ AAP scaling      │
   │ CRITICAL ERROR │          │ ✅ SAFE          │
   └────────────────┘          └──────────────────┘
```

### Decision Logic

| Condition | Action | Rationale |
|-----------|--------|-----------|
| No primary pod found | EXIT with error | Database cluster may be down or misconfigured |
| `pg_is_in_recovery() = t` | EXIT with error | Database is a replica - AAP writes would fail |
| `pg_is_in_recovery() = f` | Proceed | Database is primary - safe to scale AAP |
| Recovery status unknown | Proceed with warning | Fail-open to avoid blocking legitimate failover |

---

## Testing

### Automated Test

Run the split-brain prevention test:

```bash
cd /Users/cferman/Documents/GitHub/EDB_Testing/scripts
./test-split-brain-prevention.sh <cluster-context>
```

**Test Coverage:**

1. Database role detection (pg_is_in_recovery query)
2. Safety code presence in scale-aap-up.sh
3. Replica scenario (manual test required)
4. Dry-run validation (current cluster state)

### Manual Failover Drill

**Objective:** Verify split-brain prevention during actual replica promotion

**Procedure:**

1. **Simulate DC1 database failure:**
   ```bash
   oc scale deployment postgresql-1 -n edb-postgres --replicas=0
   ```

2. **Attempt to scale AAP (should fail):**
   ```bash
   ./scale-aap-up.sh dc1-cluster-context
   ```

   **Expected Result:**
   ```
   ❌ CRITICAL ERROR: Database is in RECOVERY mode (acting as a REPLICA)
   ```

3. **Promote DC2 replica to primary:**
   ```bash
   oc annotate cluster postgresql -n edb-postgres --overwrite \
     cnpg.io/reconciliationLoop=disabled
   ```

4. **Scale AAP in DC2 (should succeed):**
   ```bash
   ./scale-aap-up.sh dc2-cluster-context
   ```

   **Expected Result:**
   ```
   ✅ Database is in PRIMARY mode - safe to scale AAP
   ```

5. **Restore DC1:**
   ```bash
   oc scale deployment postgresql-1 -n edb-postgres --replicas=1
   ```

---

## Integration Points

### EFM Post-Promotion Hook

The split-brain check is automatically invoked during EFM-orchestrated failovers via:

**`/scripts/efm-aap-failover-wrapper.sh`** → **`/scripts/scale-aap-up.sh`**

**Configuration:**
```properties
# /etc/edb/efm-4.x/efm.properties
script.post.promotion=/usr/edb/efm-4.x/bin/efm-orchestrated-failover.sh %h %s %a %v
```

**Flow:**
1. EFM detects primary failure
2. Promotes local replica to primary
3. Calls `efm-orchestrated-failover.sh`
4. Wrapper detects datacenter
5. Calls `scale-aap-up.sh` with correct context
6. **Split-brain check validates database role**
7. AAP scaled only if database is primary

### Manual Failover

When executing manual failover:

```bash
# Always use the scale-aap-up.sh script (never scale directly with oc)
./scripts/scale-aap-up.sh <cluster-context>
```

**The script will automatically:**
- Verify database is in primary mode
- Prevent scaling against replicas
- Provide clear error messages if database is not ready

---

## Monitoring & Alerting

### Prometheus Metrics (Recommended)

**Metric:** `aap_database_role_check_failures_total`

```yaml
# Increment on split-brain check failure
curl -X POST http://localhost:9091/metrics/job/aap-failover \
  --data 'aap_database_role_check_failures_total 1'
```

**Alert:**
```yaml
- alert: SplitBrainPreventionTriggered
  expr: increase(aap_database_role_check_failures_total[5m]) > 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "Split-brain prevention blocked AAP scaling"
    description: "scale-aap-up.sh detected database in replica mode and prevented AAP scaling to avoid split-brain scenario"
```

### Log Monitoring

**Keyword:** `CRITICAL ERROR: Database is in RECOVERY mode`

**Action:** Immediate investigation required - indicates:
- Incorrect failover attempt
- Database promotion not completed
- Misconfigured cluster context

---

## Operational Runbook

### Scenario: Split-Brain Check Fails During Failover

**Symptoms:**
- EFM triggers failover
- AAP does not scale up
- Error in logs: `Database is in RECOVERY mode`

**Diagnosis:**

1. **Verify database status:**
   ```bash
   oc exec -n edb-postgres postgresql-1 -- \
     psql -U postgres -c "SELECT pg_is_in_recovery();"
   ```

2. **Check CloudNativePG cluster status:**
   ```bash
   oc get cluster postgresql -n edb-postgres -o yaml
   ```

3. **Check pod labels:**
   ```bash
   oc get pods -n edb-postgres -l cnpg.io/cluster=postgresql --show-labels
   ```

**Resolution:**

**If database should be primary but shows as replica:**

```bash
# Promote manually
oc annotate cluster postgresql -n edb-postgres --overwrite \
  cnpg.io/reconciliationLoop=disabled

# Wait for promotion
sleep 30

# Verify primary status
oc exec -n edb-postgres postgresql-1 -- \
  psql -U postgres -c "SELECT pg_is_in_recovery();"

# Retry AAP scaling
./scripts/scale-aap-up.sh <cluster-context>
```

**If wrong datacenter was targeted:**

```bash
# Scale AAP in correct datacenter
./scripts/scale-aap-up.sh <correct-cluster-context>
```

---

## Limitations

### Current Implementation

1. **Fail-Open on Unknown Status:**
   - If `pg_is_in_recovery()` returns unexpected value, script proceeds with warning
   - **Rationale:** Avoid blocking legitimate failover due to transient query failure
   - **Risk:** Could allow scaling against replica in edge case

2. **No Fencing:**
   - Does not actively prevent AAP from connecting to replica
   - Relies on operator not bypassing script
   - **Mitigation:** Enforce policy that all AAP scaling must use script

3. **Single Query Point:**
   - Checks role once at script start
   - Does not monitor for role changes during scaling
   - **Mitigation:** AAP scaling is fast (~30 seconds), unlikely to change during execution

### Future Enhancements

**Phase 4 (Week 13-16):**

1. **Witness Node:**
   - Deploy 3rd EFM node in neutral location (cloud)
   - Quorum-based failover prevents dual promotion

2. **Database Fencing:**
   - Configure PostgreSQL to reject connections from AAP unless primary
   - Implement via connection validation query

3. **Continuous Monitoring:**
   - Background job validates AAP's connected DB is primary
   - Auto-scale down if replica detected

---

## References

- **PostgreSQL Documentation:** [High Availability, Load Balancing, and Replication](https://www.postgresql.org/docs/current/high-availability.html)
- **CloudNativePG Docs:** [Failover](https://cloudnative-pg.io/documentation/current/failover/)
- **EFM Integration:** `/docs/enterprisefailovermanager.md`
- **DR Scenarios:** `/docs/dr-scenarios.md`
- **Scale AAP Script:** `/scripts/scale-aap-up.sh`

---

## Change Log

| Date | Version | Author | Change |
|------|---------|--------|--------|
| 2026-03-30 | 1.0 | Claude (Backend Architect) | Initial implementation of split-brain prevention in scale-aap-up.sh |

---

**End of Split-Brain Prevention Documentation**
