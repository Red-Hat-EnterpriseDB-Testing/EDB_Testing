# Disaster Recovery Testing Guide

**Version:** 1.0
**Date:** 2026-03-31
**Status:** ✅ PRODUCTION READY

---

## Overview

This guide describes the automated disaster recovery (DR) testing framework for the Ansible Automation Platform with EnterpriseDB PostgreSQL deployment. The framework enables regular, automated testing of failover procedures to validate RTO/RPO targets and maintain organizational confidence in disaster recovery capabilities.

### Purpose

- **Validate** failover procedures work as documented
- **Measure** actual RTO (Recovery Time Objective) and RPO (Recovery Point Objective)
- **Identify** issues before real disasters occur
- **Train** teams on DR procedures through regular drills
- **Maintain** organizational readiness and compliance

### Testing Approach

| Test Type | Frequency | Automation | Scope |
|-----------|-----------|------------|-------|
| **Automated Quarterly** | Every 3 months | Fully automated | Cross-DC failover |
| **Manual Monthly** | Optional | Semi-automated | Component testing |
| **Annual Full** | Yearly | Manual oversight | Complete disaster simulation |

---

## Quick Start

### Prerequisites

- OpenShift cluster contexts configured for DC1 and DC2
- `oc` CLI tool installed and authenticated
- Cluster admin permissions
- Change window approved (for production tests)

### Run Your First Test

**Manual test (recommended for first time):**

```bash
cd /path/to/EDB_Testing/scripts

# Dry run (no actual failover)
./dr-failover-test.sh \
  --dc1-context dc1-cluster \
  --dc2-context dc2-cluster \
  --dry-run

# Actual test with automatic failback skipped
./dr-failover-test.sh \
  --dc1-context dc1-cluster \
  --dc2-context dc2-cluster \
  --skip-failback
```

**Expected output:**

```text
=============================================
DR Failover Test - dr-test-20260331-140530
=============================================
Test ID: dr-test-20260331-140530
DC1 Context: dc1-cluster
DC2 Context: dc2-cluster

Phase 1: Pre-flight Checks
✓ DC1 cluster accessible
✓ DC1 database is PRIMARY
✓ DC2 database is REPLICA
✓ Replication lag acceptable (<30s)

Phase 2: Create Data Baseline
✓ Baseline created successfully

Phase 3: Simulate DC1 Failure
✓ DC1 database scaled to 0
✅ DC2 database promoted to PRIMARY
✅ AAP pods ready in DC2 (12 pods)

Phase 4: Validate Failover
✓ DC2 database confirmed as PRIMARY
✓ Data validation PASSED
✓ AAP API responding

Phase 5: Measure RTO/RPO
RTO: 287.4 seconds (4.79 minutes)
Target: 300 seconds (5 minutes)
Result: ✅ PASSED

✅ Test Complete
```

---

## Testing Framework Components

### 1. Core Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| **`dr-failover-test.sh`** | Main orchestrator | Runs full DR test end-to-end |
| **`validate-aap-data.sh`** | Data integrity validation | Compares pre/post failover data |
| **`measure-rto-rpo.sh`** | Metrics collection | Tracks recovery time/data loss |
| **`generate-dr-report.sh`** | Report generation | Creates test summary reports |

**Location:** `/scripts/`

### 2. OpenShift automation

| Resource | Purpose | Schedule |
|----------|---------|----------|
| **CronJob** | Quarterly automated tests | 1st Sat, Jan/Apr/Jul/Oct @ 02:00 UTC |
| **ConfigMap** | Test scripts and configuration | - |
| **ServiceAccount** | RBAC permissions for test execution | - |
| **PVC** | Persistent storage for test results | 5Gi storage |

**Location:** `/tests/openshift/dr-testing/`

### 3. Test Phases

```text
┌──────────────────────┐
│ Pre-flight Checks    │ ← Validate environment health
└──────────┬───────────┘
           │
┌──────────▼───────────┐
│ Create Baseline      │ ← Snapshot current AAP data
└──────────┬───────────┘
           │
┌──────────▼───────────┐
│ Simulate Failure     │ ← Scale DC1 database to 0
└──────────┬───────────┘
           │
┌──────────▼───────────┐
│ Monitor Failover     │ ← Watch EFM promote DC2, scale AAP
└──────────┬───────────┘
           │
┌──────────▼───────────┐
│ Validate State       │ ← Verify DB role, data integrity, AAP API
└──────────┬───────────┘
           │
┌──────────▼───────────┐
│ Measure RTO/RPO      │ ← Calculate metrics against targets
└──────────┬───────────┘
           │
┌──────────▼───────────┐
│ Generate Report      │ ← Document results and recommendations
└──────────────────────┘
```

---

## Detailed Usage

### Script: dr-failover-test.sh

**Purpose:** Orchestrates complete DR failover test with automated measurement.

**Options:**

```bash
./dr-failover-test.sh [options]

Options:
  --test-id <id>           Custom test identifier (default: auto-generated)
  --dc1-context <context>  OpenShift context for DC1 (required)
  --dc2-context <context>  OpenShift context for DC2 (required)
  --skip-failback          Do not attempt automatic failback after test
  --dry-run                Simulate test without actual failover
```

**Examples:**

```bash
# Standard quarterly test
./dr-failover-test.sh \
  --dc1-context prod-dc1 \
  --dc2-context prod-dc2 \
  --skip-failback

# Dry run for validation
./dr-failover-test.sh \
  --dc1-context prod-dc1 \
  --dc2-context prod-dc2 \
  --dry-run

# Custom test ID for tracking
./dr-failover-test.sh \
  --test-id "Q1-2026-DR-Test" \
  --dc1-context prod-dc1 \
  --dc2-context prod-dc2
```

**Output Files:**

- `/tmp/dr-test-results/<test-id>.log` - Full test log
- `/tmp/dr-metrics/rto-rpo-<test-id>.json` - RTO/RPO metrics
- `/tmp/aap-validation-results/validation-report-*.txt` - Data validation

---

### Script: validate-aap-data.sh

**Purpose:** Validate AAP data integrity by comparing current state to baseline.

**Usage:**

```bash
# Create baseline before failover
./validate-aap-data.sh create-baseline <cluster-context>

# Validate after failover
./validate-aap-data.sh validate <cluster-context>
```

**Metrics Validated:**

- Organizations, Users, Teams
- Inventories, Hosts
- Projects, Job Templates, Workflow Templates
- Credentials, Schedules
- Job execution counts (successful/failed)

**Example:**

```bash
# Before failover - create baseline from DC1
./validate-aap-data.sh create-baseline prod-dc1

# After failover - validate DC2 against baseline
./validate-aap-data.sh validate prod-dc2
```

**Sample Output:**

```text
AAP Data Validation
============================================
Action: validate
Cluster: prod-dc2

Comparing current state to baseline:
-------------------------------------------
  organizations         ✓  Baseline: 3      Current: 3      Diff: 0 (0.0%)
  inventories           ✓  Baseline: 12     Current: 12     Diff: 0 (0.0%)
  job_templates         ✓  Baseline: 45     Current: 45     Diff: 0 (0.0%)
  jobs_total            ↗  Baseline: 1024   Current: 1032   Diff: +8 (0.8%)
-------------------------------------------

Status: ✅ PASSED
All metrics match baseline exactly.
```

---

### Script: measure-rto-rpo.sh

**Purpose:** Track milestones and calculate RTO/RPO metrics during DR tests.

**Usage:**

```bash
# Start measurement
./measure-rto-rpo.sh start <test-id>

# Record milestone
./measure-rto-rpo.sh milestone <test-id> <milestone-name>

# Complete measurement
./measure-rto-rpo.sh complete <test-id>

# Generate report
./measure-rto-rpo.sh report <test-id>
```

**Example:**

```bash
# Start tracking
./measure-rto-rpo.sh start dr-test-001

# Record key events
./measure-rto-rpo.sh milestone dr-test-001 "database_promoted"
./measure-rto-rpo.sh milestone dr-test-001 "aap_ready"
./measure-rto-rpo.sh milestone dr-test-001 "api_responding"

# Finalize metrics
./measure-rto-rpo.sh complete dr-test-001

# View report
./measure-rto-rpo.sh report dr-test-001
```

**Output:**

```text
RTO/RPO Measurement Report
============================================
Test ID: dr-test-001

Test Timeline:
-------------------------------------------
Start: 2026-03-31 14:05:30.123
  + database_promoted            45.234s
  + aap_ready                   124.567s
  + api_responding              142.890s
  + test_complete               287.456s
-------------------------------------------

Recovery Time Objective (RTO):
  Measured: 287.456s
  Status: ✅ PASSED (target: 300s)

Recovery Point Objective (RPO):
  Status: ℹ️  Not measured (manual validation required)
```

---

### Script: generate-dr-report.sh

**Purpose:** Generate comprehensive Markdown reports from test results.

**Usage:**

```bash
# Generate report for specific test
./generate-dr-report.sh <test-id>

# Generate report for latest test
./generate-dr-report.sh --latest
```

**Output:**

- **Markdown report:** `/tmp/dr-reports/<test-id>-report.md`
- **Text summary:** `/tmp/dr-reports/<test-id>-summary.txt`

**Report Sections:**

1. Executive Summary (key metrics, pass/fail)
2. Test Execution Timeline
3. Phase-by-phase results
4. Data Validation Results
5. Issues & Observations
6. Recommendations
7. Appendix (full logs)

---

## Automated Testing (OpenShift CronJob)

### Deploy Automated Testing

**1. Configure cluster contexts:**

Edit `/tests/openshift/dr-testing/kustomization.yaml`:

```yaml
configMapGenerator:
- name: dr-test-config
  literals:
  - dc1-context=your-dc1-context
  - dc2-context=your-dc2-context
```

**2. Create kubeconfig secret:**

```bash
oc create secret generic dr-test-kubeconfig \
  --from-file=config=$HOME/.kube/config \
  -n edb-postgres
```

**3. Deploy CronJob:**

```bash
cd tests/openshift/dr-testing
oc apply -k .
```

**4. Verify deployment:**

```bash
oc get cronjob dr-test-quarterly -n edb-postgres
oc describe cronjob dr-test-quarterly -n edb-postgres
```

### Schedule Configuration

**Default:** Quarterly on first Saturday at 02:00 UTC

**Modify schedule** in `cronjob-dr-test.yaml`:

```yaml
spec:
  # Monthly on first Saturday
  schedule: "0 2 1-7 * 6"

  # Every Sunday at 03:00
  schedule: "0 3 * * 0"
```

### Manual Trigger

```bash
# Create one-time job from CronJob
oc create job dr-test-manual-$(date +%Y%m%d) \
  --from=cronjob/dr-test-quarterly \
  -n edb-postgres

# Watch logs
oc logs -f job/dr-test-manual-YYYYMMDD -n edb-postgres
```

### Notifications

**Slack Integration:**

```yaml
# In kustomization.yaml
secretGenerator:
- name: dr-test-secrets
  literals:
  - slack-webhook-url=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

**PagerDuty (on failure):**

```yaml
- pagerduty-token=YOUR_PAGERDUTY_TOKEN
```

---

## Best Practices

### Pre-Test Checklist

- [ ] Change window approved and communicated
- [ ] All stakeholders notified
- [ ] Recent backup completed and verified
- [ ] Replication lag < 30 seconds
- [ ] No critical AAP jobs running
- [ ] On-call engineer available
- [ ] Rollback plan documented

### During Test

- [ ] Monitor test logs in real-time
- [ ] Track actual vs expected timings
- [ ] Document any deviations
- [ ] Take notes for post-test review

### Post-Test Checklist

- [ ] Review RTO/RPO metrics
- [ ] Validate data integrity
- [ ] Generate and distribute report
- [ ] Schedule post-test review meeting
- [ ] Update runbooks with findings
- [ ] File issues for any failures
- [ ] Plan remediation actions

---

## Interpreting Results

### RTO (Recovery Time Objective)

**Target:** < 300 seconds (5 minutes)

**Measurement:** Time from failure detection to full service restoration

**Milestones:**

1. **Failure Detected:** EFM recognizes primary is down
2. **Database Promoted:** DC2 replica becomes primary
3. **AAP Scaled:** AAP pods start in DC2
4. **AAP Ready:** AAP API responding
5. **First Job:** Successful job execution

**Pass/Fail:**

- ✅ **PASS:** Total RTO ≤ 300s
- ⚠️ **WARNING:** 300s < RTO ≤ 360s (within 20% of target)
- ❌ **FAIL:** RTO > 360s

**Troubleshooting slow RTO:**

- Check EFM health check interval (faster detection)
- Optimize AAP startup (readiness probes, resource limits)
- Review network latency between DCs
- Tune database promotion time

### RPO (Recovery Point Objective)

**Target:** < 5 seconds (data loss)

**Measurement:** Time between last committed transaction and recovery point

**Validation:**

1. Query `pg_last_xact_replay_timestamp()` on promoted replica
2. Compare job execution counts pre/post failover
3. Check for missing transactions in AAP database

**Pass/Fail:**

- ✅ **PASS:** Zero data loss OR < 5s lag at promotion
- ⚠️ **WARNING:** 5-30s data loss
- ❌ **FAIL:** > 30s data loss

**Troubleshooting data loss:**

- Verify streaming replication is configured
- Check replication lag before test (should be < 1s)
- Investigate network issues causing lag spikes
- Consider synchronous replication for zero data loss

### Data Validation

**Metrics checked:**

| Metric | Expected | Action if Different |
|--------|----------|---------------------|
| Organizations | Unchanged | Investigate |
| Users | Unchanged | Investigate |
| Inventories | Unchanged | Investigate |
| Job Templates | Unchanged | Investigate |
| Jobs Total | Increased (↗) | Normal |
| Jobs Failed | May increase | Review failures |

**Status:**

- ✅ **PASSED:** All critical metrics match baseline
- ⚠️ **WARNING:** Job counts changed (normal)
- ❌ **FAILED:** Configuration data decreased

---

## Troubleshooting

### Test Fails at Pre-flight

**Symptoms:** Test exits before failover simulation

**Common Causes:**

1. Cannot access cluster contexts
2. Database not in expected state (DC1 not primary)
3. High replication lag

**Resolution:**

```bash
# Verify cluster access
oc config get-contexts
oc config use-context dc1-cluster
oc get pods -n edb-postgres

# Check database status
oc exec -n edb-postgres postgresql-1 -- \
  psql -U postgres -c "SELECT pg_is_in_recovery();"

# Check replication lag
oc exec -n edb-postgres postgresql-1 -- \
  psql -U postgres -c "SELECT * FROM pg_stat_replication;"
```

### Database Not Promoting

**Symptoms:** DC2 database stays in replica mode after 5 minutes

**Causes:**

1. EFM not configured properly
2. Network partition prevents promotion
3. Manual promotion required

**Resolution:**

```bash
# Manually promote DC2 database
oc config use-context dc2-cluster

oc annotate cluster postgresql-replica -n edb-postgres --overwrite \
  cnpg.io/reconciliationLoop=disabled

# Wait 30 seconds
sleep 30

# Verify promotion
oc exec -n edb-postgres postgresql-replica-1 -- \
  psql -U postgres -c "SELECT pg_is_in_recovery();"
# Should return 'f' (false)
```

### AAP Not Scaling Up

**Symptoms:** AAP pods remain at 0 in DC2 after promotion

**Causes:**

1. EFM post-promotion hook not configured
2. Split-brain prevention blocking scale-up
3. Resource constraints

**Resolution:**

```bash
# Check if database is truly primary
oc config use-context dc2-cluster
oc exec -n edb-postgres postgresql-replica-1 -- \
  psql -U postgres -c "SELECT pg_is_in_recovery();"

# Manually scale AAP if needed
cd /path/to/EDB_Testing/scripts
./scale-aap-up.sh dc2-cluster

# Check for resource issues
oc describe nodes | grep -A 5 "Allocated resources"
```

### Data Validation Failures

**Symptoms:** Metrics show decreased counts after failover

**Causes:**

1. Replication lag at time of failure
2. Data corruption
3. Baseline created from wrong cluster

**Resolution:**

```bash
# Re-create baseline from DC2 (now primary)
./validate-aap-data.sh create-baseline dc2-cluster

# Re-run validation
./validate-aap-data.sh validate dc2-cluster

# If still failing, check replication
oc logs -n edb-postgres postgresql-replica-1 | grep -i error
```

---

## Advanced Topics

### Custom Test Scenarios

**Simulate specific failure types:**

```bash
# Network partition (block replication traffic)
# Edit Route to remove service
oc delete route postgresql-replication -n edb-postgres

# Storage failure (delete PVC)
# NOT RECOMMENDED - use annotation instead
oc annotate pvc data-postgresql-1 -n edb-postgres failure-test=true

# AAP node failure (drain node)
oc adm drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

### Integration with Chaos Engineering

```bash
# Use with LitmusChaos
kubectl apply -f - <<EOF
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: dr-test-chaos
spec:
  engineState: "active"
  experiments:
  - name: pod-delete
    spec:
      components:
        env:
        - name: TARGET_POD
          value: "postgresql-1"
EOF
```

### Metrics Collection for Trend Analysis

**Export metrics to Prometheus:**

```bash
# After each test, push metrics
cat <<EOF | curl --data-binary @- http://pushgateway:9091/metrics/job/dr-test
# TYPE dr_test_rto_seconds gauge
dr_test_rto_seconds{test_id="$TEST_ID"} $RTO
# TYPE dr_test_success gauge
dr_test_success{test_id="$TEST_ID"} 1
EOF
```

**Create Grafana dashboard:**

```promql
# RTO over time
dr_test_rto_seconds{job="dr-test"}

# Success rate
rate(dr_test_success{job="dr-test"}[30d])
```

---

## Compliance & Auditing

### Documentation Requirements

For compliance (SOC 2, ISO 27001, etc.), maintain:

1. **Test Schedule:** Documented and approved
2. **Test Results:** Retained for 12+ months
3. **Remediation Plans:** For any failures
4. **Sign-offs:** From stakeholders

### Audit Trail

**Files to retain:**

```text
/tmp/dr-test-results/<test-id>.log
/tmp/dr-metrics/rto-rpo-<test-id>.json
/tmp/aap-validation-results/validation-report-*.txt
/tmp/dr-reports/<test-id>-report.md
```

**Recommended:** Archive to S3 with lifecycle policies

```bash
# Archive results to S3
aws s3 sync /tmp/dr-test-results/ \
  s3://compliance-archives/dr-tests/ \
  --storage-class STANDARD_IA
```

---

## FAQ

**Q: How often should we run DR tests?**

A: Minimum quarterly for production systems. Monthly for mission-critical systems.

**Q: Do tests impact production?**

A: Yes - tests simulate real failures. Schedule during approved maintenance windows.

**Q: Can we test without impacting users?**

A: Use `--dry-run` flag for validation without actual failover.

**Q: What if a test fails?**

A: Document findings, create remediation plan, fix issues, and re-test within 30 days.

**Q: How long do tests take?**

A: Typically 5-10 minutes for automated tests, 1-2 hours for full annual drills.

**Q: Can we run tests in staging first?**

A: Yes - highly recommended to validate procedures before production testing.

---

## References

- **Split-Brain Prevention:** [/docs/split-brain-prevention.md](/docs/split-brain-prevention.md)
- **DR Scenarios:** [/docs/dr-scenarios.md](/docs/dr-scenarios.md)
- **Replication Validation:** [/reports/dr-replication-validation-report.md](/reports/dr-replication-validation-report.md)
- **EFM Integration:** [/docs/enterprisefailovermanager.md](/docs/enterprisefailovermanager.md)

---

## Change Log

| Date | Version | Change | Author |
|------|---------|--------|--------|
| 2026-03-31 | 1.0 | Initial DR testing framework | SRE Team |

---

**Status:** ✅ Production ready - Quarterly automated testing active
